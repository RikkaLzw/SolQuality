
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
    struct Order {
        uint256 id;
        address trader;
        address tokenA;
        address tokenB;
        uint256 amountA;
        uint256 amountB;
        bool isActive;
    }

    struct Pool {
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalLiquidity;
        mapping(address => uint256) userLiquidity;
    }

    mapping(bytes32 => Pool) public pools;
    mapping(uint256 => Order) public orders;
    mapping(address => mapping(address => uint256)) public balances;

    uint256 private orderCounter;
    uint256 private constant FEE_RATE = 3;
    uint256 private constant FEE_DENOMINATOR = 1000;

    address private owner;

    event OrderCreated(uint256 indexed orderId, address indexed trader);
    event OrderExecuted(uint256 indexed orderId, address indexed executor);
    event LiquidityAdded(bytes32 indexed poolId, address indexed provider);
    event LiquidityRemoved(bytes32 indexed poolId, address indexed provider);
    event TokensSwapped(address indexed user, address tokenIn, address tokenOut);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier validAddress(address addr) {
        require(addr != address(0), "Invalid address");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createOrder(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) external validAddress(tokenA) validAddress(tokenB) returns (uint256) {
        require(tokenA != tokenB, "Same token");
        require(amountA > 0 && amountB > 0, "Invalid amounts");

        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);

        orderCounter++;
        orders[orderCounter] = Order({
            id: orderCounter,
            trader: msg.sender,
            tokenA: tokenA,
            tokenB: tokenB,
            amountA: amountA,
            amountB: amountB,
            isActive: true
        });

        emit OrderCreated(orderCounter, msg.sender);
        return orderCounter;
    }

    function executeOrder(uint256 orderId) external {
        Order storage order = orders[orderId];
        require(order.isActive, "Order inactive");
        require(order.trader != msg.sender, "Cannot execute own order");

        IERC20(order.tokenB).transferFrom(msg.sender, order.trader, order.amountB);
        IERC20(order.tokenA).transfer(msg.sender, order.amountA);

        order.isActive = false;
        emit OrderExecuted(orderId, msg.sender);
    }

    function cancelOrder(uint256 orderId) external {
        Order storage order = orders[orderId];
        require(order.trader == msg.sender, "Not order owner");
        require(order.isActive, "Order inactive");

        IERC20(order.tokenA).transfer(msg.sender, order.amountA);
        order.isActive = false;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) external validAddress(tokenA) validAddress(tokenB) returns (uint256) {
        require(tokenA != tokenB, "Same token");
        require(amountA > 0 && amountB > 0, "Invalid amounts");

        bytes32 poolId = getPoolId(tokenA, tokenB);
        Pool storage pool = pools[poolId];

        uint256 liquidity = calculateLiquidity(pool, amountA, amountB);

        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        pool.reserveA += amountA;
        pool.reserveB += amountB;
        pool.totalLiquidity += liquidity;
        pool.userLiquidity[msg.sender] += liquidity;

        emit LiquidityAdded(poolId, msg.sender);
        return liquidity;
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity
    ) external validAddress(tokenA) validAddress(tokenB) {
        require(liquidity > 0, "Invalid liquidity");

        bytes32 poolId = getPoolId(tokenA, tokenB);
        Pool storage pool = pools[poolId];

        require(pool.userLiquidity[msg.sender] >= liquidity, "Insufficient liquidity");

        (uint256 amountA, uint256 amountB) = calculateWithdrawAmounts(pool, liquidity);

        pool.reserveA -= amountA;
        pool.reserveB -= amountB;
        pool.totalLiquidity -= liquidity;
        pool.userLiquidity[msg.sender] -= liquidity;

        IERC20(tokenA).transfer(msg.sender, amountA);
        IERC20(tokenB).transfer(msg.sender, amountB);

        emit LiquidityRemoved(poolId, msg.sender);
    }

    function swapTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external validAddress(tokenIn) validAddress(tokenOut) returns (uint256) {
        require(tokenIn != tokenOut, "Same token");
        require(amountIn > 0, "Invalid amount");

        bytes32 poolId = getPoolId(tokenIn, tokenOut);
        Pool storage pool = pools[poolId];

        uint256 amountOut = calculateSwapOutput(pool, tokenIn, tokenOut, amountIn);
        require(amountOut >= minAmountOut, "Slippage exceeded");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        updateReserves(pool, tokenIn, tokenOut, amountIn, amountOut);

        IERC20(tokenOut).transfer(msg.sender, amountOut);

        emit TokensSwapped(msg.sender, tokenIn, tokenOut);
        return amountOut;
    }

    function getPoolId(address tokenA, address tokenB) public pure returns (bytes32) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return keccak256(abi.encodePacked(token0, token1));
    }

    function getPoolInfo(address tokenA, address tokenB) external view returns (uint256, uint256, uint256) {
        bytes32 poolId = getPoolId(tokenA, tokenB);
        Pool storage pool = pools[poolId];
        return (pool.reserveA, pool.reserveB, pool.totalLiquidity);
    }

    function getUserLiquidity(address tokenA, address tokenB, address user) external view returns (uint256) {
        bytes32 poolId = getPoolId(tokenA, tokenB);
        return pools[poolId].userLiquidity[user];
    }

    function calculateLiquidity(Pool storage pool, uint256 amountA, uint256 amountB) private view returns (uint256) {
        if (pool.totalLiquidity == 0) {
            return sqrt(amountA * amountB);
        }

        uint256 liquidityA = (amountA * pool.totalLiquidity) / pool.reserveA;
        uint256 liquidityB = (amountB * pool.totalLiquidity) / pool.reserveB;

        return liquidityA < liquidityB ? liquidityA : liquidityB;
    }

    function calculateWithdrawAmounts(Pool storage pool, uint256 liquidity) private view returns (uint256, uint256) {
        uint256 amountA = (liquidity * pool.reserveA) / pool.totalLiquidity;
        uint256 amountB = (liquidity * pool.reserveB) / pool.totalLiquidity;
        return (amountA, amountB);
    }

    function calculateSwapOutput(
        Pool storage pool,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) private view returns (uint256) {
        bytes32 poolId = getPoolId(tokenIn, tokenOut);

        uint256 reserveIn = tokenIn < tokenOut ? pool.reserveA : pool.reserveB;
        uint256 reserveOut = tokenIn < tokenOut ? pool.reserveB : pool.reserveA;

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_RATE);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;

        return numerator / denominator;
    }

    function updateReserves(
        Pool storage pool,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    ) private {
        if (tokenIn < tokenOut) {
            pool.reserveA += amountIn;
            pool.reserveB -= amountOut;
        } else {
            pool.reserveA -= amountOut;
            pool.reserveB += amountIn;
        }
    }

    function sqrt(uint256 y) private pure returns (uint256 z) {
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
