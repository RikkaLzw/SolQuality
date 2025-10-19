
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


    uint256 public feeRate = 30;
    uint256 public minimumLiquidity = 1000;

    event LiquidityAdded(address indexed user, uint256 amountA, uint256 amountB, uint256 lpTokens);
    event LiquidityRemoved(address indexed user, uint256 amountA, uint256 amountB, uint256 lpTokens);
    event TokensSwapped(address indexed user, address tokenIn, uint256 amountIn, uint256 amountOut);

    constructor(address _tokenA, address _tokenB) {
        tokenA = _tokenA;
        tokenB = _tokenB;
        owner = msg.sender;
    }


    function addLiquidity(uint256 amountA, uint256 amountB) external {

        require(msg.sender != address(0), "Invalid sender");
        require(amountA > 0, "Amount A must be greater than 0");
        require(amountB > 0, "Amount B must be greater than 0");


        require(IERC20(tokenA).transferFrom(msg.sender, address(this), amountA), "Transfer A failed");
        require(IERC20(tokenB).transferFrom(msg.sender, address(this), amountB), "Transfer B failed");

        uint256 lpTokensToMint;

        if (totalLPTokenSupply == 0) {

            lpTokensToMint = sqrt(amountA * amountB) - 1000;
        } else {
            uint256 lpTokensFromA = (amountA * totalLPTokenSupply) / totalLiquidityTokenA;
            uint256 lpTokensFromB = (amountB * totalLPTokenSupply) / totalLiquidityTokenB;
            lpTokensToMint = lpTokensFromA < lpTokensFromB ? lpTokensFromA : lpTokensFromB;
        }

        require(lpTokensToMint > 0, "Insufficient liquidity minted");


        userLiquidityTokenA[msg.sender] += amountA;
        userLiquidityTokenB[msg.sender] += amountB;
        userLPTokens[msg.sender] += lpTokensToMint;
        totalLiquidityTokenA += amountA;
        totalLiquidityTokenB += amountB;
        totalLPTokenSupply += lpTokensToMint;

        emit LiquidityAdded(msg.sender, amountA, amountB, lpTokensToMint);
    }


    function removeLiquidity(uint256 lpTokenAmount) external {

        require(msg.sender != address(0), "Invalid sender");
        require(lpTokenAmount > 0, "LP token amount must be greater than 0");
        require(userLPTokens[msg.sender] >= lpTokenAmount, "Insufficient LP tokens");

        uint256 amountA = (lpTokenAmount * totalLiquidityTokenA) / totalLPTokenSupply;
        uint256 amountB = (lpTokenAmount * totalLiquidityTokenB) / totalLPTokenSupply;

        require(amountA > 0 && amountB > 0, "Insufficient liquidity");


        userLPTokens[msg.sender] -= lpTokenAmount;
        totalLPTokenSupply -= lpTokenAmount;
        totalLiquidityTokenA -= amountA;
        totalLiquidityTokenB -= amountB;


        require(IERC20(tokenA).transfer(msg.sender, amountA), "Transfer A failed");
        require(IERC20(tokenB).transfer(msg.sender, amountB), "Transfer B failed");

        emit LiquidityRemoved(msg.sender, amountA, amountB, lpTokenAmount);
    }


    function swapAForB(uint256 amountAIn) external {

        require(msg.sender != address(0), "Invalid sender");
        require(amountAIn > 0, "Amount in must be greater than 0");
        require(totalLiquidityTokenA > 0 && totalLiquidityTokenB > 0, "Insufficient liquidity");


        uint256 amountAInWithFee = amountAIn * (10000 - 30) / 10000;
        uint256 amountBOut = (amountAInWithFee * totalLiquidityTokenB) / (totalLiquidityTokenA + amountAInWithFee);

        require(amountBOut > 0, "Insufficient output amount");
        require(amountBOut < totalLiquidityTokenB, "Insufficient liquidity");


        require(IERC20(tokenA).transferFrom(msg.sender, address(this), amountAIn), "Transfer A failed");
        require(IERC20(tokenB).transfer(msg.sender, amountBOut), "Transfer B failed");


        totalLiquidityTokenA += amountAIn;
        totalLiquidityTokenB -= amountBOut;

        emit TokensSwapped(msg.sender, tokenA, amountAIn, amountBOut);
    }


    function swapBForA(uint256 amountBIn) external {

        require(msg.sender != address(0), "Invalid sender");
        require(amountBIn > 0, "Amount in must be greater than 0");
        require(totalLiquidityTokenA > 0 && totalLiquidityTokenB > 0, "Insufficient liquidity");


        uint256 amountBInWithFee = amountBIn * (10000 - 30) / 10000;
        uint256 amountAOut = (amountBInWithFee * totalLiquidityTokenA) / (totalLiquidityTokenB + amountBInWithFee);

        require(amountAOut > 0, "Insufficient output amount");
        require(amountAOut < totalLiquidityTokenA, "Insufficient liquidity");


        require(IERC20(tokenB).transferFrom(msg.sender, address(this), amountBIn), "Transfer B failed");
        require(IERC20(tokenA).transfer(msg.sender, amountAOut), "Transfer A failed");


        totalLiquidityTokenB += amountBIn;
        totalLiquidityTokenA -= amountAOut;

        emit TokensSwapped(msg.sender, tokenB, amountBIn, amountAOut);
    }


    function getReserves() external view returns (uint256 reserveA, uint256 reserveB) {

        require(msg.sender != address(0), "Invalid sender");
        return (totalLiquidityTokenA, totalLiquidityTokenB);
    }


    function getUserLiquidity(address user) external view returns (uint256 lpTokens, uint256 tokenAAmount, uint256 tokenBAmount) {

        require(user != address(0), "Invalid user address");

        lpTokens = userLPTokens[user];
        if (totalLPTokenSupply > 0) {
            tokenAAmount = (lpTokens * totalLiquidityTokenA) / totalLPTokenSupply;
            tokenBAmount = (lpTokens * totalLiquidityTokenB) / totalLPTokenSupply;
        }
    }


    function getSwapAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) external view returns (uint256) {

        require(amountIn > 0, "Amount in must be greater than 0");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");


        uint256 amountInWithFee = amountIn * (10000 - 30) / 10000;
        return (amountInWithFee * reserveOut) / (reserveIn + amountInWithFee);
    }


    function emergencyWithdraw() external {

        require(msg.sender == owner, "Only owner can call this function");
        require(msg.sender != address(0), "Invalid sender");

        uint256 balanceA = IERC20(tokenA).balanceOf(address(this));
        uint256 balanceB = IERC20(tokenB).balanceOf(address(this));

        if (balanceA > 0) {

            require(IERC20(tokenA).transfer(owner, balanceA), "Transfer A failed");
        }
        if (balanceB > 0) {

            require(IERC20(tokenB).transfer(owner, balanceB), "Transfer B failed");
        }
    }


    function updateFeeRate(uint256 newFeeRate) external {

        require(msg.sender == owner, "Only owner can call this function");
        require(msg.sender != address(0), "Invalid sender");

        require(newFeeRate <= 1000, "Fee rate too high");

        feeRate = newFeeRate;
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


    function transferOwnership(address newOwner) external {

        require(msg.sender == owner, "Only owner can call this function");
        require(newOwner != address(0), "New owner cannot be zero address");
        require(msg.sender != address(0), "Invalid sender");

        owner = newOwner;
    }


    function getTotalSupply() public view returns (uint256) {
        return totalLPTokenSupply;
    }


    function getTokenAddresses() public view returns (address, address) {
        return (tokenA, tokenB);
    }
}
