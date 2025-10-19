
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract OptimizedDEX is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;


    struct Pool {
        uint128 reserve0;
        uint128 reserve1;
        uint32 blockTimestampLast;
        uint96 totalSupply;
        uint160 kLast;
    }


    struct Order {
        address user;
        uint96 amount;
        uint32 timestamp;
        bool isActive;
    }


    mapping(bytes32 => Pool) public pools;
    mapping(bytes32 => mapping(address => uint256)) public balances;
    mapping(address => mapping(address => uint256)) public allowances;
    mapping(bytes32 => Order[]) public orders;


    mapping(bytes32 => uint256) private cachedPrices;
    mapping(bytes32 => uint256) private priceUpdateBlock;


    uint256 private constant MINIMUM_LIQUIDITY = 1000;
    uint256 private constant FEE_RATE = 30;
    uint256 private constant FEE_DENOMINATOR = 10000;
    uint256 private constant PRICE_CACHE_BLOCKS = 5;


    event Swap(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    event AddLiquidity(
        address indexed user,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity
    );

    event RemoveLiquidity(
        address indexed user,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity
    );

    constructor() {}


    function getPoolKey(address token0, address token1) public pure returns (bytes32) {
        return token0 < token1 ?
            keccak256(abi.encodePacked(token0, token1)) :
            keccak256(abi.encodePacked(token1, token0));
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
        Pool storage pool = pools[poolKey];


        uint256 _reserve0 = pool.reserve0;
        uint256 _reserve1 = pool.reserve1;
        uint256 _totalSupply = pool.totalSupply;

        if (_totalSupply == 0) {
            amount0 = amount0Desired;
            amount1 = amount1Desired;
            liquidity = sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;


            pool.reserve0 = uint128(amount0);
            pool.reserve1 = uint128(amount1);
            pool.totalSupply = uint96(liquidity + MINIMUM_LIQUIDITY);
        } else {
            uint256 amount1Optimal = (amount0Desired * _reserve1) / _reserve0;
            if (amount1Optimal <= amount1Desired) {
                require(amount1Optimal >= amount1Min, "Insufficient token1 amount");
                amount0 = amount0Desired;
                amount1 = amount1Optimal;
            } else {
                uint256 amount0Optimal = (amount1Desired * _reserve0) / _reserve1;
                require(amount0Optimal >= amount0Min, "Insufficient token0 amount");
                amount0 = amount0Optimal;
                amount1 = amount1Desired;
            }

            liquidity = min((amount0 * _totalSupply) / _reserve0, (amount1 * _totalSupply) / _reserve1);


            pool.reserve0 = uint128(_reserve0 + amount0);
            pool.reserve1 = uint128(_reserve1 + amount1);
            pool.totalSupply = uint96(_totalSupply + liquidity);
        }

        pool.blockTimestampLast = uint32(block.timestamp);
        balances[poolKey][msg.sender] += liquidity;

        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1);

        emit AddLiquidity(msg.sender, token0, token1, amount0, amount1, liquidity);
    }


    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin
    ) external nonReentrant returns (uint256 amountOut) {
        bytes32 poolKey = getPoolKey(tokenIn, tokenOut);
        Pool storage pool = pools[poolKey];


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


        uint256 currentBlock = block.number;
        if (currentBlock - priceUpdateBlock[poolKey] < PRICE_CACHE_BLOCKS) {
            amountOut = (amountIn * cachedPrices[poolKey]) / 1e18;
        } else {
            amountOut = getAmountOut(amountIn, reserveIn, reserveOut);

            cachedPrices[poolKey] = (amountOut * 1e18) / amountIn;
            priceUpdateBlock[poolKey] = currentBlock;
        }

        require(amountOut >= amountOutMin, "Insufficient output amount");


        if (tokenIn < tokenOut) {
            pool.reserve0 = uint128(reserveIn + amountIn);
            pool.reserve1 = uint128(reserveOut - amountOut);
        } else {
            pool.reserve0 = uint128(reserveOut - amountOut);
            pool.reserve1 = uint128(reserveIn + amountIn);
        }

        pool.blockTimestampLast = uint32(block.timestamp);

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }


    function removeLiquidity(
        address token0,
        address token1,
        uint256 liquidity,
        uint256 amount0Min,
        uint256 amount1Min
    ) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        bytes32 poolKey = getPoolKey(token0, token1);
        Pool storage pool = pools[poolKey];

        require(balances[poolKey][msg.sender] >= liquidity, "Insufficient liquidity");


        uint256 _reserve0 = pool.reserve0;
        uint256 _reserve1 = pool.reserve1;
        uint256 _totalSupply = pool.totalSupply;

        amount0 = (liquidity * _reserve0) / _totalSupply;
        amount1 = (liquidity * _reserve1) / _totalSupply;

        require(amount0 >= amount0Min && amount1 >= amount1Min, "Insufficient output");


        balances[poolKey][msg.sender] -= liquidity;
        pool.reserve0 = uint128(_reserve0 - amount0);
        pool.reserve1 = uint128(_reserve1 - amount1);
        pool.totalSupply = uint96(_totalSupply - liquidity);
        pool.blockTimestampLast = uint32(block.timestamp);

        IERC20(token0).safeTransfer(msg.sender, amount0);
        IERC20(token1).safeTransfer(msg.sender, amount1);

        emit RemoveLiquidity(msg.sender, token0, token1, amount0, amount1, liquidity);
    }


    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        require(amountIn > 0 && reserveIn > 0 && reserveOut > 0, "Invalid input");

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_RATE);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;

        amountOut = numerator / denominator;
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountIn) {
        require(amountOut > 0 && reserveIn > 0 && reserveOut > 0, "Invalid input");

        uint256 numerator = reserveIn * amountOut * FEE_DENOMINATOR;
        uint256 denominator = (reserveOut - amountOut) * (FEE_DENOMINATOR - FEE_RATE);

        amountIn = (numerator / denominator) + 1;
    }


    function getReserves(address token0, address token1)
        external
        view
        returns (uint256 reserve0, uint256 reserve1, uint256 blockTimestampLast)
    {
        bytes32 poolKey = getPoolKey(token0, token1);
        Pool memory pool = pools[poolKey];

        if (token0 < token1) {
            return (pool.reserve0, pool.reserve1, pool.blockTimestampLast);
        } else {
            return (pool.reserve1, pool.reserve0, pool.blockTimestampLast);
        }
    }

    function getPrice(address token0, address token1) external view returns (uint256) {
        bytes32 poolKey = getPoolKey(token0, token1);


        if (block.number - priceUpdateBlock[poolKey] < PRICE_CACHE_BLOCKS) {
            return cachedPrices[poolKey];
        }

        Pool memory pool = pools[poolKey];
        if (pool.reserve0 == 0 || pool.reserve1 == 0) return 0;

        return token0 < token1 ?
            (pool.reserve1 * 1e18) / pool.reserve0 :
            (pool.reserve0 * 1e18) / pool.reserve1;
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


    function emergencyWithdraw(address token) external onlyOwner {
        IERC20(token).safeTransfer(owner(), IERC20(token).balanceOf(address(this)));
    }

    function pause() external onlyOwner {

    }
}
