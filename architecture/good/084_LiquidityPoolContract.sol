
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";


contract LiquidityPoolContract is ERC20, ReentrancyGuard, Ownable {
    using Math for uint256;


    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant DEFAULT_FEE = 30;


    IERC20 public immutable token0;
    IERC20 public immutable token1;

    uint256 public reserve0;
    uint256 public reserve1;
    uint256 public feeRate;
    uint256 public totalFees0;
    uint256 public totalFees1;

    uint256 private unlocked = 1;


    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
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
    event FeeRateUpdated(uint256 oldFee, uint256 newFee);


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

    modifier validAmount(uint256 _amount) {
        require(_amount > 0, "LiquidityPool: ZERO_AMOUNT");
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

        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        feeRate = DEFAULT_FEE;
    }


    function addLiquidity(
        uint256 _amount0Desired,
        uint256 _amount1Desired,
        uint256 _amount0Min,
        uint256 _amount1Min,
        address _to
    )
        external
        nonReentrant
        validAddress(_to)
        validAmount(_amount0Desired)
        validAmount(_amount1Desired)
        returns (uint256 liquidity)
    {
        (uint256 amount0, uint256 amount1) = _calculateOptimalAmounts(
            _amount0Desired,
            _amount1Desired,
            _amount0Min,
            _amount1Min
        );

        _safeTransferFrom(token0, msg.sender, address(this), amount0);
        _safeTransferFrom(token1, msg.sender, address(this), amount1);

        liquidity = _mint(_to, amount0, amount1);
    }


    function removeLiquidity(
        uint256 _liquidity,
        uint256 _amount0Min,
        uint256 _amount1Min,
        address _to
    )
        external
        nonReentrant
        validAddress(_to)
        validAmount(_liquidity)
        returns (uint256 amount0, uint256 amount1)
    {
        require(balanceOf(msg.sender) >= _liquidity, "LiquidityPool: INSUFFICIENT_LIQUIDITY");

        (amount0, amount1) = _burn(msg.sender, _liquidity, _to);

        require(amount0 >= _amount0Min, "LiquidityPool: INSUFFICIENT_A_AMOUNT");
        require(amount1 >= _amount1Min, "LiquidityPool: INSUFFICIENT_B_AMOUNT");
    }


    function swap(
        uint256 _amount0Out,
        uint256 _amount1Out,
        address _to
    )
        external
        nonReentrant
        validAddress(_to)
    {
        require(_amount0Out > 0 || _amount1Out > 0, "LiquidityPool: INSUFFICIENT_OUTPUT_AMOUNT");
        require(_amount0Out < reserve0 && _amount1Out < reserve1, "LiquidityPool: INSUFFICIENT_LIQUIDITY");

        uint256 balance0Before = token0.balanceOf(address(this));
        uint256 balance1Before = token1.balanceOf(address(this));

        if (_amount0Out > 0) _safeTransfer(token0, _to, _amount0Out);
        if (_amount1Out > 0) _safeTransfer(token1, _to, _amount1Out);

        uint256 balance0After = token0.balanceOf(address(this));
        uint256 balance1After = token1.balanceOf(address(this));

        uint256 amount0In = balance0Before > balance0After ? 0 : balance0After - balance0Before;
        uint256 amount1In = balance1Before > balance1After ? 0 : balance1After - balance1Before;

        require(amount0In > 0 || amount1In > 0, "LiquidityPool: INSUFFICIENT_INPUT_AMOUNT");

        _validateSwap(amount0In, amount1In, _amount0Out, _amount1Out);
        _updateReserves(balance0After, balance1After);

        emit Swap(msg.sender, amount0In, amount1In, _amount0Out, _amount1Out, _to);
    }


    function getAmountOut(uint256 _amountIn, uint256 _reserveIn, uint256 _reserveOut)
        public
        view
        returns (uint256 amountOut)
    {
        require(_amountIn > 0, "LiquidityPool: INSUFFICIENT_INPUT_AMOUNT");
        require(_reserveIn > 0 && _reserveOut > 0, "LiquidityPool: INSUFFICIENT_LIQUIDITY");

        uint256 amountInWithFee = _amountIn * (FEE_DENOMINATOR - feeRate);
        uint256 numerator = amountInWithFee * _reserveOut;
        uint256 denominator = _reserveIn * FEE_DENOMINATOR + amountInWithFee;
        amountOut = numerator / denominator;
    }


    function getAmountIn(uint256 _amountOut, uint256 _reserveIn, uint256 _reserveOut)
        public
        view
        returns (uint256 amountIn)
    {
        require(_amountOut > 0, "LiquidityPool: INSUFFICIENT_OUTPUT_AMOUNT");
        require(_reserveIn > 0 && _reserveOut > 0, "LiquidityPool: INSUFFICIENT_LIQUIDITY");

        uint256 numerator = _reserveIn * _amountOut * FEE_DENOMINATOR;
        uint256 denominator = (_reserveOut - _amountOut) * (FEE_DENOMINATOR - feeRate);
        amountIn = (numerator / denominator) + 1;
    }


    function setFeeRate(uint256 _newFeeRate) external onlyOwner {
        require(_newFeeRate <= 1000, "LiquidityPool: FEE_TOO_HIGH");

        uint256 oldFee = feeRate;
        feeRate = _newFeeRate;

        emit FeeRateUpdated(oldFee, _newFeeRate);
    }


    function collectFees(address _to) external onlyOwner validAddress(_to) {
        if (totalFees0 > 0) {
            _safeTransfer(token0, _to, totalFees0);
            totalFees0 = 0;
        }
        if (totalFees1 > 0) {
            _safeTransfer(token1, _to, totalFees1);
            totalFees1 = 0;
        }
    }


    function sync() external lock {
        _updateReserves(token0.balanceOf(address(this)), token1.balanceOf(address(this)));
    }


    function _mint(address _to, uint256 _amount0, uint256 _amount1)
        internal
        lock
        returns (uint256 liquidity)
    {
        uint256 _totalSupply = totalSupply();

        if (_totalSupply == 0) {
            liquidity = Math.sqrt(_amount0 * _amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min(
                (_amount0 * _totalSupply) / reserve0,
                (_amount1 * _totalSupply) / reserve1
            );
        }

        require(liquidity > 0, "LiquidityPool: INSUFFICIENT_LIQUIDITY_MINTED");

        _mint(_to, liquidity);
        _updateReserves(
            token0.balanceOf(address(this)),
            token1.balanceOf(address(this))
        );

        emit Mint(msg.sender, _amount0, _amount1);
    }

    function _burn(address _from, uint256 _liquidity, address _to)
        internal
        lock
        returns (uint256 amount0, uint256 amount1)
    {
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));
        uint256 _totalSupply = totalSupply();

        amount0 = (_liquidity * balance0) / _totalSupply;
        amount1 = (_liquidity * balance1) / _totalSupply;

        require(amount0 > 0 && amount1 > 0, "LiquidityPool: INSUFFICIENT_LIQUIDITY_BURNED");

        _burn(_from, _liquidity);
        _safeTransfer(token0, _to, amount0);
        _safeTransfer(token1, _to, amount1);

        _updateReserves(
            token0.balanceOf(address(this)),
            token1.balanceOf(address(this))
        );

        emit Burn(msg.sender, amount0, amount1, _to);
    }

    function _calculateOptimalAmounts(
        uint256 _amount0Desired,
        uint256 _amount1Desired,
        uint256 _amount0Min,
        uint256 _amount1Min
    ) internal view returns (uint256 amount0, uint256 amount1) {
        if (reserve0 == 0 && reserve1 == 0) {
            (amount0, amount1) = (_amount0Desired, _amount1Desired);
        } else {
            uint256 amount1Optimal = (_amount0Desired * reserve1) / reserve0;
            if (amount1Optimal <= _amount1Desired) {
                require(amount1Optimal >= _amount1Min, "LiquidityPool: INSUFFICIENT_B_AMOUNT");
                (amount0, amount1) = (_amount0Desired, amount1Optimal);
            } else {
                uint256 amount0Optimal = (_amount1Desired * reserve0) / reserve1;
                require(amount0Optimal <= _amount0Desired && amount0Optimal >= _amount0Min,
                    "LiquidityPool: INSUFFICIENT_A_AMOUNT");
                (amount0, amount1) = (amount0Optimal, _amount1Desired);
            }
        }
    }

    function _validateSwap(
        uint256 _amount0In,
        uint256 _amount1In,
        uint256 _amount0Out,
        uint256 _amount1Out
    ) internal view {
        uint256 balance0Adjusted = (token0.balanceOf(address(this)) * FEE_DENOMINATOR) -
            (_amount0In * feeRate);
        uint256 balance1Adjusted = (token1.balanceOf(address(this)) * FEE_DENOMINATOR) -
            (_amount1In * feeRate);

        require(
            balance0Adjusted * balance1Adjusted >=
            reserve0 * reserve1 * (FEE_DENOMINATOR ** 2),
            "LiquidityPool: K"
        );
    }

    function _updateReserves(uint256 _balance0, uint256 _balance1) internal {
        reserve0 = _balance0;
        reserve1 = _balance1;
        emit Sync(reserve0, reserve1);
    }

    function _safeTransfer(IERC20 _token, address _to, uint256 _value) internal {
        require(_token.transfer(_to, _value), "LiquidityPool: TRANSFER_FAILED");
    }

    function _safeTransferFrom(IERC20 _token, address _from, address _to, uint256 _value) internal {
        require(_token.transferFrom(_from, _to, _value), "LiquidityPool: TRANSFER_FROM_FAILED");
    }


    function getReserves() external view returns (uint256 _reserve0, uint256 _reserve1) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }

    function quote(uint256 _amountA, uint256 _reserveA, uint256 _reserveB)
        external
        pure
        returns (uint256 amountB)
    {
        require(_amountA > 0, "LiquidityPool: INSUFFICIENT_AMOUNT");
        require(_reserveA > 0 && _reserveB > 0, "LiquidityPool: INSUFFICIENT_LIQUIDITY");
        amountB = (_amountA * _reserveB) / _reserveA;
    }
}
