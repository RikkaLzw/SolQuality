
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract DecentralizedExchange is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;


    struct TradingPair {
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalLiquidity;
        bool isActive;
    }


    struct LiquidityProvider {
        uint256 liquidityTokens;
        uint256 lastDepositTime;
    }


    struct Order {
        address trader;
        address tokenSell;
        address tokenBuy;
        uint256 amountSell;
        uint256 amountBuy;
        uint256 timestamp;
        bool isActive;
    }


    mapping(bytes32 => TradingPair) public tradingPairs;
    mapping(address => mapping(bytes32 => LiquidityProvider)) public liquidityProviders;
    mapping(uint256 => Order) public orders;

    bytes32[] public activePairs;
    uint256 public nextOrderId;
    uint256 public tradingFeeRate;
    uint256 public constant MAX_FEE_RATE = 1000;
    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    address public feeRecipient;


    event TradingPairCreated(
        bytes32 indexed pairId,
        address indexed tokenA,
        address indexed tokenB
    );

    event LiquidityAdded(
        bytes32 indexed pairId,
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidityTokens
    );

    event LiquidityRemoved(
        bytes32 indexed pairId,
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidityTokens
    );

    event TokensSwapped(
        bytes32 indexed pairId,
        address indexed trader,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    event OrderCreated(
        uint256 indexed orderId,
        address indexed trader,
        address tokenSell,
        address tokenBuy,
        uint256 amountSell,
        uint256 amountBuy
    );

    event OrderExecuted(
        uint256 indexed orderId,
        address indexed executor
    );

    event OrderCancelled(
        uint256 indexed orderId,
        address indexed trader
    );


    modifier validAddress(address _address) {
        require(_address != address(0), "DEX: Invalid address");
        _;
    }

    modifier pairExists(bytes32 _pairId) {
        require(tradingPairs[_pairId].isActive, "DEX: Trading pair does not exist");
        _;
    }

    modifier orderExists(uint256 _orderId) {
        require(orders[_orderId].isActive, "DEX: Order does not exist");
        _;
    }


    constructor(
        address _feeRecipient,
        uint256 _tradingFeeRate
    ) validAddress(_feeRecipient) {
        require(_tradingFeeRate <= MAX_FEE_RATE, "DEX: Fee rate too high");

        feeRecipient = _feeRecipient;
        tradingFeeRate = _tradingFeeRate;
        nextOrderId = 1;
    }


    function createTradingPair(
        address _tokenA,
        address _tokenB
    )
        external
        onlyOwner
        validAddress(_tokenA)
        validAddress(_tokenB)
        whenNotPaused
    {
        require(_tokenA != _tokenB, "DEX: Identical tokens");

        bytes32 pairId = getPairId(_tokenA, _tokenB);
        require(!tradingPairs[pairId].isActive, "DEX: Pair already exists");


        if (_tokenA > _tokenB) {
            (_tokenA, _tokenB) = (_tokenB, _tokenA);
        }

        tradingPairs[pairId] = TradingPair({
            tokenA: _tokenA,
            tokenB: _tokenB,
            reserveA: 0,
            reserveB: 0,
            totalLiquidity: 0,
            isActive: true
        });

        activePairs.push(pairId);

        emit TradingPairCreated(pairId, _tokenA, _tokenB);
    }


    function addLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 _amountA,
        uint256 _amountB,
        uint256 _minAmountA,
        uint256 _minAmountB
    )
        external
        nonReentrant
        whenNotPaused
    {
        bytes32 pairId = getPairId(_tokenA, _tokenB);
        require(tradingPairs[pairId].isActive, "DEX: Pair does not exist");

        TradingPair storage pair = tradingPairs[pairId];

        uint256 actualAmountA = _amountA;
        uint256 actualAmountB = _amountB;
        uint256 liquidityTokens;

        if (pair.totalLiquidity == 0) {

            liquidityTokens = sqrt(actualAmountA * actualAmountB);
            require(liquidityTokens > MINIMUM_LIQUIDITY, "DEX: Insufficient liquidity");
        } else {

            uint256 ratioA = (actualAmountA * pair.reserveB) / pair.reserveA;
            uint256 ratioB = (actualAmountB * pair.reserveA) / pair.reserveB;

            if (ratioA < actualAmountB) {
                actualAmountB = ratioA;
            } else {
                actualAmountA = ratioB;
            }

            require(actualAmountA >= _minAmountA, "DEX: Insufficient amount A");
            require(actualAmountB >= _minAmountB, "DEX: Insufficient amount B");

            liquidityTokens = (actualAmountA * pair.totalLiquidity) / pair.reserveA;
        }


        IERC20(pair.tokenA).safeTransferFrom(msg.sender, address(this), actualAmountA);
        IERC20(pair.tokenB).safeTransferFrom(msg.sender, address(this), actualAmountB);


        pair.reserveA += actualAmountA;
        pair.reserveB += actualAmountB;
        pair.totalLiquidity += liquidityTokens;


        liquidityProviders[msg.sender][pairId].liquidityTokens += liquidityTokens;
        liquidityProviders[msg.sender][pairId].lastDepositTime = block.timestamp;

        emit LiquidityAdded(pairId, msg.sender, actualAmountA, actualAmountB, liquidityTokens);
    }


    function removeLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 _liquidityTokens,
        uint256 _minAmountA,
        uint256 _minAmountB
    )
        external
        nonReentrant
        whenNotPaused
    {
        bytes32 pairId = getPairId(_tokenA, _tokenB);
        require(tradingPairs[pairId].isActive, "DEX: Pair does not exist");

        TradingPair storage pair = tradingPairs[pairId];
        LiquidityProvider storage provider = liquidityProviders[msg.sender][pairId];

        require(provider.liquidityTokens >= _liquidityTokens, "DEX: Insufficient liquidity tokens");
        require(pair.totalLiquidity > 0, "DEX: No liquidity");


        uint256 amountA = (_liquidityTokens * pair.reserveA) / pair.totalLiquidity;
        uint256 amountB = (_liquidityTokens * pair.reserveB) / pair.totalLiquidity;

        require(amountA >= _minAmountA, "DEX: Insufficient amount A");
        require(amountB >= _minAmountB, "DEX: Insufficient amount B");


        provider.liquidityTokens -= _liquidityTokens;
        pair.totalLiquidity -= _liquidityTokens;
        pair.reserveA -= amountA;
        pair.reserveB -= amountB;


        IERC20(pair.tokenA).safeTransfer(msg.sender, amountA);
        IERC20(pair.tokenB).safeTransfer(msg.sender, amountB);

        emit LiquidityRemoved(pairId, msg.sender, amountA, amountB, _liquidityTokens);
    }


    function swapTokens(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _minAmountOut
    )
        external
        nonReentrant
        whenNotPaused
    {
        require(_tokenIn != _tokenOut, "DEX: Identical tokens");
        require(_amountIn > 0, "DEX: Invalid amount");

        bytes32 pairId = getPairId(_tokenIn, _tokenOut);
        require(tradingPairs[pairId].isActive, "DEX: Pair does not exist");

        TradingPair storage pair = tradingPairs[pairId];


        uint256 reserveIn;
        uint256 reserveOut;

        if (_tokenIn == pair.tokenA) {
            reserveIn = pair.reserveA;
            reserveOut = pair.reserveB;
        } else {
            reserveIn = pair.reserveB;
            reserveOut = pair.reserveA;
        }

        require(reserveIn > 0 && reserveOut > 0, "DEX: Insufficient liquidity");


        uint256 amountInWithFee = _amountIn * (10000 - tradingFeeRate);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10000) + amountInWithFee;
        uint256 amountOut = numerator / denominator;

        require(amountOut >= _minAmountOut, "DEX: Insufficient output amount");
        require(amountOut < reserveOut, "DEX: Insufficient liquidity");


        IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), _amountIn);
        IERC20(_tokenOut).safeTransfer(msg.sender, amountOut);


        uint256 feeAmount = (_amountIn * tradingFeeRate) / 10000;
        if (feeAmount > 0) {
            IERC20(_tokenIn).safeTransfer(feeRecipient, feeAmount);
        }


        if (_tokenIn == pair.tokenA) {
            pair.reserveA += (_amountIn - feeAmount);
            pair.reserveB -= amountOut;
        } else {
            pair.reserveB += (_amountIn - feeAmount);
            pair.reserveA -= amountOut;
        }

        emit TokensSwapped(pairId, msg.sender, _tokenIn, _tokenOut, _amountIn, amountOut);
    }


    function createOrder(
        address _tokenSell,
        address _tokenBuy,
        uint256 _amountSell,
        uint256 _amountBuy
    )
        external
        nonReentrant
        whenNotPaused
        returns (uint256 orderId)
    {
        require(_tokenSell != _tokenBuy, "DEX: Identical tokens");
        require(_amountSell > 0 && _amountBuy > 0, "DEX: Invalid amounts");

        bytes32 pairId = getPairId(_tokenSell, _tokenBuy);
        require(tradingPairs[pairId].isActive, "DEX: Pair does not exist");


        IERC20(_tokenSell).safeTransferFrom(msg.sender, address(this), _amountSell);

        orderId = nextOrderId++;
        orders[orderId] = Order({
            trader: msg.sender,
            tokenSell: _tokenSell,
            tokenBuy: _tokenBuy,
            amountSell: _amountSell,
            amountBuy: _amountBuy,
            timestamp: block.timestamp,
            isActive: true
        });

        emit OrderCreated(orderId, msg.sender, _tokenSell, _tokenBuy, _amountSell, _amountBuy);
    }


    function executeOrder(uint256 _orderId)
        external
        nonReentrant
        whenNotPaused
        orderExists(_orderId)
    {
        Order storage order = orders[_orderId];


        require(
            IERC20(order.tokenBuy).balanceOf(msg.sender) >= order.amountBuy,
            "DEX: Insufficient balance"
        );


        IERC20(order.tokenBuy).safeTransferFrom(msg.sender, order.trader, order.amountBuy);
        IERC20(order.tokenSell).safeTransfer(msg.sender, order.amountSell);


        order.isActive = false;

        emit OrderExecuted(_orderId, msg.sender);
    }


    function cancelOrder(uint256 _orderId)
        external
        nonReentrant
        orderExists(_orderId)
    {
        Order storage order = orders[_orderId];
        require(order.trader == msg.sender, "DEX: Not order owner");


        IERC20(order.tokenSell).safeTransfer(msg.sender, order.amountSell);


        order.isActive = false;

        emit OrderCancelled(_orderId, msg.sender);
    }


    function getPairId(address _tokenA, address _tokenB)
        public
        pure
        returns (bytes32)
    {
        return _tokenA < _tokenB
            ? keccak256(abi.encodePacked(_tokenA, _tokenB))
            : keccak256(abi.encodePacked(_tokenB, _tokenA));
    }


    function getAmountOut(
        uint256 _amountIn,
        uint256 _reserveIn,
        uint256 _reserveOut
    )
        public
        view
        returns (uint256)
    {
        require(_amountIn > 0, "DEX: Invalid input amount");
        require(_reserveIn > 0 && _reserveOut > 0, "DEX: Insufficient liquidity");

        uint256 amountInWithFee = _amountIn * (10000 - tradingFeeRate);
        uint256 numerator = amountInWithFee * _reserveOut;
        uint256 denominator = (_reserveIn * 10000) + amountInWithFee;

        return numerator / denominator;
    }


    function getLiquidityProviderInfo(
        address _provider,
        address _tokenA,
        address _tokenB
    )
        external
        view
        returns (uint256 liquidityTokens, uint256 lastDepositTime)
    {
        bytes32 pairId = getPairId(_tokenA, _tokenB);
        LiquidityProvider memory provider = liquidityProviders[_provider][pairId];

        return (provider.liquidityTokens, provider.lastDepositTime);
    }


    function getActivePairsCount() external view returns (uint256) {
        return activePairs.length;
    }


    function setTradingFeeRate(uint256 _newFeeRate) external onlyOwner {
        require(_newFeeRate <= MAX_FEE_RATE, "DEX: Fee rate too high");
        tradingFeeRate = _newFeeRate;
    }


    function setFeeRecipient(address _newFeeRecipient)
        external
        onlyOwner
        validAddress(_newFeeRecipient)
    {
        feeRecipient = _newFeeRecipient;
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
    }


    function emergencyWithdraw(address _token, uint256 _amount)
        external
        onlyOwner
        validAddress(_token)
    {
        IERC20(_token).safeTransfer(owner(), _amount);
    }


    function sqrt(uint256 _x) internal pure returns (uint256) {
        if (_x == 0) return 0;

        uint256 z = (_x + 1) / 2;
        uint256 y = _x;

        while (z < y) {
            y = z;
            z = (_x / z + z) / 2;
        }

        return y;
    }
}
