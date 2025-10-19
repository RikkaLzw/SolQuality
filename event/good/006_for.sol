
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


    mapping(address => mapping(address => LiquidityPool)) public pools;


    mapping(address => mapping(address => mapping(address => uint256))) public liquidityShares;


    mapping(address => mapping(address => uint256)) public totalShares;

    struct LiquidityPool {
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalLiquidity;
        bool exists;
    }


    event PoolCreated(
        address indexed token0,
        address indexed token1,
        uint256 initialReserve0,
        uint256 initialReserve1
    );

    event LiquidityAdded(
        address indexed provider,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 shares
    );

    event LiquidityRemoved(
        address indexed provider,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 shares
    );

    event TokensSwapped(
        address indexed trader,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee
    );

    event TradingFeeUpdated(uint256 oldFee, uint256 newFee);

    event FeesCollected(address indexed token, uint256 amount);


    error InvalidTokenAddress();
    error IdenticalTokens();
    error PoolAlreadyExists();
    error PoolDoesNotExist();
    error InsufficientLiquidity();
    error InsufficientAmount();
    error InvalidFee();
    error SlippageExceeded();
    error InsufficientShares();
    error TransferFailed();

    constructor() {}


    function createPool(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1
    ) external nonReentrant whenNotPaused {
        if (token0 == address(0) || token1 == address(0)) {
            revert InvalidTokenAddress();
        }
        if (token0 == token1) {
            revert IdenticalTokens();
        }
        if (amount0 == 0 || amount1 == 0) {
            revert InsufficientAmount();
        }


        if (token0 > token1) {
            (token0, token1) = (token1, token0);
            (amount0, amount1) = (amount1, amount0);
        }

        if (pools[token0][token1].exists) {
            revert PoolAlreadyExists();
        }


        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1);


        uint256 initialLiquidity = _sqrt(amount0 * amount1);
        if (initialLiquidity == 0) {
            revert InsufficientLiquidity();
        }


        pools[token0][token1] = LiquidityPool({
            reserve0: amount0,
            reserve1: amount1,
            totalLiquidity: initialLiquidity,
            exists: true
        });


        liquidityShares[msg.sender][token0][token1] = initialLiquidity;
        totalShares[token0][token1] = initialLiquidity;

        emit PoolCreated(token0, token1, amount0, amount1);
        emit LiquidityAdded(msg.sender, token0, token1, amount0, amount1, initialLiquidity);
    }


    function addLiquidity(
        address token0,
        address token1,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) external nonReentrant whenNotPaused returns (uint256 shares) {
        if (token0 == address(0) || token1 == address(0)) {
            revert InvalidTokenAddress();
        }
        if (token0 == token1) {
            revert IdenticalTokens();
        }


        if (token0 > token1) {
            (token0, token1) = (token1, token0);
            (amount0Desired, amount1Desired) = (amount1Desired, amount0Desired);
            (amount0Min, amount1Min) = (amount1Min, amount0Min);
        }

        LiquidityPool storage pool = pools[token0][token1];
        if (!pool.exists) {
            revert PoolDoesNotExist();
        }

        uint256 amount0;
        uint256 amount1;


        if (pool.reserve0 == 0 || pool.reserve1 == 0) {
            amount0 = amount0Desired;
            amount1 = amount1Desired;
        } else {
            uint256 amount1Optimal = (amount0Desired * pool.reserve1) / pool.reserve0;
            if (amount1Optimal <= amount1Desired) {
                if (amount1Optimal < amount1Min) {
                    revert SlippageExceeded();
                }
                amount0 = amount0Desired;
                amount1 = amount1Optimal;
            } else {
                uint256 amount0Optimal = (amount1Desired * pool.reserve0) / pool.reserve1;
                if (amount0Optimal < amount0Min) {
                    revert SlippageExceeded();
                }
                amount0 = amount0Optimal;
                amount1 = amount1Desired;
            }
        }


        if (pool.totalLiquidity == 0) {
            shares = _sqrt(amount0 * amount1);
        } else {
            shares = _min(
                (amount0 * pool.totalLiquidity) / pool.reserve0,
                (amount1 * pool.totalLiquidity) / pool.reserve1
            );
        }

        if (shares == 0) {
            revert InsufficientLiquidity();
        }


        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1);


        pool.reserve0 += amount0;
        pool.reserve1 += amount1;
        pool.totalLiquidity += shares;


        liquidityShares[msg.sender][token0][token1] += shares;
        totalShares[token0][token1] += shares;

        emit LiquidityAdded(msg.sender, token0, token1, amount0, amount1, shares);
    }


    function removeLiquidity(
        address token0,
        address token1,
        uint256 shares,
        uint256 amount0Min,
        uint256 amount1Min
    ) external nonReentrant whenNotPaused returns (uint256 amount0, uint256 amount1) {
        if (token0 == address(0) || token1 == address(0)) {
            revert InvalidTokenAddress();
        }
        if (token0 == token1) {
            revert IdenticalTokens();
        }


        if (token0 > token1) {
            (token0, token1) = (token1, token0);
            (amount0Min, amount1Min) = (amount1Min, amount0Min);
        }

        LiquidityPool storage pool = pools[token0][token1];
        if (!pool.exists) {
            revert PoolDoesNotExist();
        }

        uint256 userShares = liquidityShares[msg.sender][token0][token1];
        if (shares > userShares) {
            revert InsufficientShares();
        }


        amount0 = (shares * pool.reserve0) / pool.totalLiquidity;
        amount1 = (shares * pool.reserve1) / pool.totalLiquidity;

        if (amount0 < amount0Min || amount1 < amount1Min) {
            revert SlippageExceeded();
        }


        liquidityShares[msg.sender][token0][token1] -= shares;
        totalShares[token0][token1] -= shares;
        pool.reserve0 -= amount0;
        pool.reserve1 -= amount1;
        pool.totalLiquidity -= shares;


        IERC20(token0).safeTransfer(msg.sender, amount0);
        IERC20(token1).safeTransfer(msg.sender, amount1);

        emit LiquidityRemoved(msg.sender, token0, token1, amount0, amount1, shares);
    }


    function swapTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin
    ) external nonReentrant whenNotPaused returns (uint256 amountOut) {
        if (tokenIn == address(0) || tokenOut == address(0)) {
            revert InvalidTokenAddress();
        }
        if (tokenIn == tokenOut) {
            revert IdenticalTokens();
        }
        if (amountIn == 0) {
            revert InsufficientAmount();
        }

        address token0 = tokenIn < tokenOut ? tokenIn : tokenOut;
        address token1 = tokenIn < tokenOut ? tokenOut : tokenIn;

        LiquidityPool storage pool = pools[token0][token1];
        if (!pool.exists) {
            revert PoolDoesNotExist();
        }

        uint256 reserveIn;
        uint256 reserveOut;

        if (tokenIn == token0) {
            reserveIn = pool.reserve0;
            reserveOut = pool.reserve1;
        } else {
            reserveIn = pool.reserve1;
            reserveOut = pool.reserve0;
        }




        uint256 amountInWithFee = amountIn * (10000 - tradingFee);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10000) + amountInWithFee;
        amountOut = numerator / denominator;

        if (amountOut < amountOutMin) {
            revert SlippageExceeded();
        }
        if (amountOut >= reserveOut) {
            revert InsufficientLiquidity();
        }


        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);


        if (tokenIn == token0) {
            pool.reserve0 += amountIn;
            pool.reserve1 -= amountOut;
        } else {
            pool.reserve1 += amountIn;
            pool.reserve0 -= amountOut;
        }

        uint256 fee = (amountIn * tradingFee) / 10000;

        emit TokensSwapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut, fee);
    }


    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        if (tokenIn == tokenOut) {
            revert IdenticalTokens();
        }

        address token0 = tokenIn < tokenOut ? tokenIn : tokenOut;
        address token1 = tokenIn < tokenOut ? tokenOut : tokenIn;

        LiquidityPool memory pool = pools[token0][token1];
        if (!pool.exists) {
            revert PoolDoesNotExist();
        }

        uint256 reserveIn = tokenIn == token0 ? pool.reserve0 : pool.reserve1;
        uint256 reserveOut = tokenIn == token0 ? pool.reserve1 : pool.reserve0;

        uint256 amountInWithFee = amountIn * (10000 - tradingFee);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10000) + amountInWithFee;
        amountOut = numerator / denominator;
    }


    function setTradingFee(uint256 newFee) external onlyOwner {
        if (newFee > MAX_FEE) {
            revert InvalidFee();
        }

        uint256 oldFee = tradingFee;
        tradingFee = newFee;

        emit TradingFeeUpdated(oldFee, newFee);
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
    }


    function getPool(address token0, address token1)
        external
        view
        returns (uint256 reserve0, uint256 reserve1, uint256 totalLiquidity, bool exists)
    {
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }

        LiquidityPool memory pool = pools[token0][token1];
        return (pool.reserve0, pool.reserve1, pool.totalLiquidity, pool.exists);
    }


    function getUserShares(address user, address token0, address token1)
        external
        view
        returns (uint256 shares)
    {
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }
        return liquidityShares[user][token0][token1];
    }


    function _sqrt(uint256 x) internal pure returns (uint256 result) {
        if (x == 0) return 0;

        uint256 z = (x + 1) / 2;
        result = x;
        while (z < result) {
            result = z;
            z = (x / z + z) / 2;
        }
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
