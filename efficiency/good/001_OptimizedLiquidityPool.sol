
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract OptimizedLiquidityPool is ERC20, ReentrancyGuard, Ownable {
    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;

    uint256 private reserveA;
    uint256 private reserveB;
    uint256 private blockTimestampLast;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public kLast;

    uint256 private constant MINIMUM_LIQUIDITY = 10**3;
    uint256 private constant FEE_RATE = 3;
    uint256 private constant FEE_DENOMINATOR = 1000;

    mapping(address => uint256) private userLastDeposit;

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

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "EXPIRED");
        _;
    }

    constructor(
        address _tokenA,
        address _tokenB,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        require(_tokenA != address(0) && _tokenB != address(0), "ZERO_ADDRESS");
        require(_tokenA != _tokenB, "IDENTICAL_ADDRESSES");

        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    function getReserves() public view returns (uint256 _reserveA, uint256 _reserveB, uint256 _blockTimestampLast) {
        _reserveA = reserveA;
        _reserveB = reserveB;
        _blockTimestampLast = blockTimestampLast;
    }

    function _update(uint256 balanceA, uint256 balanceB, uint256 _reserveA, uint256 _reserveB) private {
        require(balanceA <= type(uint112).max && balanceB <= type(uint112).max, "OVERFLOW");

        uint256 blockTimestamp = block.timestamp % 2**32;
        uint256 timeElapsed;

        unchecked {
            timeElapsed = blockTimestamp - blockTimestampLast;
        }

        if (timeElapsed > 0 && _reserveA != 0 && _reserveB != 0) {
            unchecked {
                price0CumulativeLast += ((_reserveB * 1e18) / _reserveA) * timeElapsed;
                price1CumulativeLast += ((_reserveA * 1e18) / _reserveB) * timeElapsed;
            }
        }

        reserveA = balanceA;
        reserveB = balanceB;
        blockTimestampLast = blockTimestamp;

        emit Sync(reserveA, reserveB);
    }

    function _mintFee(uint256 _reserveA, uint256 _reserveB) private returns (bool feeOn) {
        address feeTo = owner();
        feeOn = feeTo != address(0);
        uint256 _kLast = kLast;

        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = _sqrt(_reserveA * _reserveB);
                uint256 rootKLast = _sqrt(_kLast);

                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply() * (rootK - rootKLast);
                    uint256 denominator = rootK * 5 + rootKLast;
                    uint256 liquidity = numerator / denominator;

                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    function mint(address to) external nonReentrant returns (uint256 liquidity) {
        (uint256 _reserveA, uint256 _reserveB,) = getReserves();
        uint256 balanceA = tokenA.balanceOf(address(this));
        uint256 balanceB = tokenB.balanceOf(address(this));
        uint256 amountA = balanceA - _reserveA;
        uint256 amountB = balanceB - _reserveB;

        bool feeOn = _mintFee(_reserveA, _reserveB);
        uint256 _totalSupply = totalSupply();

        if (_totalSupply == 0) {
            liquidity = _sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            uint256 liquidityA = (amountA * _totalSupply) / _reserveA;
            uint256 liquidityB = (amountB * _totalSupply) / _reserveB;
            liquidity = liquidityA < liquidityB ? liquidityA : liquidityB;
        }

        require(liquidity > 0, "INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);

        _update(balanceA, balanceB, _reserveA, _reserveB);

        if (feeOn) kLast = reserveA * reserveB;

        userLastDeposit[to] = block.timestamp;
        emit Mint(msg.sender, amountA, amountB);
    }

    function burn(address to) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        (uint256 _reserveA, uint256 _reserveB,) = getReserves();
        address _tokenA = address(tokenA);
        address _tokenB = address(tokenB);
        uint256 balanceA = IERC20(_tokenA).balanceOf(address(this));
        uint256 balanceB = IERC20(_tokenB).balanceOf(address(this));
        uint256 liquidity = balanceOf(address(this));

        bool feeOn = _mintFee(_reserveA, _reserveB);
        uint256 _totalSupply = totalSupply();

        amountA = (liquidity * balanceA) / _totalSupply;
        amountB = (liquidity * balanceB) / _totalSupply;

        require(amountA > 0 && amountB > 0, "INSUFFICIENT_LIQUIDITY_BURNED");

        _burn(address(this), liquidity);

        IERC20(_tokenA).transfer(to, amountA);
        IERC20(_tokenB).transfer(to, amountB);

        balanceA = IERC20(_tokenA).balanceOf(address(this));
        balanceB = IERC20(_tokenB).balanceOf(address(this));

        _update(balanceA, balanceB, _reserveA, _reserveB);

        if (feeOn) kLast = reserveA * reserveB;

        emit Burn(msg.sender, amountA, amountB, to);
    }

    function swap(uint256 amountAOut, uint256 amountBOut, address to, bytes calldata data) external nonReentrant {
        require(amountAOut > 0 || amountBOut > 0, "INSUFFICIENT_OUTPUT_AMOUNT");
        (uint256 _reserveA, uint256 _reserveB,) = getReserves();
        require(amountAOut < _reserveA && amountBOut < _reserveB, "INSUFFICIENT_LIQUIDITY");

        uint256 balanceA;
        uint256 balanceB;

        {
            address _tokenA = address(tokenA);
            address _tokenB = address(tokenB);
            require(to != _tokenA && to != _tokenB, "INVALID_TO");

            if (amountAOut > 0) IERC20(_tokenA).transfer(to, amountAOut);
            if (amountBOut > 0) IERC20(_tokenB).transfer(to, amountBOut);

            if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amountAOut, amountBOut, data);

            balanceA = IERC20(_tokenA).balanceOf(address(this));
            balanceB = IERC20(_tokenB).balanceOf(address(this));
        }

        uint256 amountAIn = balanceA > _reserveA - amountAOut ? balanceA - (_reserveA - amountAOut) : 0;
        uint256 amountBIn = balanceB > _reserveB - amountBOut ? balanceB - (_reserveB - amountBOut) : 0;

        require(amountAIn > 0 || amountBIn > 0, "INSUFFICIENT_INPUT_AMOUNT");

        {
            uint256 balanceAAdjusted = balanceA * FEE_DENOMINATOR - amountAIn * FEE_RATE;
            uint256 balanceBAdjusted = balanceB * FEE_DENOMINATOR - amountBIn * FEE_RATE;
            require(balanceAAdjusted * balanceBAdjusted >= _reserveA * _reserveB * (FEE_DENOMINATOR**2), "K");
        }

        _update(balanceA, balanceB, _reserveA, _reserveB);
        emit Swap(msg.sender, amountAIn, amountBIn, amountAOut, amountBOut, to);
    }

    function skim(address to) external nonReentrant {
        address _tokenA = address(tokenA);
        address _tokenB = address(tokenB);

        IERC20(_tokenA).transfer(to, IERC20(_tokenA).balanceOf(address(this)) - reserveA);
        IERC20(_tokenB).transfer(to, IERC20(_tokenB).balanceOf(address(this)) - reserveB);
    }

    function sync() external nonReentrant {
        _update(tokenA.balanceOf(address(this)), tokenB.balanceOf(address(this)), reserveA, reserveB);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_RATE);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * FEE_DENOMINATOR + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        returns (uint256 amountIn)
    {
        require(amountOut > 0, "INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");

        uint256 numerator = reserveIn * amountOut * FEE_DENOMINATOR;
        uint256 denominator = (reserveOut - amountOut) * (FEE_DENOMINATOR - FEE_RATE);
        amountIn = (numerator / denominator) + 1;
    }

    function _sqrt(uint256 y) internal pure returns (uint256 z) {
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

interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint256 amountAOut, uint256 amountBOut, bytes calldata data) external;
}
