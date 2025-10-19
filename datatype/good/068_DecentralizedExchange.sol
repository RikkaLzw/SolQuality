
pragma solidity ^0.8.19;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract DecentralizedExchange {

    mapping(bytes32 => TradingPair) public tradingPairs;
    mapping(address => mapping(address => uint256)) public userBalances;
    mapping(bytes32 => Order[]) public orderBooks;
    mapping(address => uint256) public userOrderCounts;
    mapping(bytes32 => bool) public pairExists;

    struct TradingPair {
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalLiquidity;
        bool isActive;
    }

    struct Order {
        bytes32 orderId;
        address trader;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint256 timestamp;
        bool isFilled;
        bool isBuyOrder;
    }


    uint16 public constant FEE_RATE = 30;
    uint16 public constant FEE_DENOMINATOR = 10000;

    address public owner;
    bool public paused;

    event PairCreated(bytes32 indexed pairId, address indexed tokenA, address indexed tokenB);
    event LiquidityAdded(bytes32 indexed pairId, address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(bytes32 indexed pairId, address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event OrderPlaced(bytes32 indexed orderId, address indexed trader, bytes32 indexed pairId, uint256 amountIn, uint256 amountOut, bool isBuyOrder);
    event OrderFilled(bytes32 indexed orderId, address indexed trader, uint256 amountIn, uint256 amountOut);
    event Swap(bytes32 indexed pairId, address indexed trader, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract paused");
        _;
    }

    modifier validPair(bytes32 pairId) {
        require(pairExists[pairId], "Pair does not exist");
        _;
    }

    constructor() {
        owner = msg.sender;
        paused = false;
    }

    function createTradingPair(address tokenA, address tokenB) external onlyOwner returns (bytes32 pairId) {
        require(tokenA != tokenB, "Identical tokens");
        require(tokenA != address(0) && tokenB != address(0), "Zero address");


        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }

        pairId = keccak256(abi.encodePacked(tokenA, tokenB));
        require(!pairExists[pairId], "Pair already exists");

        tradingPairs[pairId] = TradingPair({
            tokenA: tokenA,
            tokenB: tokenB,
            reserveA: 0,
            reserveB: 0,
            totalLiquidity: 0,
            isActive: true
        });

        pairExists[pairId] = true;

        emit PairCreated(pairId, tokenA, tokenB);
    }

    function addLiquidity(
        bytes32 pairId,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) external whenNotPaused validPair(pairId) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        TradingPair storage pair = tradingPairs[pairId];
        require(pair.isActive, "Pair not active");

        if (pair.reserveA == 0 && pair.reserveB == 0) {
            amountA = amountADesired;
            amountB = amountBDesired;
        } else {
            uint256 amountBOptimal = (amountADesired * pair.reserveB) / pair.reserveA;
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "Insufficient B amount");
                amountA = amountADesired;
                amountB = amountBOptimal;
            } else {
                uint256 amountAOptimal = (amountBDesired * pair.reserveA) / pair.reserveB;
                require(amountAOptimal <= amountADesired && amountAOptimal >= amountAMin, "Insufficient A amount");
                amountA = amountAOptimal;
                amountB = amountBDesired;
            }
        }

        IERC20(pair.tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(pair.tokenB).transferFrom(msg.sender, address(this), amountB);

        if (pair.totalLiquidity == 0) {
            liquidity = sqrt(amountA * amountB);
        } else {
            liquidity = min((amountA * pair.totalLiquidity) / pair.reserveA, (amountB * pair.totalLiquidity) / pair.reserveB);
        }

        require(liquidity > 0, "Insufficient liquidity minted");

        pair.reserveA += amountA;
        pair.reserveB += amountB;
        pair.totalLiquidity += liquidity;
        userBalances[msg.sender][address(this)] += liquidity;

        emit LiquidityAdded(pairId, msg.sender, amountA, amountB, liquidity);
    }

    function removeLiquidity(
        bytes32 pairId,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin
    ) external whenNotPaused validPair(pairId) returns (uint256 amountA, uint256 amountB) {
        TradingPair storage pair = tradingPairs[pairId];
        require(userBalances[msg.sender][address(this)] >= liquidity, "Insufficient liquidity");

        amountA = (liquidity * pair.reserveA) / pair.totalLiquidity;
        amountB = (liquidity * pair.reserveB) / pair.totalLiquidity;

        require(amountA >= amountAMin && amountB >= amountBMin, "Insufficient output amount");

        userBalances[msg.sender][address(this)] -= liquidity;
        pair.totalLiquidity -= liquidity;
        pair.reserveA -= amountA;
        pair.reserveB -= amountB;

        IERC20(pair.tokenA).transfer(msg.sender, amountA);
        IERC20(pair.tokenB).transfer(msg.sender, amountB);

        emit LiquidityRemoved(pairId, msg.sender, amountA, amountB, liquidity);
    }

    function swapExactTokensForTokens(
        bytes32 pairId,
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn
    ) external whenNotPaused validPair(pairId) returns (uint256 amountOut) {
        TradingPair storage pair = tradingPairs[pairId];
        require(pair.isActive, "Pair not active");
        require(tokenIn == pair.tokenA || tokenIn == pair.tokenB, "Invalid token");

        bool isTokenA = tokenIn == pair.tokenA;
        address tokenOut = isTokenA ? pair.tokenB : pair.tokenA;
        uint256 reserveIn = isTokenA ? pair.reserveA : pair.reserveB;
        uint256 reserveOut = isTokenA ? pair.reserveB : pair.reserveA;

        amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        require(amountOut >= amountOutMin, "Insufficient output amount");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).transfer(msg.sender, amountOut);

        if (isTokenA) {
            pair.reserveA += amountIn;
            pair.reserveB -= amountOut;
        } else {
            pair.reserveB += amountIn;
            pair.reserveA -= amountOut;
        }

        emit Swap(pairId, msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    function placeOrder(
        bytes32 pairId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        bool isBuyOrder
    ) external whenNotPaused validPair(pairId) returns (bytes32 orderId) {
        require(amountIn > 0 && amountOut > 0, "Invalid amounts");

        orderId = keccak256(abi.encodePacked(msg.sender, block.timestamp, userOrderCounts[msg.sender]));
        userOrderCounts[msg.sender]++;

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        Order memory newOrder = Order({
            orderId: orderId,
            trader: msg.sender,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            amountOut: amountOut,
            timestamp: block.timestamp,
            isFilled: false,
            isBuyOrder: isBuyOrder
        });

        orderBooks[pairId].push(newOrder);

        emit OrderPlaced(orderId, msg.sender, pairId, amountIn, amountOut, isBuyOrder);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256 amountOut) {
        require(amountIn > 0, "Insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_RATE);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function getReserves(bytes32 pairId) external view validPair(pairId) returns (uint256 reserveA, uint256 reserveB) {
        TradingPair storage pair = tradingPairs[pairId];
        reserveA = pair.reserveA;
        reserveB = pair.reserveB;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    function setPairActive(bytes32 pairId, bool _isActive) external onlyOwner validPair(pairId) {
        tradingPairs[pairId].isActive = _isActive;
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }
}
