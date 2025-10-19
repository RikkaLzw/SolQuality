
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
    mapping(address => uint256[]) public userOrders;

    bytes32[] public activePairs;
    uint256 public nextOrderId;
    uint256 public tradingFeeRate;
    uint256 public constant MAX_FEE_RATE = 1000;
    uint256 public constant MINIMUM_LIQUIDITY = 1000;


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
        address indexed trader,
        uint256 amountExecuted
    );

    event OrderCancelled(
        uint256 indexed orderId,
        address indexed trader
    );

    event TradingFeeUpdated(
        uint256 oldFeeRate,
        uint256 newFeeRate
    );


    constructor(uint256 _tradingFeeRate) {
        require(_tradingFeeRate <= MAX_FEE_RATE, "Fee rate too high");
        tradingFeeRate = _tradingFeeRate;
        nextOrderId = 1;
    }


    function createTradingPair(
        address tokenA,
        address tokenB
    ) external onlyOwner {
        require(tokenA != address(0) && tokenB != address(0), "Invalid token address");
        require(tokenA != tokenB, "Identical tokens");

        bytes32 pairId = _getPairId(tokenA, tokenB);
        require(!tradingPairs[pairId].isActive, "Trading pair already exists");


        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }

        tradingPairs[pairId] = TradingPair({
            tokenA: tokenA,
            tokenB: tokenB,
            reserveA: 0,
            reserveB: 0,
            totalLiquidity: 0,
            isActive: true
        });

        activePairs.push(pairId);

        emit TradingPairCreated(pairId, tokenA, tokenB);
    }


    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 minAmountA,
        uint256 minAmountB
    ) external nonReentrant whenNotPaused {
        bytes32 pairId = _getPairId(tokenA, tokenB);
        TradingPair storage pair = tradingPairs[pairId];
        require(pair.isActive, "Trading pair not active");


        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
            (amountA, amountB) = (amountB, amountA);
            (minAmountA, minAmountB) = (minAmountB, minAmountA);
        }

        uint256 liquidityTokens;

        if (pair.totalLiquidity == 0) {

            liquidityTokens = _sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
            require(liquidityTokens > 0, "Insufficient liquidity");
        } else {

            uint256 amountBOptimal = (amountA * pair.reserveB) / pair.reserveA;
            if (amountBOptimal <= amountB) {
                require(amountBOptimal >= minAmountB, "Insufficient B amount");
                amountB = amountBOptimal;
            } else {
                uint256 amountAOptimal = (amountB * pair.reserveA) / pair.reserveB;
                require(amountAOptimal <= amountA && amountAOptimal >= minAmountA, "Insufficient A amount");
                amountA = amountAOptimal;
            }

            liquidityTokens = _min(
                (amountA * pair.totalLiquidity) / pair.reserveA,
                (amountB * pair.totalLiquidity) / pair.reserveB
            );
        }

        require(liquidityTokens > 0, "Insufficient liquidity minted");


        IERC20(tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountB);


        pair.reserveA += amountA;
        pair.reserveB += amountB;
        pair.totalLiquidity += liquidityTokens;


        liquidityProviders[msg.sender][pairId].liquidityTokens += liquidityTokens;
        liquidityProviders[msg.sender][pairId].lastDepositTime = block.timestamp;

        emit LiquidityAdded(pairId, msg.sender, amountA, amountB, liquidityTokens);
    }


    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidityTokens,
        uint256 minAmountA,
        uint256 minAmountB
    ) external nonReentrant whenNotPaused {
        bytes32 pairId = _getPairId(tokenA, tokenB);
        TradingPair storage pair = tradingPairs[pairId];
        require(pair.isActive, "Trading pair not active");

        LiquidityProvider storage provider = liquidityProviders[msg.sender][pairId];
        require(provider.liquidityTokens >= liquidityTokens, "Insufficient liquidity tokens");


        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
            (minAmountA, minAmountB) = (minAmountB, minAmountA);
        }


        uint256 amountA = (liquidityTokens * pair.reserveA) / pair.totalLiquidity;
        uint256 amountB = (liquidityTokens * pair.reserveB) / pair.totalLiquidity;

        require(amountA >= minAmountA && amountB >= minAmountB, "Insufficient output amount");


        provider.liquidityTokens -= liquidityTokens;
        pair.reserveA -= amountA;
        pair.reserveB -= amountB;
        pair.totalLiquidity -= liquidityTokens;


        IERC20(tokenA).safeTransfer(msg.sender, amountA);
        IERC20(tokenB).safeTransfer(msg.sender, amountB);

        emit LiquidityRemoved(pairId, msg.sender, amountA, amountB, liquidityTokens);
    }


    function swapTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external nonReentrant whenNotPaused {
        require(tokenIn != tokenOut, "Identical tokens");
        require(amountIn > 0, "Invalid input amount");

        bytes32 pairId = _getPairId(tokenIn, tokenOut);
        TradingPair storage pair = tradingPairs[pairId];
        require(pair.isActive, "Trading pair not active");


        uint256 amountOut = _getAmountOut(amountIn, tokenIn, tokenOut, pairId);
        require(amountOut >= minAmountOut, "Insufficient output amount");


        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);


        if (tokenIn == pair.tokenA) {
            pair.reserveA += amountIn;
            pair.reserveB -= amountOut;
        } else {
            pair.reserveB += amountIn;
            pair.reserveA -= amountOut;
        }


        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);

        emit TokensSwapped(pairId, msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }


    function createOrder(
        address tokenSell,
        address tokenBuy,
        uint256 amountSell,
        uint256 amountBuy
    ) external nonReentrant whenNotPaused {
        require(tokenSell != tokenBuy, "Identical tokens");
        require(amountSell > 0 && amountBuy > 0, "Invalid amounts");

        bytes32 pairId = _getPairId(tokenSell, tokenBuy);
        require(tradingPairs[pairId].isActive, "Trading pair not active");


        IERC20(tokenSell).safeTransferFrom(msg.sender, address(this), amountSell);


        orders[nextOrderId] = Order({
            trader: msg.sender,
            tokenSell: tokenSell,
            tokenBuy: tokenBuy,
            amountSell: amountSell,
            amountBuy: amountBuy,
            timestamp: block.timestamp,
            isActive: true
        });

        userOrders[msg.sender].push(nextOrderId);

        emit OrderCreated(nextOrderId, msg.sender, tokenSell, tokenBuy, amountSell, amountBuy);

        nextOrderId++;
    }


    function cancelOrder(uint256 orderId) external nonReentrant {
        Order storage order = orders[orderId];
        require(order.trader == msg.sender, "Not order owner");
        require(order.isActive, "Order not active");

        order.isActive = false;


        IERC20(order.tokenSell).safeTransfer(msg.sender, order.amountSell);

        emit OrderCancelled(orderId, msg.sender);
    }


    function executeOrder(
        uint256 orderId,
        uint256 amountToFill
    ) external nonReentrant whenNotPaused {
        Order storage order = orders[orderId];
        require(order.isActive, "Order not active");
        require(amountToFill > 0 && amountToFill <= order.amountSell, "Invalid fill amount");

        uint256 buyAmount = (amountToFill * order.amountBuy) / order.amountSell;


        IERC20(order.tokenBuy).safeTransferFrom(msg.sender, address(this), buyAmount);


        IERC20(order.tokenSell).safeTransfer(msg.sender, amountToFill);


        IERC20(order.tokenBuy).safeTransfer(order.trader, buyAmount);


        order.amountSell -= amountToFill;
        order.amountBuy -= buyAmount;

        if (order.amountSell == 0) {
            order.isActive = false;
        }

        emit OrderExecuted(orderId, order.trader, amountToFill);
    }


    function setTradingFeeRate(uint256 newFeeRate) external onlyOwner {
        require(newFeeRate <= MAX_FEE_RATE, "Fee rate too high");
        uint256 oldFeeRate = tradingFeeRate;
        tradingFeeRate = newFeeRate;
        emit TradingFeeUpdated(oldFeeRate, newFeeRate);
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
    }


    function _getPairId(address tokenA, address tokenB) internal pure returns (bytes32) {
        return tokenA < tokenB ?
            keccak256(abi.encodePacked(tokenA, tokenB)) :
            keccak256(abi.encodePacked(tokenB, tokenA));
    }


    function _getAmountOut(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        bytes32 pairId
    ) internal view returns (uint256) {
        TradingPair storage pair = tradingPairs[pairId];

        uint256 reserveIn;
        uint256 reserveOut;

        if (tokenIn == pair.tokenA) {
            reserveIn = pair.reserveA;
            reserveOut = pair.reserveB;
        } else {
            reserveIn = pair.reserveB;
            reserveOut = pair.reserveA;
        }

        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");


        uint256 amountInWithFee = amountIn * (10000 - tradingFeeRate);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 10000) + amountInWithFee;

        return numerator / denominator;
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


    function getTradingPair(
        address tokenA,
        address tokenB
    ) external view returns (TradingPair memory) {
        bytes32 pairId = _getPairId(tokenA, tokenB);
        return tradingPairs[pairId];
    }


    function getUserLiquidity(
        address user,
        address tokenA,
        address tokenB
    ) external view returns (LiquidityProvider memory) {
        bytes32 pairId = _getPairId(tokenA, tokenB);
        return liquidityProviders[user][pairId];
    }


    function getUserOrders(address user) external view returns (uint256[] memory) {
        return userOrders[user];
    }


    function getActivePairsCount() external view returns (uint256) {
        return activePairs.length;
    }


    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256) {
        bytes32 pairId = _getPairId(tokenIn, tokenOut);
        return _getAmountOut(amountIn, tokenIn, tokenOut, pairId);
    }
}
