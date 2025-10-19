
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
    mapping(address => uint256) public fees;

    address public owner;
    uint256 public totalFeeCollected;

    event LiquidityAdded(address indexed user, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);
    event TokenSwapped(address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }




    function addLiquidityAndValidateTokensAndCalculateFeesAndEmitEvents(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        bool shouldValidateTokens,
        uint256 customFeeRate
    ) public returns (bool, uint256, string memory) {

        if (shouldValidateTokens) {
            if (tokenA != address(0)) {
                if (tokenB != address(0)) {
                    if (tokenA != tokenB) {
                        if (amountA > 0) {
                            if (amountB > 0) {
                                if (IERC20(tokenA).balanceOf(msg.sender) >= amountA) {
                                    if (IERC20(tokenB).balanceOf(msg.sender) >= amountB) {
                                        supportedTokens[tokenA] = true;
                                        supportedTokens[tokenB] = true;


                                        require(IERC20(tokenA).transferFrom(msg.sender, address(this), amountA), "Transfer A failed");
                                        require(IERC20(tokenB).transferFrom(msg.sender, address(this), amountB), "Transfer B failed");


                                        liquidity[msg.sender][tokenA] += amountA;
                                        liquidity[msg.sender][tokenB] += amountB;
                                        reserves[tokenA][tokenB] += amountA;
                                        reserves[tokenB][tokenA] += amountB;


                                        uint256 calculatedFee = (amountA * customFeeRate) / 10000;
                                        fees[tokenA] += calculatedFee;
                                        totalFeeCollected += calculatedFee;


                                        emit LiquidityAdded(msg.sender, tokenA, tokenB, amountA, amountB);

                                        return (true, calculatedFee, "Liquidity added successfully");
                                    } else {
                                        return (false, 0, "Insufficient balance B");
                                    }
                                } else {
                                    return (false, 0, "Insufficient balance A");
                                }
                            } else {
                                return (false, 0, "Amount B must be positive");
                            }
                        } else {
                            return (false, 0, "Amount A must be positive");
                        }
                    } else {
                        return (false, 0, "Tokens must be different");
                    }
                } else {
                    return (false, 0, "Token B cannot be zero");
                }
            } else {
                return (false, 0, "Token A cannot be zero");
            }
        } else {

            require(IERC20(tokenA).transferFrom(msg.sender, address(this), amountA), "Transfer A failed");
            require(IERC20(tokenB).transferFrom(msg.sender, address(this), amountB), "Transfer B failed");

            liquidity[msg.sender][tokenA] += amountA;
            liquidity[msg.sender][tokenB] += amountB;
            reserves[tokenA][tokenB] += amountA;
            reserves[tokenB][tokenA] += amountB;

            emit LiquidityAdded(msg.sender, tokenA, tokenB, amountA, amountB);
            return (true, 0, "Liquidity added without validation");
        }
    }


    function calculateSwapAmountAndUpdateReservesAndCollectFees(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public returns (uint256) {
        uint256 reserveIn = reserves[tokenIn][tokenOut];
        uint256 reserveOut = reserves[tokenOut][tokenIn];

        require(reserveIn > 0 && reserveOut > 0, "No liquidity");


        uint256 amountInWithFee = (amountIn * 997) / 1000;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn + amountInWithFee;
        uint256 amountOut = numerator / denominator;


        reserves[tokenIn][tokenOut] += amountIn;
        reserves[tokenOut][tokenIn] -= amountOut;


        uint256 feeAmount = (amountIn * 3) / 1000;
        fees[tokenIn] += feeAmount;
        totalFeeCollected += feeAmount;

        return amountOut;
    }



    function swapTokensWithSlippageProtectionAndBalanceCheckAndEventEmission(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        bool checkBalance,
        bool enableSlippageProtection,
        uint256 maxSlippagePercent
    ) public {

        if (checkBalance) {
            if (IERC20(tokenIn).balanceOf(msg.sender) >= amountIn) {
                if (enableSlippageProtection) {
                    if (maxSlippagePercent <= 10000) {
                        uint256 expectedAmountOut = calculateSwapAmountAndUpdateReservesAndCollectFees(tokenIn, tokenOut, amountIn);

                        if (expectedAmountOut >= minAmountOut) {
                            uint256 slippageAmount = (expectedAmountOut * maxSlippagePercent) / 10000;
                            if (expectedAmountOut >= (minAmountOut + slippageAmount)) {

                                require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "Transfer in failed");
                                require(IERC20(tokenOut).transfer(msg.sender, expectedAmountOut), "Transfer out failed");

                                emit TokenSwapped(msg.sender, tokenIn, tokenOut, amountIn, expectedAmountOut);
                            } else {
                                revert("Slippage too high");
                            }
                        } else {
                            revert("Amount out below minimum");
                        }
                    } else {
                        revert("Invalid slippage percent");
                    }
                } else {

                    uint256 amountOut = calculateSwapAmountAndUpdateReservesAndCollectFees(tokenIn, tokenOut, amountIn);
                    require(amountOut >= minAmountOut, "Amount out below minimum");

                    require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "Transfer in failed");
                    require(IERC20(tokenOut).transfer(msg.sender, amountOut), "Transfer out failed");

                    emit TokenSwapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
                }
            } else {
                revert("Insufficient balance");
            }
        } else {

            uint256 amountOut = calculateSwapAmountAndUpdateReservesAndCollectFees(tokenIn, tokenOut, amountIn);
            require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "Transfer in failed");
            require(IERC20(tokenOut).transfer(msg.sender, amountOut), "Transfer out failed");

            emit TokenSwapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
        }
    }


    function getReserveRatioAndLiquidityInfoAndFeeData(address tokenA, address tokenB)
        public
        view
        returns (uint256, uint256, uint256, uint256, uint256)
    {
        return (
            reserves[tokenA][tokenB],
            reserves[tokenB][tokenA],
            liquidity[msg.sender][tokenA],
            liquidity[msg.sender][tokenB],
            fees[tokenA]
        );
    }

    function removeLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) external {
        require(liquidity[msg.sender][tokenA] >= amountA, "Insufficient liquidity A");
        require(liquidity[msg.sender][tokenB] >= amountB, "Insufficient liquidity B");

        liquidity[msg.sender][tokenA] -= amountA;
        liquidity[msg.sender][tokenB] -= amountB;
        reserves[tokenA][tokenB] -= amountA;
        reserves[tokenB][tokenA] -= amountB;

        require(IERC20(tokenA).transfer(msg.sender, amountA), "Transfer A failed");
        require(IERC20(tokenB).transfer(msg.sender, amountB), "Transfer B failed");
    }

    function withdrawFees(address token) external onlyOwner {
        uint256 feeAmount = fees[token];
        require(feeAmount > 0, "No fees to withdraw");

        fees[token] = 0;
        require(IERC20(token).transfer(owner, feeAmount), "Fee transfer failed");
    }

    function getAmountOut(address tokenIn, address tokenOut, uint256 amountIn)
        external
        view
        returns (uint256)
    {
        uint256 reserveIn = reserves[tokenIn][tokenOut];
        uint256 reserveOut = reserves[tokenOut][tokenIn];

        require(reserveIn > 0 && reserveOut > 0, "No liquidity");

        uint256 amountInWithFee = (amountIn * 997) / 1000;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn + amountInWithFee;

        return numerator / denominator;
    }
}
