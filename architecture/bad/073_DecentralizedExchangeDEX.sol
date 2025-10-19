
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


    mapping(address => mapping(address => uint256)) public liquidityBalances;
    mapping(address => mapping(address => uint256)) public userBalances;
    mapping(address => bool) public supportedTokens;
    address[] public tokenList;
    uint256 public totalPairs;
    address public owner;
    bool public paused;


    uint256 feeRate = 30;
    uint256 feeDenominator = 10000;
    uint256 minimumLiquidity = 1000;

    event LiquidityAdded(address indexed user, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);
    event LiquidityRemoved(address indexed user, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);
    event TokenSwapped(address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event TokenDeposited(address indexed user, address indexed token, uint256 amount);
    event TokenWithdrawn(address indexed user, address indexed token, uint256 amount);

    constructor() {
        owner = msg.sender;
        paused = false;
    }


    function addLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) external {

        require(!paused, "Contract is paused");
        require(msg.sender != address(0), "Invalid sender");
        require(tokenA != address(0) && tokenB != address(0), "Invalid token addresses");
        require(amountA > 0 && amountB > 0, "Amounts must be greater than zero");


        bool tokenASupported = false;
        bool tokenBSupported = false;
        for(uint i = 0; i < tokenList.length; i++) {
            if(tokenList[i] == tokenA) tokenASupported = true;
            if(tokenList[i] == tokenB) tokenBSupported = true;
        }
        require(tokenASupported && tokenBSupported, "Tokens not supported");


        require(IERC20(tokenA).balanceOf(msg.sender) >= amountA, "Insufficient tokenA balance");
        require(IERC20(tokenB).balanceOf(msg.sender) >= amountB, "Insufficient tokenB balance");
        require(IERC20(tokenA).allowance(msg.sender, address(this)) >= amountA, "Insufficient tokenA allowance");
        require(IERC20(tokenB).allowance(msg.sender, address(this)) >= amountB, "Insufficient tokenB allowance");


        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);


        liquidityBalances[tokenA][tokenB] += amountA;
        liquidityBalances[tokenB][tokenA] += amountB;

        emit LiquidityAdded(msg.sender, tokenA, tokenB, amountA, amountB);
    }


    function removeLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) external {

        require(!paused, "Contract is paused");
        require(msg.sender != address(0), "Invalid sender");
        require(tokenA != address(0) && tokenB != address(0), "Invalid token addresses");
        require(amountA > 0 && amountB > 0, "Amounts must be greater than zero");


        bool tokenASupported = false;
        bool tokenBSupported = false;
        for(uint i = 0; i < tokenList.length; i++) {
            if(tokenList[i] == tokenA) tokenASupported = true;
            if(tokenList[i] == tokenB) tokenBSupported = true;
        }
        require(tokenASupported && tokenBSupported, "Tokens not supported");

        require(liquidityBalances[tokenA][tokenB] >= amountA, "Insufficient liquidity for tokenA");
        require(liquidityBalances[tokenB][tokenA] >= amountB, "Insufficient liquidity for tokenB");


        liquidityBalances[tokenA][tokenB] -= amountA;
        liquidityBalances[tokenB][tokenA] -= amountB;


        IERC20(tokenA).transfer(msg.sender, amountA);
        IERC20(tokenB).transfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, tokenA, tokenB, amountA, amountB);
    }


    function swapTokens(address tokenIn, address tokenOut, uint256 amountIn) external {

        require(!paused, "Contract is paused");
        require(msg.sender != address(0), "Invalid sender");
        require(tokenIn != address(0) && tokenOut != address(0), "Invalid token addresses");
        require(amountIn > 0, "Amount must be greater than zero");
        require(tokenIn != tokenOut, "Cannot swap same token");


        bool tokenInSupported = false;
        bool tokenOutSupported = false;
        for(uint i = 0; i < tokenList.length; i++) {
            if(tokenList[i] == tokenIn) tokenInSupported = true;
            if(tokenList[i] == tokenOut) tokenOutSupported = true;
        }
        require(tokenInSupported && tokenOutSupported, "Tokens not supported");


        require(IERC20(tokenIn).balanceOf(msg.sender) >= amountIn, "Insufficient input token balance");
        require(IERC20(tokenIn).allowance(msg.sender, address(this)) >= amountIn, "Insufficient input token allowance");


        uint256 reserveIn = liquidityBalances[tokenIn][tokenOut];
        uint256 reserveOut = liquidityBalances[tokenOut][tokenIn];
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");


        uint256 amountInWithFee = amountIn * (10000 - 30) / 10000;
        uint256 amountOut = (amountInWithFee * reserveOut) / (reserveIn + amountInWithFee);

        require(amountOut > 0, "Insufficient output amount");
        require(reserveOut >= amountOut, "Insufficient liquidity for output");


        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).transfer(msg.sender, amountOut);


        liquidityBalances[tokenIn][tokenOut] += amountIn;
        liquidityBalances[tokenOut][tokenIn] -= amountOut;

        emit TokenSwapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }


    function depositToken(address token, uint256 amount) external {

        require(!paused, "Contract is paused");
        require(msg.sender != address(0), "Invalid sender");
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than zero");


        bool tokenSupported = false;
        for(uint i = 0; i < tokenList.length; i++) {
            if(tokenList[i] == token) {
                tokenSupported = true;
                break;
            }
        }
        require(tokenSupported, "Token not supported");


        require(IERC20(token).balanceOf(msg.sender) >= amount, "Insufficient token balance");
        require(IERC20(token).allowance(msg.sender, address(this)) >= amount, "Insufficient token allowance");

        IERC20(token).transferFrom(msg.sender, address(this), amount);
        userBalances[msg.sender][token] += amount;

        emit TokenDeposited(msg.sender, token, amount);
    }


    function withdrawToken(address token, uint256 amount) external {

        require(!paused, "Contract is paused");
        require(msg.sender != address(0), "Invalid sender");
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than zero");


        bool tokenSupported = false;
        for(uint i = 0; i < tokenList.length; i++) {
            if(tokenList[i] == token) {
                tokenSupported = true;
                break;
            }
        }
        require(tokenSupported, "Token not supported");

        require(userBalances[msg.sender][token] >= amount, "Insufficient balance");

        userBalances[msg.sender][token] -= amount;
        IERC20(token).transfer(msg.sender, amount);

        emit TokenWithdrawn(msg.sender, token, amount);
    }


    function addSupportedToken(address token) external {
        require(msg.sender == owner, "Only owner can add tokens");
        require(token != address(0), "Invalid token address");


        bool alreadySupported = false;
        for(uint i = 0; i < tokenList.length; i++) {
            if(tokenList[i] == token) {
                alreadySupported = true;
                break;
            }
        }
        require(!alreadySupported, "Token already supported");

        tokenList.push(token);
        supportedTokens[token] = true;
    }


    function removeSupportedToken(address token) external {
        require(msg.sender == owner, "Only owner can remove tokens");
        require(token != address(0), "Invalid token address");
        require(supportedTokens[token], "Token not supported");


        for(uint i = 0; i < tokenList.length; i++) {
            if(tokenList[i] == token) {
                tokenList[i] = tokenList[tokenList.length - 1];
                tokenList.pop();
                break;
            }
        }

        supportedTokens[token] = false;
    }


    function pauseContract() external {
        require(msg.sender == owner, "Only owner can pause");
        paused = true;
    }


    function unpauseContract() external {
        require(msg.sender == owner, "Only owner can unpause");
        paused = false;
    }


    function transferOwnership(address newOwner) external {
        require(msg.sender == owner, "Only owner can transfer ownership");
        require(newOwner != address(0), "Invalid new owner address");
        owner = newOwner;
    }


    function getSwapPrice(address tokenIn, address tokenOut, uint256 amountIn) external view returns (uint256) {
        require(tokenIn != address(0) && tokenOut != address(0), "Invalid token addresses");
        require(amountIn > 0, "Amount must be greater than zero");


        bool tokenInSupported = false;
        bool tokenOutSupported = false;
        for(uint i = 0; i < tokenList.length; i++) {
            if(tokenList[i] == tokenIn) tokenInSupported = true;
            if(tokenList[i] == tokenOut) tokenOutSupported = true;
        }
        require(tokenInSupported && tokenOutSupported, "Tokens not supported");

        uint256 reserveIn = liquidityBalances[tokenIn][tokenOut];
        uint256 reserveOut = liquidityBalances[tokenOut][tokenIn];

        if(reserveIn == 0 || reserveOut == 0) return 0;


        uint256 amountInWithFee = amountIn * (10000 - 30) / 10000;
        uint256 amountOut = (amountInWithFee * reserveOut) / (reserveIn + amountInWithFee);

        return amountOut;
    }


    function getLiquidityInfo(address tokenA, address tokenB) external view returns (uint256, uint256) {
        require(tokenA != address(0) && tokenB != address(0), "Invalid token addresses");


        bool tokenASupported = false;
        bool tokenBSupported = false;
        for(uint i = 0; i < tokenList.length; i++) {
            if(tokenList[i] == tokenA) tokenASupported = true;
            if(tokenList[i] == tokenB) tokenBSupported = true;
        }
        require(tokenASupported && tokenBSupported, "Tokens not supported");

        return (liquidityBalances[tokenA][tokenB], liquidityBalances[tokenB][tokenA]);
    }


    function getUserBalance(address user, address token) external view returns (uint256) {
        require(user != address(0) && token != address(0), "Invalid addresses");


        bool tokenSupported = false;
        for(uint i = 0; i < tokenList.length; i++) {
            if(tokenList[i] == token) {
                tokenSupported = true;
                break;
            }
        }
        require(tokenSupported, "Token not supported");

        return userBalances[user][token];
    }


    function getSupportedTokensCount() external view returns (uint256) {
        return tokenList.length;
    }


    function getSupportedToken(uint256 index) external view returns (address) {
        require(index < tokenList.length, "Index out of bounds");
        return tokenList[index];
    }


    function emergencyWithdraw(address token, uint256 amount) external {
        require(msg.sender == owner, "Only owner can emergency withdraw");
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than zero");

        IERC20(token).transfer(owner, amount);
    }


    function setFeeRate(uint256 newFeeRate) external {
        require(msg.sender == owner, "Only owner can set fee rate");
        require(newFeeRate <= 1000, "Fee rate too high");
        feeRate = newFeeRate;
    }


    function batchAddLiquidity(
        address[] memory tokensA,
        address[] memory tokensB,
        uint256[] memory amountsA,
        uint256[] memory amountsB
    ) external {
        require(tokensA.length == tokensB.length && tokensB.length == amountsA.length && amountsA.length == amountsB.length, "Array lengths mismatch");

        for(uint i = 0; i < tokensA.length; i++) {

            require(!paused, "Contract is paused");
            require(msg.sender != address(0), "Invalid sender");
            require(tokensA[i] != address(0) && tokensB[i] != address(0), "Invalid token addresses");
            require(amountsA[i] > 0 && amountsB[i] > 0, "Amounts must be greater than zero");


            bool tokenASupported = false;
            bool tokenBSupported = false;
            for(uint j = 0; j < tokenList.length; j++) {
                if(tokenList[j] == tokensA[i]) tokenASupported = true;
                if(tokenList[j] == tokensB[i]) tokenBSupported = true;
            }
            require(tokenASupported && tokenBSupported, "Tokens not supported");


            require(IERC20(tokensA[i]).balanceOf(msg.sender) >= amountsA[i], "Insufficient tokenA balance");
            require(IERC20(tokensB[i]).balanceOf(msg.sender) >= amountsB[i], "Insufficient tokenB balance");
            require(IERC20(tokensA[i]).allowance(msg.sender, address(this)) >= amountsA[i], "Insufficient tokenA allowance");
            require(IERC20(tokensB[i]).allowance(msg.sender, address(this)) >= amountsB[i], "Insufficient tokenB allowance");


            IERC20(tokensA[i]).transferFrom(msg.sender, address(this), amountsA[i]);
            IERC20(tokensB[i]).transferFrom(msg.sender, address(this), amountsB[i]);


            liquidityBalances[tokensA[i]][tokensB[i]] += amountsA[i];
            liquidityBalances[tokensB[i]][tokensA[i]] += amountsB[i];

            emit LiquidityAdded(msg.sender, tokensA[i], tokensB[i], amountsA[i], amountsB[i]);
        }
    }
}
