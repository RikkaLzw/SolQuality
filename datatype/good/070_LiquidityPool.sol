
pragma solidity ^0.8.19;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract LiquidityPool {
    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;

    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public totalLiquidity;

    mapping(address => uint256) public liquidityBalance;

    uint256 private constant MINIMUM_LIQUIDITY = 1000;
    uint256 private constant FEE_RATE = 3;
    uint256 private constant FEE_DENOMINATOR = 1000;

    bytes32 private constant POOL_IDENTIFIER = keccak256("LIQUIDITY_POOL_V1");

    bool private locked;

    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event Swap(address indexed user, address indexed tokenIn, uint256 amountIn, uint256 amountOut);

    modifier nonReentrant() {
        require(!locked, "ReentrancyGuard: reentrant call");
        locked = true;
        _;
        locked = false;
    }

    modifier validAddress(address addr) {
        require(addr != address(0), "Invalid address");
        _;
    }

    constructor(address _tokenA, address _tokenB)
        validAddress(_tokenA)
        validAddress(_tokenB)
    {
        require(_tokenA != _tokenB, "Identical tokens");
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    function addLiquidity(uint256 amountA, uint256 amountB)
        external
        nonReentrant
        returns (uint256 liquidity)
    {
        require(amountA > 0 && amountB > 0, "Invalid amounts");

        if (totalLiquidity == 0) {
            liquidity = sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
            require(liquidity > 0, "Insufficient liquidity minted");
            totalLiquidity = liquidity + MINIMUM_LIQUIDITY;
        } else {
            uint256 liquidityA = (amountA * totalLiquidity) / reserveA;
            uint256 liquidityB = (amountB * totalLiquidity) / reserveB;
            liquidity = liquidityA < liquidityB ? liquidityA : liquidityB;
            require(liquidity > 0, "Insufficient liquidity minted");
            totalLiquidity += liquidity;
        }

        liquidityBalance[msg.sender] += liquidity;

        require(tokenA.transferFrom(msg.sender, address(this), amountA), "Transfer A failed");
        require(tokenB.transferFrom(msg.sender, address(this), amountB), "Transfer B failed");

        reserveA += amountA;
        reserveB += amountB;

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }

    function removeLiquidity(uint256 liquidity)
        external
        nonReentrant
        returns (uint256 amountA, uint256 amountB)
    {
        require(liquidity > 0, "Invalid liquidity amount");
        require(liquidityBalance[msg.sender] >= liquidity, "Insufficient liquidity balance");

        amountA = (liquidity * reserveA) / totalLiquidity;
        amountB = (liquidity * reserveB) / totalLiquidity;

        require(amountA > 0 && amountB > 0, "Insufficient liquidity burned");

        liquidityBalance[msg.sender] -= liquidity;
        totalLiquidity -= liquidity;

        reserveA -= amountA;
        reserveB -= amountB;

        require(tokenA.transfer(msg.sender, amountA), "Transfer A failed");
        require(tokenB.transfer(msg.sender, amountB), "Transfer B failed");

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);
    }

    function swapAForB(uint256 amountAIn)
        external
        nonReentrant
        returns (uint256 amountBOut)
    {
        require(amountAIn > 0, "Invalid input amount");
        require(reserveA > 0 && reserveB > 0, "Insufficient liquidity");

        uint256 amountAInWithFee = amountAIn * (FEE_DENOMINATOR - FEE_RATE);
        uint256 numerator = amountAInWithFee * reserveB;
        uint256 denominator = (reserveA * FEE_DENOMINATOR) + amountAInWithFee;
        amountBOut = numerator / denominator;

        require(amountBOut > 0, "Insufficient output amount");
        require(amountBOut < reserveB, "Insufficient liquidity");

        require(tokenA.transferFrom(msg.sender, address(this), amountAIn), "Transfer in failed");
        require(tokenB.transfer(msg.sender, amountBOut), "Transfer out failed");

        reserveA += amountAIn;
        reserveB -= amountBOut;

        emit Swap(msg.sender, address(tokenA), amountAIn, amountBOut);
    }

    function swapBForA(uint256 amountBIn)
        external
        nonReentrant
        returns (uint256 amountAOut)
    {
        require(amountBIn > 0, "Invalid input amount");
        require(reserveA > 0 && reserveB > 0, "Insufficient liquidity");

        uint256 amountBInWithFee = amountBIn * (FEE_DENOMINATOR - FEE_RATE);
        uint256 numerator = amountBInWithFee * reserveA;
        uint256 denominator = (reserveB * FEE_DENOMINATOR) + amountBInWithFee;
        amountAOut = numerator / denominator;

        require(amountAOut > 0, "Insufficient output amount");
        require(amountAOut < reserveA, "Insufficient liquidity");

        require(tokenB.transferFrom(msg.sender, address(this), amountBIn), "Transfer in failed");
        require(tokenA.transfer(msg.sender, amountAOut), "Transfer out failed");

        reserveB += amountBIn;
        reserveA -= amountAOut;

        emit Swap(msg.sender, address(tokenB), amountBIn, amountAOut);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "Invalid input amount");
        require(reserveIn > 0 && reserveOut > 0, "Invalid reserves");

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_RATE);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    function getPoolIdentifier() external pure returns (bytes32) {
        return POOL_IDENTIFIER;
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
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
