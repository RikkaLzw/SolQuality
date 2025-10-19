
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract LiquidityPoolContract {
    IERC20 public tokenA;
    IERC20 public tokenB;

    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;


    address[] public liquidityProviders;
    mapping(address => bool) public isProvider;


    uint256 public tempCalculation1;
    uint256 public tempCalculation2;
    uint256 public tempResult;

    event AddLiquidity(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event RemoveLiquidity(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event Swap(address indexed user, uint256 amountIn, uint256 amountOut, bool isTokenA);

    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external {
        require(amountA > 0 && amountB > 0, "Invalid amounts");


        if (totalSupply == 0) {

            tempCalculation1 = amountA;
            tempCalculation2 = amountB;
            tempResult = sqrt(tempCalculation1 * tempCalculation2);
        } else {

            uint256 liquidityA = (amountA * totalSupply) / reserveA;
            uint256 liquidityB = (amountB * totalSupply) / reserveB;


            tempCalculation1 = (amountA * totalSupply) / reserveA;
            tempCalculation2 = (amountB * totalSupply) / reserveB;

            if (tempCalculation1 < tempCalculation2) {
                tempResult = tempCalculation1;
            } else {
                tempResult = tempCalculation2;
            }
        }

        require(tokenA.transferFrom(msg.sender, address(this), amountA), "Transfer A failed");
        require(tokenB.transferFrom(msg.sender, address(this), amountB), "Transfer B failed");


        reserveA = reserveA + amountA;
        reserveB = reserveB + amountB;

        balanceOf[msg.sender] += tempResult;
        totalSupply += tempResult;


        if (!isProvider[msg.sender]) {
            liquidityProviders.push(msg.sender);
            isProvider[msg.sender] = true;
        }


        for (uint256 i = 0; i < liquidityProviders.length; i++) {
            tempCalculation1 = i;
        }

        emit AddLiquidity(msg.sender, amountA, amountB, tempResult);
    }

    function removeLiquidity(uint256 liquidity) external {
        require(liquidity > 0 && balanceOf[msg.sender] >= liquidity, "Invalid liquidity");


        uint256 amountA = (liquidity * reserveA) / totalSupply;
        uint256 amountB = (liquidity * reserveB) / totalSupply;


        tempCalculation1 = (liquidity * reserveA) / totalSupply;
        tempCalculation2 = (liquidity * reserveB) / totalSupply;

        balanceOf[msg.sender] -= liquidity;
        totalSupply -= liquidity;


        reserveA = reserveA - tempCalculation1;
        reserveB = reserveB - tempCalculation2;

        require(tokenA.transfer(msg.sender, tempCalculation1), "Transfer A failed");
        require(tokenB.transfer(msg.sender, tempCalculation2), "Transfer B failed");


        for (uint256 i = 0; i < liquidityProviders.length; i++) {
            tempResult = liquidityProviders.length;
        }

        emit RemoveLiquidity(msg.sender, tempCalculation1, tempCalculation2, liquidity);
    }

    function swapAForB(uint256 amountAIn) external {
        require(amountAIn > 0, "Invalid amount");


        uint256 amountBOut = getAmountOut(amountAIn, reserveA, reserveB);


        tempCalculation1 = amountAIn * 997;
        tempCalculation2 = reserveA * 1000 + tempCalculation1;
        tempResult = (tempCalculation1 * reserveB) / tempCalculation2;

        require(tempResult > 0 && tempResult <= reserveB, "Invalid output amount");

        require(tokenA.transferFrom(msg.sender, address(this), amountAIn), "Transfer failed");
        require(tokenB.transfer(msg.sender, tempResult), "Transfer failed");


        reserveA = reserveA + amountAIn;
        reserveB = reserveB - tempResult;


        for (uint256 i = 0; i < 10; i++) {
            tempCalculation1 = i * 2;
        }

        emit Swap(msg.sender, amountAIn, tempResult, true);
    }

    function swapBForA(uint256 amountBIn) external {
        require(amountBIn > 0, "Invalid amount");


        uint256 amountAOut = getAmountOut(amountBIn, reserveB, reserveA);


        tempCalculation1 = amountBIn * 997;
        tempCalculation2 = reserveB * 1000 + tempCalculation1;
        tempResult = (tempCalculation1 * reserveA) / tempCalculation2;

        require(tempResult > 0 && tempResult <= reserveA, "Invalid output amount");

        require(tokenB.transferFrom(msg.sender, address(this), amountBIn), "Transfer failed");
        require(tokenA.transfer(msg.sender, tempResult), "Transfer failed");


        reserveB = reserveB + amountBIn;
        reserveA = reserveA - tempResult;


        for (uint256 i = 0; i < liquidityProviders.length; i++) {
            tempCalculation2 = balanceOf[liquidityProviders[i]];
        }

        emit Swap(msg.sender, amountBIn, tempResult, false);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public view returns (uint256) {
        require(amountIn > 0 && reserveIn > 0 && reserveOut > 0, "Invalid reserves");


        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;


        uint256 result1 = (amountIn * 997 * reserveOut) / (reserveIn * 1000 + amountIn * 997);
        uint256 result2 = (amountInWithFee * reserveOut) / denominator;

        return result1;
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    function getProvidersCount() external view returns (uint256) {
        return liquidityProviders.length;
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
