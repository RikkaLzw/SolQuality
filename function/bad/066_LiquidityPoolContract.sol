
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
    uint256 public totalShares;
    uint256 public reserveA;
    uint256 public reserveB;

    address public owner;
    bool public paused;
    uint256 public feeRate = 30;
    uint256 public constant FEE_DENOMINATOR = 10000;

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





    function complexMultiPurposeFunction(
        uint256 amountA,
        uint256 amountB,
        uint256 minLiquidity,
        bool shouldUpdateFee,
        uint256 newFeeRate,
        address beneficiary,
        bool emergencyMode
    ) public notPaused returns (uint256) {
        if (emergencyMode) {
            if (msg.sender == owner) {
                if (shouldUpdateFee) {
                    if (newFeeRate <= 1000) {
                        feeRate = newFeeRate;
                        if (newFeeRate == 0) {
                            if (paused) {
                                paused = false;
                            } else {
                                if (totalShares > 0) {
                                    uint256 emergencyWithdraw = liquidityShares[msg.sender];
                                    if (emergencyWithdraw > 0) {
                                        liquidityShares[msg.sender] = 0;
                                        totalShares -= emergencyWithdraw;
                                        uint256 withdrawA = (emergencyWithdraw * reserveA) / totalShares;
                                        uint256 withdrawB = (emergencyWithdraw * reserveB) / totalShares;
                                        reserveA -= withdrawA;
                                        reserveB -= withdrawB;
                                        tokenA.transfer(beneficiary != address(0) ? beneficiary : msg.sender, withdrawA);
                                        tokenB.transfer(beneficiary != address(0) ? beneficiary : msg.sender, withdrawB);
                                        return withdrawA + withdrawB;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } else {
            if (amountA > 0 && amountB > 0) {
                if (totalShares == 0) {
                    uint256 initialLiquidity = sqrt(amountA * amountB);
                    if (initialLiquidity >= minLiquidity) {
                        tokenA.transferFrom(msg.sender, address(this), amountA);
                        tokenB.transferFrom(msg.sender, address(this), amountB);
                        reserveA = amountA;
                        reserveB = amountB;
                        liquidityShares[msg.sender] = initialLiquidity;
                        totalShares = initialLiquidity;
                        if (shouldUpdateFee && msg.sender == owner) {
                            if (newFeeRate <= 1000) {
                                feeRate = newFeeRate;
                            }
                        }
                        return initialLiquidity;
                    }
                } else {
                    uint256 liquidityA = (amountA * totalShares) / reserveA;
                    uint256 liquidityB = (amountB * totalShares) / reserveB;
                    uint256 liquidity = liquidityA < liquidityB ? liquidityA : liquidityB;
                    if (liquidity >= minLiquidity) {
                        uint256 actualAmountA = (liquidity * reserveA) / totalShares;
                        uint256 actualAmountB = (liquidity * reserveB) / totalShares;
                        tokenA.transferFrom(msg.sender, address(this), actualAmountA);
                        tokenB.transferFrom(msg.sender, address(this), actualAmountB);
                        reserveA += actualAmountA;
                        reserveB += actualAmountB;
                        liquidityShares[msg.sender] += liquidity;
                        totalShares += liquidity;
                        if (shouldUpdateFee && msg.sender == owner) {
                            if (newFeeRate <= 1000) {
                                feeRate = newFeeRate;
                            }
                        }
                        return liquidity;
                    }
                }
            }
        }
        return 0;
    }


    function calculateSwapAmount(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        require(amountIn > 0 && reserveIn > 0 && reserveOut > 0, "Invalid amounts");
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        return numerator / denominator;
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

    function swapAForB(uint256 amountAIn, uint256 minAmountBOut) external notPaused {
        require(amountAIn > 0, "Amount must be positive");

        uint256 amountBOut = calculateSwapAmount(amountAIn, reserveA, reserveB);
        require(amountBOut >= minAmountBOut, "Insufficient output amount");

        uint256 fee = (amountAIn * feeRate) / FEE_DENOMINATOR;
        uint256 amountAInAfterFee = amountAIn - fee;

        tokenA.transferFrom(msg.sender, address(this), amountAIn);
        reserveA += amountAInAfterFee;
        reserveB -= amountBOut;
        tokenB.transfer(msg.sender, amountBOut);
    }

    function swapBForA(uint256 amountBIn, uint256 minAmountAOut) external notPaused {
        require(amountBIn > 0, "Amount must be positive");

        uint256 amountAOut = calculateSwapAmount(amountBIn, reserveB, reserveA);
        require(amountAOut >= minAmountAOut, "Insufficient output amount");

        uint256 fee = (amountBIn * feeRate) / FEE_DENOMINATOR;
        uint256 amountBInAfterFee = amountBIn - fee;

        tokenB.transferFrom(msg.sender, address(this), amountBIn);
        reserveB += amountBInAfterFee;
        reserveA -= amountAOut;
        tokenA.transfer(msg.sender, amountAOut);
    }

    function removeLiquidity(uint256 liquidity) external notPaused {
        require(liquidity > 0 && liquidity <= liquidityShares[msg.sender], "Invalid liquidity amount");

        uint256 amountA = (liquidity * reserveA) / totalShares;
        uint256 amountB = (liquidity * reserveB) / totalShares;

        liquidityShares[msg.sender] -= liquidity;
        totalShares -= liquidity;
        reserveA -= amountA;
        reserveB -= amountB;

        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    function setFeeRate(uint256 _feeRate) external onlyOwner {
        require(_feeRate <= 1000, "Fee rate too high");
        feeRate = _feeRate;
    }
}
