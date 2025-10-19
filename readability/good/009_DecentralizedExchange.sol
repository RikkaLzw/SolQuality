
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract DecentralizedExchange is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;




    uint256 public tradingFeeRate = 30;


    uint256 public liquidityProviderFeeRate = 25;


    uint256 public protocolFeeRate = 5;


    uint256 public constant MINIMUM_LIQUIDITY = 1000;


    uint256 public tradingPairCount;




    struct TradingPair {
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalLiquidity;
        uint256 kLast;
        bool isActive;
    }


    struct LiquidityProvider {
        uint256 liquidityTokens;
        uint256 lastUpdateTime;
    }




    mapping(uint256 => TradingPair) public tradingPairs;


    mapping(address => mapping(address => uint256)) public getPairId;


    mapping(uint256 => mapping(address => LiquidityProvider)) public liquidityProviders;


    mapping(address => uint256) public protocolFees;




    event TradingPairCreated(
        uint256 indexed pairId,
        address indexed tokenA,
        address indexed tokenB,
        address creator
    );


    event LiquidityAdded(
        uint256 indexed pairId,
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidityMinted
    );


    event LiquidityRemoved(
        uint256 indexed pairId,
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidityBurned
    );


    event TokenSwapped(
        uint256 indexed pairId,
        address indexed trader,
        address indexed tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );




    modifier validPair(uint256 pairId) {
        require(pairId > 0 && pairId <= tradingPairCount, "DEX: Invalid pair ID");
        require(tradingPairs[pairId].isActive, "DEX: Pair not active");
        _;
    }


    modifier validAddress(address addr) {
        require(addr != address(0), "DEX: Invalid address");
        _;
    }




    constructor() {
        tradingPairCount = 0;
    }




    function createTradingPair(
        address tokenA,
        address tokenB
    )
        external
        validAddress(tokenA)
        validAddress(tokenB)
        whenNotPaused
        returns (uint256 pairId)
    {
        require(tokenA != tokenB, "DEX: Identical tokens");
        require(getPairId[tokenA][tokenB] == 0, "DEX: Pair already exists");


        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }

        tradingPairCount++;
        pairId = tradingPairCount;

        tradingPairs[pairId] = TradingPair({
            tokenA: tokenA,
            tokenB: tokenB,
            reserveA: 0,
            reserveB: 0,
            totalLiquidity: 0,
            kLast: 0,
            isActive: true
        });

        getPairId[tokenA][tokenB] = pairId;
        getPairId[tokenB][tokenA] = pairId;

        emit TradingPairCreated(pairId, tokenA, tokenB, msg.sender);
    }


    function addLiquidity(
        uint256 pairId,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    )
        external
        validPair(pairId)
        nonReentrant
        whenNotPaused
        returns (uint256 amountA, uint256 amountB, uint256 liquidityMinted)
    {
        TradingPair storage pair = tradingPairs[pairId];


        (amountA, amountB) = _calculateLiquidityAmounts(
            pair,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );


        liquidityMinted = _calculateLiquidityMinted(pair, amountA, amountB);


        IERC20(pair.tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(pair.tokenB).safeTransferFrom(msg.sender, address(this), amountB);


        pair.reserveA += amountA;
        pair.reserveB += amountB;
        pair.totalLiquidity += liquidityMinted;


        liquidityProviders[pairId][msg.sender].liquidityTokens += liquidityMinted;
        liquidityProviders[pairId][msg.sender].lastUpdateTime = block.timestamp;


        pair.kLast = pair.reserveA * pair.reserveB;

        emit LiquidityAdded(pairId, msg.sender, amountA, amountB, liquidityMinted);
    }


    function removeLiquidity(
        uint256 pairId,
        uint256 liquidityAmount,
        uint256 amountAMin,
        uint256 amountBMin
    )
        external
        validPair(pairId)
        nonReentrant
        whenNotPaused
        returns (uint256 amountA, uint256 amountB)
    {
        TradingPair storage pair = tradingPairs[pairId];
        LiquidityProvider storage provider = liquidityProviders[pairId][msg.sender];

        require(provider.liquidityTokens >= liquidityAmount, "DEX: Insufficient liquidity");
        require(liquidityAmount > 0, "DEX: Invalid liquidity amount");


        amountA = (liquidityAmount * pair.reserveA) / pair.totalLiquidity;
        amountB = (liquidityAmount * pair.reserveB) / pair.totalLiquidity;

        require(amountA >= amountAMin, "DEX: Insufficient token A amount");
        require(amountB >= amountBMin, "DEX: Insufficient token B amount");


        provider.liquidityTokens -= liquidityAmount;
        provider.lastUpdateTime = block.timestamp;
        pair.totalLiquidity -= liquidityAmount;
        pair.reserveA -= amountA;
        pair.reserveB -= amountB;


        IERC20(pair.tokenA).safeTransfer(msg.sender, amountA);
        IERC20(pair.tokenB).safeTransfer(msg.sender, amountB);


        pair.kLast = pair.reserveA * pair.reserveB;

        emit LiquidityRemoved(pairId, msg.sender, amountA, amountB, liquidityAmount);
    }


    function swapTokens(
        uint256 pairId,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOutMin
    )
        external
        validPair(pairId)
        validAddress(tokenIn)
        nonReentrant
        whenNotPaused
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "DEX: Invalid input amount");

        TradingPair storage pair = tradingPairs[pairId];
        address tokenOut;
        uint256 reserveIn;
        uint256 reserveOut;


        if (tokenIn == pair.tokenA) {
            tokenOut = pair.tokenB;
            reserveIn = pair.reserveA;
            reserveOut = pair.reserveB;
        } else if (tokenIn == pair.tokenB) {
            tokenOut = pair.tokenA;
            reserveIn = pair.reserveA;
            reserveOut = pair.reserveB;
        } else {
            revert("DEX: Invalid token");
        }


        amountOut = _getAmountOut(amountIn, reserveIn, reserveOut);
        require(amountOut >= amountOutMin, "DEX: Insufficient output amount");


        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);


        uint256 protocolFee = (amountIn * protocolFeeRate) / 10000;
        protocolFees[tokenIn] += protocolFee;


        if (tokenIn == pair.tokenA) {
            pair.reserveA += amountIn;
            pair.reserveB -= amountOut;
        } else {
            pair.reserveB += amountIn;
            pair.reserveA -= amountOut;
        }


        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);


        pair.kLast = pair.reserveA * pair.reserveB;

        emit TokenSwapped(pairId, msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }


    function getTradingPair(uint256 pairId) external view returns (TradingPair memory pair) {
        require(pairId > 0 && pairId <= tradingPairCount, "DEX: Invalid pair ID");
        return tradingPairs[pairId];
    }


    function getLiquidityProvider(
        uint256 pairId,
        address user
    ) external view returns (LiquidityProvider memory provider) {
        return liquidityProviders[pairId][user];
    }


    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external view returns (uint256 amountOut) {
        return _getAmountOut(amountIn, reserveIn, reserveOut);
    }




    function setTradingFeeRate(uint256 newFeeRate) external onlyOwner {
        require(newFeeRate <= 1000, "DEX: Fee rate too high");
        tradingFeeRate = newFeeRate;
    }


    function setProtocolFeeRate(uint256 newFeeRate) external onlyOwner {
        require(newFeeRate <= 100, "DEX: Protocol fee rate too high");
        protocolFeeRate = newFeeRate;
    }


    function withdrawProtocolFees(address token, uint256 amount) external onlyOwner {
        require(protocolFees[token] >= amount, "DEX: Insufficient protocol fees");
        protocolFees[token] -= amount;
        IERC20(token).safeTransfer(owner(), amount);
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
    }


    function deactivatePair(uint256 pairId) external onlyOwner {
        require(pairId > 0 && pairId <= tradingPairCount, "DEX: Invalid pair ID");
        tradingPairs[pairId].isActive = false;
    }




    function _calculateLiquidityAmounts(
        TradingPair storage pair,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal view returns (uint256 amountA, uint256 amountB) {
        if (pair.reserveA == 0 && pair.reserveB == 0) {

            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {

            uint256 amountBOptimal = (amountADesired * pair.reserveB) / pair.reserveA;
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "DEX: Insufficient token B amount");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = (amountBDesired * pair.reserveA) / pair.reserveB;
                require(amountAOptimal >= amountAMin, "DEX: Insufficient token A amount");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }


    function _calculateLiquidityMinted(
        TradingPair storage pair,
        uint256 amountA,
        uint256 amountB
    ) internal view returns (uint256 liquidityMinted) {
        if (pair.totalLiquidity == 0) {

            liquidityMinted = _sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
        } else {

            liquidityMinted = _min(
                (amountA * pair.totalLiquidity) / pair.reserveA,
                (amountB * pair.totalLiquidity) / pair.reserveB
            );
        }
        require(liquidityMinted > 0, "DEX: Insufficient liquidity minted");
    }


    function _getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal view returns (uint256 amountOut) {
        require(amountIn > 0, "DEX: Insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "DEX: Insufficient liquidity");


        uint256 amountInWithFee = amountIn * (10000 - tradingFeeRate);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10000) + amountInWithFee;
        amountOut = numerator / denominator;
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


    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
