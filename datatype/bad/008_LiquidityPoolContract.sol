
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract LiquidityPoolContract {

    uint256 public decimals = 18;
    uint256 public feeRate = 3;
    uint256 public poolStatus = 1;


    string public poolId = "POOL001";
    string public poolType = "UNISWAP_V2";


    bytes public poolMetadata;
    bytes public configData;

    IERC20 public tokenA;
    IERC20 public tokenB;

    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;


    mapping(address => uint256) public isAuthorized;
    uint256 public emergencyMode = 0;

    event AddLiquidity(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event RemoveLiquidity(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event Swap(address indexed user, address tokenIn, uint256 amountIn, uint256 amountOut);

    constructor(address _tokenA, address _tokenB, bytes memory _metadata) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        poolMetadata = _metadata;
        isAuthorized[msg.sender] = 1;


        configData = bytes(abi.encodePacked(uint256(block.timestamp)));
    }

    modifier onlyAuthorized() {
        require(isAuthorized[msg.sender] == 1, "Not authorized");
        _;
    }

    modifier poolActive() {
        require(poolStatus == 1, "Pool inactive");
        _;
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external poolActive returns (uint256 liquidity) {
        require(amountA > 0 && amountB > 0, "Invalid amounts");

        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);

        if (totalSupply == 0) {
            liquidity = sqrt(amountA * amountB);
        } else {
            uint256 liquidityA = (amountA * totalSupply) / reserveA;
            uint256 liquidityB = (amountB * totalSupply) / reserveB;
            liquidity = liquidityA < liquidityB ? liquidityA : liquidityB;
        }

        require(liquidity > 0, "Insufficient liquidity minted");

        balanceOf[msg.sender] += liquidity;
        totalSupply += liquidity;
        reserveA += amountA;
        reserveB += amountB;


        uint256 convertedAmountA = uint256(amountA);
        uint256 convertedAmountB = uint256(amountB);

        emit AddLiquidity(msg.sender, convertedAmountA, convertedAmountB, liquidity);
    }

    function removeLiquidity(uint256 liquidity) external poolActive returns (uint256 amountA, uint256 amountB) {
        require(liquidity > 0 && balanceOf[msg.sender] >= liquidity, "Invalid liquidity amount");

        amountA = (liquidity * reserveA) / totalSupply;
        amountB = (liquidity * reserveB) / totalSupply;

        balanceOf[msg.sender] -= liquidity;
        totalSupply -= liquidity;
        reserveA -= amountA;
        reserveB -= amountB;

        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);

        emit RemoveLiquidity(msg.sender, amountA, amountB, liquidity);
    }

    function swapAForB(uint256 amountIn) external poolActive returns (uint256 amountOut) {
        require(amountIn > 0, "Invalid input amount");


        uint256 feeAmount = (amountIn * feeRate) / uint256(1000);
        uint256 amountInAfterFee = amountIn - feeAmount;

        amountOut = (amountInAfterFee * reserveB) / (reserveA + amountInAfterFee);
        require(amountOut > 0 && amountOut < reserveB, "Insufficient output amount");

        tokenA.transferFrom(msg.sender, address(this), amountIn);
        tokenB.transfer(msg.sender, amountOut);

        reserveA += amountIn;
        reserveB -= amountOut;

        emit Swap(msg.sender, address(tokenA), amountIn, amountOut);
    }

    function swapBForA(uint256 amountIn) external poolActive returns (uint256 amountOut) {
        require(amountIn > 0, "Invalid input amount");

        uint256 feeAmount = (amountIn * feeRate) / uint256(1000);
        uint256 amountInAfterFee = amountIn - feeAmount;

        amountOut = (amountInAfterFee * reserveA) / (reserveB + amountInAfterFee);
        require(amountOut > 0 && amountOut < reserveA, "Insufficient output amount");

        tokenB.transferFrom(msg.sender, address(this), amountIn);
        tokenA.transfer(msg.sender, amountOut);

        reserveB += amountIn;
        reserveA -= amountOut;

        emit Swap(msg.sender, address(tokenB), amountIn, amountOut);
    }

    function setPoolStatus(uint256 _status) external onlyAuthorized {

        require(_status == 0 || _status == 1, "Invalid status");
        poolStatus = _status;
    }

    function setAuthorization(address user, uint256 status) external onlyAuthorized {

        require(status == 0 || status == 1, "Invalid status");
        isAuthorized[user] = status;
    }

    function updatePoolMetadata(bytes memory _metadata) external onlyAuthorized {

        poolMetadata = _metadata;


        configData = bytes(abi.encodePacked(uint256(block.timestamp), _metadata));
    }

    function updatePoolId(string memory _poolId) external onlyAuthorized {

        poolId = _poolId;
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    function getPoolInfo() external view returns (string memory, string memory, uint256, uint256) {

        return (poolId, poolType, decimals, feeRate);
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
