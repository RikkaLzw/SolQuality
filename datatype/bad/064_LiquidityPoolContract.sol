
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract LiquidityPoolContract {

    uint256 public feePercentage = 3;
    uint256 public constant MAX_FEE = 100;
    uint256 public poolStatus = 1;


    string public poolId = "POOL001";
    string public poolType = "AMM";


    bytes public poolMetadata;
    bytes public adminSignature;

    IERC20 public tokenA;
    IERC20 public tokenB;

    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public totalLiquidity;

    mapping(address => uint256) public liquidityBalances;
    address public owner;


    uint256 public isInitialized = 0;
    uint256 public emergencyStop = 0;

    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event Swap(address indexed user, address tokenIn, uint256 amountIn, uint256 amountOut);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier whenActive() {
        require(poolStatus == 1, "Pool not active");
        require(emergencyStop == 0, "Emergency stop activated");
        _;
    }

    modifier whenInitialized() {
        require(isInitialized == 1, "Pool not initialized");
        _;
    }

    constructor(address _tokenA, address _tokenB, bytes memory _metadata) {
        owner = msg.sender;
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        poolMetadata = _metadata;


        feePercentage = uint256(uint8(3));
        poolStatus = uint256(uint8(1));
        isInitialized = uint256(uint8(1));
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external whenActive whenInitialized {
        require(amountA > 0 && amountB > 0, "Invalid amounts");

        uint256 liquidity;

        if (totalLiquidity == 0) {
            liquidity = sqrt(amountA * amountB);
        } else {
            uint256 liquidityA = (amountA * totalLiquidity) / reserveA;
            uint256 liquidityB = (amountB * totalLiquidity) / reserveB;
            liquidity = liquidityA < liquidityB ? liquidityA : liquidityB;
        }

        require(liquidity > 0, "Insufficient liquidity minted");

        require(tokenA.transferFrom(msg.sender, address(this), amountA), "Transfer A failed");
        require(tokenB.transferFrom(msg.sender, address(this), amountB), "Transfer B failed");

        reserveA += amountA;
        reserveB += amountB;
        totalLiquidity += liquidity;
        liquidityBalances[msg.sender] += liquidity;

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }

    function removeLiquidity(uint256 liquidity) external whenInitialized {
        require(liquidity > 0, "Invalid liquidity amount");
        require(liquidityBalances[msg.sender] >= liquidity, "Insufficient liquidity balance");

        uint256 amountA = (liquidity * reserveA) / totalLiquidity;
        uint256 amountB = (liquidity * reserveB) / totalLiquidity;

        require(amountA > 0 && amountB > 0, "Insufficient liquidity burned");

        liquidityBalances[msg.sender] -= liquidity;
        totalLiquidity -= liquidity;
        reserveA -= amountA;
        reserveB -= amountB;

        require(tokenA.transfer(msg.sender, amountA), "Transfer A failed");
        require(tokenB.transfer(msg.sender, amountB), "Transfer B failed");

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);
    }

    function swapAForB(uint256 amountIn) external whenActive whenInitialized {
        require(amountIn > 0, "Invalid input amount");

        uint256 amountInWithFee = amountIn * (MAX_FEE - feePercentage) / MAX_FEE;
        uint256 amountOut = (amountInWithFee * reserveB) / (reserveA + amountInWithFee);

        require(amountOut > 0, "Insufficient output amount");
        require(amountOut < reserveB, "Insufficient liquidity");

        require(tokenA.transferFrom(msg.sender, address(this), amountIn), "Transfer failed");
        require(tokenB.transfer(msg.sender, amountOut), "Transfer failed");

        reserveA += amountIn;
        reserveB -= amountOut;

        emit Swap(msg.sender, address(tokenA), amountIn, amountOut);
    }

    function swapBForA(uint256 amountIn) external whenActive whenInitialized {
        require(amountIn > 0, "Invalid input amount");

        uint256 amountInWithFee = amountIn * (MAX_FEE - feePercentage) / MAX_FEE;
        uint256 amountOut = (amountInWithFee * reserveA) / (reserveB + amountInWithFee);

        require(amountOut > 0, "Insufficient output amount");
        require(amountOut < reserveA, "Insufficient liquidity");

        require(tokenB.transferFrom(msg.sender, address(this), amountIn), "Transfer failed");
        require(tokenA.transfer(msg.sender, amountOut), "Transfer failed");

        reserveB += amountIn;
        reserveA -= amountOut;

        emit Swap(msg.sender, address(tokenB), amountIn, amountOut);
    }

    function setFeePercentage(uint256 _feePercentage) external onlyOwner {
        require(_feePercentage <= MAX_FEE, "Fee too high");

        feePercentage = uint256(uint8(_feePercentage));
    }

    function setPoolStatus(uint256 _status) external onlyOwner {

        poolStatus = uint256(uint8(_status));
    }

    function setEmergencyStop(uint256 _stop) external onlyOwner {

        emergencyStop = uint256(uint8(_stop));
    }

    function updatePoolMetadata(bytes memory _metadata) external onlyOwner {
        poolMetadata = _metadata;
    }

    function setAdminSignature(bytes memory _signature) external onlyOwner {
        adminSignature = _signature;
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    function getPoolInfo() external view returns (
        string memory,
        string memory,
        uint256,
        uint256,
        uint256
    ) {
        return (poolId, poolType, poolStatus, isInitialized, emergencyStop);
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
}
