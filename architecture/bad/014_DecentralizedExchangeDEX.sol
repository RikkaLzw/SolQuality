
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
    mapping(address => uint256) internal tokenBalances;
    mapping(address => mapping(address => uint256)) internal allowances;
    address[] internal supportedTokens;
    mapping(address => bool) internal isTokenSupported;
    uint256 internal totalTrades;
    uint256 internal totalVolume;
    mapping(address => uint256) internal userTradeCount;

    event LiquidityAdded(address indexed user, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);
    event LiquidityRemoved(address indexed user, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);
    event TokenSwapped(address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event PoolCreated(address indexed tokenA, address indexed tokenB);

    constructor() {
        owner = msg.sender;
    }

    function addLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) external {

        if (msg.sender == address(0)) {
            revert("Invalid sender");
        }
        if (tokenA == address(0) || tokenB == address(0)) {
            revert("Invalid token address");
        }
        if (amountA == 0 || amountB == 0) {
            revert("Invalid amounts");
        }
        if (tokenA == tokenB) {
            revert("Same token");
        }


        if (amountA < 1000 || amountB < 1000) {
            revert("Minimum liquidity not met");
        }


        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);


        liquidityPools[tokenA][tokenB] += amountA;
        liquidityPools[tokenB][tokenA] += amountB;


        userLiquidity[msg.sender][tokenA] += amountA;
        userLiquidity[msg.sender][tokenB] += amountB;


        if (!isTokenSupported[tokenA]) {
            supportedTokens.push(tokenA);
            isTokenSupported[tokenA] = true;
        }
        if (!isTokenSupported[tokenB]) {
            supportedTokens.push(tokenB);
            isTokenSupported[tokenB] = true;
        }

        emit LiquidityAdded(msg.sender, tokenA, tokenB, amountA, amountB);
        emit PoolCreated(tokenA, tokenB);
    }

    function removeLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) external {

        if (msg.sender == address(0)) {
            revert("Invalid sender");
        }
        if (tokenA == address(0) || tokenB == address(0)) {
            revert("Invalid token address");
        }
        if (amountA == 0 || amountB == 0) {
            revert("Invalid amounts");
        }
        if (tokenA == tokenB) {
            revert("Same token");
        }


        if (userLiquidity[msg.sender][tokenA] < amountA) {
            revert("Insufficient liquidity A");
        }
        if (userLiquidity[msg.sender][tokenB] < amountB) {
            revert("Insufficient liquidity B");
        }


        if (liquidityPools[tokenA][tokenB] < amountA) {
            revert("Insufficient pool liquidity A");
        }
        if (liquidityPools[tokenB][tokenA] < amountB) {
            revert("Insufficient pool liquidity B");
        }


        liquidityPools[tokenA][tokenB] -= amountA;
        liquidityPools[tokenB][tokenA] -= amountB;


        userLiquidity[msg.sender][tokenA] -= amountA;
        userLiquidity[msg.sender][tokenB] -= amountB;


        IERC20(tokenA).transfer(msg.sender, amountA);
        IERC20(tokenB).transfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, tokenA, tokenB, amountA, amountB);
    }

    function swapTokens(address tokenIn, address tokenOut, uint256 amountIn) external {

        if (msg.sender == address(0)) {
            revert("Invalid sender");
        }
        if (tokenIn == address(0) || tokenOut == address(0)) {
            revert("Invalid token address");
        }
        if (amountIn == 0) {
            revert("Invalid amount");
        }
        if (tokenIn == tokenOut) {
            revert("Same token");
        }


        if (liquidityPools[tokenIn][tokenOut] == 0 || liquidityPools[tokenOut][tokenIn] == 0) {
            revert("Pool does not exist");
        }



        uint256 amountInWithFee = (amountIn * 997) / 1000;
        uint256 numerator = amountInWithFee * liquidityPools[tokenOut][tokenIn];
        uint256 denominator = liquidityPools[tokenIn][tokenOut] + amountInWithFee;
        uint256 amountOut = numerator / denominator;


        if (amountOut < 1) {
            revert("Insufficient output amount");
        }


        if (liquidityPools[tokenOut][tokenIn] < amountOut) {
            revert("Insufficient liquidity");
        }


        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);


        liquidityPools[tokenIn][tokenOut] += amountIn;
        liquidityPools[tokenOut][tokenIn] -= amountOut;


        IERC20(tokenOut).transfer(msg.sender, amountOut);


        totalTrades += 1;
        totalVolume += amountIn;
        userTradeCount[msg.sender] += 1;

        emit TokenSwapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    function getSwapAmount(address tokenIn, address tokenOut, uint256 amountIn) external view returns (uint256) {

        if (tokenIn == address(0) || tokenOut == address(0)) {
            revert("Invalid token address");
        }
        if (amountIn == 0) {
            revert("Invalid amount");
        }
        if (tokenIn == tokenOut) {
            revert("Same token");
        }

        if (liquidityPools[tokenIn][tokenOut] == 0 || liquidityPools[tokenOut][tokenIn] == 0) {
            return 0;
        }


        uint256 amountInWithFee = (amountIn * 997) / 1000;
        uint256 numerator = amountInWithFee * liquidityPools[tokenOut][tokenIn];
        uint256 denominator = liquidityPools[tokenIn][tokenOut] + amountInWithFee;
        return numerator / denominator;
    }

    function getLiquidityPool(address tokenA, address tokenB) external view returns (uint256, uint256) {
        return (liquidityPools[tokenA][tokenB], liquidityPools[tokenB][tokenA]);
    }

    function getUserLiquidity(address user, address token) external view returns (uint256) {
        return userLiquidity[user][token];
    }

    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }

    function getTotalTrades() external view returns (uint256) {
        return totalTrades;
    }

    function getTotalVolume() external view returns (uint256) {
        return totalVolume;
    }

    function getUserTradeCount(address user) external view returns (uint256) {
        return userTradeCount[user];
    }

    function getOwner() external view returns (address) {
        return owner;
    }

    function emergencyWithdraw(address token, uint256 amount) external {

        if (msg.sender == address(0)) {
            revert("Invalid sender");
        }
        if (token == address(0)) {
            revert("Invalid token address");
        }
        if (amount == 0) {
            revert("Invalid amount");
        }


        if (msg.sender != owner) {
            revert("Not owner");
        }

        IERC20(token).transfer(owner, amount);
    }

    function updateOwner(address newOwner) external {

        if (msg.sender == address(0)) {
            revert("Invalid sender");
        }
        if (newOwner == address(0)) {
            revert("Invalid new owner");
        }

        if (msg.sender != owner) {
            revert("Not owner");
        }

        owner = newOwner;
    }

    function addSupportedToken(address token) external {

        if (msg.sender == address(0)) {
            revert("Invalid sender");
        }
        if (token == address(0)) {
            revert("Invalid token address");
        }

        if (msg.sender != owner) {
            revert("Not owner");
        }

        if (!isTokenSupported[token]) {
            supportedTokens.push(token);
            isTokenSupported[token] = true;
        }
    }

    function removeSupportedToken(address token) external {

        if (msg.sender == address(0)) {
            revert("Invalid sender");
        }
        if (token == address(0)) {
            revert("Invalid token address");
        }

        if (msg.sender != owner) {
            revert("Not owner");
        }

        if (isTokenSupported[token]) {
            isTokenSupported[token] = false;

            for (uint256 i = 0; i < supportedTokens.length; i++) {
                if (supportedTokens[i] == token) {
                    supportedTokens[i] = supportedTokens[supportedTokens.length - 1];
                    supportedTokens.pop();
                    break;
                }
            }
        }
    }

    function getPoolPrice(address tokenA, address tokenB) external view returns (uint256) {
        if (liquidityPools[tokenA][tokenB] == 0 || liquidityPools[tokenB][tokenA] == 0) {
            return 0;
        }


        return (liquidityPools[tokenB][tokenA] * 1000000) / liquidityPools[tokenA][tokenB];
    }

    function calculateLiquidityShare(address user, address tokenA, address tokenB) external view returns (uint256, uint256) {
        uint256 userLiquidityA = userLiquidity[user][tokenA];
        uint256 userLiquidityB = userLiquidity[user][tokenB];
        uint256 totalLiquidityA = liquidityPools[tokenA][tokenB];
        uint256 totalLiquidityB = liquidityPools[tokenB][tokenA];

        if (totalLiquidityA == 0 || totalLiquidityB == 0) {
            return (0, 0);
        }


        uint256 shareA = (userLiquidityA * 10000) / totalLiquidityA;
        uint256 shareB = (userLiquidityB * 10000) / totalLiquidityB;

        return (shareA, shareB);
    }
}
