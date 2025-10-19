
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


    mapping(address => mapping(address => uint256)) public userBalances;
    mapping(address => mapping(address => mapping(address => uint256))) public allowances;
    mapping(address => mapping(address => uint256)) public liquidityPools;
    mapping(address => mapping(address => address)) public poolExists;
    mapping(address => mapping(address => uint256)) public userLiquidityShares;
    mapping(address => mapping(address => uint256)) public totalLiquidityShares;
    address public owner;
    uint256 public totalTradingVolume;
    uint256 public totalFees;

    event LiquidityAdded(address indexed user, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);
    event LiquidityRemoved(address indexed user, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);
    event TokensSwapped(address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event FeesCollected(address indexed token, uint256 amount);

    constructor() {
        owner = msg.sender;
    }


    function deposit(address token, uint256 amount) public {

        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than 0");
        require(msg.sender != address(0), "Invalid sender");

        IERC20(token).transferFrom(msg.sender, address(this), amount);
        userBalances[msg.sender][token] += amount;
    }

    function withdraw(address token, uint256 amount) public {

        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than 0");
        require(msg.sender != address(0), "Invalid sender");
        require(userBalances[msg.sender][token] >= amount, "Insufficient balance");

        userBalances[msg.sender][token] -= amount;
        IERC20(token).transfer(msg.sender, amount);
    }


    function addLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) public {

        require(tokenA != address(0), "Invalid token address");
        require(tokenB != address(0), "Invalid token address");
        require(amountA > 0, "Amount must be greater than 0");
        require(amountB > 0, "Amount must be greater than 0");
        require(msg.sender != address(0), "Invalid sender");
        require(tokenA != tokenB, "Tokens must be different");


        require(amountA >= 1000, "Minimum liquidity A not met");
        require(amountB >= 1000, "Minimum liquidity B not met");

        require(userBalances[msg.sender][tokenA] >= amountA, "Insufficient balance A");
        require(userBalances[msg.sender][tokenB] >= amountB, "Insufficient balance B");


        if (tokenA > tokenB) {
            address temp = tokenA;
            tokenA = tokenB;
            tokenB = temp;
            uint256 tempAmount = amountA;
            amountA = amountB;
            amountB = tempAmount;
        }


        bool poolExistsFlag = false;
        if (liquidityPools[tokenA][tokenB] > 0 || liquidityPools[tokenB][tokenA] > 0) {
            poolExistsFlag = true;
        }

        uint256 liquidityMinted = 0;

        if (!poolExistsFlag) {

            liquidityMinted = sqrt(amountA * amountB);

            require(liquidityMinted > 1000, "Insufficient liquidity minted");
            totalLiquidityShares[tokenA][tokenB] = liquidityMinted;
        } else {

            uint256 reserveA = liquidityPools[tokenA][tokenB];
            uint256 reserveB = liquidityPools[tokenB][tokenA];

            uint256 liquidityA = (amountA * totalLiquidityShares[tokenA][tokenB]) / reserveA;
            uint256 liquidityB = (amountB * totalLiquidityShares[tokenA][tokenB]) / reserveB;

            liquidityMinted = liquidityA < liquidityB ? liquidityA : liquidityB;
            totalLiquidityShares[tokenA][tokenB] += liquidityMinted;
        }

        userBalances[msg.sender][tokenA] -= amountA;
        userBalances[msg.sender][tokenB] -= amountB;

        liquidityPools[tokenA][tokenB] += amountA;
        liquidityPools[tokenB][tokenA] += amountB;

        userLiquidityShares[msg.sender][tokenA] += liquidityMinted;

        poolExists[tokenA][tokenB] = address(this);

        emit LiquidityAdded(msg.sender, tokenA, tokenB, amountA, amountB);
    }


    function removeLiquidity(address tokenA, address tokenB, uint256 liquidity) public {

        require(tokenA != address(0), "Invalid token address");
        require(tokenB != address(0), "Invalid token address");
        require(liquidity > 0, "Amount must be greater than 0");
        require(msg.sender != address(0), "Invalid sender");
        require(tokenA != tokenB, "Tokens must be different");


        if (tokenA > tokenB) {
            address temp = tokenA;
            tokenA = tokenB;
            tokenB = temp;
        }

        require(userLiquidityShares[msg.sender][tokenA] >= liquidity, "Insufficient liquidity shares");
        require(totalLiquidityShares[tokenA][tokenB] >= liquidity, "Invalid liquidity amount");

        uint256 reserveA = liquidityPools[tokenA][tokenB];
        uint256 reserveB = liquidityPools[tokenB][tokenA];

        uint256 amountA = (liquidity * reserveA) / totalLiquidityShares[tokenA][tokenB];
        uint256 amountB = (liquidity * reserveB) / totalLiquidityShares[tokenA][tokenB];

        require(amountA > 0 && amountB > 0, "Insufficient liquidity burned");

        userLiquidityShares[msg.sender][tokenA] -= liquidity;
        totalLiquidityShares[tokenA][tokenB] -= liquidity;

        liquidityPools[tokenA][tokenB] -= amountA;
        liquidityPools[tokenB][tokenA] -= amountB;

        userBalances[msg.sender][tokenA] += amountA;
        userBalances[msg.sender][tokenB] += amountB;

        emit LiquidityRemoved(msg.sender, tokenA, tokenB, amountA, amountB);
    }


    function swapTokens(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut) public {

        require(tokenIn != address(0), "Invalid token address");
        require(tokenOut != address(0), "Invalid token address");
        require(amountIn > 0, "Amount must be greater than 0");
        require(msg.sender != address(0), "Invalid sender");
        require(tokenIn != tokenOut, "Tokens must be different");

        require(userBalances[msg.sender][tokenIn] >= amountIn, "Insufficient balance");


        address token0 = tokenIn < tokenOut ? tokenIn : tokenOut;
        address token1 = tokenIn < tokenOut ? tokenOut : tokenIn;

        require(liquidityPools[token0][token1] > 0, "Pool does not exist");

        uint256 reserveIn;
        uint256 reserveOut;

        if (tokenIn == token0) {
            reserveIn = liquidityPools[token0][token1];
            reserveOut = liquidityPools[token1][token0];
        } else {
            reserveIn = liquidityPools[token1][token0];
            reserveOut = liquidityPools[token0][token1];
        }

        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");


        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        uint256 amountOut = numerator / denominator;

        require(amountOut >= minAmountOut, "Insufficient output amount");
        require(amountOut < reserveOut, "Insufficient liquidity");


        uint256 feeAmount = amountIn * 3 / 1000;

        userBalances[msg.sender][tokenIn] -= amountIn;
        userBalances[msg.sender][tokenOut] += amountOut;


        if (tokenIn == token0) {
            liquidityPools[token0][token1] += amountIn;
            liquidityPools[token1][token0] -= amountOut;
        } else {
            liquidityPools[token1][token0] += amountIn;
            liquidityPools[token0][token1] -= amountOut;
        }


        totalTradingVolume += amountIn;
        totalFees += feeAmount;

        emit TokensSwapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }


    function getAmountOut(uint256 amountIn, address tokenIn, address tokenOut) public view returns (uint256) {

        require(tokenIn != address(0), "Invalid token address");
        require(tokenOut != address(0), "Invalid token address");
        require(amountIn > 0, "Amount must be greater than 0");
        require(tokenIn != tokenOut, "Tokens must be different");

        address token0 = tokenIn < tokenOut ? tokenIn : tokenOut;
        address token1 = tokenIn < tokenOut ? tokenOut : tokenIn;

        uint256 reserveIn;
        uint256 reserveOut;

        if (tokenIn == token0) {
            reserveIn = liquidityPools[token0][token1];
            reserveOut = liquidityPools[token1][token0];
        } else {
            reserveIn = liquidityPools[token1][token0];
            reserveOut = liquidityPools[token0][token1];
        }

        if (reserveIn == 0 || reserveOut == 0) {
            return 0;
        }


        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;

        return numerator / denominator;
    }


    function sqrt(uint256 x) public pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }


    function collectFees(address token) public {
        require(msg.sender == owner, "Only owner can collect fees");
        require(token != address(0), "Invalid token address");

        uint256 balance = IERC20(token).balanceOf(address(this));

        uint256 feeAmount = balance * 1 / 1000;

        if (feeAmount > 0) {
            IERC20(token).transfer(owner, feeAmount);
            emit FeesCollected(token, feeAmount);
        }
    }


    function updateOwner(address newOwner) public {
        require(msg.sender == owner, "Only owner can update owner");
        require(newOwner != address(0), "Invalid new owner address");
        owner = newOwner;
    }


    function getPoolReserves(address tokenA, address tokenB) public view returns (uint256, uint256) {
        require(tokenA != address(0), "Invalid token address");
        require(tokenB != address(0), "Invalid token address");
        require(tokenA != tokenB, "Tokens must be different");

        address token0 = tokenA < tokenB ? tokenA : tokenB;
        address token1 = tokenA < tokenB ? tokenB : tokenA;

        return (liquidityPools[token0][token1], liquidityPools[token1][token0]);
    }


    function getUserBalance(address user, address token) public view returns (uint256) {

        require(user != address(0), "Invalid user address");
        require(token != address(0), "Invalid token address");

        return userBalances[user][token];
    }


    function emergencyWithdraw(address token) public {
        require(msg.sender == owner, "Only owner can emergency withdraw");
        require(token != address(0), "Invalid token address");

        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).transfer(owner, balance);
        }
    }


    function getTotalStats() public view returns (uint256, uint256) {
        return (totalTradingVolume, totalFees);
    }


    function min(uint256 a, uint256 b) public pure returns (uint256) {
        return a < b ? a : b;
    }

    function max(uint256 a, uint256 b) public pure returns (uint256) {
        return a > b ? a : b;
    }
}
