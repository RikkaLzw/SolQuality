
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
    address public owner;
    mapping(address => mapping(address => uint256)) public liquidity;
    mapping(address => uint256) public totalLiquidity;
    mapping(address => mapping(address => uint256)) public userLiquidity;
    uint256 public feeRate = 30;
    uint256 public constant FEE_DENOMINATOR = 10000;

    event LiquidityAdded(address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB, address indexed provider);
    event LiquidityRemoved(address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB, address indexed provider);
    event TokenSwapped(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut, address indexed trader);

    constructor() {
        owner = msg.sender;
    }

    function addLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) external {

        require(msg.sender != address(0), "Invalid sender");
        require(tokenA != address(0), "Invalid token A");
        require(tokenB != address(0), "Invalid token B");
        require(tokenA != tokenB, "Same tokens");
        require(amountA > 0, "Amount A must be positive");
        require(amountB > 0, "Amount B must be positive");


        require(amountA >= 1000, "Minimum amount A is 1000");
        require(amountB >= 1000, "Minimum amount B is 1000");

        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);


        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
            (amountA, amountB) = (amountB, amountA);
        }

        liquidity[tokenA][tokenB] += amountA;
        liquidity[tokenB][tokenA] += amountB;
        totalLiquidity[tokenA] += amountA;
        totalLiquidity[tokenB] += amountB;
        userLiquidity[msg.sender][tokenA] += amountA;
        userLiquidity[msg.sender][tokenB] += amountB;

        emit LiquidityAdded(tokenA, tokenB, amountA, amountB, msg.sender);
    }

    function removeLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) external {

        require(msg.sender != address(0), "Invalid sender");
        require(tokenA != address(0), "Invalid token A");
        require(tokenB != address(0), "Invalid token B");
        require(tokenA != tokenB, "Same tokens");
        require(amountA > 0, "Amount A must be positive");
        require(amountB > 0, "Amount B must be positive");


        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
            (amountA, amountB) = (amountB, amountA);
        }

        require(userLiquidity[msg.sender][tokenA] >= amountA, "Insufficient liquidity A");
        require(userLiquidity[msg.sender][tokenB] >= amountB, "Insufficient liquidity B");
        require(liquidity[tokenA][tokenB] >= amountA, "Pool insufficient A");
        require(liquidity[tokenB][tokenA] >= amountB, "Pool insufficient B");

        liquidity[tokenA][tokenB] -= amountA;
        liquidity[tokenB][tokenA] -= amountB;
        totalLiquidity[tokenA] -= amountA;
        totalLiquidity[tokenB] -= amountB;
        userLiquidity[msg.sender][tokenA] -= amountA;
        userLiquidity[msg.sender][tokenB] -= amountB;

        IERC20(tokenA).transfer(msg.sender, amountA);
        IERC20(tokenB).transfer(msg.sender, amountB);

        emit LiquidityRemoved(tokenA, tokenB, amountA, amountB, msg.sender);
    }

    function swapTokens(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut) external {

        require(msg.sender != address(0), "Invalid sender");
        require(tokenIn != address(0), "Invalid token in");
        require(tokenOut != address(0), "Invalid token out");
        require(tokenIn != tokenOut, "Same tokens");
        require(amountIn > 0, "Amount in must be positive");


        require(amountIn >= 100, "Minimum swap amount is 100");

        uint256 reserveIn;
        uint256 reserveOut;


        if (tokenIn < tokenOut) {
            reserveIn = liquidity[tokenIn][tokenOut];
            reserveOut = liquidity[tokenOut][tokenIn];
        } else {
            reserveIn = liquidity[tokenOut][tokenIn];
            reserveOut = liquidity[tokenIn][tokenOut];
        }

        require(reserveIn > 0 && reserveOut > 0, "No liquidity");


        uint256 amountInWithFee = amountIn * (10000 - 30);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 10000 + amountInWithFee;
        uint256 amountOut = numerator / denominator;

        require(amountOut >= minAmountOut, "Slippage too high");
        require(amountOut < reserveOut, "Insufficient liquidity");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);


        if (tokenIn < tokenOut) {
            liquidity[tokenIn][tokenOut] += amountIn;
            liquidity[tokenOut][tokenIn] -= amountOut;
        } else {
            liquidity[tokenOut][tokenIn] += amountIn;
            liquidity[tokenIn][tokenOut] -= amountOut;
        }

        totalLiquidity[tokenIn] += amountIn;
        totalLiquidity[tokenOut] -= amountOut;

        IERC20(tokenOut).transfer(msg.sender, amountOut);

        emit TokenSwapped(tokenIn, tokenOut, amountIn, amountOut, msg.sender);
    }

    function getAmountOut(address tokenIn, address tokenOut, uint256 amountIn) public view returns (uint256) {

        require(tokenIn != address(0), "Invalid token in");
        require(tokenOut != address(0), "Invalid token out");
        require(tokenIn != tokenOut, "Same tokens");
        require(amountIn > 0, "Amount in must be positive");

        uint256 reserveIn;
        uint256 reserveOut;


        if (tokenIn < tokenOut) {
            reserveIn = liquidity[tokenIn][tokenOut];
            reserveOut = liquidity[tokenOut][tokenIn];
        } else {
            reserveIn = liquidity[tokenOut][tokenIn];
            reserveOut = liquidity[tokenIn][tokenOut];
        }

        if (reserveIn == 0 || reserveOut == 0) {
            return 0;
        }


        uint256 amountInWithFee = amountIn * (10000 - 30);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 10000 + amountInWithFee;
        return numerator / denominator;
    }

    function getLiquidityPool(address tokenA, address tokenB) public view returns (uint256, uint256) {

        require(tokenA != address(0), "Invalid token A");
        require(tokenB != address(0), "Invalid token B");
        require(tokenA != tokenB, "Same tokens");


        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }

        return (liquidity[tokenA][tokenB], liquidity[tokenB][tokenA]);
    }

    function getUserLiquidity(address user, address token) public view returns (uint256) {

        return userLiquidity[user][token];
    }

    function setFeeRate(uint256 newFeeRate) external {

        require(msg.sender == owner, "Only owner");
        require(newFeeRate <= 1000, "Fee too high");
        feeRate = newFeeRate;
    }

    function withdrawFees(address token) external {

        require(msg.sender == owner, "Only owner");
        require(token != address(0), "Invalid token");


        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 totalPool = totalLiquidity[token];

        if (balance > totalPool) {
            uint256 fees = balance - totalPool;
            IERC20(token).transfer(owner, fees);
        }
    }

    function emergencyWithdraw(address token, uint256 amount) external {

        require(msg.sender == owner, "Only owner");
        require(token != address(0), "Invalid token");
        require(amount > 0, "Amount must be positive");

        IERC20(token).transfer(owner, amount);
    }

    function changeOwner(address newOwner) external {

        require(msg.sender == owner, "Only owner");
        require(newOwner != address(0), "Invalid new owner");
        owner = newOwner;
    }


    function getOwner() public view returns (address) {
        return owner;
    }

    function getTotalLiquidity(address token) public view returns (uint256) {
        return totalLiquidity[token];
    }

    function getFeeRate() public view returns (uint256) {
        return feeRate;
    }


    function pauseContract() external {

        require(msg.sender == owner, "Only owner");


    }

    receive() external payable {


    }
}
