
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract DecentralizedExchangeContract {
    mapping(address => mapping(address => uint256)) public liquidity;
    mapping(address => mapping(address => uint256)) public reserves;
    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public totalSupply;
    mapping(address => mapping(address => uint256)) public balances;

    address public owner;
    uint256 public feeRate = 3;
    uint256 public constant FEE_DENOMINATOR = 1000;

    event LiquidityAdded(address indexed provider, address tokenA, address tokenB, uint256 amountA, uint256 amountB);
    event TokensSwapped(address indexed user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event LiquidityRemoved(address indexed provider, address tokenA, address tokenB, uint256 amountA, uint256 amountB);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }


    function addLiquidityAndSwapAndUpdateFeeAndCheckBalance(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 swapAmount,
        uint256 newFeeRate,
        address checkBalanceToken
    ) public {

        if (amountA > 0 && amountB > 0) {
            IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
            IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);
            liquidity[msg.sender][tokenA] += amountA;
            liquidity[msg.sender][tokenB] += amountB;
            reserves[tokenA][tokenB] += amountA;
            reserves[tokenB][tokenA] += amountB;
            emit LiquidityAdded(msg.sender, tokenA, tokenB, amountA, amountB);
        }


        if (swapAmount > 0) {
            uint256 outputAmount = getAmountOut(swapAmount, reserves[tokenA][tokenB], reserves[tokenB][tokenA]);
            IERC20(tokenA).transferFrom(msg.sender, address(this), swapAmount);
            IERC20(tokenB).transfer(msg.sender, outputAmount);
            reserves[tokenA][tokenB] += swapAmount;
            reserves[tokenB][tokenA] -= outputAmount;
            emit TokensSwapped(msg.sender, tokenA, tokenB, swapAmount, outputAmount);
        }


        if (newFeeRate > 0 && msg.sender == owner) {
            feeRate = newFeeRate;
        }


        if (checkBalanceToken != address(0)) {
            balances[msg.sender][checkBalanceToken] = IERC20(checkBalanceToken).balanceOf(msg.sender);
        }
    }


    function complexSwapOperation(address tokenIn, address tokenOut, uint256 amountIn) public {
        require(supportedTokens[tokenIn] && supportedTokens[tokenOut], "Token not supported");

        uint256 amountOut = getAmountOut(amountIn, reserves[tokenIn][tokenOut], reserves[tokenOut][tokenIn]);

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).transfer(msg.sender, amountOut);

        reserves[tokenIn][tokenOut] += amountIn;
        reserves[tokenOut][tokenIn] -= amountOut;

        emit TokensSwapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }


    function calculateFee(uint256 amount) public pure returns (uint256) {
        return (amount * 3) / 1000;
    }

    function updateReserves(address tokenA, address tokenB, uint256 reserveA, uint256 reserveB) public {
        reserves[tokenA][tokenB] = reserveA;
        reserves[tokenB][tokenA] = reserveB;
    }


    function removeLiquidityWithComplexLogic(address tokenA, address tokenB, uint256 liquidityAmount) public {
        require(liquidity[msg.sender][tokenA] >= liquidityAmount, "Insufficient liquidity");

        if (reserves[tokenA][tokenB] > 0) {
            if (reserves[tokenB][tokenA] > 0) {
                uint256 totalLiquidityA = reserves[tokenA][tokenB];
                uint256 totalLiquidityB = reserves[tokenB][tokenA];

                if (totalLiquidityA > 0 && totalLiquidityB > 0) {
                    uint256 amountA = (liquidityAmount * totalLiquidityA) / totalSupply[tokenA];
                    uint256 amountB = (liquidityAmount * totalLiquidityB) / totalSupply[tokenB];

                    if (amountA > 0) {
                        if (amountB > 0) {
                            if (IERC20(tokenA).balanceOf(address(this)) >= amountA) {
                                if (IERC20(tokenB).balanceOf(address(this)) >= amountB) {
                                    liquidity[msg.sender][tokenA] -= liquidityAmount;
                                    reserves[tokenA][tokenB] -= amountA;
                                    reserves[tokenB][tokenA] -= amountB;

                                    if (amountA > 0) {
                                        IERC20(tokenA).transfer(msg.sender, amountA);
                                    }
                                    if (amountB > 0) {
                                        IERC20(tokenB).transfer(msg.sender, amountB);
                                    }

                                    emit LiquidityRemoved(msg.sender, tokenA, tokenB, amountA, amountB);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function addSupportedToken(address token) external onlyOwner {
        supportedTokens[token] = true;
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal view returns (uint256) {
        require(amountIn > 0, "Insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - feeRate);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;

        return numerator / denominator;
    }

    function getLiquidityBalance(address provider, address token) external view returns (uint256) {
        return liquidity[provider][token];
    }

    function getReserves(address tokenA, address tokenB) external view returns (uint256, uint256) {
        return (reserves[tokenA][tokenB], reserves[tokenB][tokenA]);
    }
}
