
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


    struct Pool {
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalLiquidity;
        mapping(address => uint256) liquidityBalance;
        bool exists;
    }


    uint256 private poolCounter;


    mapping(uint256 => Pool) public pools;


    mapping(address => mapping(address => uint256)) public getPoolId;


    event PoolCreated(
        uint256 indexed poolId,
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB,
        address creator
    );

    event LiquidityAdded(
        uint256 indexed poolId,
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );

    event LiquidityRemoved(
        uint256 indexed poolId,
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );

    event TokenSwapped(
        uint256 indexed poolId,
        address indexed trader,
        address indexed tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee
    );

    event TradingFeeUpdated(uint256 oldFee, uint256 newFee);

    constructor() {}


    function createPool(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) external nonReentrant whenNotPaused returns (uint256 poolId) {
        require(tokenA != address(0), "DEX: tokenA cannot be zero address");
        require(tokenB != address(0), "DEX: tokenB cannot be zero address");
        require(tokenA != tokenB, "DEX: tokens must be different");
        require(amountA > 0, "DEX: amountA must be greater than zero");
        require(amountB > 0, "DEX: amountB must be greater than zero");


        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
            (amountA, amountB) = (amountB, amountA);
        }

        require(getPoolId[tokenA][tokenB] == 0, "DEX: pool already exists");

        poolCounter++;
        poolId = poolCounter;

        Pool storage pool = pools[poolId];
        pool.tokenA = tokenA;
        pool.tokenB = tokenB;
        pool.reserveA = amountA;
        pool.reserveB = amountB;
        pool.exists = true;


        uint256 liquidity = sqrt(amountA * amountB);
        require(liquidity > 0, "DEX: insufficient liquidity minted");

        pool.totalLiquidity = liquidity;
        pool.liquidityBalance[msg.sender] = liquidity;


        getPoolId[tokenA][tokenB] = poolId;


        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountB);

        emit PoolCreated(poolId, tokenA, tokenB, amountA, amountB, msg.sender);
    }


    function addLiquidity(
        uint256 poolId,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) external nonReentrant whenNotPaused returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        Pool storage pool = pools[poolId];
        require(pool.exists, "DEX: pool does not exist");
        require(amountADesired > 0, "DEX: amountADesired must be greater than zero");
        require(amountBDesired > 0, "DEX: amountBDesired must be greater than zero");


        if (pool.reserveA == 0 && pool.reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = (amountADesired * pool.reserveB) / pool.reserveA;
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "DEX: insufficient B amount");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = (amountBDesired * pool.reserveA) / pool.reserveB;
                require(amountAOptimal <= amountADesired, "DEX: insufficient A amount");
                require(amountAOptimal >= amountAMin, "DEX: insufficient A amount");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }


        if (pool.totalLiquidity == 0) {
            liquidity = sqrt(amountA * amountB);
        } else {
            liquidity = min(
                (amountA * pool.totalLiquidity) / pool.reserveA,
                (amountB * pool.totalLiquidity) / pool.reserveB
            );
        }

        require(liquidity > 0, "DEX: insufficient liquidity minted");


        pool.reserveA += amountA;
        pool.reserveB += amountB;
        pool.totalLiquidity += liquidity;
        pool.liquidityBalance[msg.sender] += liquidity;


        IERC20(pool.tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(pool.tokenB).safeTransferFrom(msg.sender, address(this), amountB);

        emit LiquidityAdded(poolId, msg.sender, amountA, amountB, liquidity);
    }


    function removeLiquidity(
        uint256 poolId,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin
    ) external nonReentrant whenNotPaused returns (uint256 amountA, uint256 amountB) {
        Pool storage pool = pools[poolId];
        require(pool.exists, "DEX: pool does not exist");
        require(liquidity > 0, "DEX: liquidity must be greater than zero");
        require(pool.liquidityBalance[msg.sender] >= liquidity, "DEX: insufficient liquidity balance");


        amountA = (liquidity * pool.reserveA) / pool.totalLiquidity;
        amountB = (liquidity * pool.reserveB) / pool.totalLiquidity;

        require(amountA >= amountAMin, "DEX: insufficient A amount");
        require(amountB >= amountBMin, "DEX: insufficient B amount");


        pool.reserveA -= amountA;
        pool.reserveB -= amountB;
        pool.totalLiquidity -= liquidity;
        pool.liquidityBalance[msg.sender] -= liquidity;


        IERC20(pool.tokenA).safeTransfer(msg.sender, amountA);
        IERC20(pool.tokenB).safeTransfer(msg.sender, amountB);

        emit LiquidityRemoved(poolId, msg.sender, amountA, amountB, liquidity);
    }


    function swapExactTokensForTokens(
        uint256 poolId,
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn
    ) external nonReentrant whenNotPaused returns (uint256 amountOut) {
        Pool storage pool = pools[poolId];
        require(pool.exists, "DEX: pool does not exist");
        require(amountIn > 0, "DEX: amountIn must be greater than zero");
        require(tokenIn == pool.tokenA || tokenIn == pool.tokenB, "DEX: invalid input token");

        bool isTokenA = tokenIn == pool.tokenA;
        address tokenOut = isTokenA ? pool.tokenB : pool.tokenA;
        uint256 reserveIn = isTokenA ? pool.reserveA : pool.reserveB;
        uint256 reserveOut = isTokenA ? pool.reserveB : pool.reserveA;


        uint256 amountInWithFee = amountIn * (10000 - tradingFee);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10000) + amountInWithFee;
        amountOut = numerator / denominator;

        require(amountOut >= amountOutMin, "DEX: insufficient output amount");
        require(amountOut < reserveOut, "DEX: insufficient liquidity");


        if (isTokenA) {
            pool.reserveA += amountIn;
            pool.reserveB -= amountOut;
        } else {
            pool.reserveB += amountIn;
            pool.reserveA -= amountOut;
        }


        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);

        uint256 fee = (amountIn * tradingFee) / 10000;

        emit TokenSwapped(poolId, msg.sender, tokenIn, tokenOut, amountIn, amountOut, fee);
    }


    function getAmountOut(
        uint256 poolId,
        uint256 amountIn,
        address tokenIn
    ) external view returns (uint256 amountOut) {
        Pool storage pool = pools[poolId];
        require(pool.exists, "DEX: pool does not exist");
        require(amountIn > 0, "DEX: amountIn must be greater than zero");
        require(tokenIn == pool.tokenA || tokenIn == pool.tokenB, "DEX: invalid input token");

        bool isTokenA = tokenIn == pool.tokenA;
        uint256 reserveIn = isTokenA ? pool.reserveA : pool.reserveB;
        uint256 reserveOut = isTokenA ? pool.reserveB : pool.reserveA;

        uint256 amountInWithFee = amountIn * (10000 - tradingFee);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10000) + amountInWithFee;
        amountOut = numerator / denominator;
    }


    function getLiquidityBalance(uint256 poolId, address user) external view returns (uint256) {
        return pools[poolId].liquidityBalance[user];
    }


    function getReserves(uint256 poolId) external view returns (uint256 reserveA, uint256 reserveB) {
        Pool storage pool = pools[poolId];
        return (pool.reserveA, pool.reserveB);
    }


    function setTradingFee(uint256 newFee) external onlyOwner {
        require(newFee <= MAX_FEE, "DEX: fee exceeds maximum");
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


    function emergencyWithdraw(address token, uint256 amount) external onlyOwner whenPaused {
        require(token != address(0), "DEX: token cannot be zero address");
        IERC20(token).safeTransfer(owner(), amount);
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
