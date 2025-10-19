
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
    uint256 private constant FEE_RATE = 3;
    uint256 private constant FEE_DENOMINATOR = 1000;


    event LiquidityAdded(
        address indexed provider,
        uint256 indexed amountA,
        uint256 indexed amountB,
        uint256 liquidity
    );

    event LiquidityRemoved(
        address indexed provider,
        uint256 indexed amountA,
        uint256 indexed amountB,
        uint256 liquidity
    );

    event TokensSwapped(
        address indexed trader,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    event ReservesUpdated(uint256 reserveA, uint256 reserveB);


    error InsufficientLiquidity();
    error InvalidTokenAmount();
    error InsufficientInputAmount();
    error InsufficientOutputAmount();
    error TransferFailed();
    error ZeroAddress();
    error IdenticalTokens();
    error InsufficientLiquidityBalance();

    constructor(address _tokenA, address _tokenB) {
        if (_tokenA == address(0) || _tokenB == address(0)) {
            revert ZeroAddress();
        }
        if (_tokenA == _tokenB) {
            revert IdenticalTokens();
        }

        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external returns (uint256 liquidity) {
        if (amountA == 0 || amountB == 0) {
            revert InvalidTokenAmount();
        }


        if (!tokenA.transferFrom(msg.sender, address(this), amountA)) {
            revert TransferFailed();
        }
        if (!tokenB.transferFrom(msg.sender, address(this), amountB)) {
            revert TransferFailed();
        }

        if (totalLiquidity == 0) {

            liquidity = _sqrt(amountA * amountB);
            if (liquidity <= MINIMUM_LIQUIDITY) {
                revert InsufficientLiquidity();
            }
            liquidity -= MINIMUM_LIQUIDITY;
        } else {

            uint256 liquidityA = (amountA * totalLiquidity) / reserveA;
            uint256 liquidityB = (amountB * totalLiquidity) / reserveB;
            liquidity = liquidityA < liquidityB ? liquidityA : liquidityB;

            if (liquidity == 0) {
                revert InsufficientLiquidity();
            }
        }

        liquidityBalance[msg.sender] += liquidity;
        totalLiquidity += liquidity;

        _updateReserves();

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }

    function removeLiquidity(uint256 liquidity) external returns (uint256 amountA, uint256 amountB) {
        if (liquidity == 0) {
            revert InvalidTokenAmount();
        }
        if (liquidityBalance[msg.sender] < liquidity) {
            revert InsufficientLiquidityBalance();
        }

        uint256 totalSupply = totalLiquidity;
        amountA = (liquidity * reserveA) / totalSupply;
        amountB = (liquidity * reserveB) / totalSupply;

        if (amountA == 0 || amountB == 0) {
            revert InsufficientLiquidity();
        }

        liquidityBalance[msg.sender] -= liquidity;
        totalLiquidity -= liquidity;

        if (!tokenA.transfer(msg.sender, amountA)) {
            revert TransferFailed();
        }
        if (!tokenB.transfer(msg.sender, amountB)) {
            revert TransferFailed();
        }

        _updateReserves();

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);
    }

    function swapAForB(uint256 amountAIn, uint256 minAmountBOut) external returns (uint256 amountBOut) {
        if (amountAIn == 0) {
            revert InsufficientInputAmount();
        }

        amountBOut = getAmountOut(amountAIn, reserveA, reserveB);
        if (amountBOut < minAmountBOut) {
            revert InsufficientOutputAmount();
        }

        if (!tokenA.transferFrom(msg.sender, address(this), amountAIn)) {
            revert TransferFailed();
        }
        if (!tokenB.transfer(msg.sender, amountBOut)) {
            revert TransferFailed();
        }

        _updateReserves();

        emit TokensSwapped(msg.sender, address(tokenA), address(tokenB), amountAIn, amountBOut);
    }

    function swapBForA(uint256 amountBIn, uint256 minAmountAOut) external returns (uint256 amountAOut) {
        if (amountBIn == 0) {
            revert InsufficientInputAmount();
        }

        amountAOut = getAmountOut(amountBIn, reserveB, reserveA);
        if (amountAOut < minAmountAOut) {
            revert InsufficientOutputAmount();
        }

        if (!tokenB.transferFrom(msg.sender, address(this), amountBIn)) {
            revert TransferFailed();
        }
        if (!tokenA.transfer(msg.sender, amountAOut)) {
            revert TransferFailed();
        }

        _updateReserves();

        emit TokensSwapped(msg.sender, address(tokenB), address(tokenA), amountBIn, amountAOut);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        returns (uint256 amountOut)
    {
        if (amountIn == 0) {
            revert InsufficientInputAmount();
        }
        if (reserveIn == 0 || reserveOut == 0) {
            revert InsufficientLiquidity();
        }

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_RATE);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    function _updateReserves() private {
        reserveA = tokenA.balanceOf(address(this));
        reserveB = tokenB.balanceOf(address(this));
        emit ReservesUpdated(reserveA, reserveB);
    }

    function _sqrt(uint256 x) private pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
