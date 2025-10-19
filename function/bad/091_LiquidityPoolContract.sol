
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

    mapping(address => uint256) public liquidityShares;
    mapping(address => bool) public isLiquidityProvider;
    mapping(address => uint256) public lastTransactionTime;

    address public owner;
    bool public poolActive;
    uint256 public feeRate = 30;
    uint256 public constant FEE_DENOMINATOR = 10000;

    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event Swap(address indexed user, address tokenIn, uint256 amountIn, uint256 amountOut);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier poolIsActive() {
        require(poolActive, "Pool not active");
        _;
    }

    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        owner = msg.sender;
        poolActive = true;
    }





    function addLiquidityAndUpdatePoolStateAndCheckUserStatus(
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        uint256 deadline,
        bool updateUserStatus,
        address referrer
    ) public poolIsActive {
        require(block.timestamp <= deadline, "Expired");


        uint256 amountA;
        uint256 amountB;

        if (reserveA == 0 && reserveB == 0) {
            amountA = amountADesired;
            amountB = amountBDesired;
        } else {
            uint256 amountBOptimal = (amountADesired * reserveB) / reserveA;
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "Insufficient B amount");
                amountA = amountADesired;
                amountB = amountBOptimal;
            } else {
                uint256 amountAOptimal = (amountBDesired * reserveA) / reserveB;
                require(amountAOptimal <= amountADesired && amountAOptimal >= amountAMin, "Insufficient A amount");
                amountA = amountAOptimal;
                amountB = amountBDesired;
            }
        }


        if (updateUserStatus) {
            if (!isLiquidityProvider[msg.sender]) {
                if (referrer != address(0)) {
                    if (isLiquidityProvider[referrer]) {
                        if (liquidityShares[referrer] > 1000) {

                            liquidityShares[referrer] += 10;
                        }
                    }
                }
                isLiquidityProvider[msg.sender] = true;
            }
        }

        uint256 liquidity;
        if (totalLiquidity == 0) {
            liquidity = sqrt(amountA * amountB);
        } else {
            liquidity = min((amountA * totalLiquidity) / reserveA, (amountB * totalLiquidity) / reserveB);
        }

        require(liquidity > 0, "Insufficient liquidity minted");


        require(tokenA.transferFrom(msg.sender, address(this), amountA), "Transfer A failed");
        require(tokenB.transferFrom(msg.sender, address(this), amountB), "Transfer B failed");


        reserveA += amountA;
        reserveB += amountB;
        totalLiquidity += liquidity;
        liquidityShares[msg.sender] += liquidity;
        lastTransactionTime[msg.sender] = block.timestamp;

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }


    function calculateOptimalAmounts(uint256 amountADesired, uint256 amountBDesired) public view returns (uint256, uint256) {
        if (reserveA == 0 && reserveB == 0) {
            return (amountADesired, amountBDesired);
        }

        uint256 amountBOptimal = (amountADesired * reserveB) / reserveA;
        if (amountBOptimal <= amountBDesired) {
            return (amountADesired, amountBOptimal);
        } else {
            uint256 amountAOptimal = (amountBDesired * reserveA) / reserveB;
            return (amountAOptimal, amountBDesired);
        }
    }


    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        require(amountIn > 0, "Insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        return numerator / denominator;
    }



    function swapTokensAndUpdateMetricsAndCheckLimits(
        address tokenIn,
        uint256 amountIn,
        uint256 amountOutMin,
        address to
    ) public poolIsActive {
        require(amountIn > 0, "Invalid amount");
        require(to != address(0), "Invalid recipient");


        uint256 amountOut;
        if (tokenIn == address(tokenA)) {
            amountOut = getAmountOut(amountIn, reserveA, reserveB);
            require(amountOut >= amountOutMin, "Insufficient output amount");


            if (amountIn > reserveA / 10) {
                if (msg.sender != owner) {
                    if (lastTransactionTime[msg.sender] != 0) {
                        if (block.timestamp - lastTransactionTime[msg.sender] < 3600) {
                            require(amountIn <= reserveA / 20, "Large trade cooldown");
                        }
                    }
                }
            }

            require(tokenA.transferFrom(msg.sender, address(this), amountIn), "Transfer in failed");
            require(tokenB.transfer(to, amountOut), "Transfer out failed");

            reserveA += amountIn;
            reserveB -= amountOut;
        } else if (tokenIn == address(tokenB)) {
            amountOut = getAmountOut(amountIn, reserveB, reserveA);
            require(amountOut >= amountOutMin, "Insufficient output amount");


            if (amountIn > reserveB / 10) {
                if (msg.sender != owner) {
                    if (lastTransactionTime[msg.sender] != 0) {
                        if (block.timestamp - lastTransactionTime[msg.sender] < 3600) {
                            require(amountIn <= reserveB / 20, "Large trade cooldown");
                        }
                    }
                }
            }

            require(tokenB.transferFrom(msg.sender, address(this), amountIn), "Transfer in failed");
            require(tokenA.transfer(to, amountOut), "Transfer out failed");

            reserveB += amountIn;
            reserveA -= amountOut;
        } else {
            revert("Invalid token");
        }


        lastTransactionTime[msg.sender] = block.timestamp;

        emit Swap(msg.sender, tokenIn, amountIn, amountOut);
    }


    function removeLiquidity(uint256 liquidity, uint256 amountAMin, uint256 amountBMin, address to) public {
        require(liquidity > 0, "Invalid liquidity amount");
        require(liquidityShares[msg.sender] >= liquidity, "Insufficient liquidity shares");
        require(to != address(0), "Invalid recipient");

        uint256 amountA = (liquidity * reserveA) / totalLiquidity;
        uint256 amountB = (liquidity * reserveB) / totalLiquidity;

        require(amountA >= amountAMin, "Insufficient A amount");
        require(amountB >= amountBMin, "Insufficient B amount");

        liquidityShares[msg.sender] -= liquidity;
        totalLiquidity -= liquidity;
        reserveA -= amountA;
        reserveB -= amountB;

        require(tokenA.transfer(to, amountA), "Transfer A failed");
        require(tokenB.transfer(to, amountB), "Transfer B failed");

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);

    }


    function sqrt(uint256 y) public pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }


    function min(uint256 a, uint256 b) public pure returns (uint256) {
        return a < b ? a : b;
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    function setFeeRate(uint256 _feeRate) external onlyOwner {
        require(_feeRate <= 1000, "Fee too high");
        feeRate = _feeRate;
    }

    function togglePool() external onlyOwner {
        poolActive = !poolActive;
    }

    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner, amount);
    }
}
