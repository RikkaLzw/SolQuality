
pragma solidity ^0.8.19;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract OptimizedDEX {

    struct Pool {
        uint128 reserve0;
        uint128 reserve1;
        uint32 blockTimestampLast;
        bool exists;
    }

    struct UserLiquidity {
        uint128 amount;
        uint128 lastRewardPerShare;
    }


    mapping(bytes32 => Pool) public pools;
    mapping(bytes32 => mapping(address => UserLiquidity)) public userLiquidity;
    mapping(bytes32 => uint256) public totalLiquidity;
    mapping(bytes32 => uint256) public rewardPerShare;

    address public immutable factory;
    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    uint256 public constant FEE_RATE = 30;
    uint256 public constant FEE_DENOMINATOR = 10000;

    event Swap(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

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

    modifier poolExists(address token0, address token1) {
        bytes32 poolId = getPoolId(token0, token1);
        require(pools[poolId].exists, "Pool does not exist");
        _;
    }

    constructor() {
        factory = msg.sender;
    }

    function getPoolId(address token0, address token1) public pure returns (bytes32) {

        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }
        return keccak256(abi.encodePacked(token0, token1));
    }

    function createPool(address token0, address token1) external returns (bytes32 poolId) {
        require(token0 != token1, "Identical tokens");
        require(token0 != address(0) && token1 != address(0), "Zero address");

        poolId = getPoolId(token0, token1);
        require(!pools[poolId].exists, "Pool already exists");

        pools[poolId] = Pool({
            reserve0: 0,
            reserve1: 0,
            blockTimestampLast: uint32(block.timestamp),
            exists: true
        });
    }

    function addLiquidity(
        address token0,
        address token1,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) external poolExists(token0, token1) returns (uint256 liquidity) {
        bytes32 poolId = getPoolId(token0, token1);
        Pool storage pool = pools[poolId];

        uint256 amount0;
        uint256 amount1;


        uint256 reserve0 = uint256(pool.reserve0);
        uint256 reserve1 = uint256(pool.reserve1);
        uint256 totalLiq = totalLiquidity[poolId];

        if (reserve0 == 0 && reserve1 == 0) {

            amount0 = amount0Desired;
            amount1 = amount1Desired;
            liquidity = sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;

            userLiquidity[poolId][address(0)].amount = uint128(MINIMUM_LIQUIDITY);
            totalLiq = liquidity + MINIMUM_LIQUIDITY;
        } else {

            uint256 amount1Optimal = (amount0Desired * reserve1) / reserve0;
            if (amount1Optimal <= amount1Desired) {
                require(amount1Optimal >= amount1Min, "Insufficient token1 amount");
                amount0 = amount0Desired;
                amount1 = amount1Optimal;
            } else {
                uint256 amount0Optimal = (amount1Desired * reserve0) / reserve1;
                require(amount0Optimal >= amount0Min, "Insufficient token0 amount");
                amount0 = amount0Optimal;
                amount1 = amount1Desired;
            }
            liquidity = min((amount0 * totalLiq) / reserve0, (amount1 * totalLiq) / reserve1);
        }

        require(liquidity > 0, "Insufficient liquidity minted");


        pool.reserve0 = uint128(reserve0 + amount0);
        pool.reserve1 = uint128(reserve1 + amount1);
        totalLiquidity[poolId] = totalLiq + liquidity;

        UserLiquidity storage userLiq = userLiquidity[poolId][msg.sender];
        userLiq.amount += uint128(liquidity);
        userLiq.lastRewardPerShare = uint128(rewardPerShare[poolId]);


        IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        IERC20(token1).transferFrom(msg.sender, address(this), amount1);

        emit LiquidityAdded(msg.sender, token0, token1, amount0, amount1, liquidity);
    }

    function removeLiquidity(
        address token0,
        address token1,
        uint256 liquidity,
        uint256 amount0Min,
        uint256 amount1Min
    ) external poolExists(token0, token1) returns (uint256 amount0, uint256 amount1) {
        bytes32 poolId = getPoolId(token0, token1);
        Pool storage pool = pools[poolId];

        require(liquidity > 0, "Insufficient liquidity");
        require(userLiquidity[poolId][msg.sender].amount >= liquidity, "Insufficient user liquidity");


        uint256 reserve0 = uint256(pool.reserve0);
        uint256 reserve1 = uint256(pool.reserve1);
        uint256 totalLiq = totalLiquidity[poolId];

        amount0 = (liquidity * reserve0) / totalLiq;
        amount1 = (liquidity * reserve1) / totalLiq;

        require(amount0 >= amount0Min && amount1 >= amount1Min, "Insufficient output amount");


        pool.reserve0 = uint128(reserve0 - amount0);
        pool.reserve1 = uint128(reserve1 - amount1);
        totalLiquidity[poolId] = totalLiq - liquidity;
        userLiquidity[poolId][msg.sender].amount -= uint128(liquidity);


        IERC20(token0).transfer(msg.sender, amount0);
        IERC20(token1).transfer(msg.sender, amount1);

        emit LiquidityRemoved(msg.sender, token0, token1, amount0, amount1, liquidity);
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path
    ) external returns (uint256[] memory amounts) {
        require(path.length >= 2, "Invalid path");
        amounts = getAmountsOut(amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "Insufficient output amount");

        IERC20(path[0]).transferFrom(msg.sender, address(this), amounts[0]);
        _swap(amounts, path, msg.sender);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path
    ) external returns (uint256[] memory amounts) {
        require(path.length >= 2, "Invalid path");
        amounts = getAmountsIn(amountOut, path);
        require(amounts[0] <= amountInMax, "Excessive input amount");

        IERC20(path[0]).transferFrom(msg.sender, address(this), amounts[0]);
        _swap(amounts, path, msg.sender);
    }

    function _swap(
        uint256[] memory amounts,
        address[] calldata path,
        address to
    ) internal {
        for (uint256 i = 0; i < path.length - 1;) {
            address tokenIn = path[i];
            address tokenOut = path[i + 1];
            uint256 amountIn = amounts[i];
            uint256 amountOut = amounts[i + 1];

            bytes32 poolId = getPoolId(tokenIn, tokenOut);
            Pool storage pool = pools[poolId];


            uint256 reserve0 = uint256(pool.reserve0);
            uint256 reserve1 = uint256(pool.reserve1);


            bool token0IsInput = tokenIn < tokenOut;
            (uint256 reserveIn, uint256 reserveOut) = token0IsInput ?
                (reserve0, reserve1) : (reserve1, reserve0);


            uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_RATE);
            require(
                amountOut * FEE_DENOMINATOR * reserveIn <=
                amountInWithFee * reserveOut,
                "K invariant violation"
            );


            if (token0IsInput) {
                pool.reserve0 = uint128(reserve0 + amountIn);
                pool.reserve1 = uint128(reserve1 - amountOut);
            } else {
                pool.reserve0 = uint128(reserve0 - amountOut);
                pool.reserve1 = uint128(reserve1 + amountIn);
            }


            address recipient = i == path.length - 2 ? to : address(this);
            IERC20(tokenOut).transfer(recipient, amountOut);

            emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);

            unchecked { ++i; }
        }
    }

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        public view returns (uint256[] memory amounts)
    {
        require(path.length >= 2, "Invalid path");
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;

        for (uint256 i = 0; i < path.length - 1;) {
            bytes32 poolId = getPoolId(path[i], path[i + 1]);
            Pool storage pool = pools[poolId];
            require(pool.exists, "Pool does not exist");

            bool token0IsInput = path[i] < path[i + 1];
            (uint256 reserveIn, uint256 reserveOut) = token0IsInput ?
                (uint256(pool.reserve0), uint256(pool.reserve1)) :
                (uint256(pool.reserve1), uint256(pool.reserve0));

            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
            unchecked { ++i; }
        }
    }

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        public view returns (uint256[] memory amounts)
    {
        require(path.length >= 2, "Invalid path");
        amounts = new uint256[](path.length);
        amounts[amounts.length - 1] = amountOut;

        for (uint256 i = path.length - 1; i > 0;) {
            bytes32 poolId = getPoolId(path[i - 1], path[i]);
            Pool storage pool = pools[poolId];
            require(pool.exists, "Pool does not exist");

            bool token0IsInput = path[i - 1] < path[i];
            (uint256 reserveIn, uint256 reserveOut) = token0IsInput ?
                (uint256(pool.reserve0), uint256(pool.reserve1)) :
                (uint256(pool.reserve1), uint256(pool.reserve0));

            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
            unchecked { --i; }
        }
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public pure returns (uint256 amountOut)
    {
        require(amountIn > 0 && reserveIn > 0 && reserveOut > 0, "Invalid amounts");
        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_RATE);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * FEE_DENOMINATOR + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        public pure returns (uint256 amountIn)
    {
        require(amountOut > 0 && reserveIn > 0 && reserveOut > amountOut, "Invalid amounts");
        uint256 numerator = reserveIn * amountOut * FEE_DENOMINATOR;
        uint256 denominator = (reserveOut - amountOut) * (FEE_DENOMINATOR - FEE_RATE);
        amountIn = (numerator / denominator) + 1;
    }

    function getReserves(address token0, address token1)
        external view returns (uint256 reserve0, uint256 reserve1, uint32 blockTimestampLast)
    {
        bytes32 poolId = getPoolId(token0, token1);
        Pool storage pool = pools[poolId];
        return (uint256(pool.reserve0), uint256(pool.reserve1), pool.blockTimestampLast);
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
