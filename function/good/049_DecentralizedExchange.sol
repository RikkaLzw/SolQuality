
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract DecentralizedExchange {
    mapping(address => mapping(address => uint256)) public liquidity;
    mapping(address => mapping(address => uint256)) public reserves;
    mapping(address => uint256) public totalLiquidity;

    uint256 public constant FEE_RATE = 3;
    uint256 public constant FEE_DENOMINATOR = 1000;

    event LiquidityAdded(address indexed provider, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);
    event LiquidityRemoved(address indexed provider, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);
    event TokensSwapped(address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    modifier validToken(address token) {
        require(token != address(0), "Invalid token address");
        _;
    }

    modifier validAmount(uint256 amount) {
        require(amount > 0, "Amount must be greater than zero");
        _;
    }

    function addLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB)
        external
        validToken(tokenA)
        validToken(tokenB)
        validAmount(amountA)
        validAmount(amountB)
    {
        require(tokenA != tokenB, "Tokens must be different");

        _transferTokensFrom(tokenA, msg.sender, amountA);
        _transferTokensFrom(tokenB, msg.sender, amountB);

        _updateReserves(tokenA, tokenB, amountA, amountB);
        _updateLiquidity(tokenA, tokenB, amountA, amountB);

        emit LiquidityAdded(msg.sender, tokenA, tokenB, amountA, amountB);
    }

    function removeLiquidity(address tokenA, address tokenB, uint256 liquidityAmount)
        external
        validToken(tokenA)
        validToken(tokenB)
        validAmount(liquidityAmount)
    {
        require(liquidity[msg.sender][_getPairKey(tokenA, tokenB)] >= liquidityAmount, "Insufficient liquidity");

        (uint256 amountA, uint256 amountB) = _calculateWithdrawalAmounts(tokenA, tokenB, liquidityAmount);

        _updateLiquidityOnRemoval(tokenA, tokenB, liquidityAmount);
        _updateReservesOnRemoval(tokenA, tokenB, amountA, amountB);

        _transferTokensTo(tokenA, msg.sender, amountA);
        _transferTokensTo(tokenB, msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, tokenA, tokenB, amountA, amountB);
    }

    function swapTokens(address tokenIn, address tokenOut, uint256 amountIn)
        external
        validToken(tokenIn)
        validToken(tokenOut)
        validAmount(amountIn)
        returns (uint256 amountOut)
    {
        require(tokenIn != tokenOut, "Tokens must be different");

        amountOut = _calculateSwapOutput(tokenIn, tokenOut, amountIn);
        require(amountOut > 0, "Insufficient output amount");
        require(reserves[tokenOut][tokenIn] >= amountOut, "Insufficient liquidity");

        _transferTokensFrom(tokenIn, msg.sender, amountIn);
        _transferTokensTo(tokenOut, msg.sender, amountOut);

        _updateReservesAfterSwap(tokenIn, tokenOut, amountIn, amountOut);

        emit TokensSwapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    function getSwapOutput(address tokenIn, address tokenOut, uint256 amountIn)
        external
        view
        validToken(tokenIn)
        validToken(tokenOut)
        validAmount(amountIn)
        returns (uint256)
    {
        return _calculateSwapOutput(tokenIn, tokenOut, amountIn);
    }

    function getLiquidityBalance(address provider, address tokenA, address tokenB)
        external
        view
        returns (uint256)
    {
        return liquidity[provider][_getPairKey(tokenA, tokenB)];
    }

    function getReserves(address tokenA, address tokenB)
        external
        view
        returns (uint256 reserveA, uint256 reserveB)
    {
        reserveA = reserves[tokenA][tokenB];
        reserveB = reserves[tokenB][tokenA];
    }

    function _transferTokensFrom(address token, address from, uint256 amount) internal {
        require(IERC20(token).transferFrom(from, address(this), amount), "Transfer failed");
    }

    function _transferTokensTo(address token, address to, uint256 amount) internal {
        require(IERC20(token).transfer(to, amount), "Transfer failed");
    }

    function _updateReserves(address tokenA, address tokenB, uint256 amountA, uint256 amountB) internal {
        reserves[tokenA][tokenB] += amountA;
        reserves[tokenB][tokenA] += amountB;
    }

    function _updateLiquidity(address tokenA, address tokenB, uint256 amountA, uint256 amountB) internal {
        bytes32 pairKey = _getPairKey(tokenA, tokenB);
        uint256 liquidityMinted = _calculateLiquidityMinted(amountA, amountB);

        liquidity[msg.sender][pairKey] += liquidityMinted;
        totalLiquidity[uint256(pairKey)] += liquidityMinted;
    }

    function _calculateWithdrawalAmounts(address tokenA, address tokenB, uint256 liquidityAmount)
        internal
        view
        returns (uint256 amountA, uint256 amountB)
    {
        bytes32 pairKey = _getPairKey(tokenA, tokenB);
        uint256 totalLiq = totalLiquidity[uint256(pairKey)];

        amountA = (reserves[tokenA][tokenB] * liquidityAmount) / totalLiq;
        amountB = (reserves[tokenB][tokenA] * liquidityAmount) / totalLiq;
    }

    function _updateLiquidityOnRemoval(address tokenA, address tokenB, uint256 liquidityAmount) internal {
        bytes32 pairKey = _getPairKey(tokenA, tokenB);
        liquidity[msg.sender][pairKey] -= liquidityAmount;
        totalLiquidity[uint256(pairKey)] -= liquidityAmount;
    }

    function _updateReservesOnRemoval(address tokenA, address tokenB, uint256 amountA, uint256 amountB) internal {
        reserves[tokenA][tokenB] -= amountA;
        reserves[tokenB][tokenA] -= amountB;
    }

    function _calculateSwapOutput(address tokenIn, address tokenOut, uint256 amountIn)
        internal
        view
        returns (uint256)
    {
        uint256 reserveIn = reserves[tokenIn][tokenOut];
        uint256 reserveOut = reserves[tokenOut][tokenIn];

        if (reserveIn == 0 || reserveOut == 0) {
            return 0;
        }

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_RATE);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;

        return numerator / denominator;
    }

    function _updateReservesAfterSwap(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut) internal {
        reserves[tokenIn][tokenOut] += amountIn;
        reserves[tokenOut][tokenIn] -= amountOut;
    }

    function _calculateLiquidityMinted(uint256 amountA, uint256 amountB) internal pure returns (uint256) {
        return _sqrt(amountA * amountB);
    }

    function _getPairKey(address tokenA, address tokenB) internal pure returns (bytes32) {
        return tokenA < tokenB ? keccak256(abi.encodePacked(tokenA, tokenB)) : keccak256(abi.encodePacked(tokenB, tokenA));
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
