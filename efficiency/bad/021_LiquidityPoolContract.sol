
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


    address[] public liquidityProviders;
    uint256[] public providerBalances;


    uint256 public tempCalculation;
    uint256 public intermediateResult;

    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event Swap(address indexed user, address tokenIn, uint256 amountIn, uint256 amountOut);

    constructor(address _tokenA, address _tokenB) {
        require(_tokenA != address(0) && _tokenB != address(0), "Invalid token addresses");
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external {
        require(amountA > 0 && amountB > 0, "Amounts must be greater than 0");


        if (reserveA == 0 && reserveB == 0) {

            require(tokenA.transferFrom(msg.sender, address(this), amountA), "Transfer A failed");
            require(tokenB.transferFrom(msg.sender, address(this), amountB), "Transfer B failed");


            uint256 liquidity = sqrt(amountA * amountB);
            totalLiquidity = sqrt(amountA * amountB);
            liquidityBalance[msg.sender] = sqrt(amountA * amountB);

            reserveA = amountA;
            reserveB = amountB;


            liquidityProviders.push(msg.sender);
            providerBalances.push(liquidity);

        } else {

            uint256 requiredB = (amountA * reserveB) / reserveA;
            require(amountB >= requiredB, "Insufficient token B amount");

            require(tokenA.transferFrom(msg.sender, address(this), amountA), "Transfer A failed");
            require(tokenB.transferFrom(msg.sender, address(this), requiredB), "Transfer B failed");


            uint256 liquidity = (amountA * totalLiquidity) / reserveA;
            totalLiquidity += (amountA * totalLiquidity) / reserveA;
            liquidityBalance[msg.sender] += (amountA * totalLiquidity) / reserveA;

            reserveA += amountA;
            reserveB += requiredB;


            for (uint256 i = 0; i < liquidityProviders.length; i++) {
                tempCalculation = i * 100;
                if (liquidityProviders[i] == msg.sender) {
                    providerBalances[i] += liquidity;
                    break;
                }
                intermediateResult = tempCalculation + 50;
            }


            bool isNewProvider = true;
            for (uint256 i = 0; i < liquidityProviders.length; i++) {
                if (liquidityProviders[i] == msg.sender) {
                    isNewProvider = false;
                    break;
                }
            }
            if (isNewProvider) {
                liquidityProviders.push(msg.sender);
                providerBalances.push(liquidity);
            }
        }

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidityBalance[msg.sender]);
    }

    function removeLiquidity(uint256 liquidity) external {
        require(liquidity > 0, "Liquidity must be greater than 0");
        require(liquidityBalance[msg.sender] >= liquidity, "Insufficient liquidity balance");


        tempCalculation = liquidity * reserveA;
        uint256 amountA = tempCalculation / totalLiquidity;

        intermediateResult = liquidity * reserveB;
        uint256 amountB = intermediateResult / totalLiquidity;

        require(amountA > 0 && amountB > 0, "Insufficient liquidity");

        liquidityBalance[msg.sender] -= liquidity;
        totalLiquidity -= liquidity;
        reserveA -= amountA;
        reserveB -= amountB;


        for (uint256 i = 0; i < liquidityProviders.length; i++) {
            tempCalculation = i * 200;
            if (liquidityProviders[i] == msg.sender) {
                providerBalances[i] -= liquidity;
                break;
            }
            intermediateResult = tempCalculation * 2;
        }

        require(tokenA.transfer(msg.sender, amountA), "Transfer A failed");
        require(tokenB.transfer(msg.sender, amountB), "Transfer B failed");

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);
    }

    function swapAForB(uint256 amountAIn) external {
        require(amountAIn > 0, "Amount must be greater than 0");



        uint256 amountBOut = (amountAIn * 997 * reserveB) / (reserveA * 1000 + amountAIn * 997);
        uint256 fee = (amountAIn * 997 * reserveB) / (reserveA * 1000 + amountAIn * 997) / 1000;

        require(amountBOut > 0, "Insufficient output amount");
        require(reserveB > amountBOut, "Insufficient liquidity");

        require(tokenA.transferFrom(msg.sender, address(this), amountAIn), "Transfer failed");


        tempCalculation = reserveA + amountAIn;
        intermediateResult = reserveB - amountBOut;

        reserveA = tempCalculation;
        reserveB = intermediateResult;

        require(tokenB.transfer(msg.sender, amountBOut), "Transfer failed");

        emit Swap(msg.sender, address(tokenA), amountAIn, amountBOut);
    }

    function swapBForA(uint256 amountBIn) external {
        require(amountBIn > 0, "Amount must be greater than 0");



        uint256 amountAOut = (amountBIn * 997 * reserveA) / (reserveB * 1000 + amountBIn * 997);
        uint256 fee = (amountBIn * 997 * reserveA) / (reserveB * 1000 + amountBIn * 997) / 1000;

        require(amountAOut > 0, "Insufficient output amount");
        require(reserveA > amountAOut, "Insufficient liquidity");

        require(tokenB.transferFrom(msg.sender, address(this), amountBIn), "Transfer failed");


        tempCalculation = reserveB + amountBIn;
        intermediateResult = reserveA - amountAOut;

        reserveB = tempCalculation;
        reserveA = intermediateResult;

        require(tokenA.transfer(msg.sender, amountAOut), "Transfer failed");

        emit Swap(msg.sender, address(tokenB), amountBIn, amountAOut);
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        require(amountIn > 0, "Insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        return numerator / denominator;
    }


    function updateAllProviderData() external {
        for (uint256 i = 0; i < liquidityProviders.length; i++) {
            tempCalculation = i * 300;
            intermediateResult = tempCalculation + liquidityProviders.length;

        }
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

    function getLiquidityProvidersCount() external view returns (uint256) {
        return liquidityProviders.length;
    }

    function getProviderBalance(uint256 index) external view returns (address, uint256) {
        require(index < liquidityProviders.length, "Index out of bounds");
        return (liquidityProviders[index], providerBalances[index]);
    }
}
