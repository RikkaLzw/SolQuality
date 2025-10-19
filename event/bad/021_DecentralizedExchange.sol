
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
    mapping(address => uint256) public totalLiquidity;
    mapping(address => bool) public supportedTokens;
    address public owner;
    uint256 public feeRate = 30;
    uint256 public constant FEE_DENOMINATOR = 10000;


    event LiquidityAdded(address token, address provider, uint256 amount);
    event LiquidityRemoved(address token, address provider, uint256 amount);
    event TokenSwapped(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event TokenSupported(address token);


    error InvalidInput();
    error NotAllowed();
    error Failed();

    modifier onlyOwner() {

        require(msg.sender == owner);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function addSupportedToken(address token) external onlyOwner {

        require(token != address(0));
        require(!supportedTokens[token]);

        supportedTokens[token] = true;

    }

    function addLiquidity(address token, uint256 amount) external {

        require(supportedTokens[token]);
        require(amount > 0);

        IERC20(token).transferFrom(msg.sender, address(this), amount);

        liquidity[token][msg.sender] += amount;
        totalLiquidity[token] += amount;

        emit LiquidityAdded(token, msg.sender, amount);
    }

    function removeLiquidity(address token, uint256 amount) external {

        require(liquidity[token][msg.sender] >= amount);
        require(amount > 0);

        liquidity[token][msg.sender] -= amount;
        totalLiquidity[token] -= amount;

        IERC20(token).transfer(msg.sender, amount);

        emit LiquidityRemoved(token, msg.sender, amount);
    }

    function swapTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external {

        require(supportedTokens[tokenIn]);
        require(supportedTokens[tokenOut]);
        require(amountIn > 0);
        require(totalLiquidity[tokenOut] > 0);

        uint256 amountOut = getAmountOut(tokenIn, tokenOut, amountIn);


        require(amountOut >= minAmountOut);
        require(amountOut <= totalLiquidity[tokenOut]);

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        uint256 fee = (amountIn * feeRate) / FEE_DENOMINATOR;
        uint256 amountInAfterFee = amountIn - fee;

        totalLiquidity[tokenIn] += amountInAfterFee;
        totalLiquidity[tokenOut] -= amountOut;

        IERC20(tokenOut).transfer(msg.sender, amountOut);

        emit TokenSwapped(tokenIn, tokenOut, amountIn, amountOut);
    }

    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public view returns (uint256) {

        require(totalLiquidity[tokenIn] > 0);
        require(totalLiquidity[tokenOut] > 0);

        uint256 fee = (amountIn * feeRate) / FEE_DENOMINATOR;
        uint256 amountInAfterFee = amountIn - fee;


        uint256 numerator = amountInAfterFee * totalLiquidity[tokenOut];
        uint256 denominator = totalLiquidity[tokenIn] + amountInAfterFee;

        return numerator / denominator;
    }

    function setFeeRate(uint256 newFeeRate) external onlyOwner {

        require(newFeeRate <= 1000);

        feeRate = newFeeRate;

    }

    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {

        require(IERC20(token).balanceOf(address(this)) >= amount);

        IERC20(token).transfer(owner, amount);

    }

    function getLiquidityInfo(address token, address provider)
        external
        view
        returns (uint256 userLiquidity, uint256 totalTokenLiquidity)
    {
        return (liquidity[token][provider], totalLiquidity[token]);
    }

    function getContractBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
