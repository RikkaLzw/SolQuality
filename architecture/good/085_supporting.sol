
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";


contract DecentralizedExchange is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using Math for uint256;


    uint256 public constant MINIMUM_LIQUIDITY = 10**3;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MAX_FEE_RATE = 100;


    uint256 public feeRate = 30;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    IERC20 public immutable token0;
    IERC20 public immutable token1;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public kLast;


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
    event Sync(uint112 reserve0, uint112 reserve1);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);


    modifier validAddress(address _address) {
        require(_address != address(0), "DEX: Invalid address");
        _;
    }

    modifier validAmount(uint256 _amount) {
        require(_amount > 0, "DEX: Invalid amount");
        _;
    }

    modifier sufficientBalance(address _user, uint256 _amount) {
        require(balanceOf[_user] >= _amount, "DEX: Insufficient balance");
        _;
    }

    modifier sufficientLiquidity(uint256 _amount0, uint256 _amount1) {
        require(_amount0 > 0 && _amount1 > 0, "DEX: Insufficient liquidity amounts");
        _;
    }

    constructor(address _token0, address _token1) {
        require(_token0 != address(0) && _token1 != address(0), "DEX: Invalid token addresses");
        require(_token0 != _token1, "DEX: Identical tokens");

        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }


    function _mint(address to, uint256 value) internal {
        totalSupply += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        balanceOf[from] -= value;
        totalSupply -= value;
        emit Transfer(from, address(0), value);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(address from, address to, uint256 value) internal {
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }

    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) internal {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "DEX: Overflow");

        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;

        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            price0CumulativeLast += uint256(_reserve1) * timeElapsed / _reserve0;
            price1CumulativeLast += uint256(_reserve0) * timeElapsed / _reserve1;
        }

        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;

        emit Sync(reserve0, reserve1);
    }

    function _calculateOptimalAmounts(uint256 _amount0Desired, uint256 _amount1Desired)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        if (reserve0 == 0 && reserve1 == 0) {
            return (_amount0Desired, _amount1Desired);
        }

        uint256 amount1Optimal = _amount0Desired * reserve1 / reserve0;
        if (amount1Optimal <= _amount1Desired) {
            return (_amount0Desired, amount1Optimal);
        }

        uint256 amount0Optimal = _amount1Desired * reserve0 / reserve1;
        require(amount0Optimal <= _amount0Desired, "DEX: Insufficient amount0");
        return (amount0Optimal, _amount1Desired);
    }


    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
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
        validAddress(to)
        sufficientLiquidity(amount0Desired, amount1Desired)
        returns (uint256 amount0, uint256 amount1, uint256 liquidity)
    {
        (amount0, amount1) = _calculateOptimalAmounts(amount0Desired, amount1Desired);
        require(amount0 >= amount0Min && amount1 >= amount1Min, "DEX: Insufficient amounts");

        token0.safeTransferFrom(msg.sender, address(this), amount0);
        token1.safeTransferFrom(msg.sender, address(this), amount1);

        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));

        if (totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min(amount0 * totalSupply / reserve0, amount1 * totalSupply / reserve1);
        }

        require(liquidity > 0, "DEX: Insufficient liquidity minted");
        _mint(to, liquidity);

        _update(balance0, balance1, reserve0, reserve1);
        emit Mint(msg.sender, amount0, amount1);
    }

    function removeLiquidity(
        uint256 liquidity,
        uint256 amount0Min,
        uint256 amount1Min,
        address to
    )
        external
        nonReentrant
        validAddress(to)
        validAmount(liquidity)
        sufficientBalance(msg.sender, liquidity)
        returns (uint256 amount0, uint256 amount1)
    {
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));

        amount0 = liquidity * balance0 / totalSupply;
        amount1 = liquidity * balance1 / totalSupply;

        require(amount0 >= amount0Min && amount1 >= amount1Min, "DEX: Insufficient amounts");
        require(amount0 > 0 && amount1 > 0, "DEX: Insufficient liquidity burned");

        _burn(msg.sender, liquidity);

        token0.safeTransfer(to, amount0);
        token1.safeTransfer(to, amount1);

        balance0 = token0.balanceOf(address(this));
        balance1 = token1.balanceOf(address(this));

        _update(balance0, balance1, reserve0, reserve1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to
    )
        external
        nonReentrant
        validAddress(to)
    {
        require(amount0Out > 0 || amount1Out > 0, "DEX: Insufficient output amount");
        require(amount0Out < reserve0 && amount1Out < reserve1, "DEX: Insufficient liquidity");
        require(to != address(token0) && to != address(token1), "DEX: Invalid to address");

        uint256 balance0Before = token0.balanceOf(address(this));
        uint256 balance1Before = token1.balanceOf(address(this));

        if (amount0Out > 0) token0.safeTransfer(to, amount0Out);
        if (amount1Out > 0) token1.safeTransfer(to, amount1Out);

        uint256 balance0After = token0.balanceOf(address(this));
        uint256 balance1After = token1.balanceOf(address(this));

        uint256 amount0In = balance0Before > balance0After ? balance0Before - balance0After : 0;
        uint256 amount1In = balance1Before > balance1After ? balance1Before - balance1After : 0;

        require(amount0In > 0 || amount1In > 0, "DEX: Insufficient input amount");

        uint256 balance0Adjusted = balance0After * FEE_DENOMINATOR - amount0In * feeRate;
        uint256 balance1Adjusted = balance1After * FEE_DENOMINATOR - amount1In * feeRate;

        require(
            balance0Adjusted * balance1Adjusted >= uint256(reserve0) * reserve1 * (FEE_DENOMINATOR ** 2),
            "DEX: K invariant violated"
        );

        _update(balance0After, balance1After, reserve0, reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        view
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "DEX: Insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "DEX: Insufficient liquidity");

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - feeRate);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * FEE_DENOMINATOR + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        public
        view
        returns (uint256 amountIn)
    {
        require(amountOut > 0, "DEX: Insufficient output amount");
        require(reserveIn > 0 && reserveOut > 0, "DEX: Insufficient liquidity");

        uint256 numerator = reserveIn * amountOut * FEE_DENOMINATOR;
        uint256 denominator = (reserveOut - amountOut) * (FEE_DENOMINATOR - feeRate);
        amountIn = (numerator / denominator) + 1;
    }


    function transfer(address to, uint256 value) external validAddress(to) returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value)
        external
        validAddress(from)
        validAddress(to)
        returns (bool)
    {
        if (allowance[from][msg.sender] != type(uint256).max) {
            allowance[from][msg.sender] -= value;
        }
        _transfer(from, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external validAddress(spender) returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }


    function setFeeRate(uint256 _feeRate) external onlyOwner {
        require(_feeRate <= MAX_FEE_RATE, "DEX: Fee rate too high");
        feeRate = _feeRate;
    }

    function emergencyWithdraw(address token, uint256 amount, address to)
        external
        onlyOwner
        validAddress(to)
    {
        require(token != address(token0) && token != address(token1), "DEX: Cannot withdraw pool tokens");
        IERC20(token).safeTransfer(to, amount);
    }


    function sync() external nonReentrant {
        _update(
            token0.balanceOf(address(this)),
            token1.balanceOf(address(this)),
            reserve0,
            reserve1
        );
    }
}
