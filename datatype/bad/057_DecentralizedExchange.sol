
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract DecentralizedExchange {

    uint256 public feePercentage = 3;
    uint256 public maxSlippage = 5;
    uint256 public orderCounter = 0;


    string public exchangeName = "DEX";
    string public version = "1.0";


    mapping(address => bytes) public userProfiles;
    mapping(uint256 => bytes) public orderHashes;


    mapping(address => uint256) public isAuthorizedTrader;
    mapping(address => uint256) public isPaused;
    uint256 public exchangeActive = 1;

    address public owner;
    mapping(address => mapping(address => uint256)) public liquidity;
    mapping(address => uint256) public reserves;

    struct Order {
        address trader;
        address tokenA;
        address tokenB;
        uint256 amountA;
        uint256 amountB;
        uint256 timestamp;
        uint256 isActive;
    }

    mapping(uint256 => Order) public orders;

    event LiquidityAdded(address indexed provider, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);
    event LiquidityRemoved(address indexed provider, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);
    event TokensSwapped(address indexed trader, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event OrderCreated(uint256 indexed orderId, address indexed trader, address tokenA, address tokenB, uint256 amountA, uint256 amountB);
    event OrderExecuted(uint256 indexed orderId, address indexed executor);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyAuthorized() {
        require(isAuthorizedTrader[msg.sender] == 1, "Not authorized");
        _;
    }

    modifier whenActive() {
        require(exchangeActive == 1, "Exchange paused");
        _;
    }

    constructor() {
        owner = msg.sender;

        isAuthorizedTrader[msg.sender] = uint256(1);
        exchangeActive = uint256(1);
    }

    function setAuthorizedTrader(address trader, uint256 status) external onlyOwner {

        isAuthorizedTrader[trader] = uint256(status);
    }

    function setExchangeStatus(uint256 status) external onlyOwner {

        exchangeActive = uint256(status);
    }

    function setUserProfile(bytes memory profile) external {
        userProfiles[msg.sender] = profile;
    }

    function addLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) external whenActive {
        require(tokenA != tokenB, "Same token");
        require(amountA > 0 && amountB > 0, "Invalid amounts");

        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        liquidity[msg.sender][tokenA] += amountA;
        liquidity[msg.sender][tokenB] += amountB;
        reserves[tokenA] += amountA;
        reserves[tokenB] += amountB;

        emit LiquidityAdded(msg.sender, tokenA, tokenB, amountA, amountB);
    }

    function removeLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) external whenActive {
        require(liquidity[msg.sender][tokenA] >= amountA, "Insufficient liquidity A");
        require(liquidity[msg.sender][tokenB] >= amountB, "Insufficient liquidity B");

        liquidity[msg.sender][tokenA] -= amountA;
        liquidity[msg.sender][tokenB] -= amountB;
        reserves[tokenA] -= amountA;
        reserves[tokenB] -= amountB;

        IERC20(tokenA).transfer(msg.sender, amountA);
        IERC20(tokenB).transfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, tokenA, tokenB, amountA, amountB);
    }

    function swapTokens(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut) external whenActive {
        require(tokenIn != tokenOut, "Same token");
        require(amountIn > 0, "Invalid amount");
        require(reserves[tokenIn] > 0 && reserves[tokenOut] > 0, "No liquidity");

        uint256 amountOut = getAmountOut(amountIn, reserves[tokenIn], reserves[tokenOut]);
        require(amountOut >= minAmountOut, "Slippage too high");


        uint256 fee = (amountOut * uint256(feePercentage)) / uint256(100);
        uint256 finalAmountOut = amountOut - fee;

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).transfer(msg.sender, finalAmountOut);

        reserves[tokenIn] += amountIn;
        reserves[tokenOut] -= amountOut;

        emit TokensSwapped(msg.sender, tokenIn, tokenOut, amountIn, finalAmountOut);
    }

    function createOrder(address tokenA, address tokenB, uint256 amountA, uint256 amountB) external whenActive onlyAuthorized {
        require(tokenA != tokenB, "Same token");
        require(amountA > 0 && amountB > 0, "Invalid amounts");


        orderCounter = uint256(orderCounter + 1);

        orders[orderCounter] = Order({
            trader: msg.sender,
            tokenA: tokenA,
            tokenB: tokenB,
            amountA: amountA,
            amountB: amountB,
            timestamp: block.timestamp,
            isActive: uint256(1)
        });


        orderHashes[orderCounter] = abi.encodePacked(msg.sender, tokenA, tokenB, amountA, amountB, block.timestamp);

        emit OrderCreated(orderCounter, msg.sender, tokenA, tokenB, amountA, amountB);
    }

    function executeOrder(uint256 orderId) external whenActive onlyAuthorized {
        Order storage order = orders[orderId];
        require(order.isActive == 1, "Order not active");
        require(order.trader != address(0), "Order not found");

        uint256 amountOut = getAmountOut(order.amountA, reserves[order.tokenA], reserves[order.tokenB]);
        require(amountOut >= order.amountB, "Insufficient output");


        order.isActive = uint256(0);

        IERC20(order.tokenA).transferFrom(order.trader, address(this), order.amountA);
        IERC20(order.tokenB).transfer(order.trader, order.amountB);

        reserves[order.tokenA] += order.amountA;
        reserves[order.tokenB] -= order.amountB;

        emit OrderExecuted(orderId, msg.sender);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        require(amountIn > 0, "Invalid input amount");
        require(reserveIn > 0 && reserveOut > 0, "Invalid reserves");

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;

        return numerator / denominator;
    }

    function getReserves(address token) external view returns (uint256) {
        return reserves[token];
    }

    function getOrderDetails(uint256 orderId) external view returns (Order memory) {
        return orders[orderId];
    }

    function updateFeePercentage(uint256 newFee) external onlyOwner {
        require(newFee <= 10, "Fee too high");

        feePercentage = uint256(newFee);
    }

    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner, amount);
    }
}
