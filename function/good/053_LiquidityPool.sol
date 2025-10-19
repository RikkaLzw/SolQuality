
pragma solidity ^0.8.19;

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
    uint256 private unlocked = 1;

    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed to, uint256 amount);
    event Swap(address indexed to, uint256 amountIn, uint256 amountOut);
    event Sync(uint256 reserveA, uint256 reserveB);

    modifier lock() {
        require(unlocked == 1, "LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor(address _tokenA, address _tokenB) {
        require(_tokenA != address(0) && _tokenB != address(0), "ZERO_ADDRESS");
        require(_tokenA != _tokenB, "IDENTICAL_ADDRESSES");
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external lock returns (uint256 liquidity) {
        require(amountA > 0 && amountB > 0, "INSUFFICIENT_AMOUNT");

        _safeTransferFrom(tokenA, msg.sender, amountA);
        _safeTransferFrom(tokenB, msg.sender, amountB);

        liquidity = _mintLiquidity(msg.sender, amountA, amountB);
        _updateReserves();
    }

    function removeLiquidity(uint256 liquidity) external lock returns (uint256 amountA, uint256 amountB) {
        require(liquidity > 0, "INSUFFICIENT_LIQUIDITY");
        require(balanceOf[msg.sender] >= liquidity, "INSUFFICIENT_BALANCE");

        (amountA, amountB) = _calculateWithdrawAmounts(liquidity);

        _burnLiquidity(msg.sender, liquidity);
        _safeTransfer(tokenA, msg.sender, amountA);
        _safeTransfer(tokenB, msg.sender, amountB);

        _updateReserves();
    }

    function swapAForB(uint256 amountIn) external lock returns (uint256 amountOut) {
        require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");

        amountOut = _getAmountOut(amountIn, reserveA, reserveB);
        require(amountOut > 0, "INSUFFICIENT_OUTPUT_AMOUNT");

        _safeTransferFrom(tokenA, msg.sender, amountIn);
        _safeTransfer(tokenB, msg.sender, amountOut);

        _updateReserves();
        emit Swap(msg.sender, amountIn, amountOut);
    }

    function swapBForA(uint256 amountIn) external lock returns (uint256 amountOut) {
        require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");

        amountOut = _getAmountOut(amountIn, reserveB, reserveA);
        require(amountOut > 0, "INSUFFICIENT_OUTPUT_AMOUNT");

        _safeTransferFrom(tokenB, msg.sender, amountIn);
        _safeTransfer(tokenA, msg.sender, amountOut);

        _updateReserves();
        emit Swap(msg.sender, amountIn, amountOut);
    }

    function _mintLiquidity(address to, uint256 amountA, uint256 amountB) private returns (uint256 liquidity) {
        if (totalSupply == 0) {
            liquidity = _sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
            balanceOf[address(0)] = MINIMUM_LIQUIDITY;
        } else {
            liquidity = _min(
                (amountA * totalSupply) / reserveA,
                (amountB * totalSupply) / reserveB
            );
        }

        require(liquidity > 0, "INSUFFICIENT_LIQUIDITY_MINTED");
        balanceOf[to] += liquidity;
        totalSupply += liquidity;

        emit Mint(to, liquidity);
    }

    function _burnLiquidity(address from, uint256 liquidity) private {
        balanceOf[from] -= liquidity;
        totalSupply -= liquidity;

        emit Burn(from, liquidity);
    }

    function _calculateWithdrawAmounts(uint256 liquidity) private view returns (uint256 amountA, uint256 amountB) {
        amountA = (liquidity * reserveA) / totalSupply;
        amountB = (liquidity * reserveB) / totalSupply;

        require(amountA > 0 && amountB > 0, "INSUFFICIENT_LIQUIDITY_BURNED");
    }

    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) private pure returns (uint256) {
        require(amountIn > 0 && reserveIn > 0 && reserveOut > 0, "INVALID_RESERVES");

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;

        return numerator / denominator;
    }

    function _updateReserves() private {
        reserveA = tokenA.balanceOf(address(this));
        reserveB = tokenB.balanceOf(address(this));

        emit Sync(reserveA, reserveB);
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) private {
        require(token.transfer(to, amount), "TRANSFER_FAILED");
    }

    function _safeTransferFrom(IERC20 token, address from, uint256 amount) private {
        require(token.transferFrom(from, address(this), amount), "TRANSFER_FROM_FAILED");
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
