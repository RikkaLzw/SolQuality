
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
    event Swap(address indexed user, uint256 amountIn, uint256 amountOut, bool tokenAToB);

    modifier lock() {
        require(unlocked == 1, "LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor(address _tokenA, address _tokenB) {
        require(_tokenA != address(0) && _tokenB != address(0), "ZERO_ADDRESS");
        require(_tokenA != _tokenB, "IDENTICAL_TOKENS");
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external lock returns (uint256 liquidityMinted) {
        require(amountA > 0 && amountB > 0, "INVALID_AMOUNTS");

        _transferTokensFrom(msg.sender, amountA, amountB);

        if (totalLiquidity == 0) {
            liquidityMinted = _calculateInitialLiquidity(amountA, amountB);
        } else {
            liquidityMinted = _calculateLiquidityToMint(amountA, amountB);
        }

        _mintLiquidity(msg.sender, liquidityMinted);
        _updateReserves(reserveA + amountA, reserveB + amountB);

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidityMinted);
    }

    function removeLiquidity(uint256 liquidityAmount) external lock returns (uint256 amountA, uint256 amountB) {
        require(liquidityAmount > 0, "INVALID_LIQUIDITY");
        require(liquidity[msg.sender] >= liquidityAmount, "INSUFFICIENT_LIQUIDITY");

        (amountA, amountB) = _calculateTokensToReturn(liquidityAmount);

        _burnLiquidity(msg.sender, liquidityAmount);
        _transferTokensTo(msg.sender, amountA, amountB);
        _updateReserves(reserveA - amountA, reserveB - amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidityAmount);
    }

    function swapAForB(uint256 amountAIn) external lock returns (uint256 amountBOut) {
        require(amountAIn > 0, "INVALID_AMOUNT");

        amountBOut = _calculateSwapOutput(amountAIn, reserveA, reserveB);
        require(amountBOut > 0, "INSUFFICIENT_OUTPUT");

        _executeSwap(msg.sender, amountAIn, amountBOut, true);

        emit Swap(msg.sender, amountAIn, amountBOut, true);
    }

    function swapBForA(uint256 amountBIn) external lock returns (uint256 amountAOut) {
        require(amountBIn > 0, "INVALID_AMOUNT");

        amountAOut = _calculateSwapOutput(amountBIn, reserveB, reserveA);
        require(amountAOut > 0, "INSUFFICIENT_OUTPUT");

        _executeSwap(msg.sender, amountBIn, amountAOut, false);

        emit Swap(msg.sender, amountBIn, amountAOut, false);
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    function getSwapOutput(uint256 amountIn, bool tokenAToB) external view returns (uint256) {
        if (tokenAToB) {
            return _calculateSwapOutput(amountIn, reserveA, reserveB);
        } else {
            return _calculateSwapOutput(amountIn, reserveB, reserveA);
        }
    }

    function _transferTokensFrom(address from, uint256 amountA, uint256 amountB) private {
        require(tokenA.transferFrom(from, address(this), amountA), "TRANSFER_A_FAILED");
        require(tokenB.transferFrom(from, address(this), amountB), "TRANSFER_B_FAILED");
    }

    function _transferTokensTo(address to, uint256 amountA, uint256 amountB) private {
        require(tokenA.transfer(to, amountA), "TRANSFER_A_FAILED");
        require(tokenB.transfer(to, amountB), "TRANSFER_B_FAILED");
    }

    function _calculateInitialLiquidity(uint256 amountA, uint256 amountB) private pure returns (uint256) {
        uint256 liquidityMinted = _sqrt(amountA * amountB);
        require(liquidityMinted > MINIMUM_LIQUIDITY, "INSUFFICIENT_LIQUIDITY_MINTED");
        return liquidityMinted - MINIMUM_LIQUIDITY;
    }

    function _calculateLiquidityToMint(uint256 amountA, uint256 amountB) private view returns (uint256) {
        uint256 liquidityA = (amountA * totalLiquidity) / reserveA;
        uint256 liquidityB = (amountB * totalLiquidity) / reserveB;
        return liquidityA < liquidityB ? liquidityA : liquidityB;
    }

    function _calculateTokensToReturn(uint256 liquidityAmount) private view returns (uint256, uint256) {
        uint256 amountA = (liquidityAmount * reserveA) / totalLiquidity;
        uint256 amountB = (liquidityAmount * reserveB) / totalLiquidity;
        return (amountA, amountB);
    }

    function _calculateSwapOutput(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) private pure returns (uint256) {
        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        return numerator / denominator;
    }

    function _executeSwap(address user, uint256 amountIn, uint256 amountOut, bool tokenAToB) private {
        if (tokenAToB) {
            require(tokenA.transferFrom(user, address(this), amountIn), "TRANSFER_IN_FAILED");
            require(tokenB.transfer(user, amountOut), "TRANSFER_OUT_FAILED");
            _updateReserves(reserveA + amountIn, reserveB - amountOut);
        } else {
            require(tokenB.transferFrom(user, address(this), amountIn), "TRANSFER_IN_FAILED");
            require(tokenA.transfer(user, amountOut), "TRANSFER_OUT_FAILED");
            _updateReserves(reserveA - amountOut, reserveB + amountIn);
        }
    }

    function _mintLiquidity(address to, uint256 amount) private {
        liquidity[to] += amount;
        totalLiquidity += amount;
    }

    function _burnLiquidity(address from, uint256 amount) private {
        liquidity[from] -= amount;
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
