
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
    mapping(address => uint256) public totalLiquidity;
    mapping(address => mapping(address => uint256)) public userLiquidity;

    uint256 public constant FEE_RATE = 3;
    uint256 public constant FEE_DENOMINATOR = 1000;

    address public owner;
    bool public paused;


    event LiquidityAdded(address token0, address token1, uint256 amount0, uint256 amount1, address provider);
    event LiquidityRemoved(address token0, address token1, uint256 amount0, uint256 amount1, address provider);
    event TokenSwapped(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut, address trader);
    event OwnershipTransferred(address previousOwner, address newOwner);


    error Failed();
    error NotAllowed();
    error BadInput();

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier notPaused() {
        require(!paused);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function addLiquidity(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1
    ) external notPaused {

        require(token0 != address(0) && token1 != address(0));
        require(amount0 > 0 && amount1 > 0);
        require(token0 != token1);

        IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        IERC20(token1).transferFrom(msg.sender, address(this), amount1);

        bytes32 pairKey = getPairKey(token0, token1);
        liquidity[token0][token1] += amount0;
        liquidity[token1][token0] += amount1;
        totalLiquidity[token0] += amount0;
        totalLiquidity[token1] += amount1;
        userLiquidity[msg.sender][token0] += amount0;
        userLiquidity[msg.sender][token1] += amount1;




        emit LiquidityAdded(token0, token1, amount0, amount1, msg.sender);
    }

    function removeLiquidity(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1
    ) external notPaused {
        require(token0 != address(0) && token1 != address(0));
        require(amount0 > 0 && amount1 > 0);
        require(userLiquidity[msg.sender][token0] >= amount0);
        require(userLiquidity[msg.sender][token1] >= amount1);

        liquidity[token0][token1] -= amount0;
        liquidity[token1][token0] -= amount1;
        totalLiquidity[token0] -= amount0;
        totalLiquidity[token1] -= amount1;
        userLiquidity[msg.sender][token0] -= amount0;
        userLiquidity[msg.sender][token1] -= amount1;

        IERC20(token0).transfer(msg.sender, amount0);
        IERC20(token1).transfer(msg.sender, amount1);

        emit LiquidityRemoved(token0, token1, amount0, amount1, msg.sender);
    }

    function swapTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external notPaused {
        require(tokenIn != address(0) && tokenOut != address(0));
        require(amountIn > 0);
        require(tokenIn != tokenOut);

        uint256 reserveIn = liquidity[tokenIn][tokenOut];
        uint256 reserveOut = liquidity[tokenOut][tokenIn];


        require(reserveIn > 0 && reserveOut > 0);

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_RATE);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;
        uint256 amountOut = numerator / denominator;

        if (amountOut < minAmountOut) {

            revert BadInput();
        }

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        liquidity[tokenIn][tokenOut] += amountIn;
        liquidity[tokenOut][tokenIn] -= amountOut;
        totalLiquidity[tokenIn] += amountIn;
        totalLiquidity[tokenOut] -= amountOut;

        IERC20(tokenOut).transfer(msg.sender, amountOut);

        emit TokenSwapped(tokenIn, tokenOut, amountIn, amountOut, msg.sender);
    }

    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external view returns (uint256) {
        require(tokenIn != address(0) && tokenOut != address(0));
        require(amountIn > 0);

        uint256 reserveIn = liquidity[tokenIn][tokenOut];
        uint256 reserveOut = liquidity[tokenOut][tokenIn];

        if (reserveIn == 0 || reserveOut == 0) {
            return 0;
        }

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - FEE_RATE);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;

        return numerator / denominator;
    }

    function setPaused(bool _paused) external onlyOwner {

        paused = _paused;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0));

        address previousOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {

        require(token != address(0));
        require(amount > 0);

        if (IERC20(token).balanceOf(address(this)) < amount) {

            revert Failed();
        }

        IERC20(token).transfer(owner, amount);



    }

    function getPairKey(address token0, address token1) internal pure returns (bytes32) {
        return token0 < token1 ?
            keccak256(abi.encodePacked(token0, token1)) :
            keccak256(abi.encodePacked(token1, token0));
    }

    function getLiquidityInfo(address token0, address token1) external view returns (uint256, uint256) {
        return (liquidity[token0][token1], liquidity[token1][token0]);
    }

    function getUserLiquidity(address user, address token) external view returns (uint256) {
        return userLiquidity[user][token];
    }
}
