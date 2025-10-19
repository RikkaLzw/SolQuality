
pragma solidity ^0.8.0;

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
    uint256 private unlocked = 1;


    event LiquidityAdded(
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 indexed liquidity
    );

    event LiquidityRemoved(
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 indexed liquidity
    );

    event TokensSwapped(
        address indexed trader,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    event ReservesUpdated(uint256 reserveA, uint256 reserveB);

    modifier lock() {
        require(unlocked == 1, "LiquidityPool: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor(address _tokenA, address _tokenB) {
        require(_tokenA != address(0), "LiquidityPool: Invalid token A address");
        require(_tokenB != address(0), "LiquidityPool: Invalid token B address");
        require(_tokenA != _tokenB, "LiquidityPool: Identical token addresses");

        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external lock returns (uint256 liquidity) {
        require(amountA > 0, "LiquidityPool: Insufficient amount A");
        require(amountB > 0, "LiquidityPool: Insufficient amount B");


        require(
            tokenA.transferFrom(msg.sender, address(this), amountA),
            "LiquidityPool: Token A transfer failed"
        );
        require(
            tokenB.transferFrom(msg.sender, address(this), amountB),
            "LiquidityPool: Token B transfer failed"
        );

        if (totalLiquidity == 0) {

            liquidity = sqrt(amountA * amountB);
            require(liquidity > MINIMUM_LIQUIDITY, "LiquidityPool: Insufficient initial liquidity");
            liquidity -= MINIMUM_LIQUIDITY;
        } else {

            uint256 liquidityA = (amountA * totalLiquidity) / reserveA;
            uint256 liquidityB = (amountB * totalLiquidity) / reserveB;
            liquidity = liquidityA < liquidityB ? liquidityA : liquidityB;
            require(liquidity > 0, "LiquidityPool: Insufficient liquidity minted");
        }

        liquidityBalance[msg.sender] += liquidity;
        totalLiquidity += liquidity;

        _updateReserves();

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }

    function removeLiquidity(uint256 liquidity) external lock returns (uint256 amountA, uint256 amountB) {
        require(liquidity > 0, "LiquidityPool: Invalid liquidity amount");
        require(liquidityBalance[msg.sender] >= liquidity, "LiquidityPool: Insufficient liquidity balance");
        require(totalLiquidity > 0, "LiquidityPool: No liquidity available");

        amountA = (liquidity * reserveA) / totalLiquidity;
        amountB = (liquidity * reserveB) / totalLiquidity;

        require(amountA > 0 && amountB > 0, "LiquidityPool: Insufficient liquidity burned");

        liquidityBalance[msg.sender] -= liquidity;
        totalLiquidity -= liquidity;

        require(tokenA.transfer(msg.sender, amountA), "LiquidityPool: Token A transfer failed");
        require(tokenB.transfer(msg.sender, amountB), "LiquidityPool: Token B transfer failed");

        _updateReserves();

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);
    }

    function swapAForB(uint256 amountAIn) external lock returns (uint256 amountBOut) {
        require(amountAIn > 0, "LiquidityPool: Invalid input amount");
        require(reserveA > 0 && reserveB > 0, "LiquidityPool: Insufficient liquidity");


        uint256 amountAInWithFee = amountAIn * 997;
        uint256 numerator = amountAInWithFee * reserveB;
        uint256 denominator = (reserveA * 1000) + amountAInWithFee;
        amountBOut = numerator / denominator;

        require(amountBOut > 0, "LiquidityPool: Insufficient output amount");
        require(amountBOut < reserveB, "LiquidityPool: Insufficient reserve B");

        require(
            tokenA.transferFrom(msg.sender, address(this), amountAIn),
            "LiquidityPool: Token A transfer failed"
        );
        require(
            tokenB.transfer(msg.sender, amountBOut),
            "LiquidityPool: Token B transfer failed"
        );

        _updateReserves();

        emit TokensSwapped(msg.sender, address(tokenA), address(tokenB), amountAIn, amountBOut);
    }

    function swapBForA(uint256 amountBIn) external lock returns (uint256 amountAOut) {
        require(amountBIn > 0, "LiquidityPool: Invalid input amount");
        require(reserveA > 0 && reserveB > 0, "LiquidityPool: Insufficient liquidity");


        uint256 amountBInWithFee = amountBIn * 997;
        uint256 numerator = amountBInWithFee * reserveA;
        uint256 denominator = (reserveB * 1000) + amountBInWithFee;
        amountAOut = numerator / denominator;

        require(amountAOut > 0, "LiquidityPool: Insufficient output amount");
        require(amountAOut < reserveA, "LiquidityPool: Insufficient reserve A");

        require(
            tokenB.transferFrom(msg.sender, address(this), amountBIn),
            "LiquidityPool: Token B transfer failed"
        );
        require(
            tokenA.transfer(msg.sender, amountAOut),
            "LiquidityPool: Token A transfer failed"
        );

        _updateReserves();

        emit TokensSwapped(msg.sender, address(tokenB), address(tokenA), amountBIn, amountAOut);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "LiquidityPool: Invalid input amount");
        require(reserveIn > 0 && reserveOut > 0, "LiquidityPool: Invalid reserves");

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function _updateReserves() private {
        reserveA = tokenA.balanceOf(address(this));
        reserveB = tokenB.balanceOf(address(this));
        emit ReservesUpdated(reserveA, reserveB);
    }

    function sqrt(uint256 y) private pure returns (uint256 z) {
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


    function getReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    function getLiquidityBalance(address account) external view returns (uint256) {
        return liquidityBalance[account];
    }
}
