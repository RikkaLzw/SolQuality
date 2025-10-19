
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


    uint256 public reserveA;
    uint256 public reserveB;


    uint256 public constant TRADING_FEE = 30;
    uint256 public constant FEE_DENOMINATOR = 10000;


    uint256 public constant MINIMUM_LIQUIDITY = 1000;


    uint256 public accumulatedFeeA;
    uint256 public accumulatedFeeB;


    event LiquidityAdded(
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );

    event LiquidityRemoved(
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );

    event TokensSwapped(
        address indexed trader,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    event ReservesUpdated(
        uint256 reserveA,
        uint256 reserveB
    );


    constructor(
        address _tokenA,
        address _tokenB,
        string memory _poolName,
        string memory _poolSymbol
    ) ERC20(_poolName, _poolSymbol) {
        require(_tokenA != address(0), "LiquidityPool: Invalid tokenA address");
        require(_tokenB != address(0), "LiquidityPool: Invalid tokenB address");
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
    ) external nonReentrant returns (
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    ) {
        require(to != address(0), "LiquidityPool: Invalid recipient");
        require(amountADesired > 0 && amountBDesired > 0, "LiquidityPool: Insufficient amounts");


        (amountA, amountB) = _calculateOptimalAmounts(
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );


        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);


        liquidity = _calculateLiquidityMint(amountA, amountB);


        _mint(to, liquidity);


        _updateReserves();

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }


    function removeLiquidity(
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) external nonReentrant returns (
        uint256 amountA,
        uint256 amountB
    ) {
        require(to != address(0), "LiquidityPool: Invalid recipient");
        require(liquidity > 0, "LiquidityPool: Insufficient liquidity");
        require(balanceOf(msg.sender) >= liquidity, "LiquidityPool: Insufficient balance");


        uint256 totalSupply = totalSupply();
        amountA = (liquidity * reserveA) / totalSupply;
        amountB = (liquidity * reserveB) / totalSupply;

        require(amountA >= amountAMin, "LiquidityPool: Insufficient amountA");
        require(amountB >= amountBMin, "LiquidityPool: Insufficient amountB");


        _burn(msg.sender, liquidity);


        tokenA.transfer(to, amountA);
        tokenB.transfer(to, amountB);


        _updateReserves();

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);
    }


    function swapAForB(
        uint256 amountIn,
        uint256 amountOutMin,
        address to
    ) external nonReentrant returns (uint256 amountOut) {
        require(to != address(0), "LiquidityPool: Invalid recipient");
        require(amountIn > 0, "LiquidityPool: Insufficient input amount");


        amountOut = _calculateSwapOutput(amountIn, reserveA, reserveB);
        require(amountOut >= amountOutMin, "LiquidityPool: Insufficient output amount");


        tokenA.transferFrom(msg.sender, address(this), amountIn);


        tokenB.transfer(to, amountOut);


        _updateReservesAndFees(amountIn, 0, 0, amountOut);

        emit TokensSwapped(msg.sender, address(tokenA), address(tokenB), amountIn, amountOut);
    }


    function swapBForA(
        uint256 amountIn,
        uint256 amountOutMin,
        address to
    ) external nonReentrant returns (uint256 amountOut) {
        require(to != address(0), "LiquidityPool: Invalid recipient");
        require(amountIn > 0, "LiquidityPool: Insufficient input amount");


        amountOut = _calculateSwapOutput(amountIn, reserveB, reserveA);
        require(amountOut >= amountOutMin, "LiquidityPool: Insufficient output amount");


        tokenB.transferFrom(msg.sender, address(this), amountIn);


        tokenA.transfer(to, amountOut);


        _updateReservesAndFees(0, amountIn, amountOut, 0);

        emit TokensSwapped(msg.sender, address(tokenB), address(tokenA), amountIn, amountOut);
    }


    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut) {
        return _calculateSwapOutput(amountIn, reserveIn, reserveOut);
    }


    function getCurrentRate() external view returns (
        uint256 rateAToB,
        uint256 rateBToA
    ) {
        if (reserveA > 0 && reserveB > 0) {
            rateAToB = (reserveB * 1e18) / reserveA;
            rateBToA = (reserveA * 1e18) / reserveB;
        }
    }


    function collectFees() external onlyOwner {
        if (accumulatedFeeA > 0) {
            tokenA.transfer(owner(), accumulatedFeeA);
            accumulatedFeeA = 0;
        }

        if (accumulatedFeeB > 0) {
            tokenB.transfer(owner(), accumulatedFeeB);
            accumulatedFeeB = 0;
        }
    }


    function _calculateOptimalAmounts(
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal view returns (uint256 amountA, uint256 amountB) {
        if (reserveA == 0 && reserveB == 0) {

            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {

            uint256 amountBOptimal = (amountADesired * reserveB) / reserveA;

            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "LiquidityPool: Insufficient amountB");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = (amountBDesired * reserveA) / reserveB;
                require(amountAOptimal <= amountADesired && amountAOptimal >= amountAMin,
                       "LiquidityPool: Insufficient amountA");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }


    function _calculateLiquidityMint(
        uint256 amountA,
        uint256 amountB
    ) internal view returns (uint256 liquidity) {
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
    }


    function _calculateSwapOutput(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "LiquidityPool: Insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "LiquidityPool: Insufficient liquidity");


        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - TRADING_FEE);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;

        amountOut = numerator / denominator;
    }


    function _updateReserves() internal {
        reserveA = tokenA.balanceOf(address(this)) - accumulatedFeeA;
        reserveB = tokenB.balanceOf(address(this)) - accumulatedFeeB;

        emit ReservesUpdated(reserveA, reserveB);
    }


    function _updateReservesAndFees(
        uint256 amountInA,
        uint256 amountInB,
        uint256 amountOutA,
        uint256 amountOutB
    ) internal {

        if (amountInA > 0) {
            uint256 feeA = (amountInA * TRADING_FEE) / FEE_DENOMINATOR;
            accumulatedFeeA += feeA;
        }

        if (amountInB > 0) {
            uint256 feeB = (amountInB * TRADING_FEE) / FEE_DENOMINATOR;
            accumulatedFeeB += feeB;
        }


        _updateReserves();
    }
}
