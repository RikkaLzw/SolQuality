
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract LiquidityPoolContract {

    mapping(address => uint256) public userLiquidityTokenA;
    mapping(address => uint256) public userLiquidityTokenB;
    mapping(address => uint256) public userLPTokens;


    uint256 internal totalLiquidityTokenA;
    uint256 internal totalLiquidityTokenB;
    uint256 internal totalLPTokenSupply;


    address public tokenA;
    address public tokenB;
    address public owner;


    uint256 public feeRate = 3;
    uint256 public minimumLiquidity = 1000;

    event LiquidityAdded(address indexed user, uint256 amountA, uint256 amountB, uint256 lpTokens);
    event LiquidityRemoved(address indexed user, uint256 amountA, uint256 amountB, uint256 lpTokens);
    event TokensSwapped(address indexed user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    constructor(address _tokenA, address _tokenB) {
        tokenA = _tokenA;
        tokenB = _tokenB;
        owner = msg.sender;
    }


    function addLiquidity(uint256 amountA, uint256 amountB) external {

        require(msg.sender != address(0), "Invalid address");
        require(amountA > 0, "Amount A must be greater than 0");
        require(amountB > 0, "Amount B must be greater than 0");


        require(IERC20(tokenA).balanceOf(msg.sender) >= amountA, "Insufficient token A balance");
        require(IERC20(tokenB).balanceOf(msg.sender) >= amountB, "Insufficient token B balance");
        require(IERC20(tokenA).allowance(msg.sender, address(this)) >= amountA, "Insufficient token A allowance");
        require(IERC20(tokenB).allowance(msg.sender, address(this)) >= amountB, "Insufficient token B allowance");

        uint256 lpTokensToMint;

        if (totalLPTokenSupply == 0) {

            lpTokensToMint = sqrt(amountA * amountB) - 1000;
        } else {
            uint256 lpTokensFromA = (amountA * totalLPTokenSupply) / totalLiquidityTokenA;
            uint256 lpTokensFromB = (amountB * totalLPTokenSupply) / totalLiquidityTokenB;
            lpTokensToMint = lpTokensFromA < lpTokensFromB ? lpTokensFromA : lpTokensFromB;
        }

        require(lpTokensToMint > 0, "Insufficient liquidity minted");


        bool successA = IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        require(successA, "Token A transfer failed");
        bool successB = IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);
        require(successB, "Token B transfer failed");

        userLiquidityTokenA[msg.sender] += amountA;
        userLiquidityTokenB[msg.sender] += amountB;
        userLPTokens[msg.sender] += lpTokensToMint;
        totalLiquidityTokenA += amountA;
        totalLiquidityTokenB += amountB;
        totalLPTokenSupply += lpTokensToMint;

        emit LiquidityAdded(msg.sender, amountA, amountB, lpTokensToMint);
    }

    function removeLiquidity(uint256 lpTokenAmount) external {

        require(msg.sender != address(0), "Invalid address");
        require(lpTokenAmount > 0, "LP token amount must be greater than 0");
        require(userLPTokens[msg.sender] >= lpTokenAmount, "Insufficient LP tokens");

        uint256 amountA = (lpTokenAmount * totalLiquidityTokenA) / totalLPTokenSupply;
        uint256 amountB = (lpTokenAmount * totalLiquidityTokenB) / totalLPTokenSupply;

        require(amountA > 0 && amountB > 0, "Insufficient liquidity to remove");

        userLPTokens[msg.sender] -= lpTokenAmount;
        userLiquidityTokenA[msg.sender] -= amountA;
        userLiquidityTokenB[msg.sender] -= amountB;
        totalLPTokenSupply -= lpTokenAmount;
        totalLiquidityTokenA -= amountA;
        totalLiquidityTokenB -= amountB;


        bool successA = IERC20(tokenA).transfer(msg.sender, amountA);
        require(successA, "Token A transfer failed");
        bool successB = IERC20(tokenB).transfer(msg.sender, amountB);
        require(successB, "Token B transfer failed");

        emit LiquidityRemoved(msg.sender, amountA, amountB, lpTokenAmount);
    }

    function swapAForB(uint256 amountAIn) external {

        require(msg.sender != address(0), "Invalid address");
        require(amountAIn > 0, "Amount in must be greater than 0");
        require(IERC20(tokenA).balanceOf(msg.sender) >= amountAIn, "Insufficient token A balance");
        require(IERC20(tokenA).allowance(msg.sender, address(this)) >= amountAIn, "Insufficient token A allowance");


        uint256 amountAInWithFee = amountAIn * (1000 - 3) / 1000;
        uint256 amountBOut = (amountAInWithFee * totalLiquidityTokenB) / (totalLiquidityTokenA + amountAInWithFee);

        require(amountBOut > 0, "Insufficient output amount");
        require(totalLiquidityTokenB > amountBOut, "Insufficient liquidity");


        bool successIn = IERC20(tokenA).transferFrom(msg.sender, address(this), amountAIn);
        require(successIn, "Token A transfer failed");
        bool successOut = IERC20(tokenB).transfer(msg.sender, amountBOut);
        require(successOut, "Token B transfer failed");

        totalLiquidityTokenA += amountAIn;
        totalLiquidityTokenB -= amountBOut;

        emit TokensSwapped(msg.sender, tokenA, tokenB, amountAIn, amountBOut);
    }

    function swapBForA(uint256 amountBIn) external {

        require(msg.sender != address(0), "Invalid address");
        require(amountBIn > 0, "Amount in must be greater than 0");
        require(IERC20(tokenB).balanceOf(msg.sender) >= amountBIn, "Insufficient token B balance");
        require(IERC20(tokenB).allowance(msg.sender, address(this)) >= amountBIn, "Insufficient token B allowance");


        uint256 amountBInWithFee = amountBIn * (1000 - 3) / 1000;
        uint256 amountAOut = (amountBInWithFee * totalLiquidityTokenA) / (totalLiquidityTokenB + amountBInWithFee);

        require(amountAOut > 0, "Insufficient output amount");
        require(totalLiquidityTokenA > amountAOut, "Insufficient liquidity");


        bool successIn = IERC20(tokenB).transferFrom(msg.sender, address(this), amountBIn);
        require(successIn, "Token B transfer failed");
        bool successOut = IERC20(tokenA).transfer(msg.sender, amountAOut);
        require(successOut, "Token A transfer failed");

        totalLiquidityTokenB += amountBIn;
        totalLiquidityTokenA -= amountAOut;

        emit TokensSwapped(msg.sender, tokenB, tokenA, amountBIn, amountAOut);
    }

    function getReserves() external view returns (uint256 reserveA, uint256 reserveB) {

        require(msg.sender != address(0), "Invalid address");
        return (totalLiquidityTokenA, totalLiquidityTokenB);
    }

    function getUserLiquidity(address user) external view returns (uint256 lpTokens, uint256 tokenAAmount, uint256 tokenBAmount) {

        require(user != address(0), "Invalid address");
        require(msg.sender != address(0), "Invalid caller");

        lpTokens = userLPTokens[user];
        tokenAAmount = userLiquidityTokenA[user];
        tokenBAmount = userLiquidityTokenB[user];
    }

    function getSwapAmountOut(uint256 amountIn, bool isTokenA) external view returns (uint256 amountOut) {

        require(msg.sender != address(0), "Invalid address");
        require(amountIn > 0, "Amount in must be greater than 0");

        if (isTokenA) {

            uint256 amountInWithFee = amountIn * (1000 - 3) / 1000;
            amountOut = (amountInWithFee * totalLiquidityTokenB) / (totalLiquidityTokenA + amountInWithFee);
        } else {

            uint256 amountInWithFee = amountIn * (1000 - 3) / 1000;
            amountOut = (amountInWithFee * totalLiquidityTokenA) / (totalLiquidityTokenB + amountInWithFee);
        }
    }

    function emergencyWithdraw() external {

        require(msg.sender != address(0), "Invalid address");
        require(msg.sender == owner, "Only owner can call this function");

        uint256 balanceA = IERC20(tokenA).balanceOf(address(this));
        uint256 balanceB = IERC20(tokenB).balanceOf(address(this));

        if (balanceA > 0) {

            bool successA = IERC20(tokenA).transfer(owner, balanceA);
            require(successA, "Token A transfer failed");
        }

        if (balanceB > 0) {

            bool successB = IERC20(tokenB).transfer(owner, balanceB);
            require(successB, "Token B transfer failed");
        }
    }

    function updateFeeRate(uint256 newFeeRate) external {

        require(msg.sender != address(0), "Invalid address");
        require(msg.sender == owner, "Only owner can call this function");

        require(newFeeRate <= 10, "Fee rate too high");

        feeRate = newFeeRate;
    }

    function transferOwnership(address newOwner) external {

        require(msg.sender != address(0), "Invalid address");
        require(msg.sender == owner, "Only owner can call this function");
        require(newOwner != address(0), "New owner cannot be zero address");

        owner = newOwner;
    }


    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }


    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }


    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }
}
