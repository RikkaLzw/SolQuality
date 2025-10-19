
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
    IERC20 public tokenA;
    IERC20 public tokenB;

    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public totalLiquidity;

    mapping(address => uint256) public liquidityBalance;


    event LiquidityAdded(address user, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(address user, uint256 amountA, uint256 amountB, uint256 liquidity);
    event Swap(address user, address tokenIn, uint256 amountIn, uint256 amountOut);


    error Failed();
    error Invalid();
    error NotEnough();

    constructor(address _tokenA, address _tokenB) {
        require(_tokenA != address(0));
        require(_tokenB != address(0));
        require(_tokenA != _tokenB);

        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external returns (uint256 liquidity) {
        require(amountA > 0);
        require(amountB > 0);

        if (totalLiquidity == 0) {
            liquidity = sqrt(amountA * amountB);
            require(liquidity > 0);
        } else {
            uint256 liquidityA = (amountA * totalLiquidity) / reserveA;
            uint256 liquidityB = (amountB * totalLiquidity) / reserveB;
            liquidity = liquidityA < liquidityB ? liquidityA : liquidityB;
            require(liquidity > 0);
        }

        require(tokenA.transferFrom(msg.sender, address(this), amountA));
        require(tokenB.transferFrom(msg.sender, address(this), amountB));

        liquidityBalance[msg.sender] += liquidity;
        totalLiquidity += liquidity;
        reserveA += amountA;
        reserveB += amountB;

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }

    function removeLiquidity(uint256 liquidity) external returns (uint256 amountA, uint256 amountB) {
        require(liquidity > 0);
        require(liquidityBalance[msg.sender] >= liquidity);

        amountA = (liquidity * reserveA) / totalLiquidity;
        amountB = (liquidity * reserveB) / totalLiquidity;

        require(amountA > 0);
        require(amountB > 0);

        liquidityBalance[msg.sender] -= liquidity;
        totalLiquidity -= liquidity;
        reserveA -= amountA;
        reserveB -= amountB;

        require(tokenA.transfer(msg.sender, amountA));
        require(tokenB.transfer(msg.sender, amountB));

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);
    }

    function swapAForB(uint256 amountAIn) external returns (uint256 amountBOut) {
        require(amountAIn > 0);
        require(reserveA > 0 && reserveB > 0);

        uint256 amountAInWithFee = amountAIn * 997;
        uint256 numerator = amountAInWithFee * reserveB;
        uint256 denominator = (reserveA * 1000) + amountAInWithFee;
        amountBOut = numerator / denominator;

        require(amountBOut > 0);
        require(amountBOut < reserveB);

        require(tokenA.transferFrom(msg.sender, address(this), amountAIn));
        require(tokenB.transfer(msg.sender, amountBOut));

        reserveA += amountAIn;
        reserveB -= amountBOut;



        emit Swap(msg.sender, address(tokenA), amountAIn, amountBOut);
    }

    function swapBForA(uint256 amountBIn) external returns (uint256 amountAOut) {
        require(amountBIn > 0);
        require(reserveA > 0 && reserveB > 0);

        uint256 amountBInWithFee = amountBIn * 997;
        uint256 numerator = amountBInWithFee * reserveA;
        uint256 denominator = (reserveB * 1000) + amountBInWithFee;
        amountAOut = numerator / denominator;

        require(amountAOut > 0);
        require(amountAOut < reserveA);

        require(tokenB.transferFrom(msg.sender, address(this), amountBIn));
        require(tokenA.transfer(msg.sender, amountAOut));

        reserveB += amountBIn;
        reserveA -= amountAOut;

        emit Swap(msg.sender, address(tokenB), amountBIn, amountAOut);
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public pure returns (uint256 amountOut) {
        require(amountIn > 0);
        require(reserveIn > 0 && reserveOut > 0);

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }


    function emergencyWithdraw() external {
        require(msg.sender == address(0));
    }


    function updateReserves() external {
        reserveA = tokenA.balanceOf(address(this));
        reserveB = tokenB.balanceOf(address(this));

    }
}
