
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";


contract AutomatedMarketMakerLiquidityPool is ERC20, ReentrancyGuard, Ownable {
    using Math for uint256;


    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;


    uint256 public reserveA;
    uint256 public reserveB;


    uint256 public tradingFeeRate = 30;


    uint256 public constant MINIMUM_LIQUIDITY = 1000;


    uint256 public accumulatedFeesA;
    uint256 public accumulatedFeesB;


    event LiquidityAdded(
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidityTokens
    );

    event LiquidityRemoved(
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidityTokens
    );

    event TokensSwapped(
        address indexed trader,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    event TradingFeeRateUpdated(uint256 oldRate, uint256 newRate);
    event FeesWithdrawn(uint256 amountA, uint256 amountB);


    constructor(
        address _tokenA,
        address _tokenB,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        require(_tokenA != address(0), "TokenA address cannot be zero");
        require(_tokenB != address(0), "TokenB address cannot be zero");
        require(_tokenA != _tokenB, "Tokens must be different");

        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }


    function addLiquidity(
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) external nonReentrant returns (
        uint256 amountA,
        uint256 amountB,
        uint256 liquidityTokens
    ) {
        require(amountADesired > 0, "Amount A must be greater than zero");
        require(amountBDesired > 0, "Amount B must be greater than zero");


        (amountA, amountB) = _calculateOptimalAmounts(
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );


        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);


        liquidityTokens = _calculateLiquidityTokens(amountA, amountB);
        _mint(msg.sender, liquidityTokens);


        _updateReserves();

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidityTokens);
    }


    function removeLiquidity(
        uint256 liquidityTokens,
        uint256 amountAMin,
        uint256 amountBMin
    ) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        require(liquidityTokens > 0, "Liquidity tokens must be greater than zero");
        require(balanceOf(msg.sender) >= liquidityTokens, "Insufficient liquidity tokens");

        uint256 totalSupply = totalSupply();
        require(totalSupply > 0, "No liquidity available");


        amountA = (liquidityTokens * reserveA) / totalSupply;
        amountB = (liquidityTokens * reserveB) / totalSupply;

        require(amountA >= amountAMin, "Insufficient token A amount");
        require(amountB >= amountBMin, "Insufficient token B amount");


        _burn(msg.sender, liquidityTokens);


        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);


        _updateReserves();

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidityTokens);
    }


    function swapAForB(
        uint256 amountAIn,
        uint256 amountBOutMin
    ) external nonReentrant returns (uint256 amountBOut) {
        require(amountAIn > 0, "Input amount must be greater than zero");

        amountBOut = getAmountOut(amountAIn, reserveA, reserveB);
        require(amountBOut >= amountBOutMin, "Insufficient output amount");
        require(amountBOut < reserveB, "Insufficient liquidity");


        tokenA.transferFrom(msg.sender, address(this), amountAIn);


        tokenB.transfer(msg.sender, amountBOut);


        uint256 feeA = (amountAIn * tradingFeeRate) / 10000;
        accumulatedFeesA += feeA;


        _updateReserves();

        emit TokensSwapped(msg.sender, address(tokenA), address(tokenB), amountAIn, amountBOut);
    }


    function swapBForA(
        uint256 amountBIn,
        uint256 amountAOutMin
    ) external nonReentrant returns (uint256 amountAOut) {
        require(amountBIn > 0, "Input amount must be greater than zero");

        amountAOut = getAmountOut(amountBIn, reserveB, reserveA);
        require(amountAOut >= amountAOutMin, "Insufficient output amount");
        require(amountAOut < reserveA, "Insufficient liquidity");


        tokenB.transferFrom(msg.sender, address(this), amountBIn);


        tokenA.transfer(msg.sender, amountAOut);


        uint256 feeB = (amountBIn * tradingFeeRate) / 10000;
        accumulatedFeesB += feeB;


        _updateReserves();

        emit TokensSwapped(msg.sender, address(tokenB), address(tokenA), amountBIn, amountAOut);
    }


    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public view returns (uint256 amountOut) {
        require(amountIn > 0, "Input amount must be greater than zero");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");


        uint256 amountInWithFee = amountIn * (10000 - tradingFeeRate);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10000) + amountInWithFee;

        amountOut = numerator / denominator;
    }


    function setTradingFeeRate(uint256 newFeeRate) external onlyOwner {
        require(newFeeRate <= 1000, "Fee rate cannot exceed 10%");

        uint256 oldRate = tradingFeeRate;
        tradingFeeRate = newFeeRate;

        emit TradingFeeRateUpdated(oldRate, newFeeRate);
    }


    function withdrawFees() external onlyOwner {
        uint256 feesA = accumulatedFeesA;
        uint256 feesB = accumulatedFeesB;

        accumulatedFeesA = 0;
        accumulatedFeesB = 0;

        if (feesA > 0) {
            tokenA.transfer(owner(), feesA);
        }
        if (feesB > 0) {
            tokenB.transfer(owner(), feesB);
        }

        emit FeesWithdrawn(feesA, feesB);
    }


    function getReserves() external view returns (uint256 _reserveA, uint256 _reserveB) {
        _reserveA = reserveA;
        _reserveB = reserveB;
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
                require(amountBOptimal >= amountBMin, "Insufficient token B amount");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = (amountBDesired * reserveA) / reserveB;
                require(amountAOptimal <= amountADesired && amountAOptimal >= amountAMin, "Insufficient token A amount");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }


    function _calculateLiquidityTokens(
        uint256 amountA,
        uint256 amountB
    ) internal view returns (uint256 liquidityTokens) {
        uint256 totalSupply = totalSupply();

        if (totalSupply == 0) {

            liquidityTokens = Math.sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;

            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {

            liquidityTokens = Math.min(
                (amountA * totalSupply) / reserveA,
                (amountB * totalSupply) / reserveB
            );
        }

        require(liquidityTokens > 0, "Insufficient liquidity tokens");
    }


    function _updateReserves() internal {
        reserveA = tokenA.balanceOf(address(this)) - accumulatedFeesA;
        reserveB = tokenB.balanceOf(address(this)) - accumulatedFeesB;
    }
}
