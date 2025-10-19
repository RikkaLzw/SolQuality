
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract OptimizedDEX is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;


    struct Pool {
        uint128 reserve0;
        uint128 reserve1;
        uint32 blockTimestampLast;
        uint96 kLast;
    }

    struct UserLiquidity {
        uint128 liquidity;
        uint128 lastRewardDebt;
    }


    uint256 private constant MINIMUM_LIQUIDITY = 10**3;
    uint256 private constant FEE_DENOMINATOR = 10000;
    uint256 private immutable FEE_RATE;


    mapping(address => mapping(address => Pool)) public pools;
    mapping(address => mapping(address => mapping(address => UserLiquidity))) public userLiquidity;
    mapping(address => mapping(address => uint256)) public totalLiquidity;


    mapping(address => mapping(address => bool)) public poolExists;


    event PoolCreated(address indexed token0, address indexed token1);
    event LiquidityAdded(address indexed user, address indexed token0, address indexed token1, uint256 amount0, uint256 amount1, uint256 liquidity);
    event LiquidityRemoved(address indexed user, address indexed token0, address indexed token1, uint256 amount0, uint256 amount1, uint256 liquidity);
    event Swap(address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    constructor(uint256 _feeRate) {
        require(_feeRate <= 100, "Fee too high");
        FEE_RATE = _feeRate;
    }


    function createPool(address token0, address token1) external returns (bool) {
        require(token0 != token1, "Identical tokens");
        require(token0 != address(0) && token1 != address(0), "Zero address");


        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }

        require(!poolExists[token0][token1], "Pool exists");

        poolExists[token0][token1] = true;
        emit PoolCreated(token0, token1);

        return true;
    }


    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) external nonReentrant whenNotPaused returns (uint256 amountA, uint256 amountB, uint256 liquidity) {

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(poolExists[token0][token1], "Pool not exists");


        Pool memory pool = pools[token0][token1];

        if (pool.reserve0 == 0 && pool.reserve1 == 0) {

            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {

            uint256 amountBOptimal = (amountADesired * pool.reserve1) / pool.reserve0;
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "Insufficient B amount");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = (amountBDesired * pool.reserve0) / pool.reserve1;
                require(amountAOptimal <= amountADesired && amountAOptimal >= amountAMin, "Insufficient A amount");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }


        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountB);


        uint256 _totalLiquidity = totalLiquidity[token0][token1];
        if (_totalLiquidity == 0) {
            liquidity = _sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
            totalLiquidity[token0][token1] = MINIMUM_LIQUIDITY;
        } else {
            liquidity = _min((amountA * _totalLiquidity) / pool.reserve0, (amountB * _totalLiquidity) / pool.reserve1);
        }

        require(liquidity > 0, "Insufficient liquidity minted");


        pools[token0][token1] = Pool({
            reserve0: uint128(pool.reserve0 + amountA),
            reserve1: uint128(pool.reserve1 + amountB),
            blockTimestampLast: uint32(block.timestamp),
            kLast: uint96((pool.reserve0 + amountA) * (pool.reserve1 + amountB))
        });

        totalLiquidity[token0][token1] += liquidity;
        userLiquidity[msg.sender][token0][token1].liquidity += uint128(liquidity);

        emit LiquidityAdded(msg.sender, token0, token1, amountA, amountB, liquidity);
    }


    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin
    ) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(poolExists[token0][token1], "Pool not exists");

        UserLiquidity storage userLiq = userLiquidity[msg.sender][token0][token1];
        require(userLiq.liquidity >= liquidity, "Insufficient liquidity");


        Pool memory pool = pools[token0][token1];
        uint256 _totalLiquidity = totalLiquidity[token0][token1];


        amountA = (liquidity * pool.reserve0) / _totalLiquidity;
        amountB = (liquidity * pool.reserve1) / _totalLiquidity;

        require(amountA >= amountAMin && amountB >= amountBMin, "Insufficient output amount");


        userLiq.liquidity -= uint128(liquidity);
        totalLiquidity[token0][token1] -= liquidity;

        pools[token0][token1] = Pool({
            reserve0: uint128(pool.reserve0 - amountA),
            reserve1: uint128(pool.reserve1 - amountB),
            blockTimestampLast: uint32(block.timestamp),
            kLast: uint96((pool.reserve0 - amountA) * (pool.reserve1 - amountB))
        });


        IERC20(token0).safeTransfer(msg.sender, amountA);
        IERC20(token1).safeTransfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, token0, token1, amountA, amountB, liquidity);
    }


    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to
    ) external nonReentrant whenNotPaused returns (uint256[] memory amounts) {
        require(path.length >= 2, "Invalid path");
        amounts = getAmountsOut(amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "Insufficient output amount");

        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amounts[0]);
        _swap(amounts, path, to);
    }


    function _swap(uint256[] memory amounts, address[] calldata path, address to) internal {
        for (uint256 i; i < path.length - 1;) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, address token1) = input < output ? (input, output) : (output, input);
            uint256 amountOut = amounts[i + 1];


            Pool storage pool = pools[token0][token1];

            (uint256 amount0Out, uint256 amount1Out) = input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));

            address recipient = i < path.length - 2 ? address(this) : to;


            if (amount0Out > 0) {
                pool.reserve1 = uint128(uint256(pool.reserve1) + amounts[i]);
                pool.reserve0 = uint128(uint256(pool.reserve0) - amount0Out);
                IERC20(token0).safeTransfer(recipient, amount0Out);
            } else {
                pool.reserve0 = uint128(uint256(pool.reserve0) + amounts[i]);
                pool.reserve1 = uint128(uint256(pool.reserve1) - amount1Out);
                IERC20(token1).safeTransfer(recipient, amount1Out);
            }

            pool.blockTimestampLast = uint32(block.timestamp);

            emit Swap(msg.sender, input, output, amounts[i], amountOut);

            unchecked { ++i; }
        }
    }


    function getAmountsOut(uint256 amountIn, address[] calldata path) public view returns (uint256[] memory amounts) {
        require(path.length >= 2, "Invalid path");
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;

        for (uint256 i; i < path.length - 1;) {
            (address token0, address token1) = path[i] < path[i + 1] ? (path[i], path[i + 1]) : (path[i + 1], path[i]);
            Pool memory pool = pools[token0][token1];

            (uint256 reserveIn, uint256 reserveOut) = path[i] == token0 ? (uint256(pool.reserve0), uint256(pool.reserve1)) : (uint256(pool.reserve1), uint256(pool.reserve0));
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);

            unchecked { ++i; }
        }
    }


    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public view returns (uint256 amountOut) {
        require(amountIn > 0 && reserveIn > 0 && reserveOut > 0, "Invalid input");

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_RATE);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;

        amountOut = numerator / denominator;
    }


    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }


    function _min(uint256 x, uint256 y) private pure returns (uint256 z) {
        z = x < y ? x : y;
    }

    function _sqrt(uint256 y) private pure returns (uint256 z) {
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


    function getPool(address token0, address token1) external view returns (Pool memory) {
        (address tokenA, address tokenB) = token0 < token1 ? (token0, token1) : (token1, token0);
        return pools[tokenA][tokenB];
    }


    function getUserLiquidity(address user, address token0, address token1) external view returns (UserLiquidity memory) {
        (address tokenA, address tokenB) = token0 < token1 ? (token0, token1) : (token1, token0);
        return userLiquidity[user][tokenA][tokenB];
    }
}
