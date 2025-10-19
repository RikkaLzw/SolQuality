
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

    uint256 private constant MINIMUM_LIQUIDITY = 1000;

    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed to, uint256 amount);
    event Swap(address indexed user, uint256 amountIn, uint256 amountOut, bool aToB);
    event Sync(uint256 reserveA, uint256 reserveB);

    modifier nonZero(uint256 amount) {
        require(amount > 0, "Amount must be greater than zero");
        _;
    }

    constructor(address _tokenA, address _tokenB) {
        require(_tokenA != address(0) && _tokenB != address(0), "Invalid token addresses");
        require(_tokenA != _tokenB, "Tokens must be different");
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external nonZero(amountA) nonZero(amountB) returns (uint256 liquidity) {
        _transferFrom(tokenA, msg.sender, amountA);
        _transferFrom(tokenB, msg.sender, amountB);

        liquidity = _mintLiquidity(msg.sender, amountA, amountB);
        _updateReserves();
    }

    function removeLiquidity(uint256 liquidity) external nonZero(liquidity) returns (uint256 amountA, uint256 amountB) {
        require(balanceOf[msg.sender] >= liquidity, "Insufficient liquidity balance");

        (amountA, amountB) = _calculateWithdrawAmounts(liquidity);
        _burnLiquidity(msg.sender, liquidity);

        _transfer(tokenA, msg.sender, amountA);
        _transfer(tokenB, msg.sender, amountB);
        _updateReserves();
    }

    function swapAForB(uint256 amountIn) external nonZero(amountIn) returns (uint256 amountOut) {
        amountOut = _getAmountOut(amountIn, reserveA, reserveB);

        _transferFrom(tokenA, msg.sender, amountIn);
        _transfer(tokenB, msg.sender, amountOut);
        _updateReserves();

        emit Swap(msg.sender, amountIn, amountOut, true);
    }

    function swapBForA(uint256 amountIn) external nonZero(amountIn) returns (uint256 amountOut) {
        amountOut = _getAmountOut(amountIn, reserveB, reserveA);

        _transferFrom(tokenB, msg.sender, amountIn);
        _transfer(tokenA, msg.sender, amountOut);
        _updateReserves();

        emit Swap(msg.sender, amountIn, amountOut, false);
    }

    function getAmountOut(uint256 amountIn, bool aToB) external view returns (uint256) {
        if (aToB) {
            return _getAmountOut(amountIn, reserveA, reserveB);
        } else {
            return _getAmountOut(amountIn, reserveB, reserveA);
        }
    }

    function _mintLiquidity(address to, uint256 amountA, uint256 amountB) internal returns (uint256 liquidity) {
        if (totalSupply == 0) {
            liquidity = _sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
            balanceOf[address(0)] = MINIMUM_LIQUIDITY;
            totalSupply = MINIMUM_LIQUIDITY;
        } else {
            uint256 liquidityA = (amountA * totalSupply) / reserveA;
            uint256 liquidityB = (amountB * totalSupply) / reserveB;
            liquidity = liquidityA < liquidityB ? liquidityA : liquidityB;
        }

        require(liquidity > 0, "Insufficient liquidity minted");
        balanceOf[to] += liquidity;
        totalSupply += liquidity;

        emit Mint(to, liquidity);
    }

    function _burnLiquidity(address from, uint256 liquidity) internal {
        balanceOf[from] -= liquidity;
        totalSupply -= liquidity;

        emit Burn(from, liquidity);
    }

    function _calculateWithdrawAmounts(uint256 liquidity) internal view returns (uint256 amountA, uint256 amountB) {
        amountA = (liquidity * reserveA) / totalSupply;
        amountB = (liquidity * reserveB) / totalSupply;

        require(amountA > 0 && amountB > 0, "Insufficient liquidity burned");
    }

    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256) {
        require(amountIn > 0 && reserveIn > 0 && reserveOut > 0, "Invalid input");

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;

        return numerator / denominator;
    }

    function _transferFrom(IERC20 token, address from, uint256 amount) internal {
        require(token.transferFrom(from, address(this), amount), "Transfer failed");
    }

    function _transfer(IERC20 token, address to, uint256 amount) internal {
        require(token.transfer(to, amount), "Transfer failed");
    }

    function _updateReserves() internal {
        reserveA = tokenA.balanceOf(address(this));
        reserveB = tokenB.balanceOf(address(this));

        emit Sync(reserveA, reserveB);
    }

    function _sqrt(uint256 x) internal pure returns (uint256) {
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
