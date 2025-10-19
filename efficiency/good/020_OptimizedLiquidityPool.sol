
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract OptimizedLiquidityPool is ERC20, ReentrancyGuard, Ownable {
    IERC20 public immutable token0;
    IERC20 public immutable token1;

    uint256 private reserve0;
    uint256 private reserve1;
    uint256 private blockTimestampLast;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public kLast;

    uint256 private constant MINIMUM_LIQUIDITY = 1000;
    uint256 private constant FEE_RATE = 3;
    uint256 private constant FEE_DENOMINATOR = 1000;

    address public feeTo;

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

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "EXPIRED");
        _;
    }

    constructor(
        address _token0,
        address _token1,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }

    function getReserves() public view returns (uint256 _reserve0, uint256 _reserve1, uint256 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function _safeTransfer(IERC20 token, address to, uint256 value) private {
        require(token.transfer(to, value), "TRANSFER_FAILED");
    }

    function _update(uint256 balance0, uint256 balance1, uint256 _reserve0, uint256 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "OVERFLOW");

        uint256 blockTimestamp = block.timestamp % 2**32;
        uint256 timeElapsed;
        unchecked {
            timeElapsed = blockTimestamp - blockTimestampLast;
        }

        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            unchecked {
                price0CumulativeLast += (_reserve1 * 1e18 / _reserve0) * timeElapsed;
                price1CumulativeLast += (_reserve0 * 1e18 / _reserve1) * timeElapsed;
            }
        }

        reserve0 = balance0;
        reserve1 = balance1;
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    function _mintFee(uint256 _reserve0, uint256 _reserve1) private returns (bool feeOn) {
        address _feeTo = feeTo;
        feeOn = _feeTo != address(0);
        uint256 _kLast = kLast;
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = _sqrt(_reserve0 * _reserve1);
                uint256 rootKLast = _sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply() * (rootK - rootKLast);
                    uint256 denominator = rootK * 5 + rootKLast;
                    uint256 liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(_feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    function mint(address to) external nonReentrant returns (uint256 liquidity) {
        (uint256 _reserve0, uint256 _reserve1,) = getReserves();
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply();

        if (_totalSupply == 0) {
            liquidity = _sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = _min(
                (amount0 * _totalSupply) / _reserve0,
                (amount1 * _totalSupply) / _reserve1
            );
        }

        require(liquidity > 0, "INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = reserve0 * reserve1;
        emit Mint(msg.sender, amount0, amount1);
    }

    function burn(address to) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        (uint256 _reserve0, uint256 _reserve1,) = getReserves();
        IERC20 _token0 = token0;
        IERC20 _token1 = token1;
        uint256 balance0 = _token0.balanceOf(address(this));
        uint256 balance1 = _token1.balanceOf(address(this));
        uint256 liquidity = balanceOf(address(this));

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply();

        amount0 = (liquidity * balance0) / _totalSupply;
        amount1 = (liquidity * balance1) / _totalSupply;
        require(amount0 > 0 && amount1 > 0, "INSUFFICIENT_LIQUIDITY_BURNED");

        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);

        balance0 = _token0.balanceOf(address(this));
        balance1 = _token1.balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = reserve0 * reserve1;
        emit Burn(msg.sender, amount0, amount1, to);
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external nonReentrant {
        require(amount0Out > 0 || amount1Out > 0, "INSUFFICIENT_OUTPUT_AMOUNT");
        (uint256 _reserve0, uint256 _reserve1,) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "INSUFFICIENT_LIQUIDITY");

        uint256 balance0;
        uint256 balance1;
        {
            IERC20 _token0 = token0;
            IERC20 _token1 = token1;
            require(to != address(_token0) && to != address(_token1), "INVALID_TO");
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);
            if (data.length > 0) ILiquidityPoolCallee(to).liquidityPoolCall(msg.sender, amount0Out, amount1Out, data);
            balance0 = _token0.balanceOf(address(this));
            balance1 = _token1.balanceOf(address(this));
        }

        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "INSUFFICIENT_INPUT_AMOUNT");

        {
            uint256 balance0Adjusted = (balance0 * FEE_DENOMINATOR) - (amount0In * FEE_RATE);
            uint256 balance1Adjusted = (balance1 * FEE_DENOMINATOR) - (amount1In * FEE_RATE);
            require(
                balance0Adjusted * balance1Adjusted >= _reserve0 * _reserve1 * (FEE_DENOMINATOR**2),
                "K"
            );
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    function skim(address to) external nonReentrant {
        IERC20 _token0 = token0;
        IERC20 _token1 = token1;
        _safeTransfer(_token0, to, _token0.balanceOf(address(this)) - reserve0);
        _safeTransfer(_token1, to, _token1.balanceOf(address(this)) - reserve1);
    }

    function sync() external nonReentrant {
        _update(token0.balanceOf(address(this)), token1.balanceOf(address(this)), reserve0, reserve1);
    }

    function setFeeTo(address _feeTo) external onlyOwner {
        feeTo = _feeTo;
    }

    function _min(uint256 x, uint256 y) private pure returns (uint256 z) {
        z = x < y ? x : y;
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

interface ILiquidityPoolCallee {
    function liquidityPoolCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}
