
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract DecentralizedExchange is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;

    struct Pool {
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalSupply;
        mapping(address => uint256) liquidity;
    }

    struct Order {
        address trader;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        uint256 deadline;
        bool executed;
    }

    mapping(bytes32 => Pool) public pools;
    mapping(uint256 => Order) public orders;
    mapping(address => uint256[]) public userOrders;

    uint256 public orderCounter;
    uint256 public constant FEE_RATE = 3;
    uint256 public constant FEE_DENOMINATOR = 1000;
    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    event PoolCreated(bytes32 indexed poolId, address tokenA, address tokenB);
    event LiquidityAdded(bytes32 indexed poolId, address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(bytes32 indexed poolId, address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event TokensSwapped(bytes32 indexed poolId, address indexed trader, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event OrderCreated(uint256 indexed orderId, address indexed trader, address tokenIn, address tokenOut, uint256 amountIn);
    event OrderExecuted(uint256 indexed orderId, uint256 amountOut);

    modifier validPool(bytes32 poolId) {
        require(pools[poolId].tokenA != address(0), "Pool does not exist");
        _;
    }

    modifier validOrder(uint256 orderId) {
        require(orderId < orderCounter, "Invalid order ID");
        require(!orders[orderId].executed, "Order already executed");
        require(orders[orderId].deadline >= block.timestamp, "Order expired");
        _;
    }

    constructor() {}

    function createPool(address tokenA, address tokenB) external whenNotPaused returns (bytes32) {
        require(tokenA != tokenB, "Identical tokens");
        require(tokenA != address(0) && tokenB != address(0), "Zero address");

        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }

        bytes32 poolId = keccak256(abi.encodePacked(tokenA, tokenB));
        require(pools[poolId].tokenA == address(0), "Pool already exists");

        pools[poolId].tokenA = tokenA;
        pools[poolId].tokenB = tokenB;

        emit PoolCreated(poolId, tokenA, tokenB);
        return poolId;
    }

    function addLiquidity(
        bytes32 poolId,
        uint256 amountA,
        uint256 amountB
    ) external nonReentrant whenNotPaused validPool(poolId) returns (uint256) {
        Pool storage pool = pools[poolId];

        require(amountA > 0 && amountB > 0, "Invalid amounts");

        IERC20(pool.tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(pool.tokenB).safeTransferFrom(msg.sender, address(this), amountB);

        uint256 liquidity = _calculateLiquidity(pool, amountA, amountB);

        pool.reserveA += amountA;
        pool.reserveB += amountB;
        pool.totalSupply += liquidity;
        pool.liquidity[msg.sender] += liquidity;

        emit LiquidityAdded(poolId, msg.sender, amountA, amountB, liquidity);
        return liquidity;
    }

    function removeLiquidity(
        bytes32 poolId,
        uint256 liquidityAmount
    ) external nonReentrant whenNotPaused validPool(poolId) returns (uint256, uint256) {
        Pool storage pool = pools[poolId];

        require(liquidityAmount > 0, "Invalid liquidity amount");
        require(pool.liquidity[msg.sender] >= liquidityAmount, "Insufficient liquidity");

        (uint256 amountA, uint256 amountB) = _calculateWithdrawAmounts(pool, liquidityAmount);

        pool.liquidity[msg.sender] -= liquidityAmount;
        pool.totalSupply -= liquidityAmount;
        pool.reserveA -= amountA;
        pool.reserveB -= amountB;

        IERC20(pool.tokenA).safeTransfer(msg.sender, amountA);
        IERC20(pool.tokenB).safeTransfer(msg.sender, amountB);

        emit LiquidityRemoved(poolId, msg.sender, amountA, amountB, liquidityAmount);
        return (amountA, amountB);
    }

    function swapTokens(
        bytes32 poolId,
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut
    ) external nonReentrant whenNotPaused validPool(poolId) returns (uint256) {
        Pool storage pool = pools[poolId];

        require(amountIn > 0, "Invalid input amount");
        require(tokenIn == pool.tokenA || tokenIn == pool.tokenB, "Invalid token");

        uint256 amountOut = _calculateSwapOutput(pool, tokenIn, amountIn);
        require(amountOut >= minAmountOut, "Insufficient output amount");

        address tokenOut = tokenIn == pool.tokenA ? pool.tokenB : pool.tokenA;

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        _updateReserves(pool, tokenIn, amountIn, amountOut);

        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);

        emit TokensSwapped(poolId, msg.sender, tokenIn, tokenOut, amountIn, amountOut);
        return amountOut;
    }

    function createOrder(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external whenNotPaused returns (uint256) {
        require(tokenIn != tokenOut, "Identical tokens");
        require(amountIn > 0 && minAmountOut > 0, "Invalid amounts");
        require(deadline > block.timestamp, "Invalid deadline");

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        uint256 orderId = orderCounter++;
        orders[orderId] = Order({
            trader: msg.sender,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            minAmountOut: minAmountOut,
            deadline: deadline,
            executed: false
        });

        userOrders[msg.sender].push(orderId);

        emit OrderCreated(orderId, msg.sender, tokenIn, tokenOut, amountIn);
        return orderId;
    }

    function executeOrder(uint256 orderId) external nonReentrant whenNotPaused validOrder(orderId) {
        Order storage order = orders[orderId];

        bytes32 poolId = _getPoolId(order.tokenIn, order.tokenOut);
        require(pools[poolId].tokenA != address(0), "Pool does not exist");

        Pool storage pool = pools[poolId];
        uint256 amountOut = _calculateSwapOutput(pool, order.tokenIn, order.amountIn);

        require(amountOut >= order.minAmountOut, "Insufficient output amount");

        order.executed = true;

        _updateReserves(pool, order.tokenIn, order.amountIn, amountOut);

        IERC20(order.tokenOut).safeTransfer(order.trader, amountOut);

        emit OrderExecuted(orderId, amountOut);
    }

    function getPoolReserves(bytes32 poolId) external view validPool(poolId) returns (uint256, uint256) {
        Pool storage pool = pools[poolId];
        return (pool.reserveA, pool.reserveB);
    }

    function getUserLiquidity(bytes32 poolId, address user) external view returns (uint256) {
        return pools[poolId].liquidity[user];
    }

    function getUserOrders(address user) external view returns (uint256[] memory) {
        return userOrders[user];
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _calculateLiquidity(
        Pool storage pool,
        uint256 amountA,
        uint256 amountB
    ) internal view returns (uint256) {
        if (pool.totalSupply == 0) {
            return _sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
        }

        uint256 liquidityA = (amountA * pool.totalSupply) / pool.reserveA;
        uint256 liquidityB = (amountB * pool.totalSupply) / pool.reserveB;

        return liquidityA < liquidityB ? liquidityA : liquidityB;
    }

    function _calculateWithdrawAmounts(
        Pool storage pool,
        uint256 liquidityAmount
    ) internal view returns (uint256, uint256) {
        uint256 amountA = (liquidityAmount * pool.reserveA) / pool.totalSupply;
        uint256 amountB = (liquidityAmount * pool.reserveB) / pool.totalSupply;

        return (amountA, amountB);
    }

    function _calculateSwapOutput(
        Pool storage pool,
        address tokenIn,
        uint256 amountIn
    ) internal view returns (uint256) {
        bool isTokenA = tokenIn == pool.tokenA;
        uint256 reserveIn = isTokenA ? pool.reserveA : pool.reserveB;
        uint256 reserveOut = isTokenA ? pool.reserveB : pool.reserveA;

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_RATE);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;

        return numerator / denominator;
    }

    function _updateReserves(
        Pool storage pool,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOut
    ) internal {
        if (tokenIn == pool.tokenA) {
            pool.reserveA += amountIn;
            pool.reserveB -= amountOut;
        } else {
            pool.reserveB += amountIn;
            pool.reserveA -= amountOut;
        }
    }

    function _getPoolId(address tokenA, address tokenB) internal pure returns (bytes32) {
        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }
        return keccak256(abi.encodePacked(tokenA, tokenB));
    }

    function _sqrt(uint256 y) internal pure returns (uint256) {
        if (y == 0) return 0;

        uint256 z = (y + 1) / 2;
        uint256 x = y;

        while (z < x) {
            x = z;
            z = (y / z + z) / 2;
        }

        return x;
    }
}
