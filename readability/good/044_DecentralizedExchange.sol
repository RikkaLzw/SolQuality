
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
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        uint256 deadline;
        bool isExecuted;
    }


    mapping(bytes32 => TradingPair) public tradingPairs;
    mapping(address => mapping(bytes32 => LiquidityProvider)) public liquidityProviders;
    mapping(uint256 => Order) public orders;

    bytes32[] public activePairIds;
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
        uint256 amountOut,
        uint256 fee
    );

    event OrderCreated(
        uint256 indexed orderId,
        address indexed trader,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    );

    event OrderExecuted(
        uint256 indexed orderId,
        uint256 amountOut
    );

    event TradingFeeRateUpdated(uint256 newFeeRate);
    event FeeRecipientUpdated(address newFeeRecipient);


    modifier validAddress(address _address) {
        require(_address != address(0), "Invalid address");
        _;
    }

    modifier pairExists(bytes32 _pairId) {
        require(tradingPairs[_pairId].isActive, "Trading pair does not exist");
        _;
    }

    modifier orderExists(uint256 _orderId) {
        require(_orderId < nextOrderId, "Order does not exist");
        require(!orders[_orderId].isExecuted, "Order already executed");
        _;
    }


    constructor(
        uint256 _tradingFeeRate,
        address _feeRecipient
    ) validAddress(_feeRecipient) {
        require(_tradingFeeRate <= MAX_FEE_RATE, "Fee rate too high");

        tradingFeeRate = _tradingFeeRate;
        feeRecipient = _feeRecipient;
        nextOrderId = 0;
    }


    function createTradingPair(
        address _tokenA,
        address _tokenB
    )
        external
        onlyOwner
        validAddress(_tokenA)
        validAddress(_tokenB)
        returns (bytes32 pairId)
    {
        require(_tokenA != _tokenB, "Identical tokens");


        (address token0, address token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
        pairId = keccak256(abi.encodePacked(token0, token1));

        require(!tradingPairs[pairId].isActive, "Trading pair already exists");

        tradingPairs[pairId] = TradingPair({
            tokenA: token0,
            tokenB: token1,
            reserveA: 0,
            reserveB: 0,
            totalLiquidity: 0,
            isActive: true
        });

        activePairIds.push(pairId);

        emit TradingPairCreated(pairId, token0, token1);
    }


    function addLiquidity(
        bytes32 _pairId,
        uint256 _amountA,
        uint256 _amountB,
        uint256 _minLiquidityTokens
    )
        external
        nonReentrant
        whenNotPaused
        pairExists(_pairId)
    {
        require(_amountA > 0 && _amountB > 0, "Invalid amounts");

        TradingPair storage pair = tradingPairs[_pairId];
        uint256 liquidityTokens;

        if (pair.totalLiquidity == 0) {

            liquidityTokens = _sqrt(_amountA * _amountB) - MINIMUM_LIQUIDITY;
            require(liquidityTokens > 0, "Insufficient liquidity");
        } else {

            uint256 liquidityA = (_amountA * pair.totalLiquidity) / pair.reserveA;
            uint256 liquidityB = (_amountB * pair.totalLiquidity) / pair.reserveB;
            liquidityTokens = liquidityA < liquidityB ? liquidityA : liquidityB;
        }

        require(liquidityTokens >= _minLiquidityTokens, "Insufficient liquidity tokens");


        IERC20(pair.tokenA).safeTransferFrom(msg.sender, address(this), _amountA);
        IERC20(pair.tokenB).safeTransferFrom(msg.sender, address(this), _amountB);


        pair.reserveA += _amountA;
        pair.reserveB += _amountB;
        pair.totalLiquidity += liquidityTokens;


        liquidityProviders[msg.sender][_pairId].liquidityTokens += liquidityTokens;
        liquidityProviders[msg.sender][_pairId].lastDepositTime = block.timestamp;

        emit LiquidityAdded(_pairId, msg.sender, _amountA, _amountB, liquidityTokens);
    }


    function removeLiquidity(
        bytes32 _pairId,
        uint256 _liquidityTokens,
        uint256 _minAmountA,
        uint256 _minAmountB
    )
        external
        nonReentrant
        whenNotPaused
        pairExists(_pairId)
    {
        require(_liquidityTokens > 0, "Invalid liquidity amount");

        LiquidityProvider storage provider = liquidityProviders[msg.sender][_pairId];
        require(provider.liquidityTokens >= _liquidityTokens, "Insufficient liquidity tokens");

        TradingPair storage pair = tradingPairs[_pairId];


        uint256 amountA = (_liquidityTokens * pair.reserveA) / pair.totalLiquidity;
        uint256 amountB = (_liquidityTokens * pair.reserveB) / pair.totalLiquidity;

        require(amountA >= _minAmountA && amountB >= _minAmountB, "Insufficient output amounts");


        provider.liquidityTokens -= _liquidityTokens;
        pair.reserveA -= amountA;
        pair.reserveB -= amountB;
        pair.totalLiquidity -= _liquidityTokens;


        IERC20(pair.tokenA).safeTransfer(msg.sender, amountA);
        IERC20(pair.tokenB).safeTransfer(msg.sender, amountB);

        emit LiquidityRemoved(_pairId, msg.sender, amountA, amountB, _liquidityTokens);
    }


    function swapTokens(
        bytes32 _pairId,
        address _tokenIn,
        uint256 _amountIn,
        uint256 _minAmountOut
    )
        external
        nonReentrant
        whenNotPaused
        pairExists(_pairId)
        returns (uint256 amountOut)
    {
        require(_amountIn > 0, "Invalid input amount");

        TradingPair storage pair = tradingPairs[_pairId];
        require(_tokenIn == pair.tokenA || _tokenIn == pair.tokenB, "Invalid input token");

        bool isTokenA = _tokenIn == pair.tokenA;
        address tokenOut = isTokenA ? pair.tokenB : pair.tokenA;
        uint256 reserveIn = isTokenA ? pair.reserveA : pair.reserveB;
        uint256 reserveOut = isTokenA ? pair.reserveB : pair.reserveA;


        uint256 amountInWithFee = _amountIn * (10000 - tradingFeeRate);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10000) + amountInWithFee;
        amountOut = numerator / denominator;

        require(amountOut >= _minAmountOut, "Insufficient output amount");
        require(amountOut < reserveOut, "Insufficient liquidity");


        uint256 fee = (_amountIn * tradingFeeRate) / 10000;


        IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), _amountIn);


        if (fee > 0) {
            IERC20(_tokenIn).safeTransfer(feeRecipient, fee);
        }


        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);


        if (isTokenA) {
            pair.reserveA += (_amountIn - fee);
            pair.reserveB -= amountOut;
        } else {
            pair.reserveB += (_amountIn - fee);
            pair.reserveA -= amountOut;
        }

        emit TokensSwapped(_pairId, msg.sender, _tokenIn, tokenOut, _amountIn, amountOut, fee);
    }


    function createOrder(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _minAmountOut,
        uint256 _deadline
    )
        external
        nonReentrant
        whenNotPaused
        validAddress(_tokenIn)
        validAddress(_tokenOut)
        returns (uint256 orderId)
    {
        require(_tokenIn != _tokenOut, "Identical tokens");
        require(_amountIn > 0 && _minAmountOut > 0, "Invalid amounts");
        require(_deadline > block.timestamp, "Invalid deadline");


        (address token0, address token1) = _tokenIn < _tokenOut ? (_tokenIn, _tokenOut) : (_tokenOut, _tokenIn);
        bytes32 pairId = keccak256(abi.encodePacked(token0, token1));
        require(tradingPairs[pairId].isActive, "Trading pair does not exist");

        orderId = nextOrderId++;

        orders[orderId] = Order({
            trader: msg.sender,
            tokenIn: _tokenIn,
            tokenOut: _tokenOut,
            amountIn: _amountIn,
            minAmountOut: _minAmountOut,
            deadline: _deadline,
            isExecuted: false
        });


        IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), _amountIn);

        emit OrderCreated(orderId, msg.sender, _tokenIn, _tokenOut, _amountIn, _minAmountOut);
    }


    function executeOrder(uint256 _orderId)
        external
        nonReentrant
        whenNotPaused
        orderExists(_orderId)
    {
        Order storage order = orders[_orderId];
        require(block.timestamp <= order.deadline, "Order expired");


        (address token0, address token1) = order.tokenIn < order.tokenOut ?
            (order.tokenIn, order.tokenOut) : (order.tokenOut, order.tokenIn);
        bytes32 pairId = keccak256(abi.encodePacked(token0, token1));

        TradingPair storage pair = tradingPairs[pairId];

        bool isTokenA = order.tokenIn == pair.tokenA;
        uint256 reserveIn = isTokenA ? pair.reserveA : pair.reserveB;
        uint256 reserveOut = isTokenA ? pair.reserveB : pair.reserveA;


        uint256 amountInWithFee = order.amountIn * (10000 - tradingFeeRate);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10000) + amountInWithFee;
        uint256 amountOut = numerator / denominator;

        require(amountOut >= order.minAmountOut, "Price condition not met");
        require(amountOut < reserveOut, "Insufficient liquidity");


        order.isExecuted = true;


        uint256 fee = (order.amountIn * tradingFeeRate) / 10000;


        if (fee > 0) {
            IERC20(order.tokenIn).safeTransfer(feeRecipient, fee);
        }


        IERC20(order.tokenOut).safeTransfer(order.trader, amountOut);


        if (isTokenA) {
            pair.reserveA += (order.amountIn - fee);
            pair.reserveB -= amountOut;
        } else {
            pair.reserveB += (order.amountIn - fee);
            pair.reserveA -= amountOut;
        }

        emit OrderExecuted(_orderId, amountOut);
    }


    function cancelOrder(uint256 _orderId)
        external
        nonReentrant
        orderExists(_orderId)
    {
        Order storage order = orders[_orderId];
        require(order.trader == msg.sender, "Not order owner");

        order.isExecuted = true;


        IERC20(order.tokenIn).safeTransfer(msg.sender, order.amountIn);
    }


    function getAmountOut(
        bytes32 _pairId,
        address _tokenIn,
        uint256 _amountIn
    )
        external
        view
        pairExists(_pairId)
        returns (uint256 amountOut)
    {
        require(_amountIn > 0, "Invalid input amount");

        TradingPair storage pair = tradingPairs[_pairId];
        require(_tokenIn == pair.tokenA || _tokenIn == pair.tokenB, "Invalid input token");

        bool isTokenA = _tokenIn == pair.tokenA;
        uint256 reserveIn = isTokenA ? pair.reserveA : pair.reserveB;
        uint256 reserveOut = isTokenA ? pair.reserveB : pair.reserveA;

        uint256 amountInWithFee = _amountIn * (10000 - tradingFeeRate);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10000) + amountInWithFee;
        amountOut = numerator / denominator;
    }


    function getTradingPairInfo(bytes32 _pairId)
        external
        view
        returns (
            address tokenA,
            address tokenB,
            uint256 reserveA,
            uint256 reserveB,
            uint256 totalLiquidity
        )
    {
        TradingPair storage pair = tradingPairs[_pairId];
        return (
            pair.tokenA,
            pair.tokenB,
            pair.reserveA,
            pair.reserveB,
            pair.totalLiquidity
        );
    }


    function getUserLiquidity(
        address _user,
        bytes32 _pairId
    )
        external
        view
        returns (uint256 liquidityTokens, uint256 lastDepositTime)
    {
        LiquidityProvider storage provider = liquidityProviders[_user][_pairId];
        return (provider.liquidityTokens, provider.lastDepositTime);
    }


    function getActivePairCount() external view returns (uint256 count) {
        return activePairIds.length;
    }


    function updateTradingFeeRate(uint256 _newFeeRate) external onlyOwner {
        require(_newFeeRate <= MAX_FEE_RATE, "Fee rate too high");
        tradingFeeRate = _newFeeRate;
        emit TradingFeeRateUpdated(_newFeeRate);
    }


    function updateFeeRecipient(address _newFeeRecipient)
        external
        onlyOwner
        validAddress(_newFeeRecipient)
    {
        feeRecipient = _newFeeRecipient;
        emit FeeRecipientUpdated(_newFeeRecipient);
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
    }


    function emergencyWithdraw(
        address _token,
        uint256 _amount
    )
        external
        onlyOwner
        whenPaused
        validAddress(_token)
    {
        IERC20(_token).safeTransfer(owner(), _amount);
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
