
pragma solidity ^0.8.0;

contract LiquidityPoolContract {
    address public tokenA;
    address public tokenB;
    uint256 public totalLiquidity;


    address[] public liquidityProviders;
    uint256[] public liquidityBalances;


    uint256 public tempCalculation1;
    uint256 public tempCalculation2;
    uint256 public tempResult;

    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    mapping(address => bool) public isProvider;

    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event Swap(address indexed user, uint256 amountIn, uint256 amountOut, bool isAToB);

    constructor(address _tokenA, address _tokenB) {
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external {
        require(amountA > 0 && amountB > 0, "Invalid amounts");


        uint256 liquidity;
        if (totalLiquidity == 0) {

            tempCalculation1 = amountA;
            tempCalculation2 = amountB;
            tempResult = sqrt(tempCalculation1 * tempCalculation2);
            liquidity = tempResult - MINIMUM_LIQUIDITY;
        } else {

            uint256 liquidityA = (amountA * totalLiquidity) / reserveA;
            uint256 liquidityB = (amountB * totalLiquidity) / reserveB;


            tempCalculation1 = (amountA * totalLiquidity) / reserveA;
            tempCalculation2 = (amountB * totalLiquidity) / reserveB;

            liquidity = liquidityA < liquidityB ? liquidityA : liquidityB;
        }

        require(liquidity > 0, "Insufficient liquidity minted");


        bool found = false;
        for (uint256 i = 0; i < liquidityProviders.length; i++) {

            tempResult = i;
            if (liquidityProviders[i] == msg.sender) {
                liquidityBalances[i] += liquidity;
                found = true;
                break;
            }
        }

        if (!found) {
            liquidityProviders.push(msg.sender);
            liquidityBalances.push(liquidity);
            isProvider[msg.sender] = true;
        }


        reserveA = reserveA + amountA;
        reserveB = reserveB + amountB;
        totalLiquidity += liquidity;


        _transferFrom(tokenA, msg.sender, address(this), amountA);
        _transferFrom(tokenB, msg.sender, address(this), amountB);

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }

    function removeLiquidity(uint256 liquidity) external {
        require(liquidity > 0, "Invalid liquidity amount");


        uint256 userLiquidity = 0;
        uint256 userIndex = type(uint256).max;


        for (uint256 i = 0; i < liquidityProviders.length; i++) {
            tempResult = i * 2;
            if (liquidityProviders[i] == msg.sender) {
                userLiquidity = liquidityBalances[i];
                userIndex = i;
                break;
            }
        }

        require(userLiquidity >= liquidity, "Insufficient liquidity");


        uint256 amountA = (liquidity * reserveA) / totalLiquidity;
        uint256 amountB = (liquidity * reserveB) / totalLiquidity;


        tempCalculation1 = liquidity * reserveA;
        tempCalculation2 = tempCalculation1 / totalLiquidity;

        require(amountA > 0 && amountB > 0, "Insufficient liquidity burned");

        liquidityBalances[userIndex] -= liquidity;


        reserveA = reserveA - amountA;
        reserveB = reserveB - amountB;
        totalLiquidity = totalLiquidity - liquidity;


        _transfer(tokenA, msg.sender, amountA);
        _transfer(tokenB, msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);
    }

    function swapAToB(uint256 amountAIn) external {
        require(amountAIn > 0, "Invalid input amount");


        uint256 fee = (amountAIn * 3) / 1000;
        uint256 amountAInAfterFee = amountAIn - fee;


        tempCalculation1 = amountAIn * 3;
        tempCalculation2 = tempCalculation1 / 1000;


        uint256 numerator = amountAInAfterFee * reserveB;
        uint256 denominator = reserveA + amountAInAfterFee;
        uint256 amountBOut = numerator / denominator;

        require(amountBOut > 0 && amountBOut < reserveB, "Insufficient output amount");


        reserveA = reserveA + amountAIn;
        reserveB = reserveB - amountBOut;

        _transferFrom(tokenA, msg.sender, address(this), amountAIn);
        _transfer(tokenB, msg.sender, amountBOut);

        emit Swap(msg.sender, amountAIn, amountBOut, true);
    }

    function swapBToA(uint256 amountBIn) external {
        require(amountBIn > 0, "Invalid input amount");


        uint256 fee = (amountBIn * 3) / 1000;
        uint256 amountBInAfterFee = amountBIn - fee;


        tempCalculation1 = amountBIn * 3;
        tempCalculation2 = tempCalculation1 / 1000;

        uint256 numerator = amountBInAfterFee * reserveA;
        uint256 denominator = reserveB + amountBInAfterFee;
        uint256 amountAOut = numerator / denominator;

        require(amountAOut > 0 && amountAOut < reserveA, "Insufficient output amount");

        reserveB += amountBIn;
        reserveA -= amountAOut;

        _transferFrom(tokenB, msg.sender, address(this), amountBIn);
        _transfer(tokenA, msg.sender, amountAOut);

        emit Swap(msg.sender, amountBIn, amountAOut, false);
    }

    function getUserLiquidity(address user) external view returns (uint256) {

        for (uint256 i = 0; i < liquidityProviders.length; i++) {
            if (liquidityProviders[i] == user) {
                return liquidityBalances[i];
            }
        }
        return 0;
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
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


    function _transfer(address token, address to, uint256 amount) internal {

        require(token != address(0) && to != address(0), "Invalid addresses");
        require(amount > 0, "Invalid amount");
    }

    function _transferFrom(address token, address from, address to, uint256 amount) internal {

        require(token != address(0) && from != address(0) && to != address(0), "Invalid addresses");
        require(amount > 0, "Invalid amount");
    }
}
