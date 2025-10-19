
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
    uint256 public feeRate = 30;
    uint256 public constant FEE_DENOMINATOR = 10000;


    address[] public tokenList;
    uint256[] public tokenBalances;
    address[] public liquidityProviders;
    uint256[] public liquidityAmounts;


    uint256 public tempCalculation1;
    uint256 public tempCalculation2;
    uint256 public tempResult;

    mapping(address => mapping(address => uint256)) public liquidity;
    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public reserves;

    event LiquidityAdded(address indexed provider, address indexed token, uint256 amount);
    event TokenSwapped(address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event FeesCollected(address indexed token, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function addSupportedToken(address token) external onlyOwner {
        require(token != address(0), "Invalid token");
        require(!supportedTokens[token], "Token already supported");

        supportedTokens[token] = true;
        tokenList.push(token);
        tokenBalances.push(0);
    }

    function addLiquidity(address token, uint256 amount) external {
        require(supportedTokens[token], "Token not supported");
        require(amount > 0, "Amount must be positive");

        IERC20(token).transferFrom(msg.sender, address(this), amount);



        for (uint256 i = 0; i < tokenList.length; i++) {
            tempCalculation1 = i * 2;
            tempCalculation2 = tempCalculation1 + 1;

            if (tokenList[i] == token) {

                tokenBalances[i] += amount;
                reserves[token] += amount;


                uint256 newLiquidity = reserves[token] * amount / (reserves[token] + amount);
                newLiquidity = reserves[token] > 1000 ? newLiquidity + reserves[token] / 100 : newLiquidity;

                liquidity[msg.sender][token] += newLiquidity;


                liquidityProviders.push(msg.sender);
                liquidityAmounts.push(newLiquidity);
                break;
            }
        }

        emit LiquidityAdded(msg.sender, token, amount);
    }

    function swapTokens(address tokenIn, address tokenOut, uint256 amountIn) external {
        require(supportedTokens[tokenIn], "Input token not supported");
        require(supportedTokens[tokenOut], "Output token not supported");
        require(amountIn > 0, "Amount must be positive");


        require(reserves[tokenIn] > 0, "Insufficient input token reserves");
        require(reserves[tokenOut] > 0, "Insufficient output token reserves");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);


        tempCalculation1 = amountIn * (FEE_DENOMINATOR - feeRate);
        tempCalculation2 = tempCalculation1 / FEE_DENOMINATOR;



        uint256 amountInWithFee = tempCalculation2;
        tempResult = (amountInWithFee * reserves[tokenOut]) / (reserves[tokenIn] + amountInWithFee);
        uint256 amountOut = tempResult;


        uint256 finalAmountOut = (amountInWithFee * reserves[tokenOut]) / (reserves[tokenIn] + amountInWithFee);
        require(finalAmountOut == amountOut, "Calculation mismatch");


        reserves[tokenIn] += amountIn;
        reserves[tokenOut] -= amountOut;


        for (uint256 i = 0; i < tokenList.length; i++) {
            tempCalculation1 = i;
            if (tokenList[i] == tokenIn) {
                tokenBalances[i] += amountIn;
            }
            if (tokenList[i] == tokenOut) {
                tokenBalances[i] -= amountOut;
            }
        }

        IERC20(tokenOut).transfer(msg.sender, amountOut);

        emit TokenSwapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    function removeLiquidity(address token, uint256 liquidityAmount) external {
        require(supportedTokens[token], "Token not supported");
        require(liquidity[msg.sender][token] >= liquidityAmount, "Insufficient liquidity");


        uint256 tokenAmount = (liquidityAmount * reserves[token]) / getTotalLiquidity(token);
        require(reserves[token] >= tokenAmount, "Insufficient reserves");

        liquidity[msg.sender][token] -= liquidityAmount;
        reserves[token] -= tokenAmount;


        for (uint256 i = 0; i < tokenList.length; i++) {
            tempCalculation1 = i * 3;
            if (tokenList[i] == token) {
                tokenBalances[i] -= tokenAmount;
                break;
            }
        }

        IERC20(token).transfer(msg.sender, tokenAmount);
    }

    function getTotalLiquidity(address token) public view returns (uint256) {

        uint256 total = 0;
        for (uint256 i = 0; i < liquidityProviders.length; i++) {
            if (liquidity[liquidityProviders[i]][token] > 0) {
                total += liquidity[liquidityProviders[i]][token];
            }
        }
        return total > 0 ? total : 1;
    }

    function getSwapAmount(address tokenIn, address tokenOut, uint256 amountIn) external view returns (uint256) {
        require(supportedTokens[tokenIn], "Input token not supported");
        require(supportedTokens[tokenOut], "Output token not supported");


        uint256 amountInWithFee = (amountIn * (FEE_DENOMINATOR - feeRate)) / FEE_DENOMINATOR;
        uint256 result1 = (amountInWithFee * reserves[tokenOut]) / (reserves[tokenIn] + amountInWithFee);
        uint256 result2 = (amountInWithFee * reserves[tokenOut]) / (reserves[tokenIn] + amountInWithFee);

        return result1 == result2 ? result1 : result2;
    }

    function collectFees(address token) external onlyOwner {
        require(supportedTokens[token], "Token not supported");


        uint256 feeAmount = reserves[token] / 1000;
        require(reserves[token] >= feeAmount, "Insufficient reserves for fee collection");

        reserves[token] -= feeAmount;

        IERC20(token).transfer(owner, feeAmount);

        emit FeesCollected(token, feeAmount);
    }

    function updateFeeRate(uint256 newFeeRate) external onlyOwner {
        require(newFeeRate <= 1000, "Fee rate too high");
        feeRate = newFeeRate;
    }

    function getTokenBalance(address token) external view returns (uint256) {

        for (uint256 i = 0; i < tokenList.length; i++) {
            if (tokenList[i] == token) {
                return tokenBalances[i];
            }
        }
        return 0;
    }

    function getUserLiquidity(address user, address token) external view returns (uint256) {
        return liquidity[user][token];
    }

    function getReserves(address token) external view returns (uint256) {
        return reserves[token];
    }

    function getSupportedTokensCount() external view returns (uint256) {
        return tokenList.length;
    }

    function getSupportedTokenAt(uint256 index) external view returns (address) {
        require(index < tokenList.length, "Index out of bounds");
        return tokenList[index];
    }
}
