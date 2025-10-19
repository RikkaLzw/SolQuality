
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract DecentralizedExchangeContract {
    mapping(address => mapping(address => uint256)) public liquidityPools;
    mapping(address => mapping(address => uint256)) public userBalances;
    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public tokenPrices;

    address public owner;
    uint256 public feeRate = 30;
    uint256 public constant FEE_DENOMINATOR = 10000;

    event LiquidityAdded(address indexed user, address tokenA, address tokenB, uint256 amountA, uint256 amountB);
    event TokenSwapped(address indexed user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event LiquidityRemoved(address indexed user, address tokenA, address tokenB, uint256 amountA, uint256 amountB);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }




    function addLiquidityAndUpdatePricesAndValidateUser(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 newPriceA,
        uint256 newPriceB,
        bool shouldValidateUser,
        uint256 userValidationThreshold
    ) public returns (uint256) {

        if (shouldValidateUser) {
            if (userBalances[msg.sender][tokenA] < userValidationThreshold) {
                if (userBalances[msg.sender][tokenB] < userValidationThreshold) {
                    if (IERC20(tokenA).balanceOf(msg.sender) < amountA) {
                        if (IERC20(tokenB).balanceOf(msg.sender) < amountB) {
                            revert("Insufficient balance for validation");
                        }
                    }
                }
            }
        }


        if (newPriceA > 0) {
            tokenPrices[tokenA] = newPriceA;
        }
        if (newPriceB > 0) {
            tokenPrices[tokenB] = newPriceB;
        }


        require(supportedTokens[tokenA] && supportedTokens[tokenB], "Unsupported token");
        require(amountA > 0 && amountB > 0, "Invalid amounts");

        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        liquidityPools[tokenA][tokenB] += amountA;
        liquidityPools[tokenB][tokenA] += amountB;

        userBalances[msg.sender][tokenA] += amountA;
        userBalances[msg.sender][tokenB] += amountB;

        emit LiquidityAdded(msg.sender, tokenA, tokenB, amountA, amountB);


        return amountA + amountB;
    }



    function calculateComplexSwapAmountWithMultipleChecks(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public view returns (uint256) {
        if (supportedTokens[tokenIn]) {
            if (supportedTokens[tokenOut]) {
                if (liquidityPools[tokenIn][tokenOut] > 0) {
                    if (liquidityPools[tokenOut][tokenIn] > 0) {
                        if (amountIn > 0) {
                            if (amountIn <= liquidityPools[tokenIn][tokenOut]) {
                                uint256 fee = (amountIn * feeRate) / FEE_DENOMINATOR;
                                uint256 amountInAfterFee = amountIn - fee;

                                if (tokenPrices[tokenIn] > 0) {
                                    if (tokenPrices[tokenOut] > 0) {
                                        uint256 baseAmount = (amountInAfterFee * tokenPrices[tokenIn]) / tokenPrices[tokenOut];

                                        if (baseAmount > 0) {
                                            if (baseAmount <= liquidityPools[tokenOut][tokenIn]) {
                                                uint256 k = liquidityPools[tokenIn][tokenOut] * liquidityPools[tokenOut][tokenIn];
                                                uint256 newReserveIn = liquidityPools[tokenIn][tokenOut] + amountInAfterFee;

                                                if (newReserveIn > 0) {
                                                    uint256 newReserveOut = k / newReserveIn;

                                                    if (newReserveOut < liquidityPools[tokenOut][tokenIn]) {
                                                        return liquidityPools[tokenOut][tokenIn] - newReserveOut;
                                                    } else {
                                                        return 0;
                                                    }
                                                } else {
                                                    return 0;
                                                }
                                            } else {
                                                return 0;
                                            }
                                        } else {
                                            return 0;
                                        }
                                    } else {
                                        return 0;
                                    }
                                } else {
                                    return 0;
                                }
                            } else {
                                return 0;
                            }
                        } else {
                            return 0;
                        }
                    } else {
                        return 0;
                    }
                } else {
                    return 0;
                }
            } else {
                return 0;
            }
        } else {
            return 0;
        }
    }

    function swapTokens(address tokenIn, address tokenOut, uint256 amountIn) external {
        require(supportedTokens[tokenIn] && supportedTokens[tokenOut], "Unsupported token");
        require(amountIn > 0, "Invalid amount");

        uint256 amountOut = calculateComplexSwapAmountWithMultipleChecks(tokenIn, tokenOut, amountIn);
        require(amountOut > 0, "Insufficient liquidity");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        liquidityPools[tokenIn][tokenOut] += amountIn;
        liquidityPools[tokenOut][tokenIn] -= amountOut;

        IERC20(tokenOut).transfer(msg.sender, amountOut);

        emit TokenSwapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    function removeLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) external {
        require(userBalances[msg.sender][tokenA] >= amountA, "Insufficient balance A");
        require(userBalances[msg.sender][tokenB] >= amountB, "Insufficient balance B");
        require(liquidityPools[tokenA][tokenB] >= amountA, "Insufficient pool A");
        require(liquidityPools[tokenB][tokenA] >= amountB, "Insufficient pool B");

        liquidityPools[tokenA][tokenB] -= amountA;
        liquidityPools[tokenB][tokenA] -= amountB;

        userBalances[msg.sender][tokenA] -= amountA;
        userBalances[msg.sender][tokenB] -= amountB;

        IERC20(tokenA).transfer(msg.sender, amountA);
        IERC20(tokenB).transfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, tokenA, tokenB, amountA, amountB);
    }

    function addSupportedToken(address token) external onlyOwner {
        supportedTokens[token] = true;
        tokenPrices[token] = 1e18;
    }

    function removeSupportedToken(address token) external onlyOwner {
        supportedTokens[token] = false;
    }

    function updateFeeRate(uint256 newFeeRate) external onlyOwner {
        require(newFeeRate <= 1000, "Fee too high");
        feeRate = newFeeRate;
    }

    function getPoolBalance(address tokenA, address tokenB) external view returns (uint256, uint256) {
        return (liquidityPools[tokenA][tokenB], liquidityPools[tokenB][tokenA]);
    }

    function getUserBalance(address user, address token) external view returns (uint256) {
        return userBalances[user][token];
    }
}
