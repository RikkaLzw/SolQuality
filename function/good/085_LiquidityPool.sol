
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract LiquidityPool {
    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;

    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public totalLiquidity;

    mapping(address => uint256) public liquidity;

    uint256 private constant MINIMUM_LIQUIDITY = 1000;
    uint256 private unlocked = 1;

    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidityMinted);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidityBurned);
    event Swap(address indexed user, address indexed tokenIn, uint256 amountIn, uint256 amountOut);

    modifier lock() {
        require(unlocked == 1, "Pool: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor(address _tokenA, address _tokenB) {
        require(_tokenA != address(0) && _tokenB != address(0), "Pool: ZERO_ADDRESS");
        require(_tokenA != _tokenB, "Pool: IDENTICAL_TOKENS");
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external lock returns (uint256 liquidityMinted) {
        require(amountA > 0 && amountB > 0, "Pool: INSUFFICIENT_AMOUNT");

        _transferTokensFrom(msg.sender, amountA, amountB);

        if (totalLiquidity == 0) {
            liquidityMinted = _calculateInitialLiquidity(amountA, amountB);
        } else {
            liquidityMinted = _calculateLiquidity(amountA, amountB);
        }

        _updateReservesAndLiquidity(amountA, amountB, liquidityMinted);

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidityMinted);
    }

    function removeLiquidity(uint256 liquidityAmount) external lock returns (uint256 amountA, uint256 amountB) {
        require(liquidityAmount > 0, "Pool: INSUFFICIENT_LIQUIDITY");
        require(liquidity[msg.sender] >= liquidityAmount, "Pool: INSUFFICIENT_BALANCE");

        (amountA, amountB) = _calculateWithdrawal(liquidityAmount);

        _burnLiquidity(msg.sender, liquidityAmount);
        _transferTokensTo(msg.sender, amountA, amountB);
        _updateReserves(reserveA - amountA, reserveB - amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidityAmount);
    }

    function swapAForB(uint256 amountAIn) external lock returns (uint256 amountBOut) {
        require(amountAIn > 0, "Pool: INSUFFICIENT_INPUT");

        amountBOut = _calculateSwapOutput(amountAIn, reserveA, reserveB);
        require(amountBOut > 0, "Pool: INSUFFICIENT_OUTPUT");

        _executeSwap(address(tokenA), address(tokenB), amountAIn, amountBOut);
        _updateReserves(reserveA + amountAIn, reserveB - amountBOut);

        emit Swap(msg.sender, address(tokenA), amountAIn, amountBOut);
    }

    function swapBForA(uint256 amountBIn) external lock returns (uint256 amountAOut) {
        require(amountBIn > 0, "Pool: INSUFFICIENT_INPUT");

        amountAOut = _calculateSwapOutput(amountBIn, reserveB, reserveA);
        require(amountAOut > 0, "Pool: INSUFFICIENT_OUTPUT");

        _executeSwap(address(tokenB), address(tokenA), amountBIn, amountAOut);
        _updateReserves(reserveA - amountAOut, reserveB + amountBIn);

        emit Swap(msg.sender, address(tokenB), amountBIn, amountAOut);
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    function getUserLiquidity(address user) external view returns (uint256) {
        return liquidity[user];
    }

    function _transferTokensFrom(address from, uint256 amountA, uint256 amountB) private {
        require(tokenA.transferFrom(from, address(this), amountA), "Pool: TRANSFER_A_FAILED");
        require(tokenB.transferFrom(from, address(this), amountB), "Pool: TRANSFER_B_FAILED");
    }

    function _transferTokensTo(address to, uint256 amountA, uint256 amountB) private {
        require(tokenA.transfer(to, amountA), "Pool: TRANSFER_A_FAILED");
        require(tokenB.transfer(to, amountB), "Pool: TRANSFER_B_FAILED");
    }

    function _calculateInitialLiquidity(uint256 amountA, uint256 amountB) private pure returns (uint256) {
        uint256 liquidity = _sqrt(amountA * amountB);
        require(liquidity > MINIMUM_LIQUIDITY, "Pool: INSUFFICIENT_LIQUIDITY_MINTED");
        return liquidity - MINIMUM_LIQUIDITY;
    }

    function _calculateLiquidity(uint256 amountA, uint256 amountB) private view returns (uint256) {
        uint256 liquidityA = (amountA * totalLiquidity) / reserveA;
        uint256 liquidityB = (amountB * totalLiquidity) / reserveB;
        return liquidityA < liquidityB ? liquidityA : liquidityB;
    }

    function _calculateWithdrawal(uint256 liquidityAmount) private view returns (uint256, uint256) {
        uint256 amountA = (liquidityAmount * reserveA) / totalLiquidity;
        uint256 amountB = (liquidityAmount * reserveB) / totalLiquidity;
        return (amountA, amountB);
    }

    function _calculateSwapOutput(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) private pure returns (uint256) {
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        return numerator / denominator;
    }

    function _executeSwap(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut) private {
        require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "Pool: TRANSFER_IN_FAILED");
        require(IERC20(tokenOut).transfer(msg.sender, amountOut), "Pool: TRANSFER_OUT_FAILED");
    }

    function _updateReservesAndLiquidity(uint256 amountA, uint256 amountB, uint256 liquidityMinted) private {
        reserveA += amountA;
        reserveB += amountB;
        totalLiquidity += liquidityMinted;
        liquidity[msg.sender] += liquidityMinted;
    }

    function _burnLiquidity(address user, uint256 amount) private {
        liquidity[user] -= amount;
        totalLiquidity -= amount;
    }

    function _updateReserves(uint256 newReserveA, uint256 newReserveB) private {
        reserveA = newReserveA;
        reserveB = newReserveB;
    }

    function _sqrt(uint256 y) private pure returns (uint256 z) {
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
}
