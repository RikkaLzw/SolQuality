
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
        uint256 lastDepositTime;
    }




    mapping(uint256 => TradingPair) public tradingPairs;


    mapping(address => mapping(address => uint256)) public getPairId;


    mapping(uint256 => mapping(address => LiquidityProvider)) public liquidityProviders;


    mapping(address => uint256) public protocolFees;




    event PairCreated(
        uint256 indexed pairId,
        address indexed tokenA,
        address indexed tokenB,
        uint256 timestamp
    );


    event LiquidityAdded(
        uint256 indexed pairId,
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidityTokens,
        uint256 timestamp
    );


    event LiquidityRemoved(
        uint256 indexed pairId,
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidityTokens,
        uint256 timestamp
    );


    event TokenSwapped(
        uint256 indexed pairId,
        address indexed trader,
        address indexed tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee,
        uint256 timestamp
    );


    event FeeRateUpdated(
        uint256 tradingFeeRate,
        uint256 liquidityProviderFeeRate,
        uint256 protocolFeeRate,
        uint256 timestamp
    );




    modifier validPair(uint256 _pairId) {
        require(_pairId > 0 && _pairId <= tradingPairCount, "DEX: Invalid pair ID");
        require(tradingPairs[_pairId].isActive, "DEX: Pair not active");
        _;
    }


    modifier validToken(address _token) {
        require(_token != address(0), "DEX: Invalid token address");
        require(_token != address(this), "DEX: Cannot use DEX contract as token");
        _;
    }




    constructor() {

        tradingPairCount = 0;
    }




    function createTradingPair(
        address _tokenA,
        address _tokenB
    ) external validToken(_tokenA) validToken(_tokenB) returns (uint256 pairId) {
        require(_tokenA != _tokenB, "DEX: Identical tokens");


        (address token0, address token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);

        require(getPairId[token0][token1] == 0, "DEX: Pair already exists");


        tradingPairCount++;
        pairId = tradingPairCount;

        tradingPairs[pairId] = TradingPair({
            tokenA: token0,
            tokenB: token1,
            reserveA: 0,
            reserveB: 0,
            totalLiquidity: 0,
            kLast: 0,
            isActive: true
        });


        getPairId[token0][token1] = pairId;
        getPairId[token1][token0] = pairId;

        emit PairCreated(pairId, token0, token1, block.timestamp);
    }


    function addLiquidity(
        uint256 _pairId,
        uint256 _amountADesired,
        uint256 _amountBDesired,
        uint256 _amountAMin,
        uint256 _amountBMin
    ) external nonReentrant whenNotPaused validPair(_pairId)
      returns (uint256 amountA, uint256 amountB, uint256 liquidityTokens) {

        TradingPair storage pair = tradingPairs[_pairId];


        (amountA, amountB) = _calculateLiquidityAmounts(
            pair,
            _amountADesired,
            _amountBDesired,
            _amountAMin,
            _amountBMin
        );


        if (pair.totalLiquidity == 0) {

            liquidityTokens = _sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
            pair.totalLiquidity = liquidityTokens + MINIMUM_LIQUIDITY;
        } else {

            liquidityTokens = _min(
                (amountA * pair.totalLiquidity) / pair.reserveA,
                (amountB * pair.totalLiquidity) / pair.reserveB
            );
            pair.totalLiquidity += liquidityTokens;
        }

        require(liquidityTokens > 0, "DEX: Insufficient liquidity minted");


        IERC20(pair.tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(pair.tokenB).safeTransferFrom(msg.sender, address(this), amountB);


        pair.reserveA += amountA;
        pair.reserveB += amountB;


        liquidityProviders[_pairId][msg.sender].liquidityTokens += liquidityTokens;
        liquidityProviders[_pairId][msg.sender].lastDepositTime = block.timestamp;


        pair.kLast = pair.reserveA * pair.reserveB;

        emit LiquidityAdded(_pairId, msg.sender, amountA, amountB, liquidityTokens, block.timestamp);
    }


    function removeLiquidity(
        uint256 _pairId,
        uint256 _liquidityTokens,
        uint256 _amountAMin,
        uint256 _amountBMin
    ) external nonReentrant whenNotPaused validPair(_pairId)
      returns (uint256 amountA, uint256 amountB) {

        TradingPair storage pair = tradingPairs[_pairId];
        LiquidityProvider storage provider = liquidityProviders[_pairId][msg.sender];

        require(_liquidityTokens > 0, "DEX: Invalid liquidity amount");
        require(provider.liquidityTokens >= _liquidityTokens, "DEX: Insufficient liquidity balance");


        amountA = (_liquidityTokens * pair.reserveA) / pair.totalLiquidity;
        amountB = (_liquidityTokens * pair.reserveB) / pair.totalLiquidity;

        require(amountA >= _amountAMin, "DEX: Insufficient token A amount");
        require(amountB >= _amountBMin, "DEX: Insufficient token B amount");


        provider.liquidityTokens -= _liquidityTokens;
        pair.totalLiquidity -= _liquidityTokens;
        pair.reserveA -= amountA;
        pair.reserveB -= amountB;


        IERC20(pair.tokenA).safeTransfer(msg.sender, amountA);
        IERC20(pair.tokenB).safeTransfer(msg.sender, amountB);


        pair.kLast = pair.reserveA * pair.reserveB;

        emit LiquidityRemoved(_pairId, msg.sender, amountA, amountB, _liquidityTokens, block.timestamp);
    }


    function swapTokens(
        uint256 _pairId,
        address _tokenIn,
        uint256 _amountIn,
        uint256 _amountOutMin
    ) external nonReentrant whenNotPaused validPair(_pairId) returns (uint256 amountOut) {

        require(_amountIn > 0, "DEX: Invalid input amount");

        TradingPair storage pair = tradingPairs[_pairId];


        bool isTokenA = _tokenIn == pair.tokenA;
        require(isTokenA || _tokenIn == pair.tokenB, "DEX: Invalid input token");

        address tokenOut = isTokenA ? pair.tokenB : pair.tokenA;
        uint256 reserveIn = isTokenA ? pair.reserveA : pair.reserveB;
        uint256 reserveOut = isTokenA ? pair.reserveB : pair.reserveA;


        amountOut = _getAmountOut(_amountIn, reserveIn, reserveOut);
        require(amountOut >= _amountOutMin, "DEX: Insufficient output amount");


        IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), _amountIn);


        uint256 totalFee = (_amountIn * tradingFeeRate) / 10000;
        uint256 protocolFee = (_amountIn * protocolFeeRate) / 10000;


        protocolFees[_tokenIn] += protocolFee;


        if (isTokenA) {
            pair.reserveA += _amountIn;
            pair.reserveB -= amountOut;
        } else {
            pair.reserveB += _amountIn;
            pair.reserveA -= amountOut;
        }


        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);


        pair.kLast = pair.reserveA * pair.reserveB;

        emit TokenSwapped(_pairId, msg.sender, _tokenIn, tokenOut, _amountIn, amountOut, totalFee, block.timestamp);
    }


    function getAmountOut(
        uint256 _pairId,
        address _tokenIn,
        uint256 _amountIn
    ) external view validPair(_pairId) returns (uint256 amountOut) {

        TradingPair storage pair = tradingPairs[_pairId];

        bool isTokenA = _tokenIn == pair.tokenA;
        require(isTokenA || _tokenIn == pair.tokenB, "DEX: Invalid input token");

        uint256 reserveIn = isTokenA ? pair.reserveA : pair.reserveB;
        uint256 reserveOut = isTokenA ? pair.reserveB : pair.reserveA;

        amountOut = _getAmountOut(_amountIn, reserveIn, reserveOut);
    }




    function updateFeeRates(
        uint256 _tradingFeeRate,
        uint256 _liquidityProviderFeeRate,
        uint256 _protocolFeeRate
    ) external onlyOwner {
        require(_tradingFeeRate <= 1000, "DEX: Trading fee too high");
        require(_liquidityProviderFeeRate <= 1000, "DEX: LP fee too high");
        require(_protocolFeeRate <= 100, "DEX: Protocol fee too high");
        require(_tradingFeeRate >= _liquidityProviderFeeRate + _protocolFeeRate, "DEX: Invalid fee structure");

        tradingFeeRate = _tradingFeeRate;
        liquidityProviderFeeRate = _liquidityProviderFeeRate;
        protocolFeeRate = _protocolFeeRate;

        emit FeeRateUpdated(_tradingFeeRate, _liquidityProviderFeeRate, _protocolFeeRate, block.timestamp);
    }


    function withdrawProtocolFees(address _token, uint256 _amount) external onlyOwner {
        require(protocolFees[_token] >= _amount, "DEX: Insufficient protocol fees");

        protocolFees[_token] -= _amount;
        IERC20(_token).safeTransfer(owner(), _amount);
    }


    function pauseContract() external onlyOwner {
        _pause();
    }


    function unpauseContract() external onlyOwner {
        _unpause();
    }


    function deactivatePair(uint256 _pairId) external onlyOwner validPair(_pairId) {
        tradingPairs[_pairId].isActive = false;
    }




    function _calculateLiquidityAmounts(
        TradingPair storage _pair,
        uint256 _amountADesired,
        uint256 _amountBDesired,
        uint256 _amountAMin,
        uint256 _amountBMin
    ) internal view returns (uint256 amountA, uint256 amountB) {

        if (_pair.reserveA == 0 && _pair.reserveB == 0) {

            (amountA, amountB) = (_amountADesired, _amountBDesired);
        } else {

            uint256 amountBOptimal = (_amountADesired * _pair.reserveB) / _pair.reserveA;

            if (amountBOptimal <= _amountBDesired) {
                require(amountBOptimal >= _amountBMin, "DEX: Insufficient token B amount");
                (amountA, amountB) = (_amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = (_amountBDesired * _pair.reserveA) / _pair.reserveB;
                require(amountAOptimal <= _amountADesired && amountAOptimal >= _amountAMin, "DEX: Insufficient token A amount");
                (amountA, amountB) = (amountAOptimal, _amountBDesired);
            }
        }
    }


    function _getAmountOut(
        uint256 _amountIn,
        uint256 _reserveIn,
        uint256 _reserveOut
    ) internal view returns (uint256 amountOut) {
        require(_amountIn > 0, "DEX: Insufficient input amount");
        require(_reserveIn > 0 && _reserveOut > 0, "DEX: Insufficient liquidity");


        uint256 amountInWithFee = _amountIn * (10000 - tradingFeeRate);
        uint256 numerator = amountInWithFee * _reserveOut;
        uint256 denominator = (_reserveIn * 10000) + amountInWithFee;

        amountOut = numerator / denominator;
    }


    function _sqrt(uint256 _y) internal pure returns (uint256 z) {
        if (_y > 3) {
            z = _y;
            uint256 x = _y / 2 + 1;
            while (x < z) {
                z = x;
                x = (_y / x + x) / 2;
            }
        } else if (_y != 0) {
            z = 1;
        }
    }


    function _min(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a < _b ? _a : _b;
    }




    function getTradingPairInfo(uint256 _pairId) external view returns (TradingPair memory) {
        return tradingPairs[_pairId];
    }


    function getLiquidityProviderInfo(
        uint256 _pairId,
        address _provider
    ) external view returns (LiquidityProvider memory) {
        return liquidityProviders[_pairId][_provider];
    }


    function getUserLiquidityBalance(uint256 _pairId, address _user) external view returns (uint256) {
        return liquidityProviders[_pairId][_user].liquidityTokens;
    }
}
