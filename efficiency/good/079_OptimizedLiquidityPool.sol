
pragma solidity ^0.8.19;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract OptimizedLiquidityPool {
    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;

    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 private constant MINIMUM_LIQUIDITY = 10**3;
    uint256 private constant FEE_DENOMINATOR = 10000;
    uint256 private constant FEE_NUMERATOR = 30;

    uint32 private blockTimestampLast;
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;

    uint256 private unlocked = 1;

    string public constant name = "LP Token";
    string public constant symbol = "LPT";
    uint8 public constant decimals = 18;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed to, uint256 value);
    event Burn(address indexed from, uint256 value);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint256 reserve0, uint256 reserve1);

    modifier lock() {
        require(unlocked == 1, "LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    function getReserves() external view returns (uint256 _reserveA, uint256 _reserveB, uint32 _blockTimestampLast) {
        _reserveA = reserveA;
        _reserveB = reserveB;
        _blockTimestampLast = blockTimestampLast;
    }

    function _safeTransfer(IERC20 token, address to, uint256 value) private {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FAILED");
    }

    function _update(uint256 balance0, uint256 balance1, uint256 _reserve0, uint256 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "OVERFLOW");

        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed;
        unchecked {
            timeElapsed = blockTimestamp - blockTimestampLast;
        }

        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            unchecked {
                price0CumulativeLast += uint256(_reserve1) * 2**112 / _reserve0 * timeElapsed;
                price1CumulativeLast += uint256(_reserve0) * 2**112 / _reserve1 * timeElapsed;
            }
        }

        reserveA = balance0;
        reserveB = balance1;
        blockTimestampLast = blockTimestamp;
        emit Sync(reserveA, reserveB);
    }

    function _mint(address to, uint256 value) private {
        totalSupply += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) private {
        balanceOf[from] -= value;
        totalSupply -= value;
        emit Transfer(from, address(0), value);
    }

    function _approve(address owner, address spender, uint256 value) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(address from, address to, uint256 value) private {
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint256 value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - value;
        }
        _transfer(from, to, value);
        return true;
    }

    function mint(address to) external lock returns (uint256 liquidity) {
        (uint256 _reserveA, uint256 _reserveB,) = getReserves();
        uint256 balanceA = tokenA.balanceOf(address(this));
        uint256 balanceB = tokenB.balanceOf(address(this));
        uint256 amountA = balanceA - _reserveA;
        uint256 amountB = balanceB - _reserveB;

        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            liquidity = _sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = _min(amountA * _totalSupply / _reserveA, amountB * _totalSupply / _reserveB);
        }
        require(liquidity > 0, "INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);

        _update(balanceA, balanceB, _reserveA, _reserveB);
        emit Mint(to, liquidity);
    }

    function burn(address to) external lock returns (uint256 amountA, uint256 amountB) {
        (uint256 _reserveA, uint256 _reserveB,) = getReserves();
        IERC20 _tokenA = tokenA;
        IERC20 _tokenB = tokenB;
        uint256 balanceA = _tokenA.balanceOf(address(this));
        uint256 balanceB = _tokenB.balanceOf(address(this));
        uint256 liquidity = balanceOf[address(this)];

        uint256 _totalSupply = totalSupply;
        amountA = liquidity * balanceA / _totalSupply;
        amountB = liquidity * balanceB / _totalSupply;
        require(amountA > 0 && amountB > 0, "INSUFFICIENT_LIQUIDITY_BURNED");
        _burn(address(this), liquidity);
        _safeTransfer(_tokenA, to, amountA);
        _safeTransfer(_tokenB, to, amountB);
        balanceA = _tokenA.balanceOf(address(this));
        balanceB = _tokenB.balanceOf(address(this));

        _update(balanceA, balanceB, _reserveA, _reserveB);
        emit Burn(to, liquidity);
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external lock {
        require(amount0Out > 0 || amount1Out > 0, "INSUFFICIENT_OUTPUT_AMOUNT");
        (uint256 _reserveA, uint256 _reserveB,) = getReserves();
        require(amount0Out < _reserveA && amount1Out < _reserveB, "INSUFFICIENT_LIQUIDITY");

        uint256 balance0;
        uint256 balance1;
        {
            IERC20 _tokenA = tokenA;
            IERC20 _tokenB = tokenB;
            require(to != address(_tokenA) && to != address(_tokenB), "INVALID_TO");
            if (amount0Out > 0) _safeTransfer(_tokenA, to, amount0Out);
            if (amount1Out > 0) _safeTransfer(_tokenB, to, amount1Out);
            if (data.length > 0) ICallee(to).call(msg.sender, amount0Out, amount1Out, data);
            balance0 = _tokenA.balanceOf(address(this));
            balance1 = _tokenB.balanceOf(address(this));
        }

        uint256 amount0In = balance0 > _reserveA - amount0Out ? balance0 - (_reserveA - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserveB - amount1Out ? balance1 - (_reserveB - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "INSUFFICIENT_INPUT_AMOUNT");

        {
            uint256 balance0Adjusted = balance0 * 1000 - amount0In * 3;
            uint256 balance1Adjusted = balance1 * 1000 - amount1In * 3;
            require(balance0Adjusted * balance1Adjusted >= uint256(_reserveA) * _reserveB * (1000**2), "K");
        }

        _update(balance0, balance1, _reserveA, _reserveB);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    function skim(address to) external lock {
        IERC20 _tokenA = tokenA;
        IERC20 _tokenB = tokenB;
        _safeTransfer(_tokenA, to, _tokenA.balanceOf(address(this)) - reserveA);
        _safeTransfer(_tokenB, to, _tokenB.balanceOf(address(this)) - reserveB);
    }

    function sync() external lock {
        _update(tokenA.balanceOf(address(this)), tokenB.balanceOf(address(this)), reserveA, reserveB);
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

interface ICallee {
    function call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}
