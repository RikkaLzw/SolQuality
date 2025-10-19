
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
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    uint256 private constant MINIMUM_LIQUIDITY = 10**3;

    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed to, uint256 amount);
    event Swap(address indexed to, uint256 amountIn, uint256 amountOut);
    event Sync(uint256 reserveA, uint256 reserveB);

    constructor(address _tokenA, address _tokenB) {
        require(_tokenA != address(0), "Invalid tokenA");
        require(_tokenB != address(0), "Invalid tokenB");
        require(_tokenA != _tokenB, "Identical tokens");

        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external returns (uint256 liquidity) {
        require(amountA > 0 && amountB > 0, "Invalid amounts");

        _transferFrom(tokenA, msg.sender, amountA);
        _transferFrom(tokenB, msg.sender, amountB);

        liquidity = _calculateLiquidity(amountA, amountB);
        require(liquidity > 0, "Insufficient liquidity");

        _mint(msg.sender, liquidity);
        _updateReserves();

        emit Mint(msg.sender, liquidity);
    }

    function removeLiquidity(uint256 liquidity) external returns (uint256 amountA, uint256 amountB) {
        require(liquidity > 0, "Invalid liquidity");
        require(balanceOf[msg.sender] >= liquidity, "Insufficient balance");

        (amountA, amountB) = _calculateWithdrawAmounts(liquidity);
        require(amountA > 0 && amountB > 0, "Insufficient liquidity burned");

        _burn(msg.sender, liquidity);
        _safeTransfer(tokenA, msg.sender, amountA);
        _safeTransfer(tokenB, msg.sender, amountB);
        _updateReserves();

        emit Burn(msg.sender, liquidity);
    }

    function swapAForB(uint256 amountAIn) external returns (uint256 amountBOut) {
        require(amountAIn > 0, "Invalid input amount");

        amountBOut = _getAmountOut(amountAIn, reserveA, reserveB);
        require(amountBOut > 0, "Insufficient output amount");

        _transferFrom(tokenA, msg.sender, amountAIn);
        _safeTransfer(tokenB, msg.sender, amountBOut);
        _updateReserves();

        emit Swap(msg.sender, amountAIn, amountBOut);
    }

    function swapBForA(uint256 amountBIn) external returns (uint256 amountAOut) {
        require(amountBIn > 0, "Invalid input amount");

        amountAOut = _getAmountOut(amountBIn, reserveB, reserveA);
        require(amountAOut > 0, "Insufficient output amount");

        _transferFrom(tokenB, msg.sender, amountBIn);
        _safeTransfer(tokenA, msg.sender, amountAOut);
        _updateReserves();

        emit Swap(msg.sender, amountBIn, amountAOut);
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    function _calculateLiquidity(uint256 amountA, uint256 amountB) private view returns (uint256) {
        if (totalSupply == 0) {
            return _sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
        }

        uint256 liquidityA = (amountA * totalSupply) / reserveA;
        uint256 liquidityB = (amountB * totalSupply) / reserveB;

        return liquidityA < liquidityB ? liquidityA : liquidityB;
    }

    function _calculateWithdrawAmounts(uint256 liquidity) private view returns (uint256, uint256) {
        uint256 amountA = (liquidity * reserveA) / totalSupply;
        uint256 amountB = (liquidity * reserveB) / totalSupply;
        return (amountA, amountB);
    }

    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) private pure returns (uint256) {
        require(amountIn > 0, "Invalid input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;

        return numerator / denominator;
    }

    function _mint(address to, uint256 amount) private {
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    function _burn(address from, uint256 amount) private {
        balanceOf[from] -= amount;
        totalSupply -= amount;
    }

    function _updateReserves() private {
        reserveA = tokenA.balanceOf(address(this));
        reserveB = tokenB.balanceOf(address(this));
        emit Sync(reserveA, reserveB);
    }

    function _transferFrom(IERC20 token, address from, uint256 amount) private {
        require(token.transferFrom(from, address(this), amount), "Transfer failed");
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) private {
        require(token.transfer(to, amount), "Transfer failed");
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
