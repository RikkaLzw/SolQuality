
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract DecentralizedExchangeContract {

    uint256 public feePercentage = 3;
    uint256 public constant MAX_SLIPPAGE = 5;
    uint256 public orderCounter = 0;


    string public exchangeName = "DEX_V1";
    string public version = "1.0.0";

    struct LiquidityPool {
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalLiquidity;

        uint256 isActive;
    }

    struct Order {
        address trader;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;

        bytes orderHash;

        uint256 isFilled;
    }

    mapping(address => mapping(address => LiquidityPool)) public pools;
    mapping(uint256 => Order) public orders;
    mapping(address => uint256) public userBalances;


    mapping(bytes => uint256) public poolIdentifiers;

    address public owner;

    event LiquidityAdded(address indexed user, address tokenA, address tokenB, uint256 amountA, uint256 amountB);
    event LiquidityRemoved(address indexed user, address tokenA, address tokenB, uint256 amountA, uint256 amountB);
    event Swap(address indexed user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event OrderCreated(uint256 indexed orderId, address indexed trader, address tokenIn, address tokenOut);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) external {
        require(tokenA != address(0) && tokenB != address(0), "Invalid token addresses");
        require(amountA > 0 && amountB > 0, "Invalid amounts");


        uint256 convertedAmountA = uint256(amountA);
        uint256 convertedAmountB = uint256(amountB);

        IERC20(tokenA).transferFrom(msg.sender, address(this), convertedAmountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), convertedAmountB);

        LiquidityPool storage pool = pools[tokenA][tokenB];

        if (pool.reserveA == 0 && pool.reserveB == 0) {

            pool.tokenA = tokenA;
            pool.tokenB = tokenB;
            pool.reserveA = convertedAmountA;
            pool.reserveB = convertedAmountB;
            pool.totalLiquidity = sqrt(convertedAmountA * convertedAmountB);

            pool.isActive = 1;
        } else {

            uint256 liquidityA = (convertedAmountA * pool.totalLiquidity) / pool.reserveA;
            uint256 liquidityB = (convertedAmountB * pool.totalLiquidity) / pool.reserveB;
            uint256 liquidity = liquidityA < liquidityB ? liquidityA : liquidityB;

            pool.reserveA += convertedAmountA;
            pool.reserveB += convertedAmountB;
            pool.totalLiquidity += liquidity;
        }


        bytes memory poolId = abi.encodePacked(tokenA, tokenB);
        poolIdentifiers[poolId] = pool.totalLiquidity;

        emit LiquidityAdded(msg.sender, tokenA, tokenB, convertedAmountA, convertedAmountB);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity
    ) external {
        require(liquidity > 0, "Invalid liquidity amount");

        LiquidityPool storage pool = pools[tokenA][tokenB];
        require(pool.totalLiquidity > 0, "Pool does not exist");

        require(pool.isActive == 1, "Pool not active");


        uint256 convertedLiquidity = uint256(liquidity);

        uint256 amountA = (convertedLiquidity * pool.reserveA) / pool.totalLiquidity;
        uint256 amountB = (convertedLiquidity * pool.reserveB) / pool.totalLiquidity;

        pool.reserveA -= amountA;
        pool.reserveB -= amountB;
        pool.totalLiquidity -= convertedLiquidity;

        IERC20(tokenA).transfer(msg.sender, amountA);
        IERC20(tokenB).transfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, tokenA, tokenB, amountA, amountB);
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external {
        require(tokenIn != tokenOut, "Same token swap not allowed");
        require(amountIn > 0, "Invalid input amount");

        LiquidityPool storage pool = pools[tokenIn][tokenOut];
        require(pool.reserveA > 0 && pool.reserveB > 0, "Pool does not exist");

        require(pool.isActive == 1, "Pool not active");


        uint256 convertedAmountIn = uint256(amountIn);

        uint256 amountInWithFee = convertedAmountIn * (1000 - feePercentage) / 1000;
        uint256 amountOut;

        if (pool.tokenA == tokenIn) {
            amountOut = (amountInWithFee * pool.reserveB) / (pool.reserveA + amountInWithFee);
            pool.reserveA += convertedAmountIn;
            pool.reserveB -= amountOut;
        } else {
            amountOut = (amountInWithFee * pool.reserveA) / (pool.reserveB + amountInWithFee);
            pool.reserveB += convertedAmountIn;
            pool.reserveA -= amountOut;
        }

        require(amountOut >= minAmountOut, "Slippage too high");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), convertedAmountIn);
        IERC20(tokenOut).transfer(msg.sender, amountOut);

        emit Swap(msg.sender, tokenIn, tokenOut, convertedAmountIn, amountOut);
    }

    function createOrder(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external returns (uint256) {
        require(tokenIn != tokenOut, "Same token order not allowed");
        require(amountIn > 0, "Invalid input amount");


        uint256 convertedAmountIn = uint256(amountIn);
        uint256 convertedMinAmountOut = uint256(minAmountOut);

        orderCounter++;


        bytes memory orderHash = abi.encodePacked(
            msg.sender,
            tokenIn,
            tokenOut,
            convertedAmountIn,
            block.timestamp
        );

        orders[orderCounter] = Order({
            trader: msg.sender,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: convertedAmountIn,
            minAmountOut: convertedMinAmountOut,
            orderHash: orderHash,

            isFilled: 0
        });

        IERC20(tokenIn).transferFrom(msg.sender, address(this), convertedAmountIn);

        emit OrderCreated(orderCounter, msg.sender, tokenIn, tokenOut);

        return orderCounter;
    }

    function fillOrder(uint256 orderId) external {
        Order storage order = orders[orderId];
        require(order.trader != address(0), "Order does not exist");

        require(order.isFilled == 0, "Order already filled");

        LiquidityPool storage pool = pools[order.tokenIn][order.tokenOut];
        require(pool.reserveA > 0 && pool.reserveB > 0, "Pool does not exist");

        require(pool.isActive == 1, "Pool not active");

        uint256 amountInWithFee = order.amountIn * (1000 - feePercentage) / 1000;
        uint256 amountOut;

        if (pool.tokenA == order.tokenIn) {
            amountOut = (amountInWithFee * pool.reserveB) / (pool.reserveA + amountInWithFee);
            pool.reserveA += order.amountIn;
            pool.reserveB -= amountOut;
        } else {
            amountOut = (amountInWithFee * pool.reserveA) / (pool.reserveB + amountInWithFee);
            pool.reserveB += order.amountIn;
            pool.reserveA -= amountOut;
        }

        require(amountOut >= order.minAmountOut, "Order cannot be filled at current price");


        order.isFilled = 1;

        IERC20(order.tokenOut).transfer(order.trader, amountOut);

        emit Swap(order.trader, order.tokenIn, order.tokenOut, order.amountIn, amountOut);
    }

    function setFeePercentage(uint256 newFee) external onlyOwner {
        require(newFee <= 10, "Fee too high");

        feePercentage = uint256(newFee);
    }

    function togglePoolStatus(address tokenA, address tokenB) external onlyOwner {
        LiquidityPool storage pool = pools[tokenA][tokenB];
        require(pool.reserveA > 0 || pool.reserveB > 0, "Pool does not exist");


        if (pool.isActive == 1) {
            pool.isActive = 0;
        } else {
            pool.isActive = 1;
        }
    }

    function getPoolReserves(address tokenA, address tokenB)
        external
        view
        returns (uint256 reserveA, uint256 reserveB)
    {
        LiquidityPool memory pool = pools[tokenA][tokenB];
        return (pool.reserveA, pool.reserveB);
    }

    function isPoolActive(address tokenA, address tokenB) external view returns (bool) {
        LiquidityPool memory pool = pools[tokenA][tokenB];

        return pool.isActive == 1;
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
}
