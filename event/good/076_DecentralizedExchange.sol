
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract DecentralizedExchange {

    address public owner;
    uint256 public feeRate;
    uint256 public constant MAX_FEE_RATE = 1000;


    struct Pool {
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalLiquidity;
        bool exists;
    }


    mapping(bytes32 => Pool) public pools;
    mapping(address => mapping(bytes32 => uint256)) public liquidityBalances;
    mapping(address => uint256) public feeBalances;


    event PoolCreated(
        indexed address tokenA,
        indexed address tokenB,
        indexed bytes32 poolId,
        uint256 initialReserveA,
        uint256 initialReserveB
    );

    event LiquidityAdded(
        indexed address provider,
        indexed bytes32 poolId,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );

    event LiquidityRemoved(
        indexed address provider,
        indexed bytes32 poolId,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );

    event TokensSwapped(
        indexed address trader,
        indexed bytes32 poolId,
        address indexed tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee
    );

    event FeeRateUpdated(uint256 oldRate, uint256 newRate);
    event FeesWithdrawn(indexed address recipient, uint256 amount);
    event OwnershipTransferred(indexed address previousOwner, indexed address newOwner);


    modifier onlyOwner() {
        require(msg.sender == owner, "DEX: caller is not the owner");
        _;
    }

    modifier validAddress(address _address) {
        require(_address != address(0), "DEX: invalid address - cannot be zero address");
        _;
    }

    modifier poolExists(bytes32 poolId) {
        require(pools[poolId].exists, "DEX: pool does not exist");
        _;
    }


    constructor(uint256 _feeRate) {
        require(_feeRate <= MAX_FEE_RATE, "DEX: fee rate exceeds maximum allowed rate");
        owner = msg.sender;
        feeRate = _feeRate;
        emit OwnershipTransferred(address(0), msg.sender);
        emit FeeRateUpdated(0, _feeRate);
    }


    function createPool(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) external validAddress(tokenA) validAddress(tokenB) returns (bytes32 poolId) {
        require(tokenA != tokenB, "DEX: cannot create pool with identical tokens");
        require(amountA > 0 && amountB > 0, "DEX: initial amounts must be greater than zero");


        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
            (amountA, amountB) = (amountB, amountA);
        }

        poolId = keccak256(abi.encodePacked(tokenA, tokenB));
        require(!pools[poolId].exists, "DEX: pool already exists for this token pair");


        require(
            IERC20(tokenA).transferFrom(msg.sender, address(this), amountA),
            "DEX: failed to transfer tokenA to contract"
        );
        require(
            IERC20(tokenB).transferFrom(msg.sender, address(this), amountB),
            "DEX: failed to transfer tokenB to contract"
        );


        uint256 initialLiquidity = sqrt(amountA * amountB);
        require(initialLiquidity > 0, "DEX: insufficient liquidity provided");


        pools[poolId] = Pool({
            tokenA: tokenA,
            tokenB: tokenB,
            reserveA: amountA,
            reserveB: amountB,
            totalLiquidity: initialLiquidity,
            exists: true
        });

        liquidityBalances[msg.sender][poolId] = initialLiquidity;

        emit PoolCreated(tokenA, tokenB, poolId, amountA, amountB);
        emit LiquidityAdded(msg.sender, poolId, amountA, amountB, initialLiquidity);
    }


    function addLiquidity(
        bytes32 poolId,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) external poolExists(poolId) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        Pool storage pool = pools[poolId];

        require(amountADesired > 0 && amountBDesired > 0, "DEX: desired amounts must be greater than zero");
        require(amountAMin > 0 && amountBMin > 0, "DEX: minimum amounts must be greater than zero");


        if (pool.reserveA == 0 && pool.reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = (amountADesired * pool.reserveB) / pool.reserveA;
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "DEX: insufficient tokenB amount");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = (amountBDesired * pool.reserveA) / pool.reserveB;
                require(amountAOptimal <= amountADesired && amountAOptimal >= amountAMin, "DEX: insufficient tokenA amount");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }


        require(
            IERC20(pool.tokenA).transferFrom(msg.sender, address(this), amountA),
            "DEX: failed to transfer tokenA"
        );
        require(
            IERC20(pool.tokenB).transferFrom(msg.sender, address(this), amountB),
            "DEX: failed to transfer tokenB"
        );


        if (pool.totalLiquidity == 0) {
            liquidity = sqrt(amountA * amountB);
        } else {
            liquidity = min((amountA * pool.totalLiquidity) / pool.reserveA, (amountB * pool.totalLiquidity) / pool.reserveB);
        }

        require(liquidity > 0, "DEX: insufficient liquidity minted");


        pool.reserveA += amountA;
        pool.reserveB += amountB;
        pool.totalLiquidity += liquidity;
        liquidityBalances[msg.sender][poolId] += liquidity;

        emit LiquidityAdded(msg.sender, poolId, amountA, amountB, liquidity);
    }


    function removeLiquidity(
        bytes32 poolId,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin
    ) external poolExists(poolId) returns (uint256 amountA, uint256 amountB) {
        Pool storage pool = pools[poolId];

        require(liquidity > 0, "DEX: liquidity amount must be greater than zero");
        require(liquidityBalances[msg.sender][poolId] >= liquidity, "DEX: insufficient liquidity balance");


        amountA = (liquidity * pool.reserveA) / pool.totalLiquidity;
        amountB = (liquidity * pool.reserveB) / pool.totalLiquidity;

        require(amountA >= amountAMin, "DEX: insufficient tokenA amount");
        require(amountB >= amountBMin, "DEX: insufficient tokenB amount");


        liquidityBalances[msg.sender][poolId] -= liquidity;
        pool.totalLiquidity -= liquidity;
        pool.reserveA -= amountA;
        pool.reserveB -= amountB;


        require(IERC20(pool.tokenA).transfer(msg.sender, amountA), "DEX: failed to transfer tokenA");
        require(IERC20(pool.tokenB).transfer(msg.sender, amountB), "DEX: failed to transfer tokenB");

        emit LiquidityRemoved(msg.sender, poolId, amountA, amountB, liquidity);
    }


    function swapExactTokensForTokens(
        bytes32 poolId,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOutMin
    ) external poolExists(poolId) returns (uint256 amountOut) {
        Pool storage pool = pools[poolId];

        require(amountIn > 0, "DEX: input amount must be greater than zero");
        require(tokenIn == pool.tokenA || tokenIn == pool.tokenB, "DEX: invalid input token");

        address tokenOut = tokenIn == pool.tokenA ? pool.tokenB : pool.tokenA;
        uint256 reserveIn = tokenIn == pool.tokenA ? pool.reserveA : pool.reserveB;
        uint256 reserveOut = tokenIn == pool.tokenA ? pool.reserveB : pool.reserveA;


        uint256 fee = (amountIn * feeRate) / 10000;
        uint256 amountInAfterFee = amountIn - fee;


        amountOut = getAmountOut(amountInAfterFee, reserveIn, reserveOut);
        require(amountOut >= amountOutMin, "DEX: insufficient output amount");
        require(amountOut < reserveOut, "DEX: insufficient liquidity");


        require(
            IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn),
            "DEX: failed to transfer input token"
        );


        if (tokenIn == pool.tokenA) {
            pool.reserveA += amountInAfterFee;
            pool.reserveB -= amountOut;
        } else {
            pool.reserveB += amountInAfterFee;
            pool.reserveA -= amountOut;
        }


        feeBalances[tokenIn] += fee;


        require(IERC20(tokenOut).transfer(msg.sender, amountOut), "DEX: failed to transfer output token");

        emit TokensSwapped(msg.sender, poolId, tokenIn, tokenOut, amountIn, amountOut, fee);
    }


    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "DEX: insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "DEX: insufficient liquidity");

        uint256 numerator = amountIn * reserveOut;
        uint256 denominator = reserveIn + amountIn;
        amountOut = numerator / denominator;
    }


    function getPoolInfo(bytes32 poolId)
        external
        view
        returns (
            address tokenA,
            address tokenB,
            uint256 reserveA,
            uint256 reserveB,
            uint256 totalLiquidity
        )
    {
        Pool storage pool = pools[poolId];
        require(pool.exists, "DEX: pool does not exist");

        return (pool.tokenA, pool.tokenB, pool.reserveA, pool.reserveB, pool.totalLiquidity);
    }


    function getPoolId(address tokenA, address tokenB) external pure returns (bytes32) {
        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }
        return keccak256(abi.encodePacked(tokenA, tokenB));
    }


    function setFeeRate(uint256 _feeRate) external onlyOwner {
        require(_feeRate <= MAX_FEE_RATE, "DEX: fee rate exceeds maximum");
        uint256 oldRate = feeRate;
        feeRate = _feeRate;
        emit FeeRateUpdated(oldRate, _feeRate);
    }


    function withdrawFees(address token, uint256 amount) external onlyOwner {
        require(feeBalances[token] >= amount, "DEX: insufficient fee balance");
        feeBalances[token] -= amount;
        require(IERC20(token).transfer(owner, amount), "DEX: fee withdrawal failed");
        emit FeesWithdrawn(owner, amount);
    }


    function transferOwnership(address newOwner) external onlyOwner validAddress(newOwner) {
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }


    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        require(IERC20(token).transfer(owner, amount), "DEX: emergency withdrawal failed");
    }


    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }
}
