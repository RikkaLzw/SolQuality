
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
        address tokenSell;
        address tokenBuy;
        uint256 amountSell;
        uint256 amountBuy;
        uint256 timestamp;
        bool isFilled;
        bool isCancelled;
    }


    uint256 public constant TRADING_FEE = 30;
    uint256 public constant FEE_DENOMINATOR = 10000;

    address public owner;
    bool public paused;

    event PairCreated(bytes32 indexed pairId, address indexed tokenA, address indexed tokenB);
    event LiquidityAdded(bytes32 indexed pairId, address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(bytes32 indexed pairId, address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event OrderPlaced(bytes32 indexed orderId, address indexed trader, bytes32 indexed pairId, uint256 amountSell, uint256 amountBuy);
    event OrderFilled(bytes32 indexed orderId, address indexed trader, uint256 amountFilled);
    event OrderCancelled(bytes32 indexed orderId, address indexed trader);
    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdrawal(address indexed user, address indexed token, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier notPaused() {
        require(!paused, "Contract paused");
        _;
    }

    modifier validAddress(address addr) {
        require(addr != address(0), "Invalid address");
        _;
    }

    constructor() {
        owner = msg.sender;
        paused = false;
    }

    function createTradingPair(address tokenA, address tokenB)
        external
        onlyOwner
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

    function deposit(address token, uint256 amount)
        external
        notPaused
        validAddress(token)
    {
        require(amount > 0, "Amount must be positive");

        IERC20(token).transferFrom(msg.sender, address(this), amount);
        userBalances[msg.sender][token] += amount;

        emit Deposit(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount)
        external
        notPaused
        validAddress(token)
    {
        require(amount > 0, "Amount must be positive");
        require(userBalances[msg.sender][token] >= amount, "Insufficient balance");

        userBalances[msg.sender][token] -= amount;
        IERC20(token).transfer(msg.sender, amount);

        emit Withdrawal(msg.sender, token, amount);
    }

    function addLiquidity(
        bytes32 pairId,
        uint256 amountA,
        uint256 amountB
    ) external notPaused returns (uint256 liquidity) {
        require(pairExists[pairId], "Pair does not exist");
        require(amountA > 0 && amountB > 0, "Amounts must be positive");

        TradingPair storage pair = tradingPairs[pairId];
        require(pair.isActive, "Pair not active");

        require(userBalances[msg.sender][pair.tokenA] >= amountA, "Insufficient tokenA balance");
        require(userBalances[msg.sender][pair.tokenB] >= amountB, "Insufficient tokenB balance");

        if (pair.totalLiquidity == 0) {
            liquidity = sqrt(amountA * amountB);
        } else {
            uint256 liquidityA = (amountA * pair.totalLiquidity) / pair.reserveA;
            uint256 liquidityB = (amountB * pair.totalLiquidity) / pair.reserveB;
            liquidity = liquidityA < liquidityB ? liquidityA : liquidityB;
        }

        require(liquidity > 0, "Insufficient liquidity minted");

        userBalances[msg.sender][pair.tokenA] -= amountA;
        userBalances[msg.sender][pair.tokenB] -= amountB;

        pair.reserveA += amountA;
        pair.reserveB += amountB;
        pair.totalLiquidity += liquidity;

        emit LiquidityAdded(pairId, msg.sender, amountA, amountB, liquidity);
    }

    function removeLiquidity(
        bytes32 pairId,
        uint256 liquidity
    ) external notPaused returns (uint256 amountA, uint256 amountB) {
        require(pairExists[pairId], "Pair does not exist");
        require(liquidity > 0, "Liquidity must be positive");

        TradingPair storage pair = tradingPairs[pairId];
        require(pair.totalLiquidity >= liquidity, "Insufficient total liquidity");

        amountA = (liquidity * pair.reserveA) / pair.totalLiquidity;
        amountB = (liquidity * pair.reserveB) / pair.totalLiquidity;

        require(amountA > 0 && amountB > 0, "Insufficient liquidity burned");

        pair.reserveA -= amountA;
        pair.reserveB -= amountB;
        pair.totalLiquidity -= liquidity;

        userBalances[msg.sender][pair.tokenA] += amountA;
        userBalances[msg.sender][pair.tokenB] += amountB;

        emit LiquidityRemoved(pairId, msg.sender, amountA, amountB, liquidity);
    }

    function placeOrder(
        bytes32 pairId,
        address tokenSell,
        address tokenBuy,
        uint256 amountSell,
        uint256 amountBuy
    ) external notPaused returns (bytes32 orderId) {
        require(pairExists[pairId], "Pair does not exist");
        require(amountSell > 0 && amountBuy > 0, "Amounts must be positive");
        require(tokenSell != tokenBuy, "Cannot trade same token");
        require(userBalances[msg.sender][tokenSell] >= amountSell, "Insufficient balance");

        TradingPair storage pair = tradingPairs[pairId];
        require(pair.isActive, "Pair not active");
        require(
            (tokenSell == pair.tokenA && tokenBuy == pair.tokenB) ||
            (tokenSell == pair.tokenB && tokenBuy == pair.tokenA),
            "Invalid token pair"
        );

        orderId = keccak256(abi.encodePacked(
            msg.sender,
            tokenSell,
            tokenBuy,
            amountSell,
            amountBuy,
            block.timestamp,
            userOrderCounts[msg.sender]++
        ));

        userBalances[msg.sender][tokenSell] -= amountSell;

        orderBooks[pairId].push(Order({
            orderId: orderId,
            trader: msg.sender,
            tokenSell: tokenSell,
            tokenBuy: tokenBuy,
            amountSell: amountSell,
            amountBuy: amountBuy,
            timestamp: block.timestamp,
            isFilled: false,
            isCancelled: false
        }));

        emit OrderPlaced(orderId, msg.sender, pairId, amountSell, amountBuy);
    }

    function cancelOrder(bytes32 pairId, bytes32 orderId) external notPaused {
        require(pairExists[pairId], "Pair does not exist");

        Order[] storage orders = orderBooks[pairId];
        bool found = false;

        for (uint256 i = 0; i < orders.length; i++) {
            if (orders[i].orderId == orderId) {
                require(orders[i].trader == msg.sender, "Not order owner");
                require(!orders[i].isFilled, "Order already filled");
                require(!orders[i].isCancelled, "Order already cancelled");

                orders[i].isCancelled = true;
                userBalances[msg.sender][orders[i].tokenSell] += orders[i].amountSell;
                found = true;
                break;
            }
        }

        require(found, "Order not found");
        emit OrderCancelled(orderId, msg.sender);
    }

    function executeSwap(
        bytes32 pairId,
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut
    ) external notPaused returns (uint256 amountOut) {
        require(pairExists[pairId], "Pair does not exist");
        require(amountIn > 0, "Amount must be positive");
        require(userBalances[msg.sender][tokenIn] >= amountIn, "Insufficient balance");

        TradingPair storage pair = tradingPairs[pairId];
        require(pair.isActive, "Pair not active");

        address tokenOut;
        uint256 reserveIn;
        uint256 reserveOut;

        if (tokenIn == pair.tokenA) {
            tokenOut = pair.tokenB;
            reserveIn = pair.reserveA;
            reserveOut = pair.reserveB;
        } else if (tokenIn == pair.tokenB) {
            tokenOut = pair.tokenA;
            reserveIn = pair.reserveB;
            reserveOut = pair.reserveA;
        } else {
            revert("Invalid token");
        }

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - TRADING_FEE);
        amountOut = (amountInWithFee * reserveOut) / (reserveIn * FEE_DENOMINATOR + amountInWithFee);

        require(amountOut >= minAmountOut, "Insufficient output amount");
        require(amountOut < reserveOut, "Insufficient liquidity");

        userBalances[msg.sender][tokenIn] -= amountIn;
        userBalances[msg.sender][tokenOut] += amountOut;

        if (tokenIn == pair.tokenA) {
            pair.reserveA += amountIn;
            pair.reserveB -= amountOut;
        } else {
            pair.reserveB += amountIn;
            pair.reserveA -= amountOut;
        }
    }

    function getAmountOut(
        bytes32 pairId,
        address tokenIn,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        require(pairExists[pairId], "Pair does not exist");
        require(amountIn > 0, "Amount must be positive");

        TradingPair storage pair = tradingPairs[pairId];

        uint256 reserveIn;
        uint256 reserveOut;

        if (tokenIn == pair.tokenA) {
            reserveIn = pair.reserveA;
            reserveOut = pair.reserveB;
        } else if (tokenIn == pair.tokenB) {
            reserveIn = pair.reserveB;
            reserveOut = pair.reserveA;
        } else {
            revert("Invalid token");
        }

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - TRADING_FEE);
        amountOut = (amountInWithFee * reserveOut) / (reserveIn * FEE_DENOMINATOR + amountInWithFee);
    }

    function getPairInfo(bytes32 pairId) external view returns (
        address tokenA,
        address tokenB,
        uint256 reserveA,
        uint256 reserveB,
        uint256 totalLiquidity,
        bool isActive
    ) {
        require(pairExists[pairId], "Pair does not exist");
        TradingPair storage pair = tradingPairs[pairId];
        return (
            pair.tokenA,
            pair.tokenB,
            pair.reserveA,
            pair.reserveB,
            pair.totalLiquidity,
            pair.isActive
        );
    }

    function getOrderBookLength(bytes32 pairId) external view returns (uint256) {
        return orderBooks[pairId].length;
    }

    function getOrder(bytes32 pairId, uint256 index) external view returns (
        bytes32 orderId,
        address trader,
        address tokenSell,
        address tokenBuy,
        uint256 amountSell,
        uint256 amountBuy,
        uint256 timestamp,
        bool isFilled,
        bool isCancelled
    ) {
        require(index < orderBooks[pairId].length, "Index out of bounds");
        Order storage order = orderBooks[pairId][index];
        return (
            order.orderId,
            order.trader,
            order.tokenSell,
            order.tokenBuy,
            order.amountSell,
            order.amountBuy,
            order.timestamp,
            order.isFilled,
            order.isCancelled
        );
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    function setPairActive(bytes32 pairId, bool _isActive) external onlyOwner {
        require(pairExists[pairId], "Pair does not exist");
        tradingPairs[pairId].isActive = _isActive;
    }

    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
