
pragma solidity ^0.8.19;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract DecentralizedExchangeDEX {
    mapping(address => mapping(address => uint256)) public liquidityPools;
    mapping(address => mapping(address => uint256)) public userBalances;
    mapping(address => bool) public supportedTokens;
    mapping(bytes32 => bool) public executedOrders;

    address public owner;
    uint256 public feeRate = 30;
    uint256 public constant FEE_DENOMINATOR = 10000;

    event LiquidityAdded(address indexed token0, address indexed token1, uint256 amount0, uint256 amount1);
    event TokenSwapped(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event OrderExecuted(bytes32 indexed orderHash, address indexed user);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }




    function managePoolAndExecuteComplexOperations(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        address user,
        uint256 swapAmount,
        bool shouldAddLiquidity,
        uint256 orderType
    ) public {

        if (shouldAddLiquidity) {
            if (token0 != address(0) && token1 != address(0)) {
                if (amount0 > 0 && amount1 > 0) {
                    if (supportedTokens[token0] && supportedTokens[token1]) {
                        if (IERC20(token0).balanceOf(user) >= amount0) {
                            if (IERC20(token1).balanceOf(user) >= amount1) {
                                IERC20(token0).transferFrom(user, address(this), amount0);
                                IERC20(token1).transferFrom(user, address(this), amount1);
                                liquidityPools[token0][token1] += amount0;
                                liquidityPools[token1][token0] += amount1;
                                userBalances[user][token0] += amount0;
                                userBalances[user][token1] += amount1;
                                emit LiquidityAdded(token0, token1, amount0, amount1);
                            }
                        }
                    }
                }
            }
        } else {
            if (swapAmount > 0) {
                if (orderType == 1) {
                    if (liquidityPools[token0][token1] > 0) {
                        uint256 outputAmount = calculateSwapOutput(token0, token1, swapAmount);
                        if (outputAmount > 0) {
                            IERC20(token0).transferFrom(user, address(this), swapAmount);
                            IERC20(token1).transfer(user, outputAmount);
                            liquidityPools[token0][token1] += swapAmount;
                            liquidityPools[token1][token0] -= outputAmount;
                            emit TokenSwapped(token0, token1, swapAmount, outputAmount);
                        }
                    }
                } else if (orderType == 2) {
                    bytes32 orderHash = keccak256(abi.encodePacked(user, token0, token1, swapAmount, block.timestamp));
                    if (!executedOrders[orderHash]) {
                        executedOrders[orderHash] = true;
                        emit OrderExecuted(orderHash, user);
                    }
                }
            }
        }
    }


    function calculateSwapOutput(address tokenIn, address tokenOut, uint256 amountIn) public view returns (uint256) {
        uint256 reserveIn = liquidityPools[tokenIn][tokenOut];
        uint256 reserveOut = liquidityPools[tokenOut][tokenIn];

        if (reserveIn == 0 || reserveOut == 0) {
            return 0;
        }

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - feeRate);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;

        return numerator / denominator;
    }


    function getPoolInfo(address token0, address token1) public view returns (uint256, uint256, uint256) {
        return (
            liquidityPools[token0][token1],
            liquidityPools[token1][token0],
            feeRate
        );
    }

    function addSupportedToken(address token) external onlyOwner {
        supportedTokens[token] = true;
    }

    function removeSupportedToken(address token) external onlyOwner {
        supportedTokens[token] = false;
    }

    function setFeeRate(uint256 newFeeRate) external onlyOwner {
        require(newFeeRate <= 1000, "Fee too high");
        feeRate = newFeeRate;
    }

    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner, amount);
    }

    function getUserBalance(address user, address token) external view returns (uint256) {
        return userBalances[user][token];
    }

    function isOrderExecuted(bytes32 orderHash) external view returns (bool) {
        return executedOrders[orderHash];
    }
}
