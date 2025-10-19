
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
    mapping(address => bool) public isLiquidityProvider;
    mapping(address => uint256) public lastTransactionTime;

    address public owner;
    bool public isPaused;
    uint256 public feeRate = 30;
    uint256 public constant FEE_DENOMINATOR = 10000;

    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event Swap(address indexed user, address tokenIn, uint256 amountIn, uint256 amountOut);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier notPaused() {
        require(!isPaused, "Contract paused");
        _;
    }

    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        owner = msg.sender;
    }




    function addLiquidityAndUpdateUserStatusAndCalculateFees(
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        uint256 deadline,
        bool shouldUpdateUserStatus,
        string memory userNote
    ) public notPaused {
        require(block.timestamp <= deadline, "Expired");
        require(amountADesired > 0 && amountBDesired > 0, "Invalid amounts");


        uint256 amountA = amountADesired;
        uint256 amountB = amountBDesired;

        if (reserveA > 0 && reserveB > 0) {
            uint256 amountBOptimal = (amountADesired * reserveB) / reserveA;
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "Insufficient B amount");
                amountB = amountBOptimal;
            } else {
                uint256 amountAOptimal = (amountBDesired * reserveA) / reserveB;
                require(amountAOptimal <= amountADesired && amountAOptimal >= amountAMin, "Insufficient A amount");
                amountA = amountAOptimal;
            }
        }

        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);

        uint256 liquidity;
        if (totalLiquidity == 0) {
            liquidity = sqrt(amountA * amountB);
        } else {
            liquidity = min((amountA * totalLiquidity) / reserveA, (amountB * totalLiquidity) / reserveB);
        }

        liquidityBalances[msg.sender] += liquidity;
        totalLiquidity += liquidity;
        reserveA += amountA;
        reserveB += amountB;


        if (shouldUpdateUserStatus) {
            isLiquidityProvider[msg.sender] = true;
            lastTransactionTime[msg.sender] = block.timestamp;
        }


        if (bytes(userNote).length > 0) {

        }

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }


    function calculateSwapAmount(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        require(amountIn > 0, "Invalid input amount");
        require(reserveIn > 0 && reserveOut > 0, "Invalid reserves");

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        return numerator / denominator;
    }


    function swapTokensWithComplexLogic(uint256 amountIn, bool isTokenAToB) public notPaused {
        require(amountIn > 0, "Invalid amount");

        if (isTokenAToB) {
            if (reserveA > 0 && reserveB > 0) {
                uint256 amountOut = calculateSwapAmount(amountIn, reserveA, reserveB);
                if (amountOut > 0) {
                    if (tokenB.balanceOf(address(this)) >= amountOut) {
                        tokenA.transferFrom(msg.sender, address(this), amountIn);


                        uint256 fee = (amountIn * feeRate) / FEE_DENOMINATOR;
                        if (fee > 0) {
                            if (isLiquidityProvider[msg.sender]) {
                                if (lastTransactionTime[msg.sender] + 86400 > block.timestamp) {
                                    fee = fee / 2;
                                    if (liquidityBalances[msg.sender] > totalLiquidity / 100) {
                                        fee = fee / 2;
                                        if (liquidityBalances[msg.sender] > totalLiquidity / 10) {
                                            fee = 0;
                                        }
                                    }
                                }
                            }
                        }

                        uint256 finalAmountOut = amountOut - fee;
                        tokenB.transfer(msg.sender, finalAmountOut);

                        reserveA += amountIn;
                        reserveB -= amountOut;

                        lastTransactionTime[msg.sender] = block.timestamp;

                        emit Swap(msg.sender, address(tokenA), amountIn, finalAmountOut);
                    } else {
                        revert("Insufficient liquidity");
                    }
                } else {
                    revert("Invalid swap amount");
                }
            } else {
                revert("No liquidity");
            }
        } else {
            if (reserveA > 0 && reserveB > 0) {
                uint256 amountOut = calculateSwapAmount(amountIn, reserveB, reserveA);
                if (amountOut > 0) {
                    if (tokenA.balanceOf(address(this)) >= amountOut) {
                        tokenB.transferFrom(msg.sender, address(this), amountIn);


                        uint256 fee = (amountIn * feeRate) / FEE_DENOMINATOR;
                        if (fee > 0) {
                            if (isLiquidityProvider[msg.sender]) {
                                if (lastTransactionTime[msg.sender] + 86400 > block.timestamp) {
                                    fee = fee / 2;
                                    if (liquidityBalances[msg.sender] > totalLiquidity / 100) {
                                        fee = fee / 2;
                                        if (liquidityBalances[msg.sender] > totalLiquidity / 10) {
                                            fee = 0;
                                        }
                                    }
                                }
                            }
                        }

                        uint256 finalAmountOut = amountOut - fee;
                        tokenA.transfer(msg.sender, finalAmountOut);

                        reserveB += amountIn;
                        reserveA -= amountOut;

                        lastTransactionTime[msg.sender] = block.timestamp;

                        emit Swap(msg.sender, address(tokenB), amountIn, finalAmountOut);
                    } else {
                        revert("Insufficient liquidity");
                    }
                } else {
                    revert("Invalid swap amount");
                }
            } else {
                revert("No liquidity");
            }
        }
    }

    function removeLiquidity(uint256 liquidity) public notPaused returns (uint256, uint256) {
        require(liquidity > 0, "Invalid liquidity");
        require(liquidityBalances[msg.sender] >= liquidity, "Insufficient liquidity balance");

        uint256 amountA = (liquidity * reserveA) / totalLiquidity;
        uint256 amountB = (liquidity * reserveB) / totalLiquidity;

        liquidityBalances[msg.sender] -= liquidity;
        totalLiquidity -= liquidity;
        reserveA -= amountA;
        reserveB -= amountB;

        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);

        return (amountA, amountB);
    }

    function getReserves() public view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    function pause() public onlyOwner {
        isPaused = true;
    }

    function unpause() public onlyOwner {
        isPaused = false;
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

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
