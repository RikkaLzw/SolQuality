
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract DecentralizedExchange is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Pool {
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalLiquidity;
        bool exists;
    }

    mapping(bytes32 => Pool) public pools;
    mapping(bytes32 => mapping(address => uint256)) public liquidityBalances;
    mapping(address => bool) public supportedTokens;

    uint256 public constant FEE_RATE = 3;
    uint256 public constant FEE_DENOMINATOR = 1000;
    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    event PoolCreated(address indexed tokenA, address indexed tokenB, bytes32 poolId);
    event LiquidityAdded(address indexed provider, bytes32 poolId, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, bytes32 poolId, uint256 amountA, uint256 amountB, uint256 liquidity);
    event TokensSwapped(address indexed trader, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    constructor() {}

    function addSupportedToken(address token) external onlyOwner {
        require(token != address(0), "Invalid token address");
        supportedTokens[token] = true;
    }

    function removeSupportedToken(address token) external onlyOwner {
        supportedTokens[token] = false;
    }

    function createPool(address tokenA, address tokenB) external returns (bytes32) {
        require(supportedTokens[tokenA] && supportedTokens[tokenB], "Unsupported tokens");
        require(tokenA != tokenB, "Identical tokens");

        bytes32 poolId = _getPoolId(tokenA, tokenB);
        require(!pools[poolId].exists, "Pool already exists");

        pools[poolId] = Pool({
            tokenA: tokenA,
            tokenB: tokenB,
            reserveA: 0,
            reserveB: 0,
            totalLiquidity: 0,
            exists: true
        });

        emit PoolCreated(tokenA, tokenB, poolId);
        return poolId;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) external nonReentrant returns (uint256) {
        bytes32 poolId = _getPoolId(tokenA, tokenB);
        require(pools[poolId].exists, "Pool does not exist");
        require(amountA > 0 && amountB > 0, "Invalid amounts");

        Pool storage pool = pools[poolId];
        uint256 liquidityMinted = _calculateLiquidity(pool, amountA, amountB);

        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountB);

        pool.reserveA += amountA;
        pool.reserveB += amountB;
        pool.totalLiquidity += liquidityMinted;
        liquidityBalances[poolId][msg.sender] += liquidityMinted;

        emit LiquidityAdded(msg.sender, poolId, amountA, amountB, liquidityMinted);
        return liquidityMinted;
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity
    ) external nonReentrant returns (uint256, uint256) {
        bytes32 poolId = _getPoolId(tokenA, tokenB);
        require(pools[poolId].exists, "Pool does not exist");
        require(liquidityBalances[poolId][msg.sender] >= liquidity, "Insufficient liquidity");

        Pool storage pool = pools[poolId];
        (uint256 amountA, uint256 amountB) = _calculateWithdrawal(pool, liquidity);

        liquidityBalances[poolId][msg.sender] -= liquidity;
        pool.totalLiquidity -= liquidity;
        pool.reserveA -= amountA;
        pool.reserveB -= amountB;

        IERC20(tokenA).safeTransfer(msg.sender, amountA);
        IERC20(tokenB).safeTransfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, poolId, amountA, amountB, liquidity);
        return (amountA, amountB);
    }

    function swapTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external nonReentrant returns (uint256) {
        bytes32 poolId = _getPoolId(tokenIn, tokenOut);
        require(pools[poolId].exists, "Pool does not exist");
        require(amountIn > 0, "Invalid input amount");

        Pool storage pool = pools[poolId];
        uint256 amountOut = _calculateSwapOutput(pool, tokenIn, amountIn);
        require(amountOut >= minAmountOut, "Slippage exceeded");

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        _updateReserves(pool, tokenIn, amountIn, amountOut);

        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);

        emit TokensSwapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
        return amountOut;
    }

    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256) {
        bytes32 poolId = _getPoolId(tokenIn, tokenOut);
        require(pools[poolId].exists, "Pool does not exist");

        return _calculateSwapOutput(pools[poolId], tokenIn, amountIn);
    }

    function getPoolReserves(address tokenA, address tokenB) external view returns (uint256, uint256) {
        bytes32 poolId = _getPoolId(tokenA, tokenB);
        Pool memory pool = pools[poolId];
        return (pool.reserveA, pool.reserveB);
    }

    function _getPoolId(address tokenA, address tokenB) internal pure returns (bytes32) {
        return tokenA < tokenB ?
            keccak256(abi.encodePacked(tokenA, tokenB)) :
            keccak256(abi.encodePacked(tokenB, tokenA));
    }

    function _calculateLiquidity(
        Pool memory pool,
        uint256 amountA,
        uint256 amountB
    ) internal pure returns (uint256) {
        if (pool.totalLiquidity == 0) {
            return _sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
        }

        uint256 liquidityA = (amountA * pool.totalLiquidity) / pool.reserveA;
        uint256 liquidityB = (amountB * pool.totalLiquidity) / pool.reserveB;

        return liquidityA < liquidityB ? liquidityA : liquidityB;
    }

    function _calculateWithdrawal(
        Pool memory pool,
        uint256 liquidity
    ) internal pure returns (uint256, uint256) {
        uint256 amountA = (liquidity * pool.reserveA) / pool.totalLiquidity;
        uint256 amountB = (liquidity * pool.reserveB) / pool.totalLiquidity;

        return (amountA, amountB);
    }

    function _calculateSwapOutput(
        Pool memory pool,
        address tokenIn,
        uint256 amountIn
    ) internal view returns (uint256) {
        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_RATE);

        if (tokenIn == pool.tokenA) {
            return (amountInWithFee * pool.reserveB) / (pool.reserveA * FEE_DENOMINATOR + amountInWithFee);
        } else {
            return (amountInWithFee * pool.reserveA) / (pool.reserveB * FEE_DENOMINATOR + amountInWithFee);
        }
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
}
