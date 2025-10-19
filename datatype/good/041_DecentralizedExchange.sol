
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
    event Swap(address indexed trader, bytes32 indexed pairId, uint256 amountIn, uint256 amountOut, address tokenIn, address tokenOut);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier notPaused() {
        require(!paused, "Contract paused");
        _;
    }

    modifier validAddress(address _addr) {
        require(_addr != address(0), "Invalid address");
        _;
    }

    constructor() {
        owner = msg.sender;
        paused = false;
    }

    function createTradingPair(address tokenA, address tokenB)
        external
        validAddress(tokenA)
        validAddress(tokenB)
        returns (bytes32 pairId)
    {
        require(tokenA != tokenB, "Identical tokens");


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
        uint256 amountA,
        uint256 amountB
    ) external notPaused returns (uint256 liquidity) {
        require(pairExists[pairId], "Pair does not exist");
        require(amountA > 0 && amountB > 0, "Invalid amounts");

        TradingPair storage pair = tradingPairs[pairId];
        require(pair.isActive, "Pair not active");

        IERC20(pair.tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(pair.tokenB).transferFrom(msg.sender, address(this), amountB);

        if (pair.totalLiquidity == 0) {
            liquidity = sqrt(amountA * amountB);
        } else {
            uint256 liquidityA = (amountA * pair.totalLiquidity) / pair.reserveA;
            uint256 liquidityB = (amountB * pair.totalLiquidity) / pair.reserveB;
            liquidity = liquidityA < liquidityB ? liquidityA : liquidityB;
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
        uint256 liquidity
    ) external notPaused returns (uint256 amountA, uint256 amountB) {
        require(pairExists[pairId], "Pair does not exist");
        require(liquidity > 0, "Invalid liquidity amount");
        require(userBalances[msg.sender][address(this)] >= liquidity, "Insufficient liquidity balance");

        TradingPair storage pair = tradingPairs[pairId];
        require(pair.totalLiquidity > 0, "No liquidity");

        amountA = (liquidity * pair.reserveA) / pair.totalLiquidity;
        amountB = (liquidity * pair.reserveB) / pair.totalLiquidity;

        require(amountA > 0 && amountB > 0, "Insufficient liquidity burned");

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
    ) external notPaused returns (uint256 amountOut) {
        require(pairExists[pairId], "Pair does not exist");
        require(amountIn > 0, "Invalid input amount");

        TradingPair storage pair = tradingPairs[pairId];
        require(pair.isActive, "Pair not active");
        require(tokenIn == pair.tokenA || tokenIn == pair.tokenB, "Invalid token");

        bool isTokenA = tokenIn == pair.tokenA;
        uint256 reserveIn = isTokenA ? pair.reserveA : pair.reserveB;
        uint256 reserveOut = isTokenA ? pair.reserveB : pair.reserveA;
        address tokenOut = isTokenA ? pair.tokenB : pair.tokenA;

        amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        require(amountOut >= amountOutMin, "Insufficient output amount");
        require(amountOut < reserveOut, "Insufficient liquidity");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        if (isTokenA) {
            pair.reserveA += amountIn;
            pair.reserveB -= amountOut;
        } else {
            pair.reserveB += amountIn;
            pair.reserveA -= amountOut;
        }

        IERC20(tokenOut).transfer(msg.sender, amountOut);

        emit Swap(msg.sender, pairId, amountIn, amountOut, tokenIn, tokenOut);
    }

    function placeOrder(
        bytes32 pairId,
        uint256 amountIn,
        uint256 amountOut,
        address tokenIn,
        bool isBuyOrder
    ) external notPaused returns (bytes32 orderId) {
        require(pairExists[pairId], "Pair does not exist");
        require(amountIn > 0 && amountOut > 0, "Invalid amounts");

        TradingPair storage pair = tradingPairs[pairId];
        require(pair.isActive, "Pair not active");
        require(tokenIn == pair.tokenA || tokenIn == pair.tokenB, "Invalid token");

        orderId = keccak256(abi.encodePacked(msg.sender, block.timestamp, userOrderCounts[msg.sender]));
        userOrderCounts[msg.sender]++;

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        Order memory newOrder = Order({
            orderId: orderId,
            trader: msg.sender,
            tokenIn: tokenIn,
            tokenOut: tokenIn == pair.tokenA ? pair.tokenB : pair.tokenA,
            amountIn: amountIn,
            amountOut: amountOut,
            timestamp: block.timestamp,
            isFilled: false,
            isBuyOrder: isBuyOrder
        });

        orderBooks[pairId].push(newOrder);

        emit OrderPlaced(orderId, msg.sender, pairId, amountIn, amountOut, isBuyOrder);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "Invalid input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_RATE);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        returns (uint256 amountIn)
    {
        require(amountOut > 0, "Invalid output amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");
        require(amountOut < reserveOut, "Insufficient liquidity");

        uint256 numerator = reserveIn * amountOut * FEE_DENOMINATOR;
        uint256 denominator = (reserveOut - amountOut) * (FEE_DENOMINATOR - FEE_RATE);
        amountIn = (numerator / denominator) + 1;
    }

    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    function setPairActive(bytes32 pairId, bool _isActive) external onlyOwner {
        require(pairExists[pairId], "Pair does not exist");
        tradingPairs[pairId].isActive = _isActive;
    }

    function getReserves(bytes32 pairId) external view returns (uint256 reserveA, uint256 reserveB) {
        require(pairExists[pairId], "Pair does not exist");
        TradingPair storage pair = tradingPairs[pairId];
        reserveA = pair.reserveA;
        reserveB = pair.reserveB;
    }

    function getOrderBookLength(bytes32 pairId) external view returns (uint256) {
        return orderBooks[pairId].length;
    }

    function getOrder(bytes32 pairId, uint256 index) external view returns (Order memory) {
        require(index < orderBooks[pairId].length, "Invalid index");
        return orderBooks[pairId][index];
    }
}
