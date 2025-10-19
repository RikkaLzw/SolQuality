
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";


contract LiquidityPoolContract is ERC20, ReentrancyGuard, Ownable {
    using Math for uint256;




    IERC20 public immutable tokenA;


    IERC20 public immutable tokenB;


    uint256 public tradingFeeRate;


    uint256 public protocolFeeRate;


    uint256 public accumulatedProtocolFeeA;


    uint256 public accumulatedProtocolFeeB;


    uint256 public constant MINIMUM_LIQUIDITY = 10**3;


    uint256 public constant BASIS_POINTS = 10000;




    event LiquidityAdded(
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidityMinted
    );


    event LiquidityRemoved(
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidityBurned
    );


    event TokenSwapped(
        address indexed trader,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );


    event FeeRatesUpdated(
        uint256 newTradingFeeRate,
        uint256 newProtocolFeeRate
    );




    modifier notZeroAddress(address account) {
        require(account != address(0), "LiquidityPool: Zero address not allowed");
        _;
    }


    modifier positiveAmount(uint256 amount) {
        require(amount > 0, "LiquidityPool: Amount must be positive");
        _;
    }




    constructor(
        address _tokenA,
        address _tokenB,
        uint256 _tradingFeeRate,
        uint256 _protocolFeeRate
    )
        ERC20("Liquidity Pool Token", "LPT")
        Ownable(msg.sender)
        notZeroAddress(_tokenA)
        notZeroAddress(_tokenB)
    {
        require(_tokenA != _tokenB, "LiquidityPool: Identical token addresses");
        require(_tradingFeeRate <= 1000, "LiquidityPool: Trading fee too high");
        require(_protocolFeeRate <= 500, "LiquidityPool: Protocol fee too high");

        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        tradingFeeRate = _tradingFeeRate;
        protocolFeeRate = _protocolFeeRate;
    }




    function addLiquidity(
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        nonReentrant
        notZeroAddress(to)
        positiveAmount(amountADesired)
        positiveAmount(amountBDesired)
        returns (uint256 amountA, uint256 amountB, uint256 liquidity)
    {
        require(block.timestamp <= deadline, "LiquidityPool: Transaction expired");

        (amountA, amountB) = _calculateOptimalAmounts(
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );


        require(
            tokenA.transferFrom(msg.sender, address(this), amountA),
            "LiquidityPool: TokenA transfer failed"
        );
        require(
            tokenB.transferFrom(msg.sender, address(this), amountB),
            "LiquidityPool: TokenB transfer failed"
        );


        liquidity = _mintLiquidity(to, amountA, amountB);

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }


    function removeLiquidity(
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        nonReentrant
        notZeroAddress(to)
        positiveAmount(liquidity)
        returns (uint256 amountA, uint256 amountB)
    {
        require(block.timestamp <= deadline, "LiquidityPool: Transaction expired");
        require(balanceOf(msg.sender) >= liquidity, "LiquidityPool: Insufficient liquidity");


        uint256 totalSupply = totalSupply();
        uint256 balanceA = tokenA.balanceOf(address(this)) - accumulatedProtocolFeeA;
        uint256 balanceB = tokenB.balanceOf(address(this)) - accumulatedProtocolFeeB;

        amountA = (liquidity * balanceA) / totalSupply;
        amountB = (liquidity * balanceB) / totalSupply;

        require(amountA >= amountAMin, "LiquidityPool: Insufficient TokenA amount");
        require(amountB >= amountBMin, "LiquidityPool: Insufficient TokenB amount");


        _burn(msg.sender, liquidity);


        require(tokenA.transfer(to, amountA), "LiquidityPool: TokenA transfer failed");
        require(tokenB.transfer(to, amountB), "LiquidityPool: TokenB transfer failed");

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);
    }


    function swapAForB(
        uint256 amountAIn,
        uint256 amountBOutMin,
        address to,
        uint256 deadline
    )
        external
        nonReentrant
        notZeroAddress(to)
        positiveAmount(amountAIn)
        returns (uint256 amountBOut)
    {
        require(block.timestamp <= deadline, "LiquidityPool: Transaction expired");

        amountBOut = _calculateSwapOutput(amountAIn, true);
        require(amountBOut >= amountBOutMin, "LiquidityPool: Insufficient output amount");


        require(
            tokenA.transferFrom(msg.sender, address(this), amountAIn),
            "LiquidityPool: TokenA transfer failed"
        );


        uint256 protocolFee = (amountAIn * protocolFeeRate) / BASIS_POINTS;
        accumulatedProtocolFeeA += protocolFee;


        require(tokenB.transfer(to, amountBOut), "LiquidityPool: TokenB transfer failed");

        emit TokenSwapped(msg.sender, address(tokenA), address(tokenB), amountAIn, amountBOut);
    }


    function swapBForA(
        uint256 amountBIn,
        uint256 amountAOutMin,
        address to,
        uint256 deadline
    )
        external
        nonReentrant
        notZeroAddress(to)
        positiveAmount(amountBIn)
        returns (uint256 amountAOut)
    {
        require(block.timestamp <= deadline, "LiquidityPool: Transaction expired");

        amountAOut = _calculateSwapOutput(amountBIn, false);
        require(amountAOut >= amountAOutMin, "LiquidityPool: Insufficient output amount");


        require(
            tokenB.transferFrom(msg.sender, address(this), amountBIn),
            "LiquidityPool: TokenB transfer failed"
        );


        uint256 protocolFee = (amountBIn * protocolFeeRate) / BASIS_POINTS;
        accumulatedProtocolFeeB += protocolFee;


        require(tokenA.transfer(to, amountAOut), "LiquidityPool: TokenA transfer failed");

        emit TokenSwapped(msg.sender, address(tokenB), address(tokenA), amountBIn, amountAOut);
    }




    function updateFeeRates(
        uint256 _tradingFeeRate,
        uint256 _protocolFeeRate
    ) external onlyOwner {
        require(_tradingFeeRate <= 1000, "LiquidityPool: Trading fee too high");
        require(_protocolFeeRate <= 500, "LiquidityPool: Protocol fee too high");

        tradingFeeRate = _tradingFeeRate;
        protocolFeeRate = _protocolFeeRate;

        emit FeeRatesUpdated(_tradingFeeRate, _protocolFeeRate);
    }


    function collectProtocolFees(address to) external onlyOwner notZeroAddress(to) {
        uint256 feeA = accumulatedProtocolFeeA;
        uint256 feeB = accumulatedProtocolFeeB;

        if (feeA > 0) {
            accumulatedProtocolFeeA = 0;
            require(tokenA.transfer(to, feeA), "LiquidityPool: TokenA fee transfer failed");
        }

        if (feeB > 0) {
            accumulatedProtocolFeeB = 0;
            require(tokenB.transfer(to, feeB), "LiquidityPool: TokenB fee transfer failed");
        }
    }




    function getReserves() external view returns (uint256 reserveA, uint256 reserveB) {
        reserveA = tokenA.balanceOf(address(this)) - accumulatedProtocolFeeA;
        reserveB = tokenB.balanceOf(address(this)) - accumulatedProtocolFeeB;
    }


    function getAmountOut(
        uint256 amountIn,
        bool isAForB
    ) external view returns (uint256 amountOut) {
        return _calculateSwapOutput(amountIn, isAForB);
    }




    function _calculateOptimalAmounts(
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal view returns (uint256 amountA, uint256 amountB) {
        uint256 reserveA = tokenA.balanceOf(address(this)) - accumulatedProtocolFeeA;
        uint256 reserveB = tokenB.balanceOf(address(this)) - accumulatedProtocolFeeB;

        if (reserveA == 0 && reserveB == 0) {

            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {

            uint256 amountBOptimal = (amountADesired * reserveB) / reserveA;
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "LiquidityPool: Insufficient TokenB amount");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = (amountBDesired * reserveA) / reserveB;
                require(amountAOptimal >= amountAMin, "LiquidityPool: Insufficient TokenA amount");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }


    function _mintLiquidity(
        address to,
        uint256 amountA,
        uint256 amountB
    ) internal returns (uint256 liquidity) {
        uint256 _totalSupply = totalSupply();

        if (_totalSupply == 0) {

            liquidity = Math.sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
            _mint(address(1), MINIMUM_LIQUIDITY);
        } else {

            uint256 reserveA = tokenA.balanceOf(address(this)) - accumulatedProtocolFeeA - amountA;
            uint256 reserveB = tokenB.balanceOf(address(this)) - accumulatedProtocolFeeB - amountB;

            liquidity = Math.min(
                (amountA * _totalSupply) / reserveA,
                (amountB * _totalSupply) / reserveB
            );
        }

        require(liquidity > 0, "LiquidityPool: Insufficient liquidity minted");
        _mint(to, liquidity);
    }


    function _calculateSwapOutput(
        uint256 amountIn,
        bool isAForB
    ) internal view returns (uint256 amountOut) {
        uint256 reserveA = tokenA.balanceOf(address(this)) - accumulatedProtocolFeeA;
        uint256 reserveB = tokenB.balanceOf(address(this)) - accumulatedProtocolFeeB;

        require(reserveA > 0 && reserveB > 0, "LiquidityPool: Insufficient liquidity");


        uint256 amountInWithFee = amountIn * (BASIS_POINTS - tradingFeeRate);

        if (isAForB) {

            amountOut = (amountInWithFee * reserveB) / (reserveA * BASIS_POINTS + amountInWithFee);
        } else {
            amountOut = (amountInWithFee * reserveA) / (reserveB * BASIS_POINTS + amountInWithFee);
        }

        require(amountOut > 0, "LiquidityPool: Insufficient output amount");
    }
}
