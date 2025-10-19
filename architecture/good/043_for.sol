
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";


contract LiquidityPool is ERC20, ReentrancyGuard, Ownable {
    using Math for uint256;


    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;

    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public lastBlockTimestamp;


    uint256 public constant MINIMUM_LIQUIDITY = 10**3;
    uint256 public constant FEE_RATE = 3;
    uint256 public constant FEE_DENOMINATOR = 1000;


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


    modifier validAddress(address _address) {
        require(_address != address(0), "LiquidityPool: Invalid address");
        _;
    }

    modifier validAmount(uint256 _amount) {
        require(_amount > 0, "LiquidityPool: Invalid amount");
        _;
    }

    modifier updateReserves() {
        _;
        _update();
    }

    constructor(
        address _tokenA,
        address _tokenB,
        string memory _name,
        string memory _symbol
    )
        ERC20(_name, _symbol)
        validAddress(_tokenA)
        validAddress(_tokenB)
    {
        require(_tokenA != _tokenB, "LiquidityPool: Identical tokens");
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }


    function addLiquidity(
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    )
        external
        nonReentrant
        validAddress(to)
        validAmount(amountADesired)
        validAmount(amountBDesired)
        updateReserves
        returns (uint256 amountA, uint256 amountB, uint256 liquidity)
    {
        (amountA, amountB) = _calculateLiquidityAmounts(
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );

        _transferTokensFrom(msg.sender, amountA, amountB);
        liquidity = _mintLiquidity(to, amountA, amountB);

        emit Mint(msg.sender, amountA, amountB);
    }


    function removeLiquidity(
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    )
        external
        nonReentrant
        validAddress(to)
        validAmount(liquidity)
        updateReserves
        returns (uint256 amountA, uint256 amountB)
    {
        require(balanceOf(msg.sender) >= liquidity, "LiquidityPool: Insufficient LP tokens");

        (amountA, amountB) = _calculateWithdrawAmounts(liquidity);

        require(amountA >= amountAMin, "LiquidityPool: Insufficient tokenA amount");
        require(amountB >= amountBMin, "LiquidityPool: Insufficient tokenB amount");

        _burn(msg.sender, liquidity);
        _transferTokensTo(to, amountA, amountB);

        emit Burn(msg.sender, amountA, amountB, to);
    }


    function swap(
        uint256 amountAOut,
        uint256 amountBOut,
        address to
    ) external nonReentrant validAddress(to) updateReserves {
        require(amountAOut > 0 || amountBOut > 0, "LiquidityPool: Insufficient output amount");
        require(amountAOut < reserveA && amountBOut < reserveB, "LiquidityPool: Insufficient liquidity");

        uint256 balanceABefore = tokenA.balanceOf(address(this));
        uint256 balanceBBefore = tokenB.balanceOf(address(this));

        if (amountAOut > 0) tokenA.transfer(to, amountAOut);
        if (amountBOut > 0) tokenB.transfer(to, amountBOut);

        uint256 balanceA = tokenA.balanceOf(address(this));
        uint256 balanceB = tokenB.balanceOf(address(this));

        uint256 amountAIn = balanceA > balanceABefore - amountAOut ?
            balanceA - (balanceABefore - amountAOut) : 0;
        uint256 amountBIn = balanceB > balanceBBefore - amountBOut ?
            balanceB - (balanceBBefore - amountBOut) : 0;

        require(amountAIn > 0 || amountBIn > 0, "LiquidityPool: Insufficient input amount");

        _validateSwap(balanceA, balanceB, amountAIn, amountBIn);

        emit Swap(msg.sender, amountAIn, amountBIn, amountAOut, amountBOut, to);
    }


    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        require(amountIn > 0, "LiquidityPool: Insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "LiquidityPool: Insufficient liquidity");

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_RATE);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;
        amountOut = numerator / denominator;
    }


    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountIn) {
        require(amountOut > 0, "LiquidityPool: Insufficient output amount");
        require(reserveIn > 0 && reserveOut > 0, "LiquidityPool: Insufficient liquidity");

        uint256 numerator = reserveIn * amountOut * FEE_DENOMINATOR;
        uint256 denominator = (reserveOut - amountOut) * (FEE_DENOMINATOR - FEE_RATE);
        amountIn = (numerator / denominator) + 1;
    }


    function sync() external {
        _update();
    }


    function getReserves()
        external
        view
        returns (uint256 _reserveA, uint256 _reserveB, uint256 _blockTimestamp)
    {
        _reserveA = reserveA;
        _reserveB = reserveB;
        _blockTimestamp = lastBlockTimestamp;
    }


    function _calculateLiquidityAmounts(
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal view returns (uint256 amountA, uint256 amountB) {
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = _quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "LiquidityPool: Insufficient tokenB amount");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = _quote(amountBDesired, reserveB, reserveA);
                require(amountAOptimal <= amountADesired && amountAOptimal >= amountAMin,
                    "LiquidityPool: Insufficient tokenA amount");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function _mintLiquidity(
        address to,
        uint256 amountA,
        uint256 amountB
    ) internal returns (uint256 liquidity) {
        uint256 totalSupply = totalSupply();

        if (totalSupply == 0) {
            liquidity = Math.sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = Math.min(
                (amountA * totalSupply) / reserveA,
                (amountB * totalSupply) / reserveB
            );
        }

        require(liquidity > 0, "LiquidityPool: Insufficient liquidity minted");
        _mint(to, liquidity);
    }

    function _calculateWithdrawAmounts(uint256 liquidity)
        internal
        view
        returns (uint256 amountA, uint256 amountB)
    {
        uint256 totalSupply = totalSupply();
        amountA = (liquidity * reserveA) / totalSupply;
        amountB = (liquidity * reserveB) / totalSupply;

        require(amountA > 0 && amountB > 0, "LiquidityPool: Insufficient liquidity burned");
    }

    function _transferTokensFrom(address from, uint256 amountA, uint256 amountB) internal {
        tokenA.transferFrom(from, address(this), amountA);
        tokenB.transferFrom(from, address(this), amountB);
    }

    function _transferTokensTo(address to, uint256 amountA, uint256 amountB) internal {
        tokenA.transfer(to, amountA);
        tokenB.transfer(to, amountB);
    }

    function _validateSwap(
        uint256 balanceA,
        uint256 balanceB,
        uint256 amountAIn,
        uint256 amountBIn
    ) internal view {
        uint256 balanceAdjustedA = (balanceA * FEE_DENOMINATOR) - (amountAIn * FEE_RATE);
        uint256 balanceAdjustedB = (balanceB * FEE_DENOMINATOR) - (amountBIn * FEE_RATE);

        require(
            balanceAdjustedA * balanceAdjustedB >=
            reserveA * reserveB * (FEE_DENOMINATOR ** 2),
            "LiquidityPool: K value decreased"
        );
    }

    function _update() internal {
        uint256 balanceA = tokenA.balanceOf(address(this));
        uint256 balanceB = tokenB.balanceOf(address(this));

        reserveA = balanceA;
        reserveB = balanceB;
        lastBlockTimestamp = block.timestamp;

        emit Sync(reserveA, reserveB);
    }

    function _quote(uint256 amountA, uint256 reserveA_, uint256 reserveB_)
        internal
        pure
        returns (uint256 amountB)
    {
        require(amountA > 0, "LiquidityPool: Insufficient amount");
        require(reserveA_ > 0 && reserveB_ > 0, "LiquidityPool: Insufficient liquidity");
        amountB = (amountA * reserveB_) / reserveA_;
    }
}
