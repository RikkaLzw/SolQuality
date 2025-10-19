
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
    mapping(address => mapping(address => uint256)) public liquidity;
    mapping(address => mapping(address => uint256)) public reserves;
    mapping(address => bool) public supportedTokens;

    address public owner;
    uint256 public constant FEE_RATE = 3;
    uint256 public constant FEE_DENOMINATOR = 1000;

    event LiquidityAdded(address indexed provider, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);
    event LiquidityRemoved(address indexed provider, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);
    event TokenSwapped(address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event TokenSupported(address indexed token);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier validToken(address token) {
        require(supportedTokens[token], "Token not supported");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function addSupportedToken(address token) external onlyOwner {
        require(token != address(0), "Invalid token address");
        supportedTokens[token] = true;
        emit TokenSupported(token);
    }

    function addLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB)
        external
        validToken(tokenA)
        validToken(tokenB)
    {
        require(tokenA != tokenB, "Same token");
        require(amountA > 0 && amountB > 0, "Invalid amounts");

        _transferFrom(tokenA, msg.sender, amountA);
        _transferFrom(tokenB, msg.sender, amountB);

        _updateLiquidity(tokenA, tokenB, amountA, amountB);
        _updateReserves(tokenA, tokenB, amountA, amountB);

        emit LiquidityAdded(msg.sender, tokenA, tokenB, amountA, amountB);
    }

    function removeLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB)
        external
        validToken(tokenA)
        validToken(tokenB)
    {
        require(tokenA != tokenB, "Same token");
        require(_hasLiquidity(tokenA, tokenB, amountA, amountB), "Insufficient liquidity");

        _decreaseLiquidity(tokenA, tokenB, amountA, amountB);
        _decreaseReserves(tokenA, tokenB, amountA, amountB);

        _transfer(tokenA, msg.sender, amountA);
        _transfer(tokenB, msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, tokenA, tokenB, amountA, amountB);
    }

    function swapTokens(address tokenIn, address tokenOut, uint256 amountIn)
        external
        validToken(tokenIn)
        validToken(tokenOut)
        returns (uint256 amountOut)
    {
        require(tokenIn != tokenOut, "Same token");
        require(amountIn > 0, "Invalid amount");

        amountOut = _calculateSwapOutput(tokenIn, tokenOut, amountIn);
        require(amountOut > 0, "Insufficient output");
        require(_hasReserve(tokenOut, amountOut), "Insufficient reserves");

        _transferFrom(tokenIn, msg.sender, amountIn);
        _transfer(tokenOut, msg.sender, amountOut);

        _updateReservesAfterSwap(tokenIn, tokenOut, amountIn, amountOut);

        emit TokenSwapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    function getSwapOutput(address tokenIn, address tokenOut, uint256 amountIn)
        external
        view
        returns (uint256)
    {
        return _calculateSwapOutput(tokenIn, tokenOut, amountIn);
    }

    function getLiquidityBalance(address provider, address tokenA, address tokenB)
        external
        view
        returns (uint256)
    {
        return liquidity[provider][_getPairKey(tokenA, tokenB)];
    }

    function _transferFrom(address token, address from, uint256 amount) internal {
        require(IERC20(token).transferFrom(from, address(this), amount), "Transfer failed");
    }

    function _transfer(address token, address to, uint256 amount) internal {
        require(IERC20(token).transfer(to, amount), "Transfer failed");
    }

    function _updateLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) internal {
        address pairKey = _getPairKey(tokenA, tokenB);
        liquidity[msg.sender][pairKey] += amountA + amountB;
    }

    function _updateReserves(address tokenA, address tokenB, uint256 amountA, uint256 amountB) internal {
        reserves[tokenA][tokenB] += amountA;
        reserves[tokenB][tokenA] += amountB;
    }

    function _decreaseLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) internal {
        address pairKey = _getPairKey(tokenA, tokenB);
        liquidity[msg.sender][pairKey] -= (amountA + amountB);
    }

    function _decreaseReserves(address tokenA, address tokenB, uint256 amountA, uint256 amountB) internal {
        reserves[tokenA][tokenB] -= amountA;
        reserves[tokenB][tokenA] -= amountB;
    }

    function _calculateSwapOutput(address tokenIn, address tokenOut, uint256 amountIn)
        internal
        view
        returns (uint256)
    {
        uint256 reserveIn = reserves[tokenIn][tokenOut];
        uint256 reserveOut = reserves[tokenOut][tokenIn];

        if (reserveIn == 0 || reserveOut == 0) {
            return 0;
        }

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_RATE);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;

        return numerator / denominator;
    }

    function _hasLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB)
        internal
        view
        returns (bool)
    {
        address pairKey = _getPairKey(tokenA, tokenB);
        return liquidity[msg.sender][pairKey] >= (amountA + amountB);
    }

    function _hasReserve(address token, uint256 amount) internal view returns (bool) {
        return IERC20(token).balanceOf(address(this)) >= amount;
    }

    function _updateReservesAfterSwap(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut) internal {
        reserves[tokenIn][tokenOut] += amountIn;
        reserves[tokenOut][tokenIn] -= amountOut;
    }

    function _getPairKey(address tokenA, address tokenB) internal pure returns (address) {
        return tokenA < tokenB ? tokenA : tokenB;
    }
}
