
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

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

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract LiquidityPoolContract is ReentrancyGuard {
    using SafeMath for uint256;


    uint256 private constant MINIMUM_LIQUIDITY = 10**3;
    uint256 private constant FEE_DENOMINATOR = 10000;
    uint256 private constant TRADING_FEE = 30;


    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;

    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public totalSupply;
    uint256 private unlocked = 1;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public factory;
    uint32 private blockTimestampLast;
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public kLast;


    event Mint(address indexed sender, uint256 amountA, uint256 amountB);
    event Burn(address indexed sender, uint256 amountA, uint256 amountB, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amountAIn,
        uint256 amountBIn,
        uint256 amountAOut,
        uint256 amountBOut,
        address indexed to
    );
    event Sync(uint256 reserveA, uint256 reserveB);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);


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

    constructor(address _tokenA, address _tokenB)
        validAddress(_tokenA)
        validAddress(_tokenB)
    {
        require(_tokenA != _tokenB, "LiquidityPool: IDENTICAL_ADDRESSES");
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        factory = msg.sender;
    }


    function name() public pure returns (string memory) {
        return "Liquidity Pool Token";
    }

    function symbol() public pure returns (string memory) {
        return "LPT";
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }
        _transfer(from, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }


    function addLiquidity(uint256 amountADesired, uint256 amountBDesired, address to)
        external
        nonReentrant
        lock
        validAddress(to)
        validAmount(amountADesired)
        validAmount(amountBDesired)
        returns (uint256 liquidity)
    {
        (uint256 amountA, uint256 amountB) = _calculateOptimalAmounts(amountADesired, amountBDesired);

        _safeTransferFrom(tokenA, msg.sender, address(this), amountA);
        _safeTransferFrom(tokenB, msg.sender, address(this), amountB);

        liquidity = _mint(to);

        emit Mint(msg.sender, amountA, amountB);
    }

    function removeLiquidity(uint256 liquidity, address to)
        external
        nonReentrant
        lock
        validAddress(to)
        validAmount(liquidity)
        returns (uint256 amountA, uint256 amountB)
    {
        require(balanceOf[msg.sender] >= liquidity, "LiquidityPool: INSUFFICIENT_LIQUIDITY_BALANCE");

        uint256 balanceA = tokenA.balanceOf(address(this));
        uint256 balanceB = tokenB.balanceOf(address(this));

        amountA = liquidity.mul(balanceA) / totalSupply;
        amountB = liquidity.mul(balanceB) / totalSupply;

        require(amountA > 0 && amountB > 0, "LiquidityPool: INSUFFICIENT_LIQUIDITY_BURNED");

        _burn(msg.sender, liquidity);
        _safeTransfer(tokenA, to, amountA);
        _safeTransfer(tokenB, to, amountB);

        _update(balanceA.sub(amountA), balanceB.sub(amountB));

        emit Burn(msg.sender, amountA, amountB, to);
    }

    function swap(uint256 amountAOut, uint256 amountBOut, address to)
        external
        nonReentrant
        lock
        validAddress(to)
    {
        require(amountAOut > 0 || amountBOut > 0, "LiquidityPool: INSUFFICIENT_OUTPUT_AMOUNT");
        require(amountAOut < reserveA && amountBOut < reserveB, "LiquidityPool: INSUFFICIENT_LIQUIDITY");
        require(to != address(tokenA) && to != address(tokenB), "LiquidityPool: INVALID_TO");

        if (amountAOut > 0) _safeTransfer(tokenA, to, amountAOut);
        if (amountBOut > 0) _safeTransfer(tokenB, to, amountBOut);

        uint256 balanceA = tokenA.balanceOf(address(this));
        uint256 balanceB = tokenB.balanceOf(address(this));

        uint256 amountAIn = balanceA > reserveA.sub(amountAOut) ? balanceA.sub(reserveA.sub(amountAOut)) : 0;
        uint256 amountBIn = balanceB > reserveB.sub(amountBOut) ? balanceB.sub(reserveB.sub(amountBOut)) : 0;

        require(amountAIn > 0 || amountBIn > 0, "LiquidityPool: INSUFFICIENT_INPUT_AMOUNT");

        {
            uint256 balanceAAdjusted = balanceA.mul(FEE_DENOMINATOR).sub(amountAIn.mul(TRADING_FEE));
            uint256 balanceBAdjusted = balanceB.mul(FEE_DENOMINATOR).sub(amountBIn.mul(TRADING_FEE));
            require(
                balanceAAdjusted.mul(balanceBAdjusted) >= reserveA.mul(reserveB).mul(FEE_DENOMINATOR**2),
                "LiquidityPool: K"
            );
        }

        _update(balanceA, balanceB);
        emit Swap(msg.sender, amountAIn, amountBIn, amountAOut, amountBOut, to);
    }

    function getReserves() external view returns (uint256 _reserveA, uint256 _reserveB, uint32 _blockTimestampLast) {
        _reserveA = reserveA;
        _reserveB = reserveB;
        _blockTimestampLast = blockTimestampLast;
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "LiquidityPool: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "LiquidityPool: INSUFFICIENT_LIQUIDITY");

        uint256 amountInWithFee = amountIn.mul(FEE_DENOMINATOR.sub(TRADING_FEE));
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator = reserveIn.mul(FEE_DENOMINATOR).add(amountInWithFee);
        amountOut = numerator / denominator;
    }


    function _calculateOptimalAmounts(uint256 amountADesired, uint256 amountBDesired)
        internal
        view
        returns (uint256 amountA, uint256 amountB)
    {
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = _quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = _quote(amountBDesired, reserveB, reserveA);
                require(amountAOptimal <= amountADesired, "LiquidityPool: INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function _mint(address to) internal returns (uint256 liquidity) {
        uint256 balanceA = tokenA.balanceOf(address(this));
        uint256 balanceB = tokenB.balanceOf(address(this));
        uint256 amountA = balanceA.sub(reserveA);
        uint256 amountB = balanceB.sub(reserveB);

        if (totalSupply == 0) {
            liquidity = SafeMath.sqrt(amountA.mul(amountB)).sub(MINIMUM_LIQUIDITY);
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = SafeMath.min(
                amountA.mul(totalSupply) / reserveA,
                amountB.mul(totalSupply) / reserveB
            );
        }

        require(liquidity > 0, "LiquidityPool: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);
        _update(balanceA, balanceB);
    }

    function _mint(address to, uint256 value) internal {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Transfer(from, address(0), value);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(address from, address to, uint256 value) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

    function _update(uint256 balanceA, uint256 balanceB) internal {
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;

        if (timeElapsed > 0 && reserveA != 0 && reserveB != 0) {
            price0CumulativeLast += uint256(_encode(reserveB, reserveA)) * timeElapsed;
            price1CumulativeLast += uint256(_encode(reserveA, reserveB)) * timeElapsed;
        }

        reserveA = balanceA;
        reserveB = balanceB;
        blockTimestampLast = blockTimestamp;
        emit Sync(reserveA, reserveB);
    }

    function _quote(uint256 amountA, uint256 reserveA_, uint256 reserveB_)
        internal
        pure
        returns (uint256 amountB)
    {
        require(amountA > 0, "LiquidityPool: INSUFFICIENT_AMOUNT");
        require(reserveA_ > 0 && reserveB_ > 0, "LiquidityPool: INSUFFICIENT_LIQUIDITY");
        amountB = amountA.mul(reserveB_) / reserveA_;
    }

    function _encode(uint256 y, uint256 x) internal pure returns (uint224 z) {
        require(y <= type(uint112).max, "LiquidityPool: OVERFLOW");
        z = uint224(y << 112 / x);
    }

    function _safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "LiquidityPool: TRANSFER_FAILED");
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "LiquidityPool: TRANSFER_FROM_FAILED");
    }


    function skim(address to) external lock {
        address _tokenA = address(tokenA);
        address _tokenB = address(tokenB);
        _safeTransfer(tokenA, to, IERC20(_tokenA).balanceOf(address(this)).sub(reserveA));
        _safeTransfer(tokenB, to, IERC20(_tokenB).balanceOf(address(this)).sub(reserveB));
    }


    function sync() external lock {
        _update(tokenA.balanceOf(address(this)), tokenB.balanceOf(address(this)));
    }
}
