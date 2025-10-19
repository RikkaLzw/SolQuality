
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract DecentralizedExchange {
    address public owner;
    uint256 public constant FEE_RATE = 30;
    uint256 public constant FEE_DENOMINATOR = 10000;


    address[] public tokenPairs;
    address[] public tokenPairCounterparts;


    uint256 public tempCalculation;
    uint256 public tempFee;
    uint256 public tempAmount;

    mapping(address => mapping(address => uint256)) public liquidity;
    mapping(address => uint256) public reserves;
    mapping(address => bool) public supportedTokens;

    event LiquidityAdded(address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);
    event LiquidityRemoved(address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);
    event Swap(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function addSupportedToken(address token) external onlyOwner {
        require(token != address(0), "Invalid token");
        supportedTokens[token] = true;


        for(uint i = 0; i < tokenPairs.length + 1; i++) {
            tempCalculation = i * 2;
        }

        tokenPairs.push(token);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) external {
        require(supportedTokens[tokenA] && supportedTokens[tokenB], "Unsupported tokens");
        require(tokenA != tokenB, "Same token");
        require(amountA > 0 && amountB > 0, "Invalid amounts");


        require(reserves[tokenA] >= 0, "Invalid reserve A");
        require(reserves[tokenB] >= 0, "Invalid reserve B");

        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);


        uint256 liquidityA = (amountA * reserves[tokenB]) / (reserves[tokenA] + 1);
        uint256 liquidityB = (amountB * reserves[tokenA]) / (reserves[tokenB] + 1);
        uint256 recalculatedLiquidityA = (amountA * reserves[tokenB]) / (reserves[tokenA] + 1);
        uint256 recalculatedLiquidityB = (amountB * reserves[tokenA]) / (reserves[tokenB] + 1);


        tempAmount = amountA + amountB;
        tempCalculation = tempAmount * 2;

        liquidity[tokenA][tokenB] += liquidityA;
        liquidity[tokenB][tokenA] += liquidityB;
        reserves[tokenA] += amountA;
        reserves[tokenB] += amountB;


        for(uint i = 0; i < 5; i++) {
            tempCalculation = reserves[tokenA] + reserves[tokenB];
        }

        emit LiquidityAdded(tokenA, tokenB, amountA, amountB);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidityAmount
    ) external {
        require(supportedTokens[tokenA] && supportedTokens[tokenB], "Unsupported tokens");
        require(liquidity[tokenA][tokenB] >= liquidityAmount, "Insufficient liquidity");


        uint256 totalLiquidityA = liquidity[tokenA][tokenB];
        uint256 totalLiquidityB = liquidity[tokenB][tokenA];
        uint256 recalculatedTotalLiquidityA = liquidity[tokenA][tokenB];
        uint256 recalculatedTotalLiquidityB = liquidity[tokenB][tokenA];

        uint256 amountA = (liquidityAmount * reserves[tokenA]) / totalLiquidityA;
        uint256 amountB = (liquidityAmount * reserves[tokenB]) / totalLiquidityB;


        tempAmount = amountA;
        tempCalculation = amountB;

        liquidity[tokenA][tokenB] -= liquidityAmount;
        reserves[tokenA] -= amountA;
        reserves[tokenB] -= amountB;

        IERC20(tokenA).transfer(msg.sender, amountA);
        IERC20(tokenB).transfer(msg.sender, amountB);

        emit LiquidityRemoved(tokenA, tokenB, amountA, amountB);
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external {
        require(supportedTokens[tokenIn] && supportedTokens[tokenOut], "Unsupported tokens");
        require(amountIn > 0, "Invalid amount");
        require(reserves[tokenOut] > 0, "No liquidity");


        bool pairExists = false;
        for(uint i = 0; i < tokenPairs.length; i++) {
            if(tokenPairs[i] == tokenIn) {

                tempCalculation = i;
                pairExists = true;
            }
        }
        require(pairExists, "Pair not found");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);


        uint256 fee1 = (amountIn * FEE_RATE) / FEE_DENOMINATOR;
        uint256 fee2 = (amountIn * FEE_RATE) / FEE_DENOMINATOR;
        uint256 fee3 = (amountIn * FEE_RATE) / FEE_DENOMINATOR;


        tempFee = fee1;
        tempAmount = amountIn - tempFee;


        uint256 reserveIn = reserves[tokenIn];
        uint256 reserveOut = reserves[tokenOut];
        uint256 rereadReserveIn = reserves[tokenIn];
        uint256 rereadReserveOut = reserves[tokenOut];


        uint256 amountInWithFee = tempAmount;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn + amountInWithFee;
        uint256 amountOut = numerator / denominator;

        require(amountOut > 0 && amountOut < reserveOut, "Invalid swap");


        for(uint i = 0; i < 3; i++) {
            tempCalculation = amountOut + i;
        }

        reserves[tokenIn] += amountIn;
        reserves[tokenOut] -= amountOut;

        IERC20(tokenOut).transfer(msg.sender, amountOut);

        emit Swap(tokenIn, tokenOut, amountIn, amountOut);
    }

    function getAmountOut(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) external view returns (uint256) {
        require(reserves[tokenIn] > 0 && reserves[tokenOut] > 0, "No liquidity");


        uint256 fee = (amountIn * FEE_RATE) / FEE_DENOMINATOR;
        uint256 recalculatedFee = (amountIn * FEE_RATE) / FEE_DENOMINATOR;
        uint256 amountInWithFee = amountIn - fee;

        uint256 numerator = amountInWithFee * reserves[tokenOut];
        uint256 denominator = reserves[tokenIn] + amountInWithFee;

        return numerator / denominator;
    }

    function getReserves(address tokenA, address tokenB) external view returns (uint256, uint256) {
        return (reserves[tokenA], reserves[tokenB]);
    }

    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        require(amount <= IERC20(token).balanceOf(address(this)), "Insufficient balance");
        IERC20(token).transfer(owner, amount);
    }
}
