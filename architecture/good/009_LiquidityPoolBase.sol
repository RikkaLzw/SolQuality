
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

library LiquidityPoolMath {
    uint256 internal constant MINIMUM_LIQUIDITY = 10**3;

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

    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }
}

abstract contract LiquidityPoolBase is ERC20, ReentrancyGuard, Ownable {
    using LiquidityPoolMath for uint256;


    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MAX_FEE = 300;
    uint256 public constant MINIMUM_LIQUIDITY = LiquidityPoolMath.MINIMUM_LIQUIDITY;


    IERC20 public immutable token0;
    IERC20 public immutable token1;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    uint256 public swapFee = 30;
    uint256 public totalFeeCollected0;
    uint256 public totalFeeCollected1;

    bool private unlocked = true;


    event Mint(address indexed sender, uint256 amount0, uint256 amount1, uint256 liquidity);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, uint256 liquidity, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);
    event FeeUpdated(uint256 oldFee, uint256 newFee);


    modifier lock() {
        require(unlocked, "LiquidityPool: LOCKED");
        unlocked = false;
        _;
        unlocked = true;
    }

    modifier validAddress(address _address) {
        require(_address != address(0), "LiquidityPool: ZERO_ADDRESS");
        _;
    }

    modifier validAmount(uint256 amount) {
        require(amount > 0, "LiquidityPool: INVALID_AMOUNT");
        _;
    }

    modifier validFee(uint256 fee) {
        require(fee <= MAX_FEE, "LiquidityPool: INVALID_FEE");
        _;
    }

    constructor(
        address _token0,
        address _token1,
        string memory _name,
        string memory _symbol
    )
        ERC20(_name, _symbol)
        Ownable(msg.sender)
        validAddress(_token0)
        validAddress(_token1)
    {
        require(_token0 != _token1, "LiquidityPool: IDENTICAL_ADDRESSES");
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function _update(uint256 balance0, uint256 balance1) internal {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "LiquidityPool: OVERFLOW");
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    function _safeTransfer(IERC20 token, address to, uint256 value) internal {
        require(token.transfer(to, value), "LiquidityPool: TRANSFER_FAILED");
    }

    function _calculateFee(uint256 amount) internal view returns (uint256) {
        return (amount * swapFee) / FEE_DENOMINATOR;
    }

    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal view returns (uint256) {
        require(amountIn > 0, "LiquidityPool: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "LiquidityPool: INSUFFICIENT_LIQUIDITY");

        uint256 fee = _calculateFee(amountIn);
        uint256 amountInWithFee = amountIn - fee;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn + amountInWithFee;

        return numerator / denominator;
    }
}

contract LiquidityPoolV1 is LiquidityPoolBase {
    constructor(
        address _token0,
        address _token1
    ) LiquidityPoolBase(
        _token0,
        _token1,
        string(abi.encodePacked("LP-", IERC20(_token0).symbol(), "-", IERC20(_token1).symbol())),
        "LP"
    ) {}

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
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();

        if (_reserve0 == 0 && _reserve1 == 0) {
            amount0 = amount0Desired;
            amount1 = amount1Desired;
        } else {
            uint256 amount1Optimal = (amount0Desired * _reserve1) / _reserve0;
            if (amount1Optimal <= amount1Desired) {
                require(amount1Optimal >= amount1Min, "LiquidityPool: INSUFFICIENT_1_AMOUNT");
                amount0 = amount0Desired;
                amount1 = amount1Optimal;
            } else {
                uint256 amount0Optimal = (amount1Desired * _reserve0) / _reserve1;
                require(amount0Optimal <= amount0Desired && amount0Optimal >= amount0Min, "LiquidityPool: INSUFFICIENT_0_AMOUNT");
                amount0 = amount0Optimal;
                amount1 = amount1Desired;
            }
        }

        require(token0.transferFrom(msg.sender, address(this), amount0), "LiquidityPool: TRANSFER_0_FAILED");
        require(token1.transferFrom(msg.sender, address(this), amount1), "LiquidityPool: TRANSFER_1_FAILED");

        liquidity = _mint(to);
        emit Mint(msg.sender, amount0, amount1, liquidity);
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

        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));

        amount0 = (liquidity * balance0) / totalSupply();
        amount1 = (liquidity * balance1) / totalSupply();

        require(amount0 >= amount0Min && amount1 >= amount1Min, "LiquidityPool: INSUFFICIENT_LIQUIDITY_BURNED");

        _burn(msg.sender, liquidity);
        _safeTransfer(token0, to, amount0);
        _safeTransfer(token1, to, amount1);

        balance0 = token0.balanceOf(address(this));
        balance1 = token1.balanceOf(address(this));

        _update(balance0, balance1);
        emit Burn(msg.sender, amount0, amount1, liquidity, to);
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
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "LiquidityPool: INSUFFICIENT_LIQUIDITY");

        uint256 balance0;
        uint256 balance1;

        {
            require(to != address(token0) && to != address(token1), "LiquidityPool: INVALID_TO");
            if (amount0Out > 0) _safeTransfer(token0, to, amount0Out);
            if (amount1Out > 0) _safeTransfer(token1, to, amount1Out);

            balance0 = token0.balanceOf(address(this));
            balance1 = token1.balanceOf(address(this));
        }

        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "LiquidityPool: INSUFFICIENT_INPUT_AMOUNT");

        {
            uint256 fee0 = _calculateFee(amount0In);
            uint256 fee1 = _calculateFee(amount1In);

            totalFeeCollected0 += fee0;
            totalFeeCollected1 += fee1;

            uint256 balance0Adjusted = (balance0 * FEE_DENOMINATOR) - (amount0In * swapFee);
            uint256 balance1Adjusted = (balance1 * FEE_DENOMINATOR) - (amount1In * swapFee);
            require(
                balance0Adjusted * balance1Adjusted >= uint256(_reserve0) * _reserve1 * (FEE_DENOMINATOR**2),
                "LiquidityPool: K"
            );
        }

        _update(balance0, balance1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();

        if (tokenIn == address(token0)) {
            return _getAmountOut(amountIn, _reserve0, _reserve1);
        } else if (tokenIn == address(token1)) {
            return _getAmountOut(amountIn, _reserve1, _reserve0);
        } else {
            revert("LiquidityPool: INVALID_TOKEN");
        }
    }

    function setSwapFee(uint256 _swapFee) external onlyOwner validFee(_swapFee) {
        uint256 oldFee = swapFee;
        swapFee = _swapFee;
        emit FeeUpdated(oldFee, _swapFee);
    }

    function collectFees(address to) external onlyOwner validAddress(to) {
        if (totalFeeCollected0 > 0) {
            _safeTransfer(token0, to, totalFeeCollected0);
            totalFeeCollected0 = 0;
        }
        if (totalFeeCollected1 > 0) {
            _safeTransfer(token1, to, totalFeeCollected1);
            totalFeeCollected1 = 0;
        }
    }

    function _mint(address to) internal returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            liquidity = LiquidityPoolMath.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = LiquidityPoolMath.min(
                (amount0 * _totalSupply) / _reserve0,
                (amount1 * _totalSupply) / _reserve1
            );
        }
        require(liquidity > 0, "LiquidityPool: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);

        _update(balance0, balance1);
    }

    function sync() external nonReentrant {
        _update(token0.balanceOf(address(this)), token1.balanceOf(address(this)));
    }
}
