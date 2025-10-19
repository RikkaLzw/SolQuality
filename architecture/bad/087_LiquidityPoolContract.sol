
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

    mapping(address => uint256) public userBalances;
    mapping(address => mapping(address => uint256)) public userTokenBalances;
    address public tokenA;
    address public tokenB;
    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidityShares;
    address public owner;
    uint256 public feeRate;
    uint256 public totalFees;


    uint256 internal MINIMUM_LIQUIDITY = 1000;
    uint256 internal PRECISION = 1e18;
    uint256 internal MAX_FEE_RATE = 1000;

    event LiquidityAdded(address indexed user, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(address indexed user, uint256 amountA, uint256 amountB, uint256 liquidity);
    event Swap(address indexed user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    constructor(address _tokenA, address _tokenB) {

        require(msg.sender != address(0), "Invalid owner");
        owner = msg.sender;


        require(_tokenA != address(0), "Invalid token A");
        require(_tokenB != address(0), "Invalid token B");
        require(_tokenA != _tokenB, "Tokens must be different");

        tokenA = _tokenA;
        tokenB = _tokenB;
        feeRate = 30;
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external {

        require(msg.sender != address(0), "Invalid sender");


        require(amountA > 0, "Amount A must be positive");
        require(amountB > 0, "Amount B must be positive");


        require(tokenA != address(0), "Invalid token A");
        require(tokenB != address(0), "Invalid token B");

        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        uint256 liquidity;
        if (totalLiquidity == 0) {

            liquidity = sqrt(amountA * amountB) - 1000;
        } else {
            uint256 balanceA = IERC20(tokenA).balanceOf(address(this)) - amountA;
            uint256 balanceB = IERC20(tokenB).balanceOf(address(this)) - amountB;

            uint256 liquidityA = (amountA * totalLiquidity) / balanceA;
            uint256 liquidityB = (amountB * totalLiquidity) / balanceB;

            liquidity = liquidityA < liquidityB ? liquidityA : liquidityB;
        }


        require(liquidity > 0, "Insufficient liquidity minted");

        liquidityShares[msg.sender] += liquidity;
        totalLiquidity += liquidity;

        userTokenBalances[msg.sender][tokenA] += amountA;
        userTokenBalances[msg.sender][tokenB] += amountB;

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }

    function removeLiquidity(uint256 liquidity) external {

        require(msg.sender != address(0), "Invalid sender");


        require(liquidity > 0, "Liquidity must be positive");
        require(liquidityShares[msg.sender] >= liquidity, "Insufficient liquidity");

        uint256 balanceA = IERC20(tokenA).balanceOf(address(this));
        uint256 balanceB = IERC20(tokenB).balanceOf(address(this));

        uint256 amountA = (liquidity * balanceA) / totalLiquidity;
        uint256 amountB = (liquidity * balanceB) / totalLiquidity;


        require(amountA > 0, "Insufficient token A");
        require(amountB > 0, "Insufficient token B");

        liquidityShares[msg.sender] -= liquidity;
        totalLiquidity -= liquidity;

        IERC20(tokenA).transfer(msg.sender, amountA);
        IERC20(tokenB).transfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);
    }

    function swapAForB(uint256 amountIn) external {

        require(msg.sender != address(0), "Invalid sender");


        require(amountIn > 0, "Amount must be positive");


        require(tokenA != address(0), "Invalid token A");
        require(tokenB != address(0), "Invalid token B");

        uint256 balanceA = IERC20(tokenA).balanceOf(address(this));
        uint256 balanceB = IERC20(tokenB).balanceOf(address(this));


        uint256 amountInWithFee = amountIn * (10000 - 30) / 10000;
        uint256 amountOut = (amountInWithFee * balanceB) / (balanceA + amountInWithFee);


        require(amountOut > 0, "Insufficient output amount");
        require(amountOut < balanceB, "Insufficient liquidity");

        IERC20(tokenA).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenB).transfer(msg.sender, amountOut);


        uint256 fee = amountIn * 30 / 10000;
        totalFees += fee;

        emit Swap(msg.sender, tokenA, tokenB, amountIn, amountOut);
    }

    function swapBForA(uint256 amountIn) external {

        require(msg.sender != address(0), "Invalid sender");


        require(amountIn > 0, "Amount must be positive");


        require(tokenA != address(0), "Invalid token A");
        require(tokenB != address(0), "Invalid token B");

        uint256 balanceA = IERC20(tokenA).balanceOf(address(this));
        uint256 balanceB = IERC20(tokenB).balanceOf(address(this));


        uint256 amountInWithFee = amountIn * (10000 - 30) / 10000;
        uint256 amountOut = (amountInWithFee * balanceA) / (balanceB + amountInWithFee);


        require(amountOut > 0, "Insufficient output amount");
        require(amountOut < balanceA, "Insufficient liquidity");

        IERC20(tokenB).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenA).transfer(msg.sender, amountOut);


        uint256 fee = amountIn * 30 / 10000;
        totalFees += fee;

        emit Swap(msg.sender, tokenB, tokenA, amountIn, amountOut);
    }

    function getReserves() external view returns (uint256 reserveA, uint256 reserveB) {

        require(tokenA != address(0), "Invalid token A");
        require(tokenB != address(0), "Invalid token B");

        reserveA = IERC20(tokenA).balanceOf(address(this));
        reserveB = IERC20(tokenB).balanceOf(address(this));
    }

    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256) {

        require(amountIn > 0, "Amount must be positive");


        require(tokenIn == tokenA || tokenIn == tokenB, "Invalid token");

        uint256 balanceA = IERC20(tokenA).balanceOf(address(this));
        uint256 balanceB = IERC20(tokenB).balanceOf(address(this));

        if (tokenIn == tokenA) {

            uint256 amountInWithFee = amountIn * (10000 - 30) / 10000;
            return (amountInWithFee * balanceB) / (balanceA + amountInWithFee);
        } else {

            uint256 amountInWithFee = amountIn * (10000 - 30) / 10000;
            return (amountInWithFee * balanceA) / (balanceB + amountInWithFee);
        }
    }

    function setFeeRate(uint256 newFeeRate) external {

        require(msg.sender != address(0), "Invalid sender");
        require(msg.sender == owner, "Only owner");


        require(newFeeRate <= 1000, "Fee rate too high");

        feeRate = newFeeRate;
    }

    function withdrawFees() external {

        require(msg.sender != address(0), "Invalid sender");
        require(msg.sender == owner, "Only owner");


        require(totalFees > 0, "No fees to withdraw");

        uint256 fees = totalFees;
        totalFees = 0;


        uint256 balanceA = IERC20(tokenA).balanceOf(address(this));
        if (balanceA >= fees) {
            IERC20(tokenA).transfer(owner, fees);
        }
    }

    function getUserLiquidity(address user) external view returns (uint256) {

        require(user != address(0), "Invalid user");

        return liquidityShares[user];
    }

    function getTotalLiquidity() external view returns (uint256) {
        return totalLiquidity;
    }

    function getTokenBalances(address user) external view returns (uint256 balanceA, uint256 balanceB) {

        require(user != address(0), "Invalid user");

        balanceA = userTokenBalances[user][tokenA];
        balanceB = userTokenBalances[user][tokenB];
    }


    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }


    function emergencyWithdraw() external {

        require(msg.sender != address(0), "Invalid sender");
        require(msg.sender == owner, "Only owner");

        uint256 balanceA = IERC20(tokenA).balanceOf(address(this));
        uint256 balanceB = IERC20(tokenB).balanceOf(address(this));

        if (balanceA > 0) {
            IERC20(tokenA).transfer(owner, balanceA);
        }
        if (balanceB > 0) {
            IERC20(tokenB).transfer(owner, balanceB);
        }
    }

    function transferOwnership(address newOwner) external {

        require(msg.sender != address(0), "Invalid sender");
        require(msg.sender == owner, "Only owner");
        require(newOwner != address(0), "Invalid new owner");

        owner = newOwner;
    }
}
