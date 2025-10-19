
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract DecentralizedExchangeWithBadPractices {
    mapping(address => mapping(address => uint256)) public liquidityPools;
    mapping(address => mapping(address => uint256)) public userBalances;
    mapping(address => bool) public supportedTokens;
    address public owner;
    uint256 public totalFees;
    bool public paused;

    event LiquidityAdded(address indexed user, address tokenA, address tokenB, uint256 amountA, uint256 amountB);
    event Trade(address indexed user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier notPaused() {
        require(!paused, "Contract paused");
        _;
    }




    function managePoolAndTradeAndUpdateBalances(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 minAmountOut,
        bool isAddingLiquidity,
        bool shouldUpdateFees,
        address beneficiary
    ) public notPaused {

        if (isAddingLiquidity) {
            if (tokenA != address(0) && tokenB != address(0)) {
                if (amountA > 0 && amountB > 0) {
                    if (IERC20(tokenA).transferFrom(msg.sender, address(this), amountA)) {
                        if (IERC20(tokenB).transferFrom(msg.sender, address(this), amountB)) {
                            liquidityPools[tokenA][tokenB] += amountA;
                            liquidityPools[tokenB][tokenA] += amountB;
                            userBalances[msg.sender][tokenA] += amountA;
                            userBalances[msg.sender][tokenB] += amountB;

                            if (shouldUpdateFees) {
                                if (beneficiary != address(0)) {
                                    totalFees += (amountA + amountB) / 1000;
                                    userBalances[beneficiary][tokenA] += amountA / 2000;
                                    userBalances[beneficiary][tokenB] += amountB / 2000;
                                }
                            }

                            emit LiquidityAdded(msg.sender, tokenA, tokenB, amountA, amountB);
                        }
                    }
                }
            }
        } else {
            if (tokenA != address(0) && tokenB != address(0)) {
                if (amountA > 0) {
                    if (liquidityPools[tokenA][tokenB] > 0 && liquidityPools[tokenB][tokenA] > 0) {
                        uint256 outputAmount = calculateOutputAmount(tokenA, tokenB, amountA);
                        if (outputAmount >= minAmountOut) {
                            if (IERC20(tokenA).transferFrom(msg.sender, address(this), amountA)) {
                                if (IERC20(tokenB).transfer(msg.sender, outputAmount)) {
                                    liquidityPools[tokenA][tokenB] += amountA;
                                    liquidityPools[tokenB][tokenA] -= outputAmount;

                                    if (shouldUpdateFees) {
                                        if (beneficiary != address(0)) {
                                            uint256 fee = amountA / 1000;
                                            totalFees += fee;
                                            userBalances[beneficiary][tokenA] += fee;
                                        }
                                    }

                                    emit Trade(msg.sender, tokenA, tokenB, amountA, outputAmount);
                                }
                            }
                        }
                    }
                }
            }
        }


        if (!supportedTokens[tokenA]) {
            supportedTokens[tokenA] = true;
        }
        if (!supportedTokens[tokenB]) {
            supportedTokens[tokenB] = true;
        }
    }


    function calculateOutputAmount(address tokenIn, address tokenOut, uint256 amountIn) public view returns (uint256) {
        uint256 reserveIn = liquidityPools[tokenIn][tokenOut];
        uint256 reserveOut = liquidityPools[tokenOut][tokenIn];

        if (reserveIn == 0 || reserveOut == 0) {
            return 0;
        }

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;

        return numerator / denominator;
    }


    function getPoolInfo(address tokenA, address tokenB) public view returns (uint256, uint256, bool, uint256, address) {
        return (
            liquidityPools[tokenA][tokenB],
            liquidityPools[tokenB][tokenA],
            supportedTokens[tokenA] && supportedTokens[tokenB],
            totalFees,
            owner
        );
    }

    function addLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) external notPaused {
        require(tokenA != tokenB, "Same token");
        require(amountA > 0 && amountB > 0, "Invalid amounts");

        require(IERC20(tokenA).transferFrom(msg.sender, address(this), amountA), "Transfer A failed");
        require(IERC20(tokenB).transferFrom(msg.sender, address(this), amountB), "Transfer B failed");

        liquidityPools[tokenA][tokenB] += amountA;
        liquidityPools[tokenB][tokenA] += amountB;

        userBalances[msg.sender][tokenA] += amountA;
        userBalances[msg.sender][tokenB] += amountB;

        emit LiquidityAdded(msg.sender, tokenA, tokenB, amountA, amountB);
    }

    function swapTokens(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut) external notPaused {
        require(tokenIn != tokenOut, "Same token");
        require(amountIn > 0, "Invalid amount");

        uint256 outputAmount = calculateOutputAmount(tokenIn, tokenOut, amountIn);
        require(outputAmount >= minAmountOut, "Insufficient output");
        require(outputAmount <= liquidityPools[tokenOut][tokenIn], "Insufficient liquidity");

        require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "Transfer failed");
        require(IERC20(tokenOut).transfer(msg.sender, outputAmount), "Transfer failed");

        liquidityPools[tokenIn][tokenOut] += amountIn;
        liquidityPools[tokenOut][tokenIn] -= outputAmount;

        emit Trade(msg.sender, tokenIn, tokenOut, amountIn, outputAmount);
    }

    function removeLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) external {
        require(userBalances[msg.sender][tokenA] >= amountA, "Insufficient balance A");
        require(userBalances[msg.sender][tokenB] >= amountB, "Insufficient balance B");
        require(liquidityPools[tokenA][tokenB] >= amountA, "Insufficient pool A");
        require(liquidityPools[tokenB][tokenA] >= amountB, "Insufficient pool B");

        userBalances[msg.sender][tokenA] -= amountA;
        userBalances[msg.sender][tokenB] -= amountB;

        liquidityPools[tokenA][tokenB] -= amountA;
        liquidityPools[tokenB][tokenA] -= amountB;

        require(IERC20(tokenA).transfer(msg.sender, amountA), "Transfer A failed");
        require(IERC20(tokenB).transfer(msg.sender, amountB), "Transfer B failed");
    }

    function emergencyPause() external onlyOwner {
        paused = !paused;
    }

    function withdrawFees(address token, uint256 amount) external onlyOwner {
        require(IERC20(token).transfer(owner, amount), "Transfer failed");
    }
}
