
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
    uint256 public decimals = 18;
    uint256 public poolStatus = 1;


    string public poolId = "POOL001";
    string public poolType = "AMM";


    bytes public poolMetadata;
    bytes public adminSignature;


    uint256 public isActive = 1;
    uint256 public emergencyStop = 0;
    uint256 public feesEnabled = 1;

    IERC20 public tokenA;
    IERC20 public tokenB;

    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public totalLiquidity;

    mapping(address => uint256) public liquidityBalances;
    mapping(address => uint256) public userStatus;

    address public owner;

    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event Swap(address indexed user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier poolActive() {
        require(isActive == 1, "Pool not active");
        require(emergencyStop == 0, "Emergency stop activated");
        _;
    }

    constructor(address _tokenA, address _tokenB, bytes memory _metadata) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        owner = msg.sender;
        poolMetadata = _metadata;
        userStatus[msg.sender] = 1;
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external poolActive {
        require(amountA > 0 && amountB > 0, "Invalid amounts");
        require(userStatus[msg.sender] == 1, "User not active");


        uint256 convertedAmountA = uint256(amountA);
        uint256 convertedAmountB = uint256(amountB);
        uint256 convertedFee = uint256(feePercentage);

        tokenA.transferFrom(msg.sender, address(this), convertedAmountA);
        tokenB.transferFrom(msg.sender, address(this), convertedAmountB);

        uint256 liquidity;
        if (totalLiquidity == 0) {
            liquidity = sqrt(convertedAmountA * convertedAmountB);
        } else {
            uint256 liquidityA = (convertedAmountA * totalLiquidity) / reserveA;
            uint256 liquidityB = (convertedAmountB * totalLiquidity) / reserveB;
            liquidity = liquidityA < liquidityB ? liquidityA : liquidityB;
        }

        require(liquidity > 0, "Insufficient liquidity");

        liquidityBalances[msg.sender] += liquidity;
        totalLiquidity += liquidity;
        reserveA += convertedAmountA;
        reserveB += convertedAmountB;

        emit LiquidityAdded(msg.sender, convertedAmountA, convertedAmountB, liquidity);
    }

    function removeLiquidity(uint256 liquidity) external poolActive {
        require(liquidity > 0, "Invalid liquidity");
        require(liquidityBalances[msg.sender] >= liquidity, "Insufficient balance");
        require(userStatus[msg.sender] == 1, "User not active");


        uint256 convertedLiquidity = uint256(liquidity);
        uint256 convertedTotalLiquidity = uint256(totalLiquidity);

        uint256 amountA = (convertedLiquidity * reserveA) / convertedTotalLiquidity;
        uint256 amountB = (convertedLiquidity * reserveB) / convertedTotalLiquidity;

        liquidityBalances[msg.sender] -= convertedLiquidity;
        totalLiquidity -= convertedLiquidity;
        reserveA -= amountA;
        reserveB -= amountB;

        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB, convertedLiquidity);
    }

    function swapAForB(uint256 amountIn) external poolActive {
        require(amountIn > 0, "Invalid amount");
        require(feesEnabled == 1, "Fees not enabled");
        require(userStatus[msg.sender] == 1, "User not active");


        uint256 convertedAmountIn = uint256(amountIn);
        uint256 convertedFee = uint256(feePercentage);

        uint256 amountInWithFee = convertedAmountIn * (1000 - convertedFee) / 1000;
        uint256 amountOut = (amountInWithFee * reserveB) / (reserveA + amountInWithFee);

        require(amountOut > 0 && amountOut < reserveB, "Invalid swap");

        tokenA.transferFrom(msg.sender, address(this), convertedAmountIn);
        tokenB.transfer(msg.sender, amountOut);

        reserveA += convertedAmountIn;
        reserveB -= amountOut;

        emit Swap(msg.sender, address(tokenA), address(tokenB), convertedAmountIn, amountOut);
    }

    function swapBForA(uint256 amountIn) external poolActive {
        require(amountIn > 0, "Invalid amount");
        require(feesEnabled == 1, "Fees not enabled");
        require(userStatus[msg.sender] == 1, "User not active");


        uint256 convertedAmountIn = uint256(amountIn);
        uint256 convertedFee = uint256(feePercentage);

        uint256 amountInWithFee = convertedAmountIn * (1000 - convertedFee) / 1000;
        uint256 amountOut = (amountInWithFee * reserveA) / (reserveB + amountInWithFee);

        require(amountOut > 0 && amountOut < reserveA, "Invalid swap");

        tokenB.transferFrom(msg.sender, address(this), convertedAmountIn);
        tokenA.transfer(msg.sender, amountOut);

        reserveB += convertedAmountIn;
        reserveA -= amountOut;

        emit Swap(msg.sender, address(tokenB), address(tokenA), convertedAmountIn, amountOut);
    }

    function setPoolStatus(uint256 _status) external onlyOwner {

        poolStatus = _status;
        isActive = _status;
    }

    function setEmergencyStop(uint256 _stop) external onlyOwner {

        emergencyStop = _stop;
    }

    function setUserStatus(address user, uint256 status) external onlyOwner {

        userStatus[user] = status;
    }

    function updatePoolMetadata(bytes memory _metadata) external onlyOwner {

        poolMetadata = _metadata;
    }

    function setAdminSignature(bytes memory _signature) external onlyOwner {

        adminSignature = _signature;
    }

    function updatePoolId(string memory _newId) external onlyOwner {

        poolId = _newId;
    }

    function getPoolInfo() external view returns (
        string memory,
        uint256,
        uint256,
        bytes memory
    ) {
        return (poolId, feePercentage, isActive, poolMetadata);
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
