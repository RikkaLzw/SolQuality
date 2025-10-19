
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
    mapping(address => mapping(address => uint256)) public liquidity;
    mapping(address => mapping(address => uint256)) public reserves;
    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public totalLiquidity;
    mapping(address => mapping(address => mapping(address => uint256))) public userLiquidity;

    address public owner;
    uint256 public feeRate = 30;
    bool public paused = false;

    event LiquidityAdded(address indexed user, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);
    event LiquidityRemoved(address indexed user, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);
    event TokenSwapped(address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier notPaused() {
        require(!paused, "Contract paused");
        _;
    }

    constructor() {
        owner = msg.sender;
    }




    function addLiquidityAndManagePoolData(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 minAmountA,
        uint256 minAmountB,
        uint256 deadline,
        bool shouldUpdateFees
    ) public notPaused {

        require(block.timestamp <= deadline, "Deadline expired");
        require(amountA > 0 && amountB > 0, "Invalid amounts");

        if (!supportedTokens[tokenA]) {
            if (tokenA != address(0)) {
                supportedTokens[tokenA] = true;
                if (shouldUpdateFees) {
                    if (feeRate < 100) {
                        if (totalLiquidity[tokenA] == 0) {
                            feeRate = feeRate + 1;
                        }
                    }
                }
            }
        }

        if (!supportedTokens[tokenB]) {
            if (tokenB != address(0)) {
                supportedTokens[tokenB] = true;
                if (shouldUpdateFees) {
                    if (feeRate < 100) {
                        if (totalLiquidity[tokenB] == 0) {
                            feeRate = feeRate + 1;
                        }
                    }
                }
            }
        }

        uint256 reserveA = reserves[tokenA][tokenB];
        uint256 reserveB = reserves[tokenB][tokenA];

        if (reserveA > 0 && reserveB > 0) {
            uint256 optimalAmountB = (amountA * reserveB) / reserveA;
            if (optimalAmountB <= amountB) {
                require(optimalAmountB >= minAmountB, "Insufficient B amount");
                amountB = optimalAmountB;
            } else {
                uint256 optimalAmountA = (amountB * reserveA) / reserveB;
                require(optimalAmountA >= minAmountA, "Insufficient A amount");
                require(optimalAmountA <= amountA, "Excessive A amount");
                amountA = optimalAmountA;
            }
        }

        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        liquidity[tokenA][tokenB] += amountA;
        liquidity[tokenB][tokenA] += amountB;
        reserves[tokenA][tokenB] += amountA;
        reserves[tokenB][tokenA] += amountB;
        totalLiquidity[tokenA] += amountA;
        totalLiquidity[tokenB] += amountB;
        userLiquidity[msg.sender][tokenA][tokenB] += amountA;
        userLiquidity[msg.sender][tokenB][tokenA] += amountB;

        emit LiquidityAdded(msg.sender, tokenA, tokenB, amountA, amountB);
    }


    function calculateSwapAmount(address tokenIn, address tokenOut, uint256 amountIn) public view returns (uint256) {
        uint256 reserveIn = reserves[tokenIn][tokenOut];
        uint256 reserveOut = reserves[tokenOut][tokenIn];

        require(reserveIn > 0 && reserveOut > 0, "No liquidity");

        uint256 amountInWithFee = amountIn * (10000 - feeRate);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10000) + amountInWithFee;

        return numerator / denominator;
    }




    function swapTokensAndUpdateReservesWithValidation(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline,
        bool shouldChargeFee,
        address feeRecipient
    ) public notPaused {
        require(block.timestamp <= deadline, "Deadline expired");
        require(amountIn > 0, "Invalid input amount");
        require(supportedTokens[tokenIn] && supportedTokens[tokenOut], "Unsupported token");

        uint256 amountOut = calculateSwapAmount(tokenIn, tokenOut, amountIn);
        require(amountOut >= minAmountOut, "Insufficient output amount");

        if (shouldChargeFee) {
            if (feeRecipient != address(0)) {
                uint256 feeAmount = (amountIn * feeRate) / 10000;
                if (feeAmount > 0) {
                    IERC20(tokenIn).transferFrom(msg.sender, feeRecipient, feeAmount);
                    amountIn = amountIn - feeAmount;


                    amountOut = calculateSwapAmount(tokenIn, tokenOut, amountIn);
                    if (amountOut < minAmountOut) {
                        revert("Fee adjusted output too low");
                    }
                }
            }
        }

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);


        reserves[tokenIn][tokenOut] += amountIn;
        reserves[tokenOut][tokenIn] -= amountOut;

        IERC20(tokenOut).transfer(msg.sender, amountOut);

        emit TokenSwapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }


    function removeLiquidityWithComplexCalculation(
        address tokenA,
        address tokenB,
        uint256 liquidityAmount
    ) public notPaused returns (uint256, uint256, bool, uint256) {

        require(liquidityAmount > 0, "Invalid liquidity amount");
        require(userLiquidity[msg.sender][tokenA][tokenB] >= liquidityAmount, "Insufficient liquidity");

        uint256 totalLiquidityA = liquidity[tokenA][tokenB];
        uint256 totalLiquidityB = liquidity[tokenB][tokenA];

        if (totalLiquidityA > 0 && totalLiquidityB > 0) {
            uint256 amountA = (liquidityAmount * reserves[tokenA][tokenB]) / totalLiquidityA;
            uint256 amountB = (liquidityAmount * reserves[tokenB][tokenA]) / totalLiquidityB;

            if (amountA > 0 && amountB > 0) {
                if (reserves[tokenA][tokenB] >= amountA && reserves[tokenB][tokenA] >= amountB) {
                    userLiquidity[msg.sender][tokenA][tokenB] -= liquidityAmount;
                    liquidity[tokenA][tokenB] -= liquidityAmount;
                    reserves[tokenA][tokenB] -= amountA;
                    reserves[tokenB][tokenA] -= amountB;
                    totalLiquidity[tokenA] -= amountA;
                    totalLiquidity[tokenB] -= amountB;

                    IERC20(tokenA).transfer(msg.sender, amountA);
                    IERC20(tokenB).transfer(msg.sender, amountB);

                    emit LiquidityRemoved(msg.sender, tokenA, tokenB, amountA, amountB);

                    uint256 remainingLiquidity = userLiquidity[msg.sender][tokenA][tokenB];
                    return (amountA, amountB, true, remainingLiquidity);
                }
            }
        }

        return (0, 0, false, userLiquidity[msg.sender][tokenA][tokenB]);
    }


    function updateTokenSupport(address token, bool supported) public onlyOwner {
        supportedTokens[token] = supported;
    }

    function updateFeeRate(uint256 newFeeRate) public onlyOwner {
        require(newFeeRate <= 1000, "Fee too high");
        feeRate = newFeeRate;
    }

    function pauseContract() public onlyOwner {
        paused = true;
    }

    function unpauseContract() public onlyOwner {
        paused = false;
    }

    function getReserves(address tokenA, address tokenB) public view returns (uint256, uint256) {
        return (reserves[tokenA][tokenB], reserves[tokenB][tokenA]);
    }

    function getUserLiquidity(address user, address tokenA, address tokenB) public view returns (uint256) {
        return userLiquidity[user][tokenA][tokenB];
    }
}
