
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract DecentralizedExchange is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;


    uint256 public constant MAX_FEE = 1000;
    uint256 public tradingFee = 30;


    uint256 public constant MINIMUM_LIQUIDITY = 1000;


    mapping(address => mapping(address => LiquidityPool)) public pools;


    mapping(address => mapping(address => mapping(address => uint256))) public liquidityPositions;


    mapping(address => uint256) public accumulatedFees;

    struct LiquidityPool {
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalLiquidity;
        uint256 lastUpdateTime;
        bool exists;
    }


    event LiquidityAdded(
        address indexed provider,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity
    );

    event LiquidityRemoved(
        address indexed provider,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity
    );

    event TokensSwapped(
        address indexed trader,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee
    );

    event PoolCreated(
        address indexed token0,
        address indexed token1,
        uint256 initialReserve0,
        uint256 initialReserve1
    );

    event TradingFeeUpdated(
        uint256 oldFee,
        uint256 newFee
    );

    event FeesWithdrawn(
        address indexed token,
        uint256 amount
    );

    constructor() {}


    function createPool(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1
    ) external nonReentrant whenNotPaused {
        require(token0 != address(0) && token1 != address(0), "DEX: Invalid token addresses");
        require(token0 != token1, "DEX: Identical token addresses");
        require(amount0 > 0 && amount1 > 0, "DEX: Insufficient amounts");


        if (token0 > token1) {
            (token0, token1) = (token1, token0);
            (amount0, amount1) = (amount1, amount0);
        }

        require(!pools[token0][token1].exists, "DEX: Pool already exists");


        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1);


        uint256 liquidity = _sqrt(amount0 * amount1);
        require(liquidity > MINIMUM_LIQUIDITY, "DEX: Insufficient liquidity");


        liquidity -= MINIMUM_LIQUIDITY;


        pools[token0][token1] = LiquidityPool({
            reserve0: amount0,
            reserve1: amount1,
            totalLiquidity: liquidity + MINIMUM_LIQUIDITY,
            lastUpdateTime: block.timestamp,
            exists: true
        });


        liquidityPositions[msg.sender][token0][token1] = liquidity;

        emit PoolCreated(token0, token1, amount0, amount1);
        emit LiquidityAdded(msg.sender, token0, token1, amount0, amount1, liquidity);
    }


    function addLiquidity(
        address token0,
        address token1,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) external nonReentrant whenNotPaused returns (uint256 amount0, uint256 amount1, uint256 liquidity) {
        require(token0 != address(0) && token1 != address(0), "DEX: Invalid token addresses");
        require(token0 != token1, "DEX: Identical token addresses");
        require(amount0Desired > 0 && amount1Desired > 0, "DEX: Insufficient desired amounts");


        if (token0 > token1) {
            (token0, token1) = (token1, token0);
            (amount0Desired, amount1Desired) = (amount1Desired, amount0Desired);
            (amount0Min, amount1Min) = (amount1Min, amount0Min);
        }

        LiquidityPool storage pool = pools[token0][token1];
        require(pool.exists, "DEX: Pool does not exist");


        if (pool.reserve0 == 0 && pool.reserve1 == 0) {
            amount0 = amount0Desired;
            amount1 = amount1Desired;
        } else {
            uint256 amount1Optimal = (amount0Desired * pool.reserve1) / pool.reserve0;
            if (amount1Optimal <= amount1Desired) {
                require(amount1Optimal >= amount1Min, "DEX: Insufficient amount1");
                amount0 = amount0Desired;
                amount1 = amount1Optimal;
            } else {
                uint256 amount0Optimal = (amount1Desired * pool.reserve0) / pool.reserve1;
                require(amount0Optimal <= amount0Desired && amount0Optimal >= amount0Min, "DEX: Insufficient amount0");
                amount0 = amount0Optimal;
                amount1 = amount1Desired;
            }
        }


        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1);


        if (pool.totalLiquidity == 0) {
            liquidity = _sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
        } else {
            liquidity = _min(
                (amount0 * pool.totalLiquidity) / pool.reserve0,
                (amount1 * pool.totalLiquidity) / pool.reserve1
            );
        }

        require(liquidity > 0, "DEX: Insufficient liquidity minted");


        pool.reserve0 += amount0;
        pool.reserve1 += amount1;
        pool.totalLiquidity += liquidity;
        pool.lastUpdateTime = block.timestamp;


        liquidityPositions[msg.sender][token0][token1] += liquidity;

        emit LiquidityAdded(msg.sender, token0, token1, amount0, amount1, liquidity);
    }


    function removeLiquidity(
        address token0,
        address token1,
        uint256 liquidity,
        uint256 amount0Min,
        uint256 amount1Min
    ) external nonReentrant whenNotPaused returns (uint256 amount0, uint256 amount1) {
        require(token0 != address(0) && token1 != address(0), "DEX: Invalid token addresses");
        require(token0 != token1, "DEX: Identical token addresses");
        require(liquidity > 0, "DEX: Insufficient liquidity");


        if (token0 > token1) {
            (token0, token1) = (token1, token0);
            (amount0Min, amount1Min) = (amount1Min, amount0Min);
        }

        LiquidityPool storage pool = pools[token0][token1];
        require(pool.exists, "DEX: Pool does not exist");
        require(liquidityPositions[msg.sender][token0][token1] >= liquidity, "DEX: Insufficient liquidity balance");


        amount0 = (liquidity * pool.reserve0) / pool.totalLiquidity;
        amount1 = (liquidity * pool.reserve1) / pool.totalLiquidity;

        require(amount0 >= amount0Min && amount1 >= amount1Min, "DEX: Insufficient output amounts");


        liquidityPositions[msg.sender][token0][token1] -= liquidity;
        pool.reserve0 -= amount0;
        pool.reserve1 -= amount1;
        pool.totalLiquidity -= liquidity;
        pool.lastUpdateTime = block.timestamp;


        IERC20(token0).safeTransfer(msg.sender, amount0);
        IERC20(token1).safeTransfer(msg.sender, amount1);

        emit LiquidityRemoved(msg.sender, token0, token1, amount0, amount1, liquidity);
    }


    function swapTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin
    ) external nonReentrant whenNotPaused returns (uint256 amountOut) {
        require(tokenIn != address(0) && tokenOut != address(0), "DEX: Invalid token addresses");
        require(tokenIn != tokenOut, "DEX: Identical token addresses");
        require(amountIn > 0, "DEX: Insufficient input amount");


        address token0 = tokenIn < tokenOut ? tokenIn : tokenOut;
        address token1 = tokenIn < tokenOut ? tokenOut : tokenIn;

        LiquidityPool storage pool = pools[token0][token1];
        require(pool.exists, "DEX: Pool does not exist");


        (uint256 reserveIn, uint256 reserveOut) = tokenIn == token0
            ? (pool.reserve0, pool.reserve1)
            : (pool.reserve1, pool.reserve0);

        require(reserveIn > 0 && reserveOut > 0, "DEX: Insufficient liquidity");


        uint256 amountInWithFee = amountIn * (10000 - tradingFee);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10000) + amountInWithFee;
        amountOut = numerator / denominator;

        require(amountOut >= amountOutMin, "DEX: Insufficient output amount");
        require(amountOut < reserveOut, "DEX: Insufficient liquidity for swap");


        uint256 fee = (amountIn * tradingFee) / 10000;


        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);


        if (tokenIn == token0) {
            pool.reserve0 += amountIn;
            pool.reserve1 -= amountOut;
        } else {
            pool.reserve1 += amountIn;
            pool.reserve0 -= amountOut;
        }

        pool.lastUpdateTime = block.timestamp;


        accumulatedFees[tokenIn] += fee;


        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);

        emit TokensSwapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut, fee);
    }


    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        require(tokenIn != address(0) && tokenOut != address(0), "DEX: Invalid token addresses");
        require(tokenIn != tokenOut, "DEX: Identical token addresses");
        require(amountIn > 0, "DEX: Insufficient input amount");

        address token0 = tokenIn < tokenOut ? tokenIn : tokenOut;
        address token1 = tokenIn < tokenOut ? tokenOut : tokenIn;

        LiquidityPool memory pool = pools[token0][token1];
        require(pool.exists, "DEX: Pool does not exist");

        (uint256 reserveIn, uint256 reserveOut) = tokenIn == token0
            ? (pool.reserve0, pool.reserve1)
            : (pool.reserve1, pool.reserve0);

        require(reserveIn > 0 && reserveOut > 0, "DEX: Insufficient liquidity");

        uint256 amountInWithFee = amountIn * (10000 - tradingFee);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10000) + amountInWithFee;
        amountOut = numerator / denominator;
    }


    function setTradingFee(uint256 newFee) external onlyOwner {
        require(newFee <= MAX_FEE, "DEX: Fee too high");

        uint256 oldFee = tradingFee;
        tradingFee = newFee;

        emit TradingFeeUpdated(oldFee, newFee);
    }


    function withdrawFees(address token) external onlyOwner {
        uint256 amount = accumulatedFees[token];
        require(amount > 0, "DEX: No fees to withdraw");

        accumulatedFees[token] = 0;
        IERC20(token).safeTransfer(owner(), amount);

        emit FeesWithdrawn(token, amount);
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
    }


    function emergencyWithdraw(address token, uint256 amount) external onlyOwner whenPaused {
        require(token != address(0), "DEX: Invalid token address");
        require(amount > 0, "DEX: Invalid amount");

        IERC20(token).safeTransfer(owner(), amount);
    }


    function _sqrt(uint256 y) internal pure returns (uint256 z) {
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

    function _min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }
}
