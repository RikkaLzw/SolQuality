
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract DecentralizedExchange {
    address public owner;
    uint256 public feeRate;
    uint256 public constant MAX_FEE_RATE = 1000;

    mapping(address => mapping(address => uint256)) public liquidityPools;
    mapping(address => mapping(address => mapping(address => uint256))) public userLiquidity;
    mapping(address => uint256) public collectedFees;

    event LiquidityAdded(address indexed user, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);
    event LiquidityRemoved(address indexed user, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);
    event TokensSwapped(address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event FeesCollected(address indexed token, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier validTokens(address tokenA, address tokenB) {
        require(tokenA != address(0) && tokenB != address(0), "Invalid token address");
        require(tokenA != tokenB, "Identical tokens");
        _;
    }

    constructor(uint256 _feeRate) {
        require(_feeRate <= MAX_FEE_RATE, "Fee rate too high");
        owner = msg.sender;
        feeRate = _feeRate;
    }

    function addLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB)
        external
        validTokens(tokenA, tokenB)
        returns (bool)
    {
        require(amountA > 0 && amountB > 0, "Invalid amounts");

        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        (uint256 amount0, uint256 amount1) = tokenA == token0 ? (amountA, amountB) : (amountB, amountA);

        require(_transferFrom(tokenA, msg.sender, amountA), "TokenA transfer failed");
        require(_transferFrom(tokenB, msg.sender, amountB), "TokenB transfer failed");

        liquidityPools[token0][token1] += amount0;
        liquidityPools[token1][token0] += amount1;

        userLiquidity[msg.sender][token0][token1] += amount0;
        userLiquidity[msg.sender][token1][token0] += amount1;

        emit LiquidityAdded(msg.sender, tokenA, tokenB, amountA, amountB);
        return true;
    }

    function removeLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB)
        external
        validTokens(tokenA, tokenB)
        returns (bool)
    {
        require(amountA > 0 && amountB > 0, "Invalid amounts");

        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        (uint256 amount0, uint256 amount1) = tokenA == token0 ? (amountA, amountB) : (amountB, amountA);

        require(userLiquidity[msg.sender][token0][token1] >= amount0, "Insufficient liquidity A");
        require(userLiquidity[msg.sender][token1][token0] >= amount1, "Insufficient liquidity B");

        userLiquidity[msg.sender][token0][token1] -= amount0;
        userLiquidity[msg.sender][token1][token0] -= amount1;

        liquidityPools[token0][token1] -= amount0;
        liquidityPools[token1][token0] -= amount1;

        require(_transfer(tokenA, msg.sender, amountA), "TokenA transfer failed");
        require(_transfer(tokenB, msg.sender, amountB), "TokenB transfer failed");

        emit LiquidityRemoved(msg.sender, tokenA, tokenB, amountA, amountB);
        return true;
    }

    function swapTokens(address tokenIn, address tokenOut, uint256 amountIn)
        external
        validTokens(tokenIn, tokenOut)
        returns (uint256)
    {
        require(amountIn > 0, "Invalid input amount");

        uint256 amountOut = _calculateSwapAmount(tokenIn, tokenOut, amountIn);
        require(amountOut > 0, "Insufficient output amount");

        uint256 fee = _calculateFee(amountIn);
        uint256 amountInAfterFee = amountIn - fee;

        require(_transferFrom(tokenIn, msg.sender, amountIn), "Input transfer failed");
        require(_transfer(tokenOut, msg.sender, amountOut), "Output transfer failed");

        _updatePoolBalances(tokenIn, tokenOut, amountInAfterFee, amountOut);

        collectedFees[tokenIn] += fee;

        emit TokensSwapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
        return amountOut;
    }

    function getSwapAmount(address tokenIn, address tokenOut, uint256 amountIn)
        external
        view
        validTokens(tokenIn, tokenOut)
        returns (uint256)
    {
        return _calculateSwapAmount(tokenIn, tokenOut, amountIn);
    }

    function getPoolBalance(address tokenA, address tokenB)
        external
        view
        validTokens(tokenA, tokenB)
        returns (uint256, uint256)
    {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        return (liquidityPools[token0][token1], liquidityPools[token1][token0]);
    }

    function getUserLiquidity(address user, address tokenA, address tokenB)
        external
        view
        validTokens(tokenA, tokenB)
        returns (uint256, uint256)
    {
        (address token0, address token1) = _sortTokens(tokenA, tokenB);
        return (userLiquidity[user][token0][token1], userLiquidity[user][token1][token0]);
    }

    function collectFees(address token) external onlyOwner returns (bool) {
        uint256 amount = collectedFees[token];
        require(amount > 0, "No fees to collect");

        collectedFees[token] = 0;
        require(_transfer(token, owner, amount), "Fee transfer failed");

        emit FeesCollected(token, amount);
        return true;
    }

    function updateFeeRate(uint256 newFeeRate) external onlyOwner returns (bool) {
        require(newFeeRate <= MAX_FEE_RATE, "Fee rate too high");
        feeRate = newFeeRate;
        return true;
    }

    function _calculateSwapAmount(address tokenIn, address tokenOut, uint256 amountIn)
        internal
        view
        returns (uint256)
    {
        uint256 reserveIn = liquidityPools[tokenIn][tokenOut];
        uint256 reserveOut = liquidityPools[tokenOut][tokenIn];

        if (reserveIn == 0 || reserveOut == 0) {
            return 0;
        }

        uint256 amountInAfterFee = amountIn - _calculateFee(amountIn);
        uint256 numerator = amountInAfterFee * reserveOut;
        uint256 denominator = reserveIn + amountInAfterFee;

        return numerator / denominator;
    }

    function _calculateFee(uint256 amount) internal view returns (uint256) {
        return (amount * feeRate) / 10000;
    }

    function _updatePoolBalances(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut)
        internal
    {
        liquidityPools[tokenIn][tokenOut] += amountIn;
        liquidityPools[tokenOut][tokenIn] -= amountOut;
    }

    function _sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address, address)
    {
        return tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function _transfer(address token, address to, uint256 amount)
        internal
        returns (bool)
    {
        return IERC20(token).transfer(to, amount);
    }

    function _transferFrom(address token, address from, uint256 amount)
        internal
        returns (bool)
    {
        return IERC20(token).transferFrom(from, address(this), amount);
    }
}
