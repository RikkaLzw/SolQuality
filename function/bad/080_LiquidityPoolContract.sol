
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

    mapping(address => uint256) public liquidityBalances;
    mapping(address => bool) public authorizedUsers;

    address public owner;
    uint256 public feeRate = 30;
    uint256 public constant FEE_DENOMINATOR = 10000;

    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event TokensSwapped(address indexed user, address tokenIn, uint256 amountIn, uint256 amountOut);

    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        owner = msg.sender;
        authorizedUsers[msg.sender] = true;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }




    function addLiquidityAndManageUser(
        uint256 amountA,
        uint256 amountB,
        address userToAuthorize,
        bool shouldAuthorize,
        uint256 minLiquidityOut,
        uint256 deadline,
        bool shouldUpdateFee,
        uint256 newFeeRate
    ) public returns (uint256, bool, uint256) {
        require(block.timestamp <= deadline, "Deadline exceeded");


        if (shouldUpdateFee) {
            if (msg.sender == owner) {
                if (newFeeRate <= 1000) {
                    if (newFeeRate != feeRate) {
                        feeRate = newFeeRate;
                    }
                }
            }
        }

        uint256 liquidityMinted;

        if (totalLiquidity == 0) {
            liquidityMinted = sqrt(amountA * amountB);
            if (liquidityMinted > 0) {
                if (liquidityMinted >= minLiquidityOut) {
                    totalLiquidity = liquidityMinted;
                    liquidityBalances[msg.sender] = liquidityMinted;
                    reserveA = amountA;
                    reserveB = amountB;
                } else {
                    revert("Insufficient liquidity output");
                }
            }
        } else {
            uint256 liquidityA = (amountA * totalLiquidity) / reserveA;
            uint256 liquidityB = (amountB * totalLiquidity) / reserveB;

            if (liquidityA <= liquidityB) {
                if (liquidityA >= minLiquidityOut) {
                    liquidityMinted = liquidityA;
                    if (shouldAuthorize && userToAuthorize != address(0)) {
                        if (msg.sender == owner || authorizedUsers[msg.sender]) {
                            authorizedUsers[userToAuthorize] = shouldAuthorize;
                        }
                    }
                    liquidityBalances[msg.sender] += liquidityMinted;
                    totalLiquidity += liquidityMinted;
                    reserveA += amountA;
                    reserveB += amountB;
                } else {
                    revert("Insufficient liquidity output");
                }
            } else {
                if (liquidityB >= minLiquidityOut) {
                    liquidityMinted = liquidityB;
                    if (shouldAuthorize && userToAuthorize != address(0)) {
                        if (msg.sender == owner || authorizedUsers[msg.sender]) {
                            authorizedUsers[userToAuthorize] = shouldAuthorize;
                        }
                    }
                    liquidityBalances[msg.sender] += liquidityMinted;
                    totalLiquidity += liquidityMinted;
                    reserveA += amountA;
                    reserveB += amountB;
                } else {
                    revert("Insufficient liquidity output");
                }
            }
        }

        require(tokenA.transferFrom(msg.sender, address(this), amountA), "Transfer A failed");
        require(tokenB.transferFrom(msg.sender, address(this), amountB), "Transfer B failed");

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidityMinted);

        return (liquidityMinted, shouldAuthorize, block.timestamp);
    }


    function calculateSwapAmountWithComplexLogic(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public view returns (uint256) {
        require(amountIn > 0, "Invalid input amount");
        require(reserveIn > 0 && reserveOut > 0, "Invalid reserves");

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - feeRate);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;

        return numerator / denominator;
    }



    function swapTokens(address tokenIn, uint256 amountIn, uint256 minAmountOut) public {
        require(amountIn > 0, "Invalid amount");

        uint256 amountOut;

        if (tokenIn == address(tokenA)) {
            if (reserveA > 0 && reserveB > 0) {
                amountOut = calculateSwapAmountWithComplexLogic(amountIn, reserveA, reserveB);
                if (amountOut >= minAmountOut) {
                    if (amountOut <= reserveB) {
                        reserveA += amountIn;
                        reserveB -= amountOut;
                        require(tokenA.transferFrom(msg.sender, address(this), amountIn), "Transfer in failed");
                        require(tokenB.transfer(msg.sender, amountOut), "Transfer out failed");
                        emit TokensSwapped(msg.sender, tokenIn, amountIn, amountOut);
                    } else {
                        revert("Insufficient liquidity");
                    }
                } else {
                    revert("Insufficient output amount");
                }
            } else {
                revert("No liquidity");
            }
        } else if (tokenIn == address(tokenB)) {
            if (reserveA > 0 && reserveB > 0) {
                amountOut = calculateSwapAmountWithComplexLogic(amountIn, reserveB, reserveA);
                if (amountOut >= minAmountOut) {
                    if (amountOut <= reserveA) {
                        reserveB += amountIn;
                        reserveA -= amountOut;
                        require(tokenB.transferFrom(msg.sender, address(this), amountIn), "Transfer in failed");
                        require(tokenA.transfer(msg.sender, amountOut), "Transfer out failed");
                        emit TokensSwapped(msg.sender, tokenIn, amountIn, amountOut);
                    } else {
                        revert("Insufficient liquidity");
                    }
                } else {
                    revert("Insufficient output amount");
                }
            } else {
                revert("No liquidity");
            }
        } else {
            revert("Invalid token");
        }
    }


    function removeLiquidity(uint256 liquidityAmount) public returns (uint256, uint256, bool) {
        require(liquidityAmount > 0, "Invalid liquidity amount");
        require(liquidityBalances[msg.sender] >= liquidityAmount, "Insufficient liquidity balance");

        uint256 amountA = (liquidityAmount * reserveA) / totalLiquidity;
        uint256 amountB = (liquidityAmount * reserveB) / totalLiquidity;

        liquidityBalances[msg.sender] -= liquidityAmount;
        totalLiquidity -= liquidityAmount;
        reserveA -= amountA;
        reserveB -= amountB;

        require(tokenA.transfer(msg.sender, amountA), "Transfer A failed");
        require(tokenB.transfer(msg.sender, amountB), "Transfer B failed");

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidityAmount);

        return (amountA, amountB, totalLiquidity > 0);
    }


    function sqrt(uint256 x) public pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

    function getReserves() public view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    function getLiquidityBalance(address user) public view returns (uint256) {
        return liquidityBalances[user];
    }

    function setFeeRate(uint256 newFeeRate) public onlyOwner {
        require(newFeeRate <= 1000, "Fee too high");
        feeRate = newFeeRate;
    }

    function authorizeUser(address user, bool authorized) public onlyOwner {
        authorizedUsers[user] = authorized;
    }
}
