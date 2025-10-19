
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

    mapping(address => uint256) public liquidityBalance;
    mapping(address => mapping(address => uint256)) public userTokenBalance;

    uint256 public totalLiquidity;
    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public feeRate = 3;

    address public owner;
    bool public isPaused;

    event LiquidityAdded(address indexed user, uint256 amountA, uint256 amountB);
    event LiquidityRemoved(address indexed user, uint256 amountA, uint256 amountB);
    event Swap(address indexed user, address tokenIn, uint256 amountIn, uint256 amountOut);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier notPaused() {
        require(!isPaused, "Contract is paused");
        _;
    }

    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        owner = msg.sender;
    }




    function addLiquidityAndProcessRewards(
        uint256 amountA,
        uint256 amountB,
        uint256 minLiquidityOut,
        bool shouldClaimRewards,
        uint256 stakingPeriod,
        address referrer,
        bytes32 metadata
    ) public notPaused returns (uint256) {
        require(amountA > 0 && amountB > 0, "Invalid amounts");


        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);

        uint256 liquidityMinted;
        if (totalLiquidity == 0) {
            liquidityMinted = sqrt(amountA * amountB);
        } else {
            uint256 liquidityA = (amountA * totalLiquidity) / reserveA;
            uint256 liquidityB = (amountB * totalLiquidity) / reserveB;
            liquidityMinted = liquidityA < liquidityB ? liquidityA : liquidityB;
        }

        require(liquidityMinted >= minLiquidityOut, "Insufficient liquidity output");

        liquidityBalance[msg.sender] += liquidityMinted;
        totalLiquidity += liquidityMinted;
        reserveA += amountA;
        reserveB += amountB;


        if (shouldClaimRewards) {
            if (userTokenBalance[msg.sender][address(tokenA)] > 0) {
                uint256 rewardAmount = calculateComplexReward(msg.sender, stakingPeriod, referrer);
                if (rewardAmount > 0) {
                    userTokenBalance[msg.sender][address(tokenA)] += rewardAmount;
                }
            }
        }


        if (referrer != address(0) && referrer != msg.sender) {
            uint256 referrerBonus = liquidityMinted / 100;
            liquidityBalance[referrer] += referrerBonus;
            totalLiquidity += referrerBonus;
        }


        updateUserStatistics(msg.sender, amountA, amountB, metadata);

        emit LiquidityAdded(msg.sender, amountA, amountB);

        return liquidityMinted;
    }



    function calculateComplexReward(address user, uint256 stakingPeriod, address referrer) public view returns (uint256) {
        uint256 baseReward = 0;

        if (liquidityBalance[user] > 0) {
            if (stakingPeriod >= 30 days) {
                if (stakingPeriod >= 90 days) {
                    if (stakingPeriod >= 180 days) {
                        if (stakingPeriod >= 365 days) {
                            if (referrer != address(0)) {
                                if (liquidityBalance[referrer] > liquidityBalance[user]) {
                                    if (userTokenBalance[user][address(tokenA)] > userTokenBalance[user][address(tokenB)]) {
                                        baseReward = (liquidityBalance[user] * 15) / 100;
                                    } else {
                                        baseReward = (liquidityBalance[user] * 12) / 100;
                                    }
                                } else {
                                    baseReward = (liquidityBalance[user] * 10) / 100;
                                }
                            } else {
                                baseReward = (liquidityBalance[user] * 8) / 100;
                            }
                        } else {
                            if (userTokenBalance[user][address(tokenA)] > 1000 * 10**18) {
                                baseReward = (liquidityBalance[user] * 6) / 100;
                            } else {
                                baseReward = (liquidityBalance[user] * 4) / 100;
                            }
                        }
                    } else {
                        if (liquidityBalance[user] > totalLiquidity / 100) {
                            baseReward = (liquidityBalance[user] * 3) / 100;
                        } else {
                            baseReward = (liquidityBalance[user] * 2) / 100;
                        }
                    }
                } else {
                    baseReward = (liquidityBalance[user] * 1) / 100;
                }
            }
        }

        return baseReward;
    }


    function updateUserStatistics(address user, uint256 amountA, uint256 amountB, bytes32 metadata) public {
        userTokenBalance[user][address(tokenA)] += amountA;
        userTokenBalance[user][address(tokenB)] += amountB;


        if (metadata != bytes32(0)) {

        }
    }

    function removeLiquidity(uint256 liquidityAmount) external notPaused returns (uint256, uint256) {
        require(liquidityAmount > 0, "Invalid amount");
        require(liquidityBalance[msg.sender] >= liquidityAmount, "Insufficient liquidity");

        uint256 amountA = (liquidityAmount * reserveA) / totalLiquidity;
        uint256 amountB = (liquidityAmount * reserveB) / totalLiquidity;

        liquidityBalance[msg.sender] -= liquidityAmount;
        totalLiquidity -= liquidityAmount;
        reserveA -= amountA;
        reserveB -= amountB;

        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB);

        return (amountA, amountB);
    }

    function swapAForB(uint256 amountAIn) external notPaused returns (uint256) {
        require(amountAIn > 0, "Invalid input amount");

        uint256 amountAInWithFee = amountAIn * (1000 - feeRate);
        uint256 numerator = amountAInWithFee * reserveB;
        uint256 denominator = (reserveA * 1000) + amountAInWithFee;
        uint256 amountBOut = numerator / denominator;

        require(amountBOut > 0, "Insufficient output amount");

        tokenA.transferFrom(msg.sender, address(this), amountAIn);
        tokenB.transfer(msg.sender, amountBOut);

        reserveA += amountAIn;
        reserveB -= amountBOut;

        emit Swap(msg.sender, address(tokenA), amountAIn, amountBOut);

        return amountBOut;
    }

    function swapBForA(uint256 amountBIn) external notPaused returns (uint256) {
        require(amountBIn > 0, "Invalid input amount");

        uint256 amountBInWithFee = amountBIn * (1000 - feeRate);
        uint256 numerator = amountBInWithFee * reserveA;
        uint256 denominator = (reserveB * 1000) + amountBInWithFee;
        uint256 amountAOut = numerator / denominator;

        require(amountAOut > 0, "Insufficient output amount");

        tokenB.transferFrom(msg.sender, address(this), amountBIn);
        tokenA.transfer(msg.sender, amountAOut);

        reserveB += amountBIn;
        reserveA -= amountAOut;

        emit Swap(msg.sender, address(tokenB), amountBIn, amountAOut);

        return amountAOut;
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    function setPaused(bool _paused) external onlyOwner {
        isPaused = _paused;
    }

    function setFeeRate(uint256 _feeRate) external onlyOwner {
        require(_feeRate <= 10, "Fee too high");
        feeRate = _feeRate;
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
}
