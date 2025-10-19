
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

    mapping(address => uint256) public liquidityBalance;

    uint256 private constant MINIMUM_LIQUIDITY = 1000;
    uint256 private unlocked = 1;

    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event Swap(address indexed user, address tokenIn, uint256 amountIn, uint256 amountOut);

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

    function addLiquidity(uint256 amountA, uint256 amountB) external lock returns (uint256 liquidity) {
        require(amountA > 0 && amountB > 0, "Pool: INSUFFICIENT_AMOUNT");

        _transferFrom(tokenA, msg.sender, amountA);
        _transferFrom(tokenB, msg.sender, amountB);

        if (totalLiquidity == 0) {
            liquidity = _sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
            totalLiquidity = liquidity + MINIMUM_LIQUIDITY;
        } else {
            liquidity = _min(
                (amountA * totalLiquidity) / reserveA,
                (amountB * totalLiquidity) / reserveB
            );
            totalLiquidity += liquidity;
        }

        require(liquidity > 0, "Pool: INSUFFICIENT_LIQUIDITY_MINTED");

        liquidityBalance[msg.sender] += liquidity;
        reserveA += amountA;
        reserveB += amountB;

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }

    function removeLiquidity(uint256 liquidity) external lock returns (uint256 amountA, uint256 amountB) {
        require(liquidity > 0, "Pool: INSUFFICIENT_LIQUIDITY");
        require(liquidityBalance[msg.sender] >= liquidity, "Pool: INSUFFICIENT_BALANCE");

        amountA = (liquidity * reserveA) / totalLiquidity;
        amountB = (liquidity * reserveB) / totalLiquidity;

        require(amountA > 0 && amountB > 0, "Pool: INSUFFICIENT_LIQUIDITY_BURNED");

        liquidityBalance[msg.sender] -= liquidity;
        totalLiquidity -= liquidity;
        reserveA -= amountA;
        reserveB -= amountB;

        _transfer(tokenA, msg.sender, amountA);
        _transfer(tokenB, msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);
    }

    function swapAForB(uint256 amountIn) external lock returns (uint256 amountOut) {
        require(amountIn > 0, "Pool: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "Pool: INSUFFICIENT_LIQUIDITY");

        amountOut = _getAmountOut(amountIn, reserveA, reserveB);
        require(amountOut > 0, "Pool: INSUFFICIENT_OUTPUT_AMOUNT");

        _transferFrom(tokenA, msg.sender, amountIn);
        _transfer(tokenB, msg.sender, amountOut);

        reserveA += amountIn;
        reserveB -= amountOut;

        emit Swap(msg.sender, address(tokenA), amountIn, amountOut);
    }

    function swapBForA(uint256 amountIn) external lock returns (uint256 amountOut) {
        require(amountIn > 0, "Pool: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "Pool: INSUFFICIENT_LIQUIDITY");

        amountOut = _getAmountOut(amountIn, reserveB, reserveA);
        require(amountOut > 0, "Pool: INSUFFICIENT_OUTPUT_AMOUNT");

        _transferFrom(tokenB, msg.sender, amountIn);
        _transfer(tokenA, msg.sender, amountOut);

        reserveB += amountIn;
        reserveA -= amountOut;

        emit Swap(msg.sender, address(tokenB), amountIn, amountOut);
    }

    function getAmountOut(uint256 amountIn, bool isTokenA) external view returns (uint256) {
        if (isTokenA) {
            return _getAmountOut(amountIn, reserveA, reserveB);
        } else {
            return _getAmountOut(amountIn, reserveB, reserveA);
        }
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) private pure returns (uint256) {
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        return numerator / denominator;
    }

    function _transferFrom(IERC20 token, address from, uint256 amount) private {
        require(token.transferFrom(from, address(this), amount), "Pool: TRANSFER_FROM_FAILED");
    }

    function _transfer(IERC20 token, address to, uint256 amount) private {
        require(token.transfer(to, amount), "Pool: TRANSFER_FAILED");
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

    function _min(uint256 x, uint256 y) private pure returns (uint256) {
        return x < y ? x : y;
    }
}
