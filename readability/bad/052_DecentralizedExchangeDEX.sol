
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
    address public o;
    mapping(address => mapping(address => uint256)) public l;
    mapping(address => mapping(address => uint256)) public r;
    mapping(address => uint256) public f;

uint256 constant FEE = 3;
    uint256 constant DENOMINATOR = 1000;

    event swap_event(address indexed user, address tokenA, address tokenB, uint256 amountIn, uint256 amountOut);
        event liquidity_added(address indexed provider, address tokenA, address tokenB, uint256 amountA, uint256 amountB);

    modifier onlyOwner() {
        require(msg.sender == o, "Not owner"); _;
    }

    constructor() {
        o = msg.sender;
    }

function add_liquidity(address a, address b, uint256 x, uint256 y) external {
        require(a != address(0) && b != address(0), "Invalid token");
        require(x > 0 && y > 0, "Invalid amounts");

        IERC20(a).transferFrom(msg.sender, address(this), x);
            IERC20(b).transferFrom(msg.sender, address(this), y);

        l[msg.sender][a] += x; l[msg.sender][b] += y;
        r[a][b] += x; r[b][a] += y;

        emit liquidity_added(msg.sender, a, b, x, y);
    }

    function remove_liquidity(address a, address b, uint256 x, uint256 y) external {
require(l[msg.sender][a] >= x && l[msg.sender][b] >= y, "Insufficient liquidity");

        l[msg.sender][a] -= x;
        l[msg.sender][b] -= y;
        r[a][b] -= x;
        r[b][a] -= y;

        IERC20(a).transfer(msg.sender, x);
        IERC20(b).transfer(msg.sender, y);
    }

    function swap_tokens(address tokenIn, address tokenOut, uint256 amountIn) external {
        require(tokenIn != address(0) && tokenOut != address(0), "Invalid tokens");
        require(amountIn > 0, "Invalid amount");
        require(r[tokenIn][tokenOut] > 0 && r[tokenOut][tokenIn] > 0, "No liquidity");

        uint256 fee_amount = (amountIn * FEE) / DENOMINATOR;
        uint256 amountInAfterFee = amountIn - fee_amount;

        uint256 reserveIn = r[tokenIn][tokenOut];
        uint256 reserveOut = r[tokenOut][tokenIn];


        uint256 amountOut = (amountInAfterFee * reserveOut) / (reserveIn + amountInAfterFee);

        require(amountOut > 0, "Insufficient output");
        require(amountOut < reserveOut, "Insufficient liquidity");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).transfer(msg.sender, amountOut);

        r[tokenIn][tokenOut] += amountInAfterFee;
        r[tokenOut][tokenIn] -= amountOut;
        f[tokenIn] += fee_amount;

        emit swap_event(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    function get_price(address tokenIn, address tokenOut, uint256 amountIn) external view returns (uint256) {
        require(r[tokenIn][tokenOut] > 0 && r[tokenOut][tokenIn] > 0, "No liquidity");

        uint256 fee_amount = (amountIn * FEE) / DENOMINATOR;
        uint256 amountInAfterFee = amountIn - fee_amount;

        uint256 reserveIn = r[tokenIn][tokenOut];
        uint256 reserveOut = r[tokenOut][tokenIn];

        return (amountInAfterFee * reserveOut) / (reserveIn + amountInAfterFee);
    }

function withdraw_fees(address token) external onlyOwner {
        uint256 amount = f[token]; f[token] = 0;
        IERC20(token).transfer(o, amount);
    }

    function emergency_withdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(o, amount);
    }

    function get_reserves(address a, address b) external view returns (uint256, uint256) {
        return (r[a][b], r[b][a]);
    }

    function get_user_liquidity(address user, address token) external view returns (uint256) {
        return l[user][token];
    }
}
