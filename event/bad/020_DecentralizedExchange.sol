
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
    mapping(address => mapping(address => uint256)) public liquidityProviders;
    mapping(address => uint256) public reserves;
    mapping(address => bool) public supportedTokens;

    address public owner;
    uint256 public feeRate = 30;
    uint256 public constant FEE_DENOMINATOR = 10000;


    event LiquidityAdded(address token, uint256 amount, address provider);
    event LiquidityRemoved(address token, uint256 amount, address provider);
    event TokenSwapped(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut, address trader);
    event FeeUpdated(uint256 newFee);


    error Failed();
    error Invalid();
    error NotAllowed();

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier validToken(address token) {
        require(supportedTokens[token]);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function addSupportedToken(address token) external onlyOwner {
        require(token != address(0));
        supportedTokens[token] = true;

    }

    function removeSupportedToken(address token) external onlyOwner {
        require(supportedTokens[token]);
        supportedTokens[token] = false;

    }

    function addLiquidity(address token, uint256 amount) external validToken(token) {
        require(amount > 0);

        IERC20(token).transferFrom(msg.sender, address(this), amount);
        liquidityProviders[token][msg.sender] += amount;
        reserves[token] += amount;

        emit LiquidityAdded(token, amount, msg.sender);
    }

    function removeLiquidity(address token, uint256 amount) external validToken(token) {
        require(liquidityProviders[token][msg.sender] >= amount);
        require(reserves[token] >= amount);

        liquidityProviders[token][msg.sender] -= amount;
        reserves[token] -= amount;

        IERC20(token).transfer(msg.sender, amount);

        emit LiquidityRemoved(token, amount, msg.sender);
    }

    function getAmountOut(address tokenIn, address tokenOut, uint256 amountIn)
        public view validToken(tokenIn) validToken(tokenOut) returns (uint256) {
        require(amountIn > 0);

        uint256 reserveIn = reserves[tokenIn];
        uint256 reserveOut = reserves[tokenOut];

        require(reserveIn > 0 && reserveOut > 0);

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - feeRate);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;

        return numerator / denominator;
    }

    function swapTokens(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut)
        external validToken(tokenIn) validToken(tokenOut) {
        require(amountIn > 0);
        require(tokenIn != tokenOut);

        uint256 amountOut = getAmountOut(tokenIn, tokenOut, amountIn);


        require(amountOut >= minAmountOut);
        require(reserves[tokenOut] >= amountOut);

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        reserves[tokenIn] += amountIn;
        reserves[tokenOut] -= amountOut;

        IERC20(tokenOut).transfer(msg.sender, amountOut);

        emit TokenSwapped(tokenIn, tokenOut, amountIn, amountOut, msg.sender);
    }

    function updateFeeRate(uint256 newFeeRate) external onlyOwner {
        require(newFeeRate <= 1000);
        feeRate = newFeeRate;
        emit FeeUpdated(newFeeRate);
    }

    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        require(IERC20(token).balanceOf(address(this)) >= amount);


        if (!IERC20(token).transfer(owner, amount)) {

            revert Failed();
        }

    }

    function getLiquidityProvider(address token, address provider) external view returns (uint256) {
        return liquidityProviders[token][provider];
    }

    function getReserve(address token) external view returns (uint256) {
        return reserves[token];
    }


    function batchSwap(
        address[] calldata tokensIn,
        address[] calldata tokensOut,
        uint256[] calldata amountsIn,
        uint256[] calldata minAmountsOut
    ) external {
        require(tokensIn.length == tokensOut.length);
        require(tokensIn.length == amountsIn.length);


        for (uint256 i = 0; i < tokensIn.length; i++) {

            require(supportedTokens[tokensIn[i]] && supportedTokens[tokensOut[i]]);

            uint256 amountOut = getAmountOut(tokensIn[i], tokensOut[i], amountsIn[i]);

            if (amountOut < minAmountsOut[i]) {

                revert Invalid();
            }

            IERC20(tokensIn[i]).transferFrom(msg.sender, address(this), amountsIn[i]);
            reserves[tokensIn[i]] += amountsIn[i];
            reserves[tokensOut[i]] -= amountOut;
            IERC20(tokensOut[i]).transfer(msg.sender, amountOut);

            emit TokenSwapped(tokensIn[i], tokensOut[i], amountsIn[i], amountOut, msg.sender);
        }
    }
}
