
pragma solidity ^0.8.0;


contract LiquidityPool {

    interface IERC20 {
        function totalSupply() external view returns (uint256);
        function balanceOf(address account) external view returns (uint256);
        function transfer(address to, uint256 amount) external returns (bool);
        function allowance(address owner, address spender) external view returns (uint256);
        function approve(address spender, uint256 amount) external returns (bool);
        function transferFrom(address from, address to, uint256 amount) external returns (bool);
    }


    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;

    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public totalLiquidityShares;

    uint256 public constant FEE_RATE = 3;
    uint256 public constant FEE_DENOMINATOR = 1000;


    mapping(address => uint256) public liquidityShares;


    event LiquidityAdded(
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 shares
    );

    event LiquidityRemoved(
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 shares
    );

    event TokensSwapped(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );


    modifier validAmount(uint256 _amount) {
        require(_amount > 0, "LiquidityPool: Amount must be greater than zero");
        _;
    }

    modifier sufficientReserves() {
        require(reserveA > 0 && reserveB > 0, "LiquidityPool: Insufficient reserves");
        _;
    }


    constructor(address _tokenA, address _tokenB) {
        require(_tokenA != address(0), "LiquidityPool: Invalid token A address");
        require(_tokenB != address(0), "LiquidityPool: Invalid token B address");
        require(_tokenA != _tokenB, "LiquidityPool: Tokens must be different");

        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }


    function addLiquidity(
        uint256 _amountA,
        uint256 _amountB
    ) external validAmount(_amountA) validAmount(_amountB) returns (uint256 shares) {

        require(
            tokenA.transferFrom(msg.sender, address(this), _amountA),
            "LiquidityPool: Token A transfer failed"
        );
        require(
            tokenB.transferFrom(msg.sender, address(this), _amountB),
            "LiquidityPool: Token B transfer failed"
        );


        if (totalLiquidityShares == 0) {

            shares = _sqrt(_amountA * _amountB);
            require(shares > 0, "LiquidityPool: Insufficient initial liquidity");
        } else {

            uint256 sharesFromA = (_amountA * totalLiquidityShares) / reserveA;
            uint256 sharesFromB = (_amountB * totalLiquidityShares) / reserveB;
            shares = _min(sharesFromA, sharesFromB);
            require(shares > 0, "LiquidityPool: Insufficient liquidity shares");
        }


        liquidityShares[msg.sender] += shares;
        totalLiquidityShares += shares;
        reserveA += _amountA;
        reserveB += _amountB;

        emit LiquidityAdded(msg.sender, _amountA, _amountB, shares);
    }


    function removeLiquidity(
        uint256 _shares
    ) external validAmount(_shares) sufficientReserves returns (uint256 amountA, uint256 amountB) {
        require(
            liquidityShares[msg.sender] >= _shares,
            "LiquidityPool: Insufficient liquidity shares"
        );


        amountA = (_shares * reserveA) / totalLiquidityShares;
        amountB = (_shares * reserveB) / totalLiquidityShares;

        require(amountA > 0 && amountB > 0, "LiquidityPool: Insufficient output amounts");


        liquidityShares[msg.sender] -= _shares;
        totalLiquidityShares -= _shares;
        reserveA -= amountA;
        reserveB -= amountB;


        require(tokenA.transfer(msg.sender, amountA), "LiquidityPool: Token A transfer failed");
        require(tokenB.transfer(msg.sender, amountB), "LiquidityPool: Token B transfer failed");

        emit LiquidityRemoved(msg.sender, amountA, amountB, _shares);
    }


    function swapAForB(
        uint256 _amountAIn,
        uint256 _minAmountBOut
    ) external validAmount(_amountAIn) sufficientReserves returns (uint256 amountBOut) {

        amountBOut = _getAmountOut(_amountAIn, reserveA, reserveB);
        require(amountBOut >= _minAmountBOut, "LiquidityPool: Insufficient output amount");
        require(amountBOut < reserveB, "LiquidityPool: Insufficient reserve B");


        require(
            tokenA.transferFrom(msg.sender, address(this), _amountAIn),
            "LiquidityPool: Token A transfer failed"
        );


        reserveA += _amountAIn;
        reserveB -= amountBOut;


        require(tokenB.transfer(msg.sender, amountBOut), "LiquidityPool: Token B transfer failed");

        emit TokensSwapped(msg.sender, address(tokenA), address(tokenB), _amountAIn, amountBOut);
    }


    function swapBForA(
        uint256 _amountBIn,
        uint256 _minAmountAOut
    ) external validAmount(_amountBIn) sufficientReserves returns (uint256 amountAOut) {

        amountAOut = _getAmountOut(_amountBIn, reserveB, reserveA);
        require(amountAOut >= _minAmountAOut, "LiquidityPool: Insufficient output amount");
        require(amountAOut < reserveA, "LiquidityPool: Insufficient reserve A");


        require(
            tokenB.transferFrom(msg.sender, address(this), _amountBIn),
            "LiquidityPool: Token B transfer failed"
        );


        reserveB += _amountBIn;
        reserveA -= amountAOut;


        require(tokenA.transfer(msg.sender, amountAOut), "LiquidityPool: Token A transfer failed");

        emit TokensSwapped(msg.sender, address(tokenB), address(tokenA), _amountBIn, amountAOut);
    }


    function getAmountOut(
        uint256 _amountIn,
        uint256 _reserveIn,
        uint256 _reserveOut
    ) external pure returns (uint256 amountOut) {
        return _getAmountOut(_amountIn, _reserveIn, _reserveOut);
    }


    function getUserLiquidityShares(address _user) external view returns (uint256 shares) {
        return liquidityShares[_user];
    }


    function getReserves() external view returns (uint256 _reserveA, uint256 _reserveB) {
        return (reserveA, reserveB);
    }




    function _getAmountOut(
        uint256 _amountIn,
        uint256 _reserveIn,
        uint256 _reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(_amountIn > 0, "LiquidityPool: Insufficient input amount");
        require(_reserveIn > 0 && _reserveOut > 0, "LiquidityPool: Insufficient liquidity");


        uint256 amountInWithFee = _amountIn * (FEE_DENOMINATOR - FEE_RATE);
        uint256 numerator = amountInWithFee * _reserveOut;
        uint256 denominator = (_reserveIn * FEE_DENOMINATOR) + amountInWithFee;

        amountOut = numerator / denominator;
    }


    function _sqrt(uint256 _x) internal pure returns (uint256 y) {
        if (_x == 0) return 0;

        uint256 z = (_x + 1) / 2;
        y = _x;

        while (z < y) {
            y = z;
            z = (_x / z + z) / 2;
        }
    }


    function _min(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return _a < _b ? _a : _b;
    }
}
