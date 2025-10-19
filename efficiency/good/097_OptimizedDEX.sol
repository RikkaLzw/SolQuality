
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract OptimizedDEX is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;


    struct LiquidityPool {
        uint128 reserve0;
        uint128 reserve1;
        uint32 lastUpdateTime;
        uint32 feeRate;
    }

    struct UserLiquidity {
        uint128 liquidity;
        uint128 lastRewardPerToken;
    }


    mapping(address => mapping(address => LiquidityPool)) public pools;
    mapping(address => mapping(address => mapping(address => UserLiquidity))) public userLiquidity;
    mapping(address => mapping(address => uint256)) public totalLiquidity;


    uint256 private constant MINIMUM_LIQUIDITY = 1000;
    uint256 private constant MAX_FEE_RATE = 1000;
    uint256 private constant PRECISION = 1e18;


    event LiquidityAdded(
        address indexed user,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity
    );

    event LiquidityRemoved(
        address indexed user,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity
    );

    event Swap(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    constructor() {}


    function addLiquidity(
        address token0,
        address token1,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) external nonReentrant whenNotPaused returns (uint256 liquidity) {

        (address tokenA, address tokenB) = _sortTokens(token0, token1);
        (uint256 amountA, uint256 amountB) = tokenA == token0
            ? (amount0Desired, amount1Desired)
            : (amount1Desired, amount0Desired);


        LiquidityPool memory pool = pools[tokenA][tokenB];
        uint256 totalLiq = totalLiquidity[tokenA][tokenB];

        uint256 amountAOptimal;
        uint256 amountBOptimal;

        if (pool.reserve0 == 0 && pool.reserve1 == 0) {

            amountAOptimal = amountA;
            amountBOptimal = amountB;
            liquidity = _sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
            require(liquidity > 0, "Insufficient liquidity minted");
        } else {

            uint256 amountBQuote = _quote(amountA, pool.reserve0, pool.reserve1);
            if (amountBQuote <= amountB) {
                require(amountBQuote >= (tokenA == token0 ? amount1Min : amount0Min), "Insufficient B amount");
                amountAOptimal = amountA;
                amountBOptimal = amountBQuote;
            } else {
                uint256 amountAQuote = _quote(amountB, pool.reserve1, pool.reserve0);
                require(amountAQuote <= amountA && amountAQuote >= (tokenA == token0 ? amount0Min : amount1Min), "Insufficient A amount");
                amountAOptimal = amountAQuote;
                amountBOptimal = amountB;
            }


            liquidity = _min(
                (amountAOptimal * totalLiq) / pool.reserve0,
                (amountBOptimal * totalLiq) / pool.reserve1
            );
        }

        require(liquidity > 0, "Insufficient liquidity minted");


        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountAOptimal);
        IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountBOptimal);


        pools[tokenA][tokenB] = LiquidityPool({
            reserve0: uint128(pool.reserve0 + amountAOptimal),
            reserve1: uint128(pool.reserve1 + amountBOptimal),
            lastUpdateTime: uint32(block.timestamp),
            feeRate: pool.feeRate == 0 ? 30 : pool.feeRate
        });


        userLiquidity[tokenA][tokenB][msg.sender].liquidity += uint128(liquidity);
        totalLiquidity[tokenA][tokenB] = totalLiq + liquidity;

        emit LiquidityAdded(
            msg.sender,
            tokenA,
            tokenB,
            amountAOptimal,
            amountBOptimal,
            liquidity
        );

        return liquidity;
    }


    function removeLiquidity(
        address token0,
        address token1,
        uint256 liquidity,
        uint256 amount0Min,
        uint256 amount1Min
    ) external nonReentrant whenNotPaused returns (uint256 amount0, uint256 amount1) {
        (address tokenA, address tokenB) = _sortTokens(token0, token1);


        LiquidityPool memory pool = pools[tokenA][tokenB];
        uint256 totalLiq = totalLiquidity[tokenA][tokenB];
        UserLiquidity memory userLiq = userLiquidity[tokenA][tokenB][msg.sender];

        require(userLiq.liquidity >= liquidity, "Insufficient liquidity");
        require(totalLiq > 0, "No liquidity");


        uint256 amountA = (liquidity * pool.reserve0) / totalLiq;
        uint256 amountB = (liquidity * pool.reserve1) / totalLiq;

        (amount0, amount1) = tokenA == token0 ? (amountA, amountB) : (amountB, amountA);

        require(amount0 >= amount0Min && amount1 >= amount1Min, "Insufficient output amount");


        pools[tokenA][tokenB] = LiquidityPool({
            reserve0: uint128(pool.reserve0 - amountA),
            reserve1: uint128(pool.reserve1 - amountB),
            lastUpdateTime: uint32(block.timestamp),
            feeRate: pool.feeRate
        });

        userLiquidity[tokenA][tokenB][msg.sender].liquidity = uint128(userLiq.liquidity - liquidity);
        totalLiquidity[tokenA][tokenB] = totalLiq - liquidity;


        IERC20(tokenA).safeTransfer(msg.sender, amountA);
        IERC20(tokenB).safeTransfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, tokenA, tokenB, amountA, amountB, liquidity);
    }


    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path
    ) external nonReentrant whenNotPaused returns (uint256[] memory amounts) {
        require(path.length >= 2, "Invalid path");

        amounts = new uint256[](path.length);
        amounts[0] = amountIn;


        for (uint256 i; i < path.length - 1;) {
            (address tokenA, address tokenB) = _sortTokens(path[i], path[i + 1]);
            LiquidityPool memory pool = pools[tokenA][tokenB];

            require(pool.reserve0 > 0 && pool.reserve1 > 0, "Insufficient liquidity");

            bool isToken0 = path[i] == tokenA;
            (uint128 reserveIn, uint128 reserveOut) = isToken0
                ? (pool.reserve0, pool.reserve1)
                : (pool.reserve1, pool.reserve0);

            amounts[i + 1] = _getAmountOut(amounts[i], reserveIn, reserveOut, pool.feeRate);


            if (isToken0) {
                pools[tokenA][tokenB].reserve0 += uint128(amounts[i]);
                pools[tokenA][tokenB].reserve1 -= uint128(amounts[i + 1]);
            } else {
                pools[tokenA][tokenB].reserve0 -= uint128(amounts[i + 1]);
                pools[tokenA][tokenB].reserve1 += uint128(amounts[i]);
            }
            pools[tokenA][tokenB].lastUpdateTime = uint32(block.timestamp);

            unchecked { ++i; }
        }

        require(amounts[amounts.length - 1] >= amountOutMin, "Insufficient output amount");


        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amounts[0]);
        IERC20(path[path.length - 1]).safeTransfer(msg.sender, amounts[amounts.length - 1]);

        emit Swap(msg.sender, path[0], path[path.length - 1], amounts[0], amounts[amounts.length - 1]);

        return amounts;
    }


    function getAmountOut(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) external view returns (uint256 amountOut) {
        (address tokenA, address tokenB) = _sortTokens(tokenIn, tokenOut);
        LiquidityPool memory pool = pools[tokenA][tokenB];

        bool isToken0 = tokenIn == tokenA;
        (uint128 reserveIn, uint128 reserveOut) = isToken0
            ? (pool.reserve0, pool.reserve1)
            : (pool.reserve1, pool.reserve0);

        return _getAmountOut(amountIn, reserveIn, reserveOut, pool.feeRate);
    }

    function getReserves(address token0, address token1)
        external
        view
        returns (uint128 reserve0, uint128 reserve1, uint32 lastUpdateTime)
    {
        (address tokenA, address tokenB) = _sortTokens(token0, token1);
        LiquidityPool memory pool = pools[tokenA][tokenB];

        (reserve0, reserve1) = token0 == tokenA
            ? (pool.reserve0, pool.reserve1)
            : (pool.reserve1, pool.reserve0);
        lastUpdateTime = pool.lastUpdateTime;
    }


    function _sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        require(tokenA != tokenB, "Identical tokens");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "Zero address");
    }

    function _quote(uint256 amountA, uint256 reserveA, uint256 reserveB)
        internal
        pure
        returns (uint256 amountB)
    {
        require(amountA > 0, "Insufficient amount");
        require(reserveA > 0 && reserveB > 0, "Insufficient liquidity");
        amountB = (amountA * reserveB) / reserveA;
    }

    function _getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 feeRate
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "Insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");

        uint256 amountInWithFee = amountIn * (10000 - feeRate);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function _min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
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


    function setFeeRate(address token0, address token1, uint32 feeRate) external onlyOwner {
        require(feeRate <= MAX_FEE_RATE, "Fee too high");
        (address tokenA, address tokenB) = _sortTokens(token0, token1);
        pools[tokenA][tokenB].feeRate = feeRate;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
    }
}
