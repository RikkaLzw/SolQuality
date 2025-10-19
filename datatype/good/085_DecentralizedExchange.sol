
pragma solidity ^0.8.19;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract DecentralizedExchange {

    address private owner;
    uint16 private constant FEE_RATE = 30;
    uint16 private constant FEE_DENOMINATOR = 10000;
    bool private locked;


    struct LiquidityPool {
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalLiquidity;
        bool exists;
    }


    struct Order {
        address trader;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        uint32 deadline;
        bool isActive;
    }


    mapping(bytes32 => LiquidityPool) public liquidityPools;
    mapping(bytes32 => mapping(address => uint256)) public liquidityShares;
    mapping(bytes32 => Order) public orders;
    mapping(address => uint256) public userOrderCount;
    mapping(address => uint256) public collectedFees;


    event PoolCreated(bytes32 indexed poolId, address indexed tokenA, address indexed tokenB);
    event LiquidityAdded(bytes32 indexed poolId, address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(bytes32 indexed poolId, address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event TokensSwapped(bytes32 indexed poolId, address indexed trader, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event OrderCreated(bytes32 indexed orderId, address indexed trader, address tokenIn, address tokenOut, uint256 amountIn);
    event OrderExecuted(bytes32 indexed orderId, address indexed trader, uint256 amountOut);
    event OrderCancelled(bytes32 indexed orderId, address indexed trader);


    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier nonReentrant() {
        require(!locked, "Reentrant call");
        locked = true;
        _;
        locked = false;
    }

    modifier validDeadline(uint32 deadline) {
        require(deadline >= block.timestamp, "Deadline expired");
        _;
    }

    constructor() {
        owner = msg.sender;
        locked = false;
    }


    function createPool(address tokenA, address tokenB) external returns (bytes32 poolId) {
        require(tokenA != address(0) && tokenB != address(0), "Invalid token address");
        require(tokenA != tokenB, "Identical tokens");


        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }

        poolId = keccak256(abi.encodePacked(tokenA, tokenB));
        require(!liquidityPools[poolId].exists, "Pool already exists");

        liquidityPools[poolId] = LiquidityPool({
            tokenA: tokenA,
            tokenB: tokenB,
            reserveA: 0,
            reserveB: 0,
            totalLiquidity: 0,
            exists: true
        });

        emit PoolCreated(poolId, tokenA, tokenB);
    }


    function addLiquidity(
        bytes32 poolId,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        uint32 deadline
    ) external validDeadline(deadline) nonReentrant returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        LiquidityPool storage pool = liquidityPools[poolId];
        require(pool.exists, "Pool does not exist");

        if (pool.reserveA == 0 && pool.reserveB == 0) {

            amountA = amountADesired;
            amountB = amountBDesired;
            liquidity = _sqrt(amountA * amountB);
        } else {

            uint256 amountBOptimal = (amountADesired * pool.reserveB) / pool.reserveA;
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "Insufficient B amount");
                amountA = amountADesired;
                amountB = amountBOptimal;
            } else {
                uint256 amountAOptimal = (amountBDesired * pool.reserveA) / pool.reserveB;
                require(amountAOptimal <= amountADesired && amountAOptimal >= amountAMin, "Insufficient A amount");
                amountA = amountAOptimal;
                amountB = amountBDesired;
            }

            liquidity = _min((amountA * pool.totalLiquidity) / pool.reserveA, (amountB * pool.totalLiquidity) / pool.reserveB);
        }

        require(liquidity > 0, "Insufficient liquidity minted");


        require(IERC20(pool.tokenA).transferFrom(msg.sender, address(this), amountA), "Transfer A failed");
        require(IERC20(pool.tokenB).transferFrom(msg.sender, address(this), amountB), "Transfer B failed");


        pool.reserveA += amountA;
        pool.reserveB += amountB;
        pool.totalLiquidity += liquidity;
        liquidityShares[poolId][msg.sender] += liquidity;

        emit LiquidityAdded(poolId, msg.sender, amountA, amountB, liquidity);
    }


    function removeLiquidity(
        bytes32 poolId,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        uint32 deadline
    ) external validDeadline(deadline) nonReentrant returns (uint256 amountA, uint256 amountB) {
        LiquidityPool storage pool = liquidityPools[poolId];
        require(pool.exists, "Pool does not exist");
        require(liquidityShares[poolId][msg.sender] >= liquidity, "Insufficient liquidity");

        amountA = (liquidity * pool.reserveA) / pool.totalLiquidity;
        amountB = (liquidity * pool.reserveB) / pool.totalLiquidity;

        require(amountA >= amountAMin && amountB >= amountBMin, "Insufficient output amount");


        liquidityShares[poolId][msg.sender] -= liquidity;
        pool.reserveA -= amountA;
        pool.reserveB -= amountB;
        pool.totalLiquidity -= liquidity;


        require(IERC20(pool.tokenA).transfer(msg.sender, amountA), "Transfer A failed");
        require(IERC20(pool.tokenB).transfer(msg.sender, amountB), "Transfer B failed");

        emit LiquidityRemoved(poolId, msg.sender, amountA, amountB, liquidity);
    }


    function swapExactTokensForTokens(
        bytes32 poolId,
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn,
        uint32 deadline
    ) external validDeadline(deadline) nonReentrant returns (uint256 amountOut) {
        LiquidityPool storage pool = liquidityPools[poolId];
        require(pool.exists, "Pool does not exist");
        require(tokenIn == pool.tokenA || tokenIn == pool.tokenB, "Invalid token");

        bool isTokenA = tokenIn == pool.tokenA;
        address tokenOut = isTokenA ? pool.tokenB : pool.tokenA;
        uint256 reserveIn = isTokenA ? pool.reserveA : pool.reserveB;
        uint256 reserveOut = isTokenA ? pool.reserveB : pool.reserveA;


        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_RATE);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;
        amountOut = numerator / denominator;

        require(amountOut >= amountOutMin, "Insufficient output amount");
        require(amountOut < reserveOut, "Insufficient liquidity");


        require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "Transfer in failed");
        require(IERC20(tokenOut).transfer(msg.sender, amountOut), "Transfer out failed");


        if (isTokenA) {
            pool.reserveA += amountIn;
            pool.reserveB -= amountOut;
        } else {
            pool.reserveB += amountIn;
            pool.reserveA -= amountOut;
        }


        uint256 feeAmount = (amountIn * FEE_RATE) / FEE_DENOMINATOR;
        collectedFees[tokenIn] += feeAmount;

        emit TokensSwapped(poolId, msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }


    function createOrder(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint32 deadline
    ) external validDeadline(deadline) returns (bytes32 orderId) {
        require(tokenIn != address(0) && tokenOut != address(0), "Invalid token address");
        require(tokenIn != tokenOut, "Identical tokens");
        require(amountIn > 0 && minAmountOut > 0, "Invalid amounts");

        orderId = keccak256(abi.encodePacked(msg.sender, tokenIn, tokenOut, amountIn, block.timestamp, userOrderCount[msg.sender]));

        orders[orderId] = Order({
            trader: msg.sender,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            minAmountOut: minAmountOut,
            deadline: deadline,
            isActive: true
        });

        userOrderCount[msg.sender]++;


        require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "Transfer failed");

        emit OrderCreated(orderId, msg.sender, tokenIn, tokenOut, amountIn);
    }


    function executeOrder(bytes32 orderId, bytes32 poolId) external nonReentrant {
        Order storage order = orders[orderId];
        require(order.isActive, "Order not active");
        require(order.deadline >= block.timestamp, "Order expired");

        LiquidityPool storage pool = liquidityPools[poolId];
        require(pool.exists, "Pool does not exist");
        require((order.tokenIn == pool.tokenA && order.tokenOut == pool.tokenB) ||
                (order.tokenIn == pool.tokenB && order.tokenOut == pool.tokenA), "Token mismatch");

        bool isTokenA = order.tokenIn == pool.tokenA;
        uint256 reserveIn = isTokenA ? pool.reserveA : pool.reserveB;
        uint256 reserveOut = isTokenA ? pool.reserveB : pool.reserveA;


        uint256 amountInWithFee = order.amountIn * (FEE_DENOMINATOR - FEE_RATE);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;
        uint256 amountOut = numerator / denominator;

        require(amountOut >= order.minAmountOut, "Insufficient output amount");


        order.isActive = false;


        if (isTokenA) {
            pool.reserveA += order.amountIn;
            pool.reserveB -= amountOut;
        } else {
            pool.reserveB += order.amountIn;
            pool.reserveA -= amountOut;
        }


        require(IERC20(order.tokenOut).transfer(order.trader, amountOut), "Transfer failed");


        uint256 feeAmount = (order.amountIn * FEE_RATE) / FEE_DENOMINATOR;
        collectedFees[order.tokenIn] += feeAmount;

        emit OrderExecuted(orderId, order.trader, amountOut);
    }


    function cancelOrder(bytes32 orderId) external {
        Order storage order = orders[orderId];
        require(order.trader == msg.sender, "Not order owner");
        require(order.isActive, "Order not active");

        order.isActive = false;


        require(IERC20(order.tokenIn).transfer(msg.sender, order.amountIn), "Transfer failed");

        emit OrderCancelled(orderId, msg.sender);
    }


    function getReserves(bytes32 poolId) external view returns (uint256 reserveA, uint256 reserveB) {
        LiquidityPool storage pool = liquidityPools[poolId];
        require(pool.exists, "Pool does not exist");
        return (pool.reserveA, pool.reserveB);
    }


    function getAmountOut(bytes32 poolId, uint256 amountIn, address tokenIn) external view returns (uint256 amountOut) {
        LiquidityPool storage pool = liquidityPools[poolId];
        require(pool.exists, "Pool does not exist");
        require(tokenIn == pool.tokenA || tokenIn == pool.tokenB, "Invalid token");

        bool isTokenA = tokenIn == pool.tokenA;
        uint256 reserveIn = isTokenA ? pool.reserveA : pool.reserveB;
        uint256 reserveOut = isTokenA ? pool.reserveB : pool.reserveA;

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_RATE);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;
        amountOut = numerator / denominator;
    }


    function withdrawFees(address token, uint256 amount) external onlyOwner {
        require(collectedFees[token] >= amount, "Insufficient fees");
        collectedFees[token] -= amount;
        require(IERC20(token).transfer(owner, amount), "Transfer failed");
    }


    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        require(IERC20(token).transfer(owner, amount), "Transfer failed");
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }


    function _sqrt(uint256 x) private pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}
