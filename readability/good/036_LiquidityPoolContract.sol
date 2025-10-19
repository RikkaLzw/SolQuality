
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


    uint256 public tradingFeeRate = 30;


    uint256 public constant MINIMUM_LIQUIDITY = 10**3;


    uint256 public accumulatedFeesTokenA;


    uint256 public accumulatedFeesTokenB;




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


    event TokenSwapped(
        address indexed trader,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );


    event TradingFeeRateUpdated(uint256 oldRate, uint256 newRate);




    modifier validAmount(uint256 amount) {
        require(amount > 0, "LiquidityPool: Amount must be greater than zero");
        _;
    }


    modifier validAddress(address account) {
        require(account != address(0), "LiquidityPool: Invalid address");
        _;
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
        require(_tokenA != _tokenB, "LiquidityPool: Identical token addresses");

        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
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
        validAmount(amountADesired)
        validAmount(amountBDesired)
        validAddress(to)
        returns (uint256 amountA, uint256 amountB, uint256 liquidityTokens)
    {
        require(block.timestamp <= deadline, "LiquidityPool: Transaction expired");

        (amountA, amountB) = _calculateOptimalAmounts(
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );


        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);


        liquidityTokens = _calculateLiquidityTokens(amountA, amountB);
        _mint(to, liquidityTokens);

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidityTokens);
    }


    function removeLiquidity(
        uint256 liquidityTokens,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        nonReentrant
        validAmount(liquidityTokens)
        validAddress(to)
        returns (uint256 amountA, uint256 amountB)
    {
        require(block.timestamp <= deadline, "LiquidityPool: Transaction expired");
        require(balanceOf(msg.sender) >= liquidityTokens, "LiquidityPool: Insufficient liquidity tokens");


        uint256 totalSupply = totalSupply();
        uint256 balanceA = tokenA.balanceOf(address(this)) - accumulatedFeesTokenA;
        uint256 balanceB = tokenB.balanceOf(address(this)) - accumulatedFeesTokenB;

        amountA = (liquidityTokens * balanceA) / totalSupply;
        amountB = (liquidityTokens * balanceB) / totalSupply;

        require(amountA >= amountAMin, "LiquidityPool: Insufficient token A amount");
        require(amountB >= amountBMin, "LiquidityPool: Insufficient token B amount");


        _burn(msg.sender, liquidityTokens);


        tokenA.transfer(to, amountA);
        tokenB.transfer(to, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidityTokens);
    }


    function swapTokenAForTokenB(
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline
    )
        external
        nonReentrant
        validAmount(amountIn)
        validAddress(to)
        returns (uint256 amountOut)
    {
        require(block.timestamp <= deadline, "LiquidityPool: Transaction expired");

        amountOut = getAmountOut(amountIn, true);
        require(amountOut >= amountOutMin, "LiquidityPool: Insufficient output amount");


        tokenA.transferFrom(msg.sender, address(this), amountIn);


        uint256 fee = (amountIn * tradingFeeRate) / 10000;
        accumulatedFeesTokenA += fee;


        tokenB.transfer(to, amountOut);

        emit TokenSwapped(msg.sender, address(tokenA), address(tokenB), amountIn, amountOut);
    }


    function swapTokenBForTokenA(
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline
    )
        external
        nonReentrant
        validAmount(amountIn)
        validAddress(to)
        returns (uint256 amountOut)
    {
        require(block.timestamp <= deadline, "LiquidityPool: Transaction expired");

        amountOut = getAmountOut(amountIn, false);
        require(amountOut >= amountOutMin, "LiquidityPool: Insufficient output amount");


        tokenB.transferFrom(msg.sender, address(this), amountIn);


        uint256 fee = (amountIn * tradingFeeRate) / 10000;
        accumulatedFeesTokenB += fee;


        tokenA.transfer(to, amountOut);

        emit TokenSwapped(msg.sender, address(tokenB), address(tokenA), amountIn, amountOut);
    }




    function updateTradingFeeRate(uint256 newFeeRate) external onlyOwner {
        require(newFeeRate <= 1000, "LiquidityPool: Fee rate too high");

        uint256 oldRate = tradingFeeRate;
        tradingFeeRate = newFeeRate;

        emit TradingFeeRateUpdated(oldRate, newFeeRate);
    }


    function withdrawAccumulatedFees(address to) external onlyOwner validAddress(to) {
        uint256 feesA = accumulatedFeesTokenA;
        uint256 feesB = accumulatedFeesTokenB;

        if (feesA > 0) {
            accumulatedFeesTokenA = 0;
            tokenA.transfer(to, feesA);
        }

        if (feesB > 0) {
            accumulatedFeesTokenB = 0;
            tokenB.transfer(to, feesB);
        }
    }




    function getReserves() external view returns (uint256 reserveA, uint256 reserveB) {
        reserveA = tokenA.balanceOf(address(this)) - accumulatedFeesTokenA;
        reserveB = tokenB.balanceOf(address(this)) - accumulatedFeesTokenB;
    }


    function getAmountOut(uint256 amountIn, bool isTokenAToB) public view returns (uint256 amountOut) {
        require(amountIn > 0, "LiquidityPool: Insufficient input amount");

        uint256 reserveA = tokenA.balanceOf(address(this)) - accumulatedFeesTokenA;
        uint256 reserveB = tokenB.balanceOf(address(this)) - accumulatedFeesTokenB;

        require(reserveA > 0 && reserveB > 0, "LiquidityPool: Insufficient liquidity");

        if (isTokenAToB) {
            uint256 amountInWithFee = amountIn * (10000 - tradingFeeRate);
            uint256 numerator = amountInWithFee * reserveB;
            uint256 denominator = (reserveA * 10000) + amountInWithFee;
            amountOut = numerator / denominator;
        } else {
            uint256 amountInWithFee = amountIn * (10000 - tradingFeeRate);
            uint256 numerator = amountInWithFee * reserveA;
            uint256 denominator = (reserveB * 10000) + amountInWithFee;
            amountOut = numerator / denominator;
        }
    }


    function getAmountIn(uint256 amountOut, bool isTokenAToB) external view returns (uint256 amountIn) {
        require(amountOut > 0, "LiquidityPool: Insufficient output amount");

        uint256 reserveA = tokenA.balanceOf(address(this)) - accumulatedFeesTokenA;
        uint256 reserveB = tokenB.balanceOf(address(this)) - accumulatedFeesTokenB;

        require(reserveA > 0 && reserveB > 0, "LiquidityPool: Insufficient liquidity");

        if (isTokenAToB) {
            require(amountOut < reserveB, "LiquidityPool: Insufficient reserve B");
            uint256 numerator = reserveA * amountOut * 10000;
            uint256 denominator = (reserveB - amountOut) * (10000 - tradingFeeRate);
            amountIn = (numerator / denominator) + 1;
        } else {
            require(amountOut < reserveA, "LiquidityPool: Insufficient reserve A");
            uint256 numerator = reserveB * amountOut * 10000;
            uint256 denominator = (reserveA - amountOut) * (10000 - tradingFeeRate);
            amountIn = (numerator / denominator) + 1;
        }
    }




    function _calculateOptimalAmounts(
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal view returns (uint256 amountA, uint256 amountB) {
        uint256 reserveA = tokenA.balanceOf(address(this)) - accumulatedFeesTokenA;
        uint256 reserveB = tokenB.balanceOf(address(this)) - accumulatedFeesTokenB;

        if (reserveA == 0 && reserveB == 0) {

            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {

            uint256 amountBOptimal = (amountADesired * reserveB) / reserveA;
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "LiquidityPool: Insufficient token B amount");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = (amountBDesired * reserveA) / reserveB;
                require(amountAOptimal <= amountADesired && amountAOptimal >= amountAMin,
                        "LiquidityPool: Insufficient token A amount");
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

            uint256 reserveA = tokenA.balanceOf(address(this)) - accumulatedFeesTokenA - amountA;
            uint256 reserveB = tokenB.balanceOf(address(this)) - accumulatedFeesTokenB - amountB;

            liquidityTokens = Math.min(
                (amountA * totalSupply) / reserveA,
                (amountB * totalSupply) / reserveB
            );
        }

        require(liquidityTokens > 0, "LiquidityPool: Insufficient liquidity minted");
    }
}
