
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract DecentralizedExchangeDEX {

    uint256 public feePercentage = 3;
    uint256 public constant MAX_SLIPPAGE = 5;
    uint256 public orderCounter = 0;


    string public exchangeName = "DEX_V1";
    string public version = "1.0.0";


    uint256 public exchangeActive = 1;
    uint256 public emergencyStop = 0;

    address public owner;

    struct LiquidityPool {
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalLiquidity;

        uint256 poolActive;
    }

    struct Order {
        address trader;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;

        string orderType;

        bytes orderHash;

        uint256 filled;
    }

    mapping(bytes32 => LiquidityPool) public pools;
    mapping(uint256 => Order) public orders;
    mapping(address => mapping(address => uint256)) public userBalances;


    event PoolCreated(bytes32 indexed poolId, bytes poolData);
    event OrderPlaced(uint256 indexed orderId, bytes orderData);
    event Trade(address indexed trader, bytes tradeData);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier whenActive() {

        require(exchangeActive == 1, "Exchange not active");
        require(emergencyStop == 0, "Emergency stop activated");
        _;
    }

    constructor() {
        owner = msg.sender;

        exchangeActive = uint256(1);
        emergencyStop = uint256(0);
    }

    function createPool(address tokenA, address tokenB) external onlyOwner {
        require(tokenA != tokenB, "Same token");
        require(tokenA != address(0) && tokenB != address(0), "Zero address");

        bytes32 poolId = keccak256(abi.encodePacked(tokenA, tokenB));


        pools[poolId] = LiquidityPool({
            tokenA: tokenA,
            tokenB: tokenB,
            reserveA: 0,
            reserveB: 0,
            totalLiquidity: 0,
            poolActive: uint256(1)
        });


        bytes memory poolData = abi.encode(tokenA, tokenB, block.timestamp);
        emit PoolCreated(poolId, poolData);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) external whenActive {
        bytes32 poolId = keccak256(abi.encodePacked(tokenA, tokenB));
        LiquidityPool storage pool = pools[poolId];


        require(pool.poolActive == 1, "Pool not active");

        require(
            IERC20(tokenA).transferFrom(msg.sender, address(this), amountA),
            "Transfer A failed"
        );
        require(
            IERC20(tokenB).transferFrom(msg.sender, address(this), amountB),
            "Transfer B failed"
        );

        uint256 liquidity;
        if (pool.totalLiquidity == 0) {
            liquidity = sqrt(amountA * amountB);
        } else {
            liquidity = min(
                (amountA * pool.totalLiquidity) / pool.reserveA,
                (amountB * pool.totalLiquidity) / pool.reserveB
            );
        }

        pool.reserveA += amountA;
        pool.reserveB += amountB;
        pool.totalLiquidity += liquidity;

        userBalances[msg.sender][address(this)] += liquidity;
    }

    function placeOrder(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external whenActive {
        require(amountIn > 0, "Invalid amount");
        require(
            IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn),
            "Transfer failed"
        );


        orderCounter = uint256(orderCounter + 1);


        bytes memory orderHash = keccak256(
            abi.encodePacked(msg.sender, tokenIn, tokenOut, amountIn, block.timestamp)
        );

        orders[orderCounter] = Order({
            trader: msg.sender,
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            minAmountOut: minAmountOut,
            orderType: "MARKET",
            orderHash: orderHash,
            filled: uint256(0)
        });


        bytes memory orderData = abi.encode(
            msg.sender,
            tokenIn,
            tokenOut,
            amountIn,
            minAmountOut
        );
        emit OrderPlaced(orderCounter, orderData);
    }

    function executeSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external whenActive returns (uint256 amountOut) {
        bytes32 poolId = keccak256(abi.encodePacked(tokenIn, tokenOut));
        LiquidityPool storage pool = pools[poolId];


        require(pool.poolActive == 1, "Pool not active");

        require(
            IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn),
            "Transfer failed"
        );


        uint256 amountInWithFee = (amountIn * (1000 - feePercentage)) / 1000;

        if (pool.tokenA == tokenIn) {
            amountOut = (amountInWithFee * pool.reserveB) /
                       (pool.reserveA + amountInWithFee);
            pool.reserveA += amountIn;
            pool.reserveB -= amountOut;
        } else {
            amountOut = (amountInWithFee * pool.reserveA) /
                       (pool.reserveB + amountInWithFee);
            pool.reserveB += amountIn;
            pool.reserveA -= amountOut;
        }

        require(IERC20(tokenOut).transfer(msg.sender, amountOut), "Transfer out failed");


        bytes memory tradeData = abi.encode(tokenIn, tokenOut, amountIn, amountOut);
        emit Trade(msg.sender, tradeData);
    }

    function setFeePercentage(uint256 _fee) external onlyOwner {

        require(_fee <= uint256(10), "Fee too high");
        feePercentage = _fee;
    }

    function toggleExchange() external onlyOwner {

        exchangeActive = exchangeActive == 1 ? uint256(0) : uint256(1);
    }

    function emergencyStopToggle() external onlyOwner {

        emergencyStop = emergencyStop == 1 ? uint256(0) : uint256(1);
    }


    function updateExchangeName(string memory _name) external onlyOwner {
        exchangeName = _name;
    }

    function getPoolReserves(address tokenA, address tokenB)
        external
        view
        returns (uint256, uint256)
    {
        bytes32 poolId = keccak256(abi.encodePacked(tokenA, tokenB));
        LiquidityPool memory pool = pools[poolId];
        return (pool.reserveA, pool.reserveB);
    }


    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
