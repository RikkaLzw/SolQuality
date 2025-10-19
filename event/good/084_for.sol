
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract DecentralizedExchange is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;


    uint256 public constant MAX_TRADING_FEE = 1000;
    uint256 public tradingFee = 30;


    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    struct Pool {
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalLiquidity;
        mapping(address => uint256) liquidityBalance;
        bool exists;
    }


    mapping(bytes32 => Pool) public pools;


    mapping(address => mapping(address => bytes32)) public getPoolId;


    bytes32[] public allPools;


    event PoolCreated(
        bytes32 indexed poolId,
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB
    );

    event LiquidityAdded(
        bytes32 indexed poolId,
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );

    event LiquidityRemoved(
        bytes32 indexed poolId,
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );

    event TokensSwapped(
        bytes32 indexed poolId,
        address indexed trader,
        address indexed tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee
    );

    event TradingFeeUpdated(
        uint256 oldFee,
        uint256 newFee
    );

    event FeesCollected(
        address indexed token,
        uint256 amount,
        address indexed recipient
    );


    error InvalidTokenAddress();
    error IdenticalTokens();
    error PoolAlreadyExists();
    error PoolDoesNotExist();
    error InsufficientAmount();
    error InsufficientLiquidity();
    error InsufficientReserves();
    error InvalidTradingFee();
    error SlippageExceeded();
    error DeadlineExpired();
    error ZeroAddress();

    constructor() {}


    function createPool(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) external nonReentrant whenNotPaused returns (bytes32 poolId) {
        if (tokenA == address(0) || tokenB == address(0)) {
            revert ZeroAddress();
        }
        if (tokenA == tokenB) {
            revert IdenticalTokens();
        }
        if (amountA == 0 || amountB == 0) {
            revert InsufficientAmount();
        }


        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
            (amountA, amountB) = (amountB, amountA);
        }

        poolId = keccak256(abi.encodePacked(tokenA, tokenB));

        if (pools[poolId].exists) {
            revert PoolAlreadyExists();
        }


        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountB);


        uint256 liquidity = _sqrt(amountA * amountB);
        if (liquidity <= MINIMUM_LIQUIDITY) {
            revert InsufficientLiquidity();
        }


        liquidity -= MINIMUM_LIQUIDITY;


        Pool storage pool = pools[poolId];
        pool.tokenA = tokenA;
        pool.tokenB = tokenB;
        pool.reserveA = amountA;
        pool.reserveB = amountB;
        pool.totalLiquidity = liquidity + MINIMUM_LIQUIDITY;
        pool.liquidityBalance[msg.sender] = liquidity;
        pool.exists = true;


        getPoolId[tokenA][tokenB] = poolId;
        getPoolId[tokenB][tokenA] = poolId;
        allPools.push(poolId);

        emit PoolCreated(poolId, tokenA, tokenB, amountA, amountB);
    }


    function addLiquidity(
        bytes32 poolId,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        uint256 deadline
    ) external nonReentrant whenNotPaused returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        if (block.timestamp > deadline) {
            revert DeadlineExpired();
        }
        if (!pools[poolId].exists) {
            revert PoolDoesNotExist();
        }

        Pool storage pool = pools[poolId];


        (amountA, amountB) = _calculateOptimalAmounts(
            pool.reserveA,
            pool.reserveB,
            amountADesired,
            amountBDesired
        );

        if (amountA < amountAMin) {
            revert SlippageExceeded();
        }
        if (amountB < amountBMin) {
            revert SlippageExceeded();
        }


        liquidity = _min(
            (amountA * pool.totalLiquidity) / pool.reserveA,
            (amountB * pool.totalLiquidity) / pool.reserveB
        );

        if (liquidity == 0) {
            revert InsufficientLiquidity();
        }


        IERC20(pool.tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(pool.tokenB).safeTransferFrom(msg.sender, address(this), amountB);


        pool.reserveA += amountA;
        pool.reserveB += amountB;
        pool.totalLiquidity += liquidity;
        pool.liquidityBalance[msg.sender] += liquidity;

        emit LiquidityAdded(poolId, msg.sender, amountA, amountB, liquidity);
    }


    function removeLiquidity(
        bytes32 poolId,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        uint256 deadline
    ) external nonReentrant whenNotPaused returns (uint256 amountA, uint256 amountB) {
        if (block.timestamp > deadline) {
            revert DeadlineExpired();
        }
        if (!pools[poolId].exists) {
            revert PoolDoesNotExist();
        }
        if (liquidity == 0) {
            revert InsufficientAmount();
        }

        Pool storage pool = pools[poolId];

        if (pool.liquidityBalance[msg.sender] < liquidity) {
            revert InsufficientLiquidity();
        }


        amountA = (liquidity * pool.reserveA) / pool.totalLiquidity;
        amountB = (liquidity * pool.reserveB) / pool.totalLiquidity;

        if (amountA < amountAMin) {
            revert SlippageExceeded();
        }
        if (amountB < amountBMin) {
            revert SlippageExceeded();
        }


        pool.liquidityBalance[msg.sender] -= liquidity;
        pool.totalLiquidity -= liquidity;
        pool.reserveA -= amountA;
        pool.reserveB -= amountB;


        IERC20(pool.tokenA).safeTransfer(msg.sender, amountA);
        IERC20(pool.tokenB).safeTransfer(msg.sender, amountB);

        emit LiquidityRemoved(poolId, msg.sender, amountA, amountB, liquidity);
    }


    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn,
        address tokenOut,
        uint256 deadline
    ) external nonReentrant whenNotPaused returns (uint256 amountOut) {
        if (block.timestamp > deadline) {
            revert DeadlineExpired();
        }
        if (amountIn == 0) {
            revert InsufficientAmount();
        }
        if (tokenIn == tokenOut) {
            revert IdenticalTokens();
        }

        bytes32 poolId = getPoolId[tokenIn][tokenOut];
        if (!pools[poolId].exists) {
            revert PoolDoesNotExist();
        }

        Pool storage pool = pools[poolId];


        (uint256 reserveIn, uint256 reserveOut) = tokenIn == pool.tokenA
            ? (pool.reserveA, pool.reserveB)
            : (pool.reserveB, pool.reserveA);


        amountOut = _getAmountOut(amountIn, reserveIn, reserveOut);

        if (amountOut < amountOutMin) {
            revert SlippageExceeded();
        }
        if (amountOut >= reserveOut) {
            revert InsufficientReserves();
        }


        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);


        if (tokenIn == pool.tokenA) {
            pool.reserveA += amountIn;
            pool.reserveB -= amountOut;
        } else {
            pool.reserveB += amountIn;
            pool.reserveA -= amountOut;
        }


        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);


        uint256 fee = (amountIn * tradingFee) / 10000;

        emit TokensSwapped(poolId, msg.sender, tokenIn, tokenOut, amountIn, amountOut, fee);
    }


    function getAddLiquidityQuote(
        bytes32 poolId,
        uint256 amountADesired,
        uint256 amountBDesired
    ) external view returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        if (!pools[poolId].exists) {
            revert PoolDoesNotExist();
        }

        Pool storage pool = pools[poolId];

        (amountA, amountB) = _calculateOptimalAmounts(
            pool.reserveA,
            pool.reserveB,
            amountADesired,
            amountBDesired
        );

        liquidity = _min(
            (amountA * pool.totalLiquidity) / pool.reserveA,
            (amountB * pool.totalLiquidity) / pool.reserveB
        );
    }


    function getAmountOut(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) external view returns (uint256 amountOut) {
        bytes32 poolId = getPoolId[tokenIn][tokenOut];
        if (!pools[poolId].exists) {
            revert PoolDoesNotExist();
        }

        Pool storage pool = pools[poolId];

        (uint256 reserveIn, uint256 reserveOut) = tokenIn == pool.tokenA
            ? (pool.reserveA, pool.reserveB)
            : (pool.reserveB, pool.reserveA);

        amountOut = _getAmountOut(amountIn, reserveIn, reserveOut);
    }


    function getLiquidityBalance(bytes32 poolId, address user) external view returns (uint256) {
        return pools[poolId].liquidityBalance[user];
    }


    function getReserves(bytes32 poolId) external view returns (uint256 reserveA, uint256 reserveB) {
        Pool storage pool = pools[poolId];
        return (pool.reserveA, pool.reserveB);
    }


    function getPoolCount() external view returns (uint256) {
        return allPools.length;
    }


    function setTradingFee(uint256 newFee) external onlyOwner {
        if (newFee > MAX_TRADING_FEE) {
            revert InvalidTradingFee();
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



    function _getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal view returns (uint256 amountOut) {
        if (reserveIn == 0 || reserveOut == 0) {
            revert InsufficientReserves();
        }

        uint256 amountInWithFee = amountIn * (10000 - tradingFee);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function _calculateOptimalAmounts(
        uint256 reserveA,
        uint256 reserveB,
        uint256 amountADesired,
        uint256 amountBDesired
    ) internal pure returns (uint256 amountA, uint256 amountB) {
        uint256 amountBOptimal = (amountADesired * reserveB) / reserveA;
        if (amountBOptimal <= amountBDesired) {
            return (amountADesired, amountBOptimal);
        } else {
            uint256 amountAOptimal = (amountBDesired * reserveA) / reserveB;
            return (amountAOptimal, amountBDesired);
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

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
