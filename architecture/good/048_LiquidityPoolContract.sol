
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

library LiquidityMath {
    uint256 public constant MINIMUM_LIQUIDITY = 10**3;

    function sqrt(uint256 y) internal pure returns (uint256 z) {
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

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

contract LiquidityPoolContract is ERC20, ReentrancyGuard, Ownable {
    using LiquidityMath for uint256;


    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant DEFAULT_FEE = 30;
    uint256 public constant MAX_FEE = 100;


    IERC20 public immutable token0;
    IERC20 public immutable token1;

    uint256 public reserve0;
    uint256 public reserve1;
    uint256 public fee;
    uint256 public protocolFeeShare;

    uint256 private unlocked = 1;


    event Mint(address indexed sender, uint256 amount0, uint256 amount1, uint256 liquidity);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint256 reserve0, uint256 reserve1);
    event FeeUpdated(uint256 newFee);
    event ProtocolFeeUpdated(uint256 newProtocolFeeShare);


    modifier lock() {
        require(unlocked == 1, "LiquidityPool: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    modifier validAddress(address _address) {
        require(_address != address(0), "LiquidityPool: ZERO_ADDRESS");
        _;
    }

    modifier validAmount(uint256 amount) {
        require(amount > 0, "LiquidityPool: INSUFFICIENT_AMOUNT");
        _;
    }

    modifier validFee(uint256 _fee) {
        require(_fee <= MAX_FEE, "LiquidityPool: FEE_TOO_HIGH");
        _;
    }

    constructor(
        address _token0,
        address _token1,
        string memory _name,
        string memory _symbol
    )
        ERC20(_name, _symbol)
        validAddress(_token0)
        validAddress(_token1)
    {
        require(_token0 != _token1, "LiquidityPool: IDENTICAL_ADDRESSES");
        require(_token0 < _token1, "LiquidityPool: UNSORTED_TOKENS");

        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        fee = DEFAULT_FEE;
        protocolFeeShare = 0;
    }

    function addLiquidity(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        address to
    )
        external
        nonReentrant
        lock
        validAddress(to)
        validAmount(amount0Desired)
        validAmount(amount1Desired)
        returns (uint256 amount0, uint256 amount1, uint256 liquidity)
    {
        (amount0, amount1) = _calculateOptimalAmounts(
            amount0Desired,
            amount1Desired,
            amount0Min,
            amount1Min
        );

        liquidity = _mint(amount0, amount1, to);
    }

    function removeLiquidity(
        uint256 liquidity,
        uint256 amount0Min,
        uint256 amount1Min,
        address to
    )
        external
        nonReentrant
        lock
        validAddress(to)
        validAmount(liquidity)
        returns (uint256 amount0, uint256 amount1)
    {
        require(balanceOf(msg.sender) >= liquidity, "LiquidityPool: INSUFFICIENT_LIQUIDITY_BALANCE");

        (amount0, amount1) = _burn(liquidity, to);

        require(amount0 >= amount0Min, "LiquidityPool: INSUFFICIENT_A_AMOUNT");
        require(amount1 >= amount1Min, "LiquidityPool: INSUFFICIENT_B_AMOUNT");
    }

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to
    )
        external
        nonReentrant
        lock
        validAddress(to)
    {
        require(amount0Out > 0 || amount1Out > 0, "LiquidityPool: INSUFFICIENT_OUTPUT_AMOUNT");
        require(amount0Out < reserve0 && amount1Out < reserve1, "LiquidityPool: INSUFFICIENT_LIQUIDITY");

        uint256 balance0Before = token0.balanceOf(address(this));
        uint256 balance1Before = token1.balanceOf(address(this));

        if (amount0Out > 0) _safeTransfer(token0, to, amount0Out);
        if (amount1Out > 0) _safeTransfer(token1, to, amount1Out);

        uint256 balance0After = token0.balanceOf(address(this));
        uint256 balance1After = token1.balanceOf(address(this));

        uint256 amount0In = balance0After > balance0Before - amount0Out ?
            balance0After - (balance0Before - amount0Out) : 0;
        uint256 amount1In = balance1After > balance1Before - amount1Out ?
            balance1After - (balance1Before - amount1Out) : 0;

        require(amount0In > 0 || amount1In > 0, "LiquidityPool: INSUFFICIENT_INPUT_AMOUNT");

        _validateSwap(balance0After, balance1After, amount0In, amount1In);

        _update(balance0After, balance1After);

        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    function sync() external lock {
        _update(token0.balanceOf(address(this)), token1.balanceOf(address(this)));
    }

    function setFee(uint256 _fee) external onlyOwner validFee(_fee) {
        fee = _fee;
        emit FeeUpdated(_fee);
    }

    function setProtocolFeeShare(uint256 _protocolFeeShare) external onlyOwner {
        require(_protocolFeeShare <= 100, "LiquidityPool: INVALID_PROTOCOL_FEE");
        protocolFeeShare = _protocolFeeShare;
        emit ProtocolFeeUpdated(_protocolFeeShare);
    }

    function getReserves() external view returns (uint256 _reserve0, uint256 _reserve1) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        external
        view
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "LiquidityPool: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "LiquidityPool: INSUFFICIENT_LIQUIDITY");

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - fee);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * FEE_DENOMINATOR + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function _calculateOptimalAmounts(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) private view returns (uint256 amount0, uint256 amount1) {
        if (reserve0 == 0 && reserve1 == 0) {
            (amount0, amount1) = (amount0Desired, amount1Desired);
        } else {
            uint256 amount1Optimal = _quote(amount0Desired, reserve0, reserve1);
            if (amount1Optimal <= amount1Desired) {
                require(amount1Optimal >= amount1Min, "LiquidityPool: INSUFFICIENT_B_AMOUNT");
                (amount0, amount1) = (amount0Desired, amount1Optimal);
            } else {
                uint256 amount0Optimal = _quote(amount1Desired, reserve1, reserve0);
                require(amount0Optimal <= amount0Desired && amount0Optimal >= amount0Min,
                    "LiquidityPool: INSUFFICIENT_A_AMOUNT");
                (amount0, amount1) = (amount0Optimal, amount1Desired);
            }
        }
    }

    function _mint(uint256 amount0, uint256 amount1, address to) private returns (uint256 liquidity) {
        _safeTransferFrom(token0, msg.sender, address(this), amount0);
        _safeTransferFrom(token1, msg.sender, address(this), amount1);

        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));

        uint256 _totalSupply = totalSupply();

        if (_totalSupply == 0) {
            liquidity = LiquidityMath.sqrt(amount0 * amount1) - LiquidityMath.MINIMUM_LIQUIDITY;
            _mint(address(0), LiquidityMath.MINIMUM_LIQUIDITY);
        } else {
            liquidity = LiquidityMath.min(
                amount0 * _totalSupply / reserve0,
                amount1 * _totalSupply / reserve1
            );
        }

        require(liquidity > 0, "LiquidityPool: INSUFFICIENT_LIQUIDITY_MINTED");

        _mint(to, liquidity);
        _update(balance0, balance1);

        emit Mint(msg.sender, amount0, amount1, liquidity);
    }

    function _burn(uint256 liquidity, address to) private returns (uint256 amount0, uint256 amount1) {
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));
        uint256 _totalSupply = totalSupply();

        amount0 = liquidity * balance0 / _totalSupply;
        amount1 = liquidity * balance1 / _totalSupply;

        require(amount0 > 0 && amount1 > 0, "LiquidityPool: INSUFFICIENT_LIQUIDITY_BURNED");

        _burn(msg.sender, liquidity);

        _safeTransfer(token0, to, amount0);
        _safeTransfer(token1, to, amount1);

        balance0 = token0.balanceOf(address(this));
        balance1 = token1.balanceOf(address(this));

        _update(balance0, balance1);

        emit Burn(msg.sender, amount0, amount1, to);
    }

    function _validateSwap(
        uint256 balance0,
        uint256 balance1,
        uint256 amount0In,
        uint256 amount1In
    ) private view {
        uint256 balance0Adjusted = balance0 * FEE_DENOMINATOR - amount0In * fee;
        uint256 balance1Adjusted = balance1 * FEE_DENOMINATOR - amount1In * fee;

        require(
            balance0Adjusted * balance1Adjusted >=
            uint256(reserve0) * uint256(reserve1) * (FEE_DENOMINATOR ** 2),
            "LiquidityPool: K"
        );
    }

    function _update(uint256 balance0, uint256 balance1) private {
        reserve0 = balance0;
        reserve1 = balance1;
        emit Sync(reserve0, reserve1);
    }

    function _quote(uint256 amountA, uint256 reserveA, uint256 reserveB)
        private
        pure
        returns (uint256 amountB)
    {
        require(amountA > 0, "LiquidityPool: INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "LiquidityPool: INSUFFICIENT_LIQUIDITY");
        amountB = amountA * reserveB / reserveA;
    }

    function _safeTransfer(IERC20 token, address to, uint256 value) private {
        require(token.transfer(to, value), "LiquidityPool: TRANSFER_FAILED");
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 value) private {
        require(token.transferFrom(from, to, value), "LiquidityPool: TRANSFER_FROM_FAILED");
    }
}
