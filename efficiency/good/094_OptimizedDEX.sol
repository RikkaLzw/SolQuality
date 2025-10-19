
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract OptimizedDEX is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;


    struct LiquidityPool {
        uint128 reserve0;
        uint128 reserve1;
        uint32 blockTimestampLast;
        uint32 kLast;
    }

    struct OrderBook {
        uint128 price;
        uint128 amount;
    }


    mapping(bytes32 => LiquidityPool) public pools;
    mapping(address => mapping(address => uint256)) public liquidityTokens;
    mapping(bytes32 => OrderBook[]) public buyOrders;
    mapping(bytes32 => OrderBook[]) public sellOrders;
    mapping(address => uint256) public feeBalance;


    uint256 private constant MINIMUM_LIQUIDITY = 1000;
    uint256 private constant FEE_DENOMINATOR = 10000;
    uint256 private feeRate = 30;


    event LiquidityAdded(address indexed token0, address indexed token1, uint256 amount0, uint256 amount1);
    event LiquidityRemoved(address indexed token0, address indexed token1, uint256 amount0, uint256 amount1);
    event Swap(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event OrderPlaced(address indexed token0, address indexed token1, bool isBuy, uint256 price, uint256 amount);

    constructor() {}

    function getPoolKey(address token0, address token1) public pure returns (bytes32) {
        return token0 < token1 ? keccak256(abi.encodePacked(token0, token1)) : keccak256(abi.encodePacked(token1, token0));
    }

    function addLiquidity(
        address token0,
        address token1,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) external nonReentrant returns (uint256 amount0, uint256 amount1, uint256 liquidity) {
        bytes32 poolKey = getPoolKey(token0, token1);
        LiquidityPool storage pool = pools[poolKey];


        uint256 reserve0 = pool.reserve0;
        uint256 reserve1 = pool.reserve1;

        if (reserve0 == 0 && reserve1 == 0) {
            amount0 = amount0Desired;
            amount1 = amount1Desired;
        } else {
            uint256 amount1Optimal = (amount0Desired * reserve1) / reserve0;
            if (amount1Optimal <= amount1Desired) {
                require(amount1Optimal >= amount1Min, "Insufficient amount1");
                amount0 = amount0Desired;
                amount1 = amount1Optimal;
            } else {
                uint256 amount0Optimal = (amount1Desired * reserve0) / reserve1;
                require(amount0Optimal <= amount0Desired && amount0Optimal >= amount0Min, "Insufficient amount0");
                amount0 = amount0Optimal;
                amount1 = amount1Desired;
            }
        }

        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1);


        uint256 totalSupply = getTotalLiquidity(poolKey);
        if (totalSupply == 0) {
            liquidity = sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            liquidityTokens[address(0)][address(uint160(uint256(poolKey)))] = MINIMUM_LIQUIDITY;
        } else {
            liquidity = min((amount0 * totalSupply) / reserve0, (amount1 * totalSupply) / reserve1);
        }

        require(liquidity > 0, "Insufficient liquidity minted");
        liquidityTokens[msg.sender][address(uint160(uint256(poolKey)))] += liquidity;


        pool.reserve0 = uint128(reserve0 + amount0);
        pool.reserve1 = uint128(reserve1 + amount1);
        pool.blockTimestampLast = uint32(block.timestamp);
        pool.kLast = uint32((reserve0 + amount0) * (reserve1 + amount1) / 1e18);

        emit LiquidityAdded(token0, token1, amount0, amount1);
    }

    function removeLiquidity(
        address token0,
        address token1,
        uint256 liquidity,
        uint256 amount0Min,
        uint256 amount1Min
    ) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        bytes32 poolKey = getPoolKey(token0, token1);
        LiquidityPool storage pool = pools[poolKey];

        require(liquidityTokens[msg.sender][address(uint160(uint256(poolKey)))] >= liquidity, "Insufficient liquidity");


        uint256 reserve0 = pool.reserve0;
        uint256 reserve1 = pool.reserve1;
        uint256 totalSupply = getTotalLiquidity(poolKey);

        amount0 = (liquidity * reserve0) / totalSupply;
        amount1 = (liquidity * reserve1) / totalSupply;

        require(amount0 >= amount0Min && amount1 >= amount1Min, "Insufficient output amounts");

        liquidityTokens[msg.sender][address(uint160(uint256(poolKey)))] -= liquidity;


        pool.reserve0 = uint128(reserve0 - amount0);
        pool.reserve1 = uint128(reserve1 - amount1);
        pool.blockTimestampLast = uint32(block.timestamp);

        IERC20(token0).safeTransfer(msg.sender, amount0);
        IERC20(token1).safeTransfer(msg.sender, amount1);

        emit LiquidityRemoved(token0, token1, amount0, amount1);
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn,
        address tokenOut
    ) external nonReentrant returns (uint256 amountOut) {
        bytes32 poolKey = getPoolKey(tokenIn, tokenOut);
        LiquidityPool storage pool = pools[poolKey];


        uint256 reserveIn;
        uint256 reserveOut;

        if (tokenIn < tokenOut) {
            reserveIn = pool.reserve0;
            reserveOut = pool.reserve1;
        } else {
            reserveIn = pool.reserve1;
            reserveOut = pool.reserve0;
        }

        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");


        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - feeRate);
        amountOut = (amountInWithFee * reserveOut) / (reserveIn * FEE_DENOMINATOR + amountInWithFee);

        require(amountOut >= amountOutMin, "Insufficient output amount");

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);


        if (tokenIn < tokenOut) {
            pool.reserve0 = uint128(reserveIn + amountIn);
            pool.reserve1 = uint128(reserveOut - amountOut);
        } else {
            pool.reserve0 = uint128(reserveOut - amountOut);
            pool.reserve1 = uint128(reserveIn + amountIn);
        }

        pool.blockTimestampLast = uint32(block.timestamp);

        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);

        emit Swap(tokenIn, tokenOut, amountIn, amountOut);
    }

    function placeOrder(
        address token0,
        address token1,
        bool isBuy,
        uint256 price,
        uint256 amount
    ) external nonReentrant {
        bytes32 poolKey = getPoolKey(token0, token1);

        address tokenToTransfer = isBuy ? token1 : token0;
        uint256 transferAmount = isBuy ? (amount * price) / 1e18 : amount;

        IERC20(tokenToTransfer).safeTransferFrom(msg.sender, address(this), transferAmount);

        OrderBook memory order = OrderBook({
            price: uint128(price),
            amount: uint128(amount)
        });

        if (isBuy) {
            buyOrders[poolKey].push(order);
        } else {
            sellOrders[poolKey].push(order);
        }

        emit OrderPlaced(token0, token1, isBuy, price, amount);
    }

    function getReserves(address token0, address token1) external view returns (uint256 reserve0, uint256 reserve1, uint32 blockTimestampLast) {
        bytes32 poolKey = getPoolKey(token0, token1);
        LiquidityPool storage pool = pools[poolKey];

        if (token0 < token1) {
            return (pool.reserve0, pool.reserve1, pool.blockTimestampLast);
        } else {
            return (pool.reserve1, pool.reserve0, pool.blockTimestampLast);
        }
    }

    function getTotalLiquidity(bytes32 poolKey) internal view returns (uint256 total) {

        return liquidityTokens[address(0)][address(uint160(uint256(poolKey)))] +
               liquidityTokens[msg.sender][address(uint160(uint256(poolKey)))];
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

    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }

    function setFeeRate(uint256 newFeeRate) external onlyOwner {
        require(newFeeRate <= 1000, "Fee too high");
        feeRate = newFeeRate;
    }

    function withdrawFees(address token) external onlyOwner {
        uint256 amount = feeBalance[token];
        feeBalance[token] = 0;
        IERC20(token).safeTransfer(owner(), amount);
    }
}
