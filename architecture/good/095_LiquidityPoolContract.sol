
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";


contract LiquidityPoolContract is ERC20, ReentrancyGuard, Ownable {
    using Math for uint256;


    uint256 private constant MINIMUM_LIQUIDITY = 1000;
    uint256 private constant FEE_DENOMINATOR = 10000;
    uint256 private constant MAX_FEE = 300;


    IERC20 public immutable token0;
    IERC20 public immutable token1;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public kLast;

    uint256 public swapFee = 30;
    address public feeRecipient;

    bool public tradingEnabled = true;


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
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event TradingStatusChanged(bool enabled);


    modifier onlyWhenTradingEnabled() {
        require(tradingEnabled, "Trading is disabled");
        _;
    }

    modifier validAddress(address addr) {
        require(addr != address(0), "Invalid address");
        _;
    }

    modifier validAmount(uint256 amount) {
        require(amount > 0, "Amount must be greater than 0");
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
        require(_token0 != _token1, "Identical tokens");
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        feeRecipient = msg.sender;
    }


    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        view
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "Insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - swapFee);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * FEE_DENOMINATOR + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        public
        view
        returns (uint256 amountIn)
    {
        require(amountOut > 0, "Insufficient output amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");
        require(amountOut < reserveOut, "Insufficient liquidity");

        uint256 numerator = reserveIn * amountOut * FEE_DENOMINATOR;
        uint256 denominator = (reserveOut - amountOut) * (FEE_DENOMINATOR - swapFee);
        amountIn = (numerator / denominator) + 1;
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
        validAmount(amount0Desired)
        validAmount(amount1Desired)
        returns (uint256 amount0, uint256 amount1, uint256 liquidity)
    {
        (amount0, amount1) = _calculateOptimalAmounts(amount0Desired, amount1Desired, amount0Min, amount1Min);

        _safeTransferFrom(token0, msg.sender, address(this), amount0);
        _safeTransferFrom(token1, msg.sender, address(this), amount1);

        liquidity = _mint(to);

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
        returns (uint256 amount0, uint256 amount1)
    {
        require(balanceOf(msg.sender) >= liquidity, "Insufficient LP tokens");

        _transfer(msg.sender, address(this), liquidity);
        (amount0, amount1) = _burn(to);

        require(amount0 >= amount0Min, "Insufficient token0 amount");
        require(amount1 >= amount1Min, "Insufficient token1 amount");

        emit Burn(msg.sender, amount0, amount1, to);
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn,
        address to
    )
        external
        nonReentrant
        onlyWhenTradingEnabled
        validAddress(to)
        validAmount(amountIn)
        returns (uint256 amountOut)
    {
        require(tokenIn == address(token0) || tokenIn == address(token1), "Invalid token");

        bool token0In = tokenIn == address(token0);
        (uint256 reserveIn, uint256 reserveOut) = token0In ?
            (uint256(reserve0), uint256(reserve1)) :
            (uint256(reserve1), uint256(reserve0));

        amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        require(amountOut >= amountOutMin, "Insufficient output amount");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        if (token0In) {
            _safeTransfer(token1, to, amountOut);
            _update(reserve0 + uint112(amountIn), reserve1 - uint112(amountOut));
            emit Swap(msg.sender, amountIn, 0, 0, amountOut, to);
        } else {
            _safeTransfer(token0, to, amountOut);
            _update(reserve0 - uint112(amountOut), reserve1 + uint112(amountIn));
            emit Swap(msg.sender, 0, amountIn, amountOut, 0, to);
        }
    }


    function _calculateOptimalAmounts(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) internal view returns (uint256 amount0, uint256 amount1) {
        if (reserve0 == 0 && reserve1 == 0) {
            (amount0, amount1) = (amount0Desired, amount1Desired);
        } else {
            uint256 amount1Optimal = (amount0Desired * reserve1) / reserve0;
            if (amount1Optimal <= amount1Desired) {
                require(amount1Optimal >= amount1Min, "Insufficient token1 amount");
                (amount0, amount1) = (amount0Desired, amount1Optimal);
            } else {
                uint256 amount0Optimal = (amount1Desired * reserve0) / reserve1;
                require(amount0Optimal <= amount0Desired && amount0Optimal >= amount0Min, "Insufficient token0 amount");
                (amount0, amount1) = (amount0Optimal, amount1Desired);
            }
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
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min(
                (amount0 * _totalSupply) / _reserve0,
                (amount1 * _totalSupply) / _reserve1
            );
        }

        require(liquidity > 0, "Insufficient liquidity minted");
        _mint(to, liquidity);
        _update(uint112(balance0), uint112(balance1));
    }

    function _burn(address to) internal returns (uint256 amount0, uint256 amount1) {
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));
        uint256 liquidity = balanceOf(address(this));

        uint256 _totalSupply = totalSupply();
        amount0 = (liquidity * balance0) / _totalSupply;
        amount1 = (liquidity * balance1) / _totalSupply;

        require(amount0 > 0 && amount1 > 0, "Insufficient liquidity burned");

        _burn(address(this), liquidity);
        _safeTransfer(token0, to, amount0);
        _safeTransfer(token1, to, amount1);

        balance0 = token0.balanceOf(address(this));
        balance1 = token1.balanceOf(address(this));
        _update(uint112(balance0), uint112(balance1));
    }

    function _update(uint112 balance0, uint112 balance1) internal {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "Overflow");

        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;

        if (timeElapsed > 0 && reserve0 != 0 && reserve1 != 0) {
            price0CumulativeLast += uint256((reserve1 * 2**112) / reserve0) * timeElapsed;
            price1CumulativeLast += uint256((reserve0 * 2**112) / reserve1) * timeElapsed;
        }

        reserve0 = balance0;
        reserve1 = balance1;
        blockTimestampLast = blockTimestamp;

        emit Sync(reserve0, reserve1);
    }

    function _safeTransfer(IERC20 token, address to, uint256 amount) internal {
        require(token.transfer(to, amount), "Transfer failed");
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        require(token.transferFrom(from, to, amount), "Transfer failed");
    }


    function setSwapFee(uint256 _swapFee) external onlyOwner {
        require(_swapFee <= MAX_FEE, "Fee too high");
        uint256 oldFee = swapFee;
        swapFee = _swapFee;
        emit FeeUpdated(oldFee, _swapFee);
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner validAddress(_feeRecipient) {
        feeRecipient = _feeRecipient;
    }

    function setTradingEnabled(bool _enabled) external onlyOwner {
        tradingEnabled = _enabled;
        emit TradingStatusChanged(_enabled);
    }

    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        require(token != address(token0) && token != address(token1), "Cannot withdraw pool tokens");
        IERC20(token).transfer(owner(), amount);
    }

    function sync() external {
        _update(uint112(token0.balanceOf(address(this))), uint112(token1.balanceOf(address(this))));
    }
}
