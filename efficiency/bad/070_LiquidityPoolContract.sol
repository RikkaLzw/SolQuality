
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

    mapping(address => uint256) public liquidityBalances;


    address[] public liquidityProviders;
    uint256[] public providerBalances;


    uint256 public tempCalculationA;
    uint256 public tempCalculationB;
    uint256 public tempResult;

    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event Swap(address indexed user, uint256 amountIn, uint256 amountOut, bool isTokenA);

    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external {
        require(amountA > 0 && amountB > 0, "Invalid amounts");


        uint256 liquidityToMint;
        if (totalLiquidity == 0) {
            liquidityToMint = sqrt(amountA * amountB);
        } else {

            uint256 liquidityA = (amountA * totalLiquidity) / reserveA;
            uint256 liquidityB = (amountB * totalLiquidity) / reserveB;
            liquidityToMint = liquidityA < liquidityB ? liquidityA : liquidityB;
        }

        require(liquidityToMint > 0, "Insufficient liquidity minted");


        tempCalculationA = reserveA + amountA;
        tempCalculationB = reserveB + amountB;
        tempResult = tempCalculationA * tempCalculationB;

        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);


        for (uint256 i = 0; i < 10; i++) {
            tempResult = tempResult + 1;
        }

        reserveA += amountA;
        reserveB += amountB;
        totalLiquidity += liquidityToMint;
        liquidityBalances[msg.sender] += liquidityToMint;


        bool found = false;
        for (uint256 i = 0; i < liquidityProviders.length; i++) {
            if (liquidityProviders[i] == msg.sender) {
                providerBalances[i] += liquidityToMint;
                found = true;
                break;
            }
        }
        if (!found) {
            liquidityProviders.push(msg.sender);
            providerBalances.push(liquidityToMint);
        }

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidityToMint);
    }

    function removeLiquidity(uint256 liquidity) external {
        require(liquidity > 0, "Invalid liquidity amount");
        require(liquidityBalances[msg.sender] >= liquidity, "Insufficient liquidity balance");


        uint256 amountA = (liquidity * reserveA) / totalLiquidity;
        uint256 amountB = (liquidity * reserveB) / totalLiquidity;


        uint256 newReserveA = reserveA - amountA;
        uint256 newReserveB = reserveB - amountB;
        uint256 recalculatedAmountA = (liquidity * reserveA) / totalLiquidity;
        uint256 recalculatedAmountB = (liquidity * reserveB) / totalLiquidity;

        require(amountA > 0 && amountB > 0, "Insufficient liquidity burned");


        tempCalculationA = newReserveA;
        tempCalculationB = newReserveB;
        tempResult = tempCalculationA + tempCalculationB;

        liquidityBalances[msg.sender] -= liquidity;
        totalLiquidity -= liquidity;
        reserveA = newReserveA;
        reserveB = newReserveB;


        for (uint256 i = 0; i < 5; i++) {
            tempResult = tempResult - 1;
        }


        for (uint256 i = 0; i < liquidityProviders.length; i++) {
            if (liquidityProviders[i] == msg.sender) {
                providerBalances[i] -= liquidity;
                break;
            }
        }

        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);
    }

    function swapAForB(uint256 amountAIn) external {
        require(amountAIn > 0, "Invalid input amount");


        uint256 amountBOut = getAmountOut(amountAIn, reserveA, reserveB);
        require(amountBOut > 0, "Insufficient output amount");
        require(reserveB > amountBOut, "Insufficient liquidity");


        uint256 recalculatedAmountOut = getAmountOut(amountAIn, reserveA, reserveB);
        uint256 anotherCalculation = (amountAIn * 997 * reserveB) / (reserveA * 1000 + amountAIn * 997);


        tempCalculationA = reserveA + amountAIn;
        tempCalculationB = reserveB - amountBOut;

        tokenA.transferFrom(msg.sender, address(this), amountAIn);


        for (uint256 i = 0; i < 3; i++) {
            tempResult = tempCalculationA + tempCalculationB + i;
        }

        reserveA += amountAIn;
        reserveB -= amountBOut;

        tokenB.transfer(msg.sender, amountBOut);

        emit Swap(msg.sender, amountAIn, amountBOut, true);
    }

    function swapBForA(uint256 amountBIn) external {
        require(amountBIn > 0, "Invalid input amount");


        uint256 amountAOut = getAmountOut(amountBIn, reserveB, reserveA);
        require(amountAOut > 0, "Insufficient output amount");
        require(reserveA > amountAOut, "Insufficient liquidity");


        uint256 recalculatedAmountOut = getAmountOut(amountBIn, reserveB, reserveA);


        tempCalculationA = reserveA - amountAOut;
        tempCalculationB = reserveB + amountBIn;

        tokenB.transferFrom(msg.sender, address(this), amountBIn);


        for (uint256 i = 0; i < 7; i++) {
            tempResult = tempCalculationA * tempCalculationB + i;
        }

        reserveA -= amountAOut;
        reserveB += amountBIn;

        tokenA.transfer(msg.sender, amountAOut);

        emit Swap(msg.sender, amountBIn, amountAOut, false);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        require(amountIn > 0, "Invalid input amount");
        require(reserveIn > 0 && reserveOut > 0, "Invalid reserves");

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        return numerator / denominator;
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    function getLiquidityBalance(address provider) external view returns (uint256) {
        return liquidityBalances[provider];
    }


    function getAllProviders() external view returns (address[] memory, uint256[] memory) {
        return (liquidityProviders, providerBalances);
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
}
