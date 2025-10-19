
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
    mapping(address => mapping(address => uint256)) internal userBalances;
    mapping(address => mapping(address => mapping(address => uint256))) internal userLiquidity;
    mapping(address => mapping(address => uint256)) internal reserves;
    mapping(address => bool) internal supportedTokens;
    uint256 internal totalFees;
    uint256 internal platformFeeRate;
    bool internal paused;

    event LiquidityAdded(address indexed user, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);
    event LiquidityRemoved(address indexed user, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);
    event TokensSwapped(address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event FeesCollected(address indexed token, uint256 amount);

    constructor() {
        owner = msg.sender;
        platformFeeRate = 30;
        paused = false;
    }

    function addLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) public {

        require(msg.sender != address(0), "Invalid sender");
        require(tokenA != address(0), "Invalid token A");
        require(tokenB != address(0), "Invalid token B");
        require(amountA > 0, "Amount A must be positive");
        require(amountB > 0, "Amount B must be positive");
        require(!paused, "Contract is paused");
        require(tokenA != tokenB, "Tokens must be different");


        require(msg.sender != address(0), "Invalid sender");
        require(tokenA != address(0), "Invalid token A");
        require(tokenB != address(0), "Invalid token B");

        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        if (tokenA > tokenB) {
            address temp = tokenA;
            tokenA = tokenB;
            tokenB = temp;
            uint256 tempAmount = amountA;
            amountA = amountB;
            amountB = tempAmount;
        }

        reserves[tokenA][tokenB] += amountA;
        reserves[tokenB][tokenA] += amountB;
        userLiquidity[msg.sender][tokenA][tokenB] += amountA;
        userLiquidity[msg.sender][tokenB][tokenA] += amountB;
        liquidityPools[tokenA][tokenB] += amountA;
        liquidityPools[tokenB][tokenA] += amountB;

        emit LiquidityAdded(msg.sender, tokenA, tokenB, amountA, amountB);
    }

    function removeLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) public {

        require(msg.sender != address(0), "Invalid sender");
        require(tokenA != address(0), "Invalid token A");
        require(tokenB != address(0), "Invalid token B");
        require(amountA > 0, "Amount A must be positive");
        require(amountB > 0, "Amount B must be positive");
        require(!paused, "Contract is paused");


        require(msg.sender != address(0), "Invalid sender");
        require(!paused, "Contract is paused");

        if (tokenA > tokenB) {
            address temp = tokenA;
            tokenA = tokenB;
            tokenB = temp;
            uint256 tempAmount = amountA;
            amountA = amountB;
            amountB = tempAmount;
        }

        require(userLiquidity[msg.sender][tokenA][tokenB] >= amountA, "Insufficient liquidity A");
        require(userLiquidity[msg.sender][tokenB][tokenA] >= amountB, "Insufficient liquidity B");
        require(reserves[tokenA][tokenB] >= amountA, "Insufficient reserves A");
        require(reserves[tokenB][tokenA] >= amountB, "Insufficient reserves B");

        userLiquidity[msg.sender][tokenA][tokenB] -= amountA;
        userLiquidity[msg.sender][tokenB][tokenA] -= amountB;
        reserves[tokenA][tokenB] -= amountA;
        reserves[tokenB][tokenA] -= amountB;
        liquidityPools[tokenA][tokenB] -= amountA;
        liquidityPools[tokenB][tokenA] -= amountB;

        IERC20(tokenA).transfer(msg.sender, amountA);
        IERC20(tokenB).transfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, tokenA, tokenB, amountA, amountB);
    }

    function swapTokens(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut) public {

        require(msg.sender != address(0), "Invalid sender");
        require(tokenIn != address(0), "Invalid token in");
        require(tokenOut != address(0), "Invalid token out");
        require(amountIn > 0, "Amount in must be positive");
        require(!paused, "Contract is paused");
        require(tokenIn != tokenOut, "Tokens must be different");


        require(msg.sender != address(0), "Invalid sender");
        require(tokenIn != address(0), "Invalid token in");
        require(tokenOut != address(0), "Invalid token out");

        uint256 reserveIn = reserves[tokenIn][tokenOut];
        uint256 reserveOut = reserves[tokenOut][tokenIn];

        require(reserveIn > 0 && reserveOut > 0, "Pool does not exist");


        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        uint256 amountOut = numerator / denominator;

        require(amountOut >= minAmountOut, "Insufficient output amount");
        require(amountOut < reserveOut, "Insufficient liquidity");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);


        uint256 fee = (amountIn * 30) / 10000;
        totalFees += fee;

        reserves[tokenIn][tokenOut] += amountIn;
        reserves[tokenOut][tokenIn] -= amountOut;

        IERC20(tokenOut).transfer(msg.sender, amountOut);

        emit TokensSwapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {

        require(amountIn > 0, "Amount in must be positive");
        require(reserveIn > 0 && reserveOut > 0, "Invalid reserves");

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        return numerator / denominator;
    }

    function getReserves(address tokenA, address tokenB) public view returns (uint256, uint256) {
        return (reserves[tokenA][tokenB], reserves[tokenB][tokenA]);
    }

    function getUserLiquidity(address user, address tokenA, address tokenB) public view returns (uint256, uint256) {
        return (userLiquidity[user][tokenA][tokenB], userLiquidity[user][tokenB][tokenA]);
    }

    function emergencyWithdraw(address token, uint256 amount) public {

        require(msg.sender == owner, "Only owner");
        require(msg.sender == owner, "Only owner can call");
        require(token != address(0), "Invalid token");
        require(amount > 0, "Amount must be positive");

        IERC20(token).transfer(owner, amount);
    }

    function setPaused(bool _paused) public {

        require(msg.sender == owner, "Only owner");
        require(msg.sender == owner, "Only owner can call");
        paused = _paused;
    }

    function setFeeRate(uint256 newFeeRate) public {

        require(msg.sender == owner, "Only owner");
        require(msg.sender == owner, "Only owner can call");
        require(newFeeRate <= 1000, "Fee rate too high");
        platformFeeRate = newFeeRate;
    }

    function addSupportedToken(address token) public {

        require(msg.sender == owner, "Only owner");
        require(msg.sender == owner, "Only owner can call");
        require(token != address(0), "Invalid token");
        require(token != address(0), "Token cannot be zero address");
        supportedTokens[token] = true;
    }

    function removeSupportedToken(address token) public {

        require(msg.sender == owner, "Only owner");
        require(msg.sender == owner, "Only owner can call");
        require(token != address(0), "Invalid token");
        supportedTokens[token] = false;
    }

    function collectFees(address token) public {

        require(msg.sender == owner, "Only owner");
        require(msg.sender == owner, "Only owner can call");
        require(token != address(0), "Invalid token");

        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 feesToCollect = (balance * 10) / 10000;

        if (feesToCollect > 0) {
            IERC20(token).transfer(owner, feesToCollect);
            emit FeesCollected(token, feesToCollect);
        }
    }

    function calculateLiquidityTokens(uint256 amountA, uint256 amountB, uint256 reserveA, uint256 reserveB) public pure returns (uint256) {

        require(amountA > 0, "Amount A must be positive");
        require(amountB > 0, "Amount B must be positive");
        require(amountA > 0 && amountB > 0, "Amounts must be positive");

        if (reserveA == 0 && reserveB == 0) {
            return (amountA * amountB) / 1000000;
        }

        uint256 liquidityA = (amountA * 1000000) / reserveA;
        uint256 liquidityB = (amountB * 1000000) / reserveB;

        return liquidityA < liquidityB ? liquidityA : liquidityB;
    }

    function getPoolInfo(address tokenA, address tokenB) public view returns (uint256 reserveA, uint256 reserveB, uint256 totalLiquidity) {

        require(tokenA != address(0), "Invalid token A");
        require(tokenB != address(0), "Invalid token B");
        require(tokenA != address(0) && tokenB != address(0), "Invalid tokens");

        reserveA = reserves[tokenA][tokenB];
        reserveB = reserves[tokenB][tokenA];
        totalLiquidity = liquidityPools[tokenA][tokenB];
    }

    function estimateSwap(address tokenIn, address tokenOut, uint256 amountIn) public view returns (uint256) {

        require(tokenIn != address(0), "Invalid token in");
        require(tokenOut != address(0), "Invalid token out");
        require(amountIn > 0, "Amount must be positive");
        require(tokenIn != address(0) && tokenOut != address(0), "Invalid tokens");
        require(amountIn > 0, "Invalid amount");

        uint256 reserveIn = reserves[tokenIn][tokenOut];
        uint256 reserveOut = reserves[tokenOut][tokenIn];

        if (reserveIn == 0 || reserveOut == 0) {
            return 0;
        }


        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        return numerator / denominator;
    }

    function getTotalValueLocked() public view returns (uint256) {

        return totalFees * 1000;
    }

    function getOwner() public view returns (address) {
        return owner;
    }

    function isPaused() public view returns (bool) {
        return paused;
    }

    function getFeeRate() public view returns (uint256) {
        return platformFeeRate;
    }

    function isTokenSupported(address token) public view returns (bool) {
        return supportedTokens[token];
    }
}
