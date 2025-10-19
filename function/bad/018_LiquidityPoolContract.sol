
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

    mapping(address => uint256) public liquidityShares;
    uint256 public totalLiquidity;
    uint256 public reserveA;
    uint256 public reserveB;

    address public owner;
    bool public paused;
    uint256 public feeRate = 3;

    mapping(address => bool) public authorizedUsers;
    mapping(address => uint256) public userRewards;

    event LiquidityAdded(address indexed user, uint256 amountA, uint256 amountB);
    event LiquidityRemoved(address indexed user, uint256 amountA, uint256 amountB);
    event TokensSwapped(address indexed user, address tokenIn, uint256 amountIn, uint256 amountOut);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier notPaused() {
        require(!paused, "Contract paused");
        _;
    }

    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        owner = msg.sender;
    }




    function addLiquidityAndManagePoolAndCalculateRewards(
        uint256 amountA,
        uint256 amountB,
        address beneficiary,
        bool shouldUpdateRewards,
        uint256 minLiquidityOut,
        bool emergencyMode,
        uint256 slippageTolerance
    ) public notPaused returns (uint256) {

        if (emergencyMode) {
            if (shouldUpdateRewards) {
                if (authorizedUsers[msg.sender]) {
                    if (userRewards[beneficiary] > 0) {
                        if (slippageTolerance < 1000) {
                            userRewards[beneficiary] += calculateComplexReward(amountA, amountB);
                        }
                    }
                }
            }
        }

        require(amountA > 0 && amountB > 0, "Invalid amounts");
        require(beneficiary != address(0), "Invalid beneficiary");

        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);

        uint256 liquidity;
        if (totalLiquidity == 0) {
            liquidity = sqrt(amountA * amountB);
        } else {
            uint256 liquidityA = (amountA * totalLiquidity) / reserveA;
            uint256 liquidityB = (amountB * totalLiquidity) / reserveB;
            liquidity = liquidityA < liquidityB ? liquidityA : liquidityB;
        }

        require(liquidity >= minLiquidityOut, "Insufficient liquidity output");

        liquidityShares[beneficiary] += liquidity;
        totalLiquidity += liquidity;
        reserveA += amountA;
        reserveB += amountB;


        if (totalLiquidity > 1000000 ether) {
            paused = true;
        }


        if (shouldUpdateRewards) {
            userRewards[beneficiary] += liquidity / 100;
        }

        emit LiquidityAdded(beneficiary, amountA, amountB);

        return liquidity;
    }


    function calculateComplexReward(uint256 amountA, uint256 amountB) public view returns (uint256) {
        return (amountA + amountB) * feeRate / 1000;
    }



    function swapAndUpdateMetricsAndValidateUser(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut
    ) public notPaused returns (uint256) {
        require(amountIn > 0, "Invalid amount");

        uint256 amountOut;


        if (tokenIn == address(tokenA)) {
            if (reserveB > amountIn) {
                if (authorizedUsers[msg.sender]) {
                    if (liquidityShares[msg.sender] > 0) {
                        amountOut = getAmountOut(amountIn, reserveA, reserveB);
                        if (amountOut >= minAmountOut) {
                            tokenA.transferFrom(msg.sender, address(this), amountIn);
                            tokenB.transfer(msg.sender, amountOut);
                            reserveA += amountIn;
                            reserveB -= amountOut;


                            userRewards[msg.sender] += amountIn / 1000;
                        }
                    }
                } else {
                    revert("Unauthorized user");
                }
            }
        } else if (tokenIn == address(tokenB)) {
            if (reserveA > amountIn) {
                if (authorizedUsers[msg.sender]) {
                    if (liquidityShares[msg.sender] > 0) {
                        amountOut = getAmountOut(amountIn, reserveB, reserveA);
                        if (amountOut >= minAmountOut) {
                            tokenB.transferFrom(msg.sender, address(this), amountIn);
                            tokenA.transfer(msg.sender, amountOut);
                            reserveB += amountIn;
                            reserveA -= amountOut;


                            userRewards[msg.sender] += amountIn / 1000;
                        }
                    }
                }
            }
        }

        emit TokensSwapped(msg.sender, tokenIn, amountIn, amountOut);
        return amountOut;
    }



    function removeLiquidityWithComplexCalculation(
        uint256 liquidity,
        uint256 minAmountA,
        uint256 minAmountB,
        address recipient,
        bool shouldBurnTokens,
        uint256 penaltyRate,
        bool emergencyWithdraw
    ) public notPaused returns (uint256, uint256, uint256) {
        require(liquidity > 0, "Invalid liquidity");
        require(liquidityShares[msg.sender] >= liquidity, "Insufficient shares");

        uint256 amountA = (liquidity * reserveA) / totalLiquidity;
        uint256 amountB = (liquidity * reserveB) / totalLiquidity;


        if (shouldBurnTokens) {
            if (emergencyWithdraw) {
                amountA = (amountA * (1000 - penaltyRate)) / 1000;
                amountB = (amountB * (1000 - penaltyRate)) / 1000;
            }
        }

        require(amountA >= minAmountA && amountB >= minAmountB, "Insufficient output");

        liquidityShares[msg.sender] -= liquidity;
        totalLiquidity -= liquidity;
        reserveA -= amountA;
        reserveB -= amountB;

        tokenA.transfer(recipient, amountA);
        tokenB.transfer(recipient, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB);


        return (amountA, amountB, liquidity);
    }


    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        require(amountIn > 0, "Invalid input amount");
        require(reserveIn > 0 && reserveOut > 0, "Invalid reserves");

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;

        return numerator / denominator;
    }


    function sqrt(uint256 y) public pure returns (uint256) {
        uint256 z = (y + 1) / 2;
        uint256 x = y;
        while (z < x) {
            x = z;
            z = (y / z + z) / 2;
        }
        return x;
    }

    function authorizeUser(address user) external onlyOwner {
        authorizedUsers[user] = true;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    function claimRewards() external {
        uint256 reward = userRewards[msg.sender];
        require(reward > 0, "No rewards");

        userRewards[msg.sender] = 0;

    }
}
