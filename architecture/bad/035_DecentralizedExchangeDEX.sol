
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract DecentralizedExchangeDEX {
    address internal owner;
    mapping(address => mapping(address => uint256)) internal liquidityPools;
    mapping(address => mapping(address => uint256)) internal userLiquidity;
    mapping(address => uint256) internal tokenReserves;
    mapping(address => bool) internal supportedTokens;
    address[] internal tokenList;
    uint256 internal totalTrades;
    uint256 internal totalVolume;
    bool internal paused;

    event LiquidityAdded(address indexed user, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);
    event LiquidityRemoved(address indexed user, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);
    event TokenSwapped(address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event TokenAdded(address indexed token);

    constructor() {
        owner = msg.sender;
        paused = false;
        totalTrades = 0;
        totalVolume = 0;
    }

    function addLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) external {

        require(msg.sender != address(0), "Invalid sender");
        require(tokenA != address(0), "Invalid token A");
        require(tokenB != address(0), "Invalid token B");
        require(amountA > 0, "Amount A must be positive");
        require(amountB > 0, "Amount B must be positive");
        require(!paused, "Contract is paused");
        require(supportedTokens[tokenA], "Token A not supported");
        require(supportedTokens[tokenB], "Token B not supported");


        require(amountA >= 1000, "Minimum amount A is 1000");
        require(amountB >= 1000, "Minimum amount B is 1000");

        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        liquidityPools[tokenA][tokenB] += amountA;
        liquidityPools[tokenB][tokenA] += amountB;
        userLiquidity[msg.sender][tokenA] += amountA;
        userLiquidity[msg.sender][tokenB] += amountB;
        tokenReserves[tokenA] += amountA;
        tokenReserves[tokenB] += amountB;

        emit LiquidityAdded(msg.sender, tokenA, tokenB, amountA, amountB);
    }

    function removeLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) external {

        require(msg.sender != address(0), "Invalid sender");
        require(tokenA != address(0), "Invalid token A");
        require(tokenB != address(0), "Invalid token B");
        require(amountA > 0, "Amount A must be positive");
        require(amountB > 0, "Amount B must be positive");
        require(!paused, "Contract is paused");
        require(supportedTokens[tokenA], "Token A not supported");
        require(supportedTokens[tokenB], "Token B not supported");

        require(userLiquidity[msg.sender][tokenA] >= amountA, "Insufficient liquidity A");
        require(userLiquidity[msg.sender][tokenB] >= amountB, "Insufficient liquidity B");
        require(liquidityPools[tokenA][tokenB] >= amountA, "Insufficient pool liquidity A");
        require(liquidityPools[tokenB][tokenA] >= amountB, "Insufficient pool liquidity B");

        liquidityPools[tokenA][tokenB] -= amountA;
        liquidityPools[tokenB][tokenA] -= amountB;
        userLiquidity[msg.sender][tokenA] -= amountA;
        userLiquidity[msg.sender][tokenB] -= amountB;
        tokenReserves[tokenA] -= amountA;
        tokenReserves[tokenB] -= amountB;

        IERC20(tokenA).transfer(msg.sender, amountA);
        IERC20(tokenB).transfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, tokenA, tokenB, amountA, amountB);
    }

    function swapTokens(address tokenIn, address tokenOut, uint256 amountIn) external {

        require(msg.sender != address(0), "Invalid sender");
        require(tokenIn != address(0), "Invalid token in");
        require(tokenOut != address(0), "Invalid token out");
        require(amountIn > 0, "Amount in must be positive");
        require(!paused, "Contract is paused");
        require(supportedTokens[tokenIn], "Token in not supported");
        require(supportedTokens[tokenOut], "Token out not supported");
        require(tokenIn != tokenOut, "Cannot swap same token");


        uint256 fee = amountIn * 3 / 1000;
        uint256 amountInAfterFee = amountIn - fee;

        uint256 reserveIn = liquidityPools[tokenIn][tokenOut];
        uint256 reserveOut = liquidityPools[tokenOut][tokenIn];

        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");


        uint256 amountOut = (amountInAfterFee * reserveOut) / (reserveIn + amountInAfterFee);


        require(amountOut >= amountIn * 95 / 100, "Slippage too high");

        require(amountOut <= reserveOut, "Insufficient output reserve");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).transfer(msg.sender, amountOut);

        liquidityPools[tokenIn][tokenOut] += amountInAfterFee;
        liquidityPools[tokenOut][tokenIn] -= amountOut;
        tokenReserves[tokenIn] += amountInAfterFee;
        tokenReserves[tokenOut] -= amountOut;

        totalTrades += 1;
        totalVolume += amountIn;

        emit TokenSwapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    function addSupportedToken(address token) external {

        require(msg.sender == owner, "Only owner can add tokens");
        require(token != address(0), "Invalid token address");
        require(!supportedTokens[token], "Token already supported");

        supportedTokens[token] = true;
        tokenList.push(token);

        emit TokenAdded(token);
    }

    function removeSupportedToken(address token) external {

        require(msg.sender == owner, "Only owner can remove tokens");
        require(token != address(0), "Invalid token address");
        require(supportedTokens[token], "Token not supported");

        supportedTokens[token] = false;


        for (uint256 i = 0; i < tokenList.length; i++) {
            if (tokenList[i] == token) {
                tokenList[i] = tokenList[tokenList.length - 1];
                tokenList.pop();
                break;
            }
        }
    }

    function pauseContract() external {

        require(msg.sender == owner, "Only owner can pause");
        paused = true;
    }

    function unpauseContract() external {

        require(msg.sender == owner, "Only owner can unpause");
        paused = false;
    }

    function changeOwner(address newOwner) external {

        require(msg.sender == owner, "Only owner can change owner");
        require(newOwner != address(0), "Invalid new owner");
        owner = newOwner;
    }

    function getPoolLiquidity(address tokenA, address tokenB) external view returns (uint256, uint256) {
        return (liquidityPools[tokenA][tokenB], liquidityPools[tokenB][tokenA]);
    }

    function getUserLiquidity(address user, address token) external view returns (uint256) {
        return userLiquidity[user][token];
    }

    function getTokenReserve(address token) external view returns (uint256) {
        return tokenReserves[token];
    }

    function isTokenSupported(address token) external view returns (bool) {
        return supportedTokens[token];
    }

    function getSupportedTokens() external view returns (address[] memory) {
        return tokenList;
    }

    function getTotalTrades() external view returns (uint256) {
        return totalTrades;
    }

    function getTotalVolume() external view returns (uint256) {
        return totalVolume;
    }

    function isPaused() external view returns (bool) {
        return paused;
    }

    function getOwner() external view returns (address) {
        return owner;
    }

    function calculateSwapOutput(address tokenIn, address tokenOut, uint256 amountIn) external view returns (uint256) {

        require(tokenIn != address(0), "Invalid token in");
        require(tokenOut != address(0), "Invalid token out");
        require(amountIn > 0, "Amount in must be positive");
        require(supportedTokens[tokenIn], "Token in not supported");
        require(supportedTokens[tokenOut], "Token out not supported");
        require(tokenIn != tokenOut, "Cannot swap same token");


        uint256 fee = amountIn * 3 / 1000;
        uint256 amountInAfterFee = amountIn - fee;

        uint256 reserveIn = liquidityPools[tokenIn][tokenOut];
        uint256 reserveOut = liquidityPools[tokenOut][tokenIn];

        if (reserveIn == 0 || reserveOut == 0) {
            return 0;
        }

        uint256 amountOut = (amountInAfterFee * reserveOut) / (reserveIn + amountInAfterFee);
        return amountOut;
    }

    function emergencyWithdraw(address token, uint256 amount) external {

        require(msg.sender == owner, "Only owner can emergency withdraw");
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be positive");

        IERC20(token).transfer(owner, amount);
    }

    function batchAddLiquidity(
        address[] memory tokensA,
        address[] memory tokensB,
        uint256[] memory amountsA,
        uint256[] memory amountsB
    ) external {
        require(tokensA.length == tokensB.length, "Arrays length mismatch");
        require(tokensA.length == amountsA.length, "Arrays length mismatch");
        require(tokensA.length == amountsB.length, "Arrays length mismatch");

        for (uint256 i = 0; i < tokensA.length; i++) {

            require(msg.sender != address(0), "Invalid sender");
            require(tokensA[i] != address(0), "Invalid token A");
            require(tokensB[i] != address(0), "Invalid token B");
            require(amountsA[i] > 0, "Amount A must be positive");
            require(amountsB[i] > 0, "Amount B must be positive");
            require(!paused, "Contract is paused");
            require(supportedTokens[tokensA[i]], "Token A not supported");
            require(supportedTokens[tokensB[i]], "Token B not supported");

            IERC20(tokensA[i]).transferFrom(msg.sender, address(this), amountsA[i]);
            IERC20(tokensB[i]).transferFrom(msg.sender, address(this), amountsB[i]);

            liquidityPools[tokensA[i]][tokensB[i]] += amountsA[i];
            liquidityPools[tokensB[i]][tokensA[i]] += amountsB[i];
            userLiquidity[msg.sender][tokensA[i]] += amountsA[i];
            userLiquidity[msg.sender][tokensB[i]] += amountsB[i];
            tokenReserves[tokensA[i]] += amountsA[i];
            tokenReserves[tokensB[i]] += amountsB[i];

            emit LiquidityAdded(msg.sender, tokensA[i], tokensB[i], amountsA[i], amountsB[i]);
        }
    }
}
