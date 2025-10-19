
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
    mapping(bytes32 => bool) public processedOrders;

    address public owner;
    uint256 public feeRate = 30;
    uint256 public constant FEE_DENOMINATOR = 10000;

    event LiquidityAdded(address indexed token0, address indexed token1, uint256 amount0, uint256 amount1);
    event TokenSwapped(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event LiquidityRemoved(address indexed token0, address indexed token1, uint256 amount0, uint256 amount1);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }


    function manageTokensAndLiquidityAndFees(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        bool addLiquidity,
        uint256 newFeeRate,
        bool updateFee
    ) public {

        if (!supportedTokens[token0]) {
            supportedTokens[token0] = true;
        }
        if (!supportedTokens[token1]) {
            supportedTokens[token1] = true;
        }


        if (addLiquidity) {
            require(amount0 > 0 && amount1 > 0, "Invalid amounts");
            IERC20(token0).transferFrom(msg.sender, address(this), amount0);
            IERC20(token1).transferFrom(msg.sender, address(this), amount1);
            liquidityPools[token0][token1] += amount0;
            liquidityPools[token1][token0] += amount1;
            emit LiquidityAdded(token0, token1, amount0, amount1);
        }


        if (updateFee && msg.sender == owner) {
            require(newFeeRate <= 1000, "Fee too high");
            feeRate = newFeeRate;
        }
    }


    function complexSwapAndCalculateWithMultipleConditions(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public returns (uint256) {
        require(supportedTokens[tokenIn] && supportedTokens[tokenOut], "Unsupported tokens");
        require(amountIn > 0, "Invalid amount");

        uint256 result;

        if (liquidityPools[tokenIn][tokenOut] > 0) {
            if (liquidityPools[tokenOut][tokenIn] > 0) {
                if (amountIn <= IERC20(tokenIn).balanceOf(msg.sender)) {
                    if (IERC20(tokenIn).allowance(msg.sender, address(this)) >= amountIn) {
                        uint256 fee = (amountIn * feeRate) / FEE_DENOMINATOR;
                        uint256 amountInAfterFee = amountIn - fee;

                        if (amountInAfterFee > 0) {
                            uint256 reserveIn = liquidityPools[tokenIn][tokenOut];
                            uint256 reserveOut = liquidityPools[tokenOut][tokenIn];

                            if (reserveIn > 0 && reserveOut > 0) {
                                uint256 amountOut = (amountInAfterFee * reserveOut) / (reserveIn + amountInAfterFee);

                                if (amountOut > 0 && amountOut <= reserveOut) {
                                    if (IERC20(tokenOut).balanceOf(address(this)) >= amountOut) {
                                        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
                                        IERC20(tokenOut).transfer(msg.sender, amountOut);

                                        liquidityPools[tokenIn][tokenOut] += amountInAfterFee;
                                        liquidityPools[tokenOut][tokenIn] -= amountOut;

                                        result = amountOut;
                                        emit TokenSwapped(tokenIn, tokenOut, amountIn, amountOut);
                                    } else {
                                        result = 0;
                                    }
                                } else {
                                    result = 0;
                                }
                            } else {
                                result = 0;
                            }
                        } else {
                            result = 0;
                        }
                    } else {
                        result = 0;
                    }
                } else {
                    result = 0;
                }
            } else {
                result = 0;
            }
        } else {
            result = 0;
        }

        return result;
    }


    function calculateSwapAmount(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        require(amountIn > 0, "Invalid input amount");
        require(reserveIn > 0 && reserveOut > 0, "Invalid reserves");

        uint256 amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
        return amountOut;
    }


    function validateTokenPair(address token0, address token1) public view returns (bool) {
        return supportedTokens[token0] && supportedTokens[token1] && token0 != token1;
    }


    function removeLiquidityWithComplexValidation(
        address token0,
        address token1,
        uint256 liquidity0,
        uint256 liquidity1,
        uint256 minAmount0,
        uint256 minAmount1,
        address recipient,
        uint256 deadline
    ) public {
        require(block.timestamp <= deadline, "Expired");
        require(recipient != address(0), "Invalid recipient");

        if (validateTokenPair(token0, token1)) {
            if (liquidityPools[token0][token1] >= liquidity0) {
                if (liquidityPools[token1][token0] >= liquidity1) {
                    if (liquidity0 >= minAmount0) {
                        if (liquidity1 >= minAmount1) {
                            if (IERC20(token0).balanceOf(address(this)) >= liquidity0) {
                                if (IERC20(token1).balanceOf(address(this)) >= liquidity1) {
                                    liquidityPools[token0][token1] -= liquidity0;
                                    liquidityPools[token1][token0] -= liquidity1;

                                    IERC20(token0).transfer(recipient, liquidity0);
                                    IERC20(token1).transfer(recipient, liquidity1);

                                    emit LiquidityRemoved(token0, token1, liquidity0, liquidity1);
                                } else {
                                    revert("Insufficient token1 balance");
                                }
                            } else {
                                revert("Insufficient token0 balance");
                            }
                        } else {
                            revert("Amount1 below minimum");
                        }
                    } else {
                        revert("Amount0 below minimum");
                    }
                } else {
                    revert("Insufficient liquidity1");
                }
            } else {
                revert("Insufficient liquidity0");
            }
        } else {
            revert("Invalid token pair");
        }
    }

    function getReserves(address token0, address token1) public view returns (uint256, uint256) {
        return (liquidityPools[token0][token1], liquidityPools[token1][token0]);
    }

    function addSupportedToken(address token) public onlyOwner {
        supportedTokens[token] = true;
    }

    function removeSupportedToken(address token) public onlyOwner {
        supportedTokens[token] = false;
    }

    function updateFeeRate(uint256 newFeeRate) public onlyOwner {
        require(newFeeRate <= 1000, "Fee rate too high");
        feeRate = newFeeRate;
    }

    function emergencyWithdraw(address token, uint256 amount) public onlyOwner {
        IERC20(token).transfer(owner, amount);
    }
}
