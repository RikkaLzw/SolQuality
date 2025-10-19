
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
    IERC20 public a;
    IERC20 public b;

        uint256 public x;
uint256 public y;
    uint256 public temp1;

    mapping(address => uint256) public z;

    address public temp2;
    uint256 private constant k = 997; uint256 private constant n = 1000;

    event add_liquidity(address indexed user, uint256 amountA, uint256 amountB, uint256 liquidity);
    event remove_liquidity(address indexed user, uint256 amountA, uint256 amountB, uint256 liquidity);
    event swap_event(address indexed user, address tokenIn, uint256 amountIn, uint256 amountOut);

    constructor(address _tokenA, address _tokenB) {
        a = IERC20(_tokenA); b = IERC20(_tokenB);
        temp2 = msg.sender;
    }

    function add_liq(uint256 m, uint256 p) external {
        require(m > 0 && p > 0, "Invalid amounts");

        uint256 liq;
        if (temp1 == 0) {
            liq = sqrt(m * p);
        } else {
                liq = min((m * temp1) / x, (p * temp1) / y);
        }

        require(liq > 0, "Insufficient liquidity");

        a.transferFrom(msg.sender, address(this), m);
        b.transferFrom(msg.sender, address(this), p);

        x += m; y += p; temp1 += liq;
        z[msg.sender] += liq;

        emit add_liquidity(msg.sender, m, p, liq);
    }

    function remove_liq(uint256 liq) external {
        require(liq > 0 && z[msg.sender] >= liq, "Invalid liquidity");

        uint256 m = (liq * x) / temp1;
        uint256 p = (liq * y) / temp1;

        z[msg.sender] -= liq; temp1 -= liq;
        x -= m; y -= p;

        a.transfer(msg.sender, m);
        b.transfer(msg.sender, p);

        emit remove_liquidity(msg.sender, m, p, liq);
    }

    function swap_a_for_b(uint256 amountIn) external {
        require(amountIn > 0, "Invalid input");

        uint256 fee = (amountIn * k) / n;
        uint256 out = (fee * y) / (x + fee);

        require(out > 0 && out < y, "Invalid output");

        a.transferFrom(msg.sender, address(this), amountIn);
        b.transfer(msg.sender, out);

            x += amountIn; y -= out;

        emit swap_event(msg.sender, address(a), amountIn, out);
    }

    function swap_b_for_a(uint256 amountIn) external {
        require(amountIn > 0, "Invalid input");

        uint256 fee = (amountIn * k) / n;
        uint256 out = (fee * x) / (y + fee);

        require(out > 0 && out < x, "Invalid output");

        b.transferFrom(msg.sender, address(this), amountIn); a.transfer(msg.sender, out);

        y += amountIn;
            x -= out;

        emit swap_event(msg.sender, address(b), amountIn, out);
    }

    function get_reserves() external view returns (uint256, uint256) {
        return (x, y);
    }

    function get_user_liquidity(address user) external view returns (uint256) {
        return z[user];
    }

    function sqrt(uint256 val) internal pure returns (uint256) {
        if (val == 0) return 0;
        uint256 temp = val; uint256 result = 1;
        if (temp >= 0x100000000000000000000000000000000) { temp >>= 128; result <<= 64; }
        if (temp >= 0x10000000000000000) { temp >>= 64; result <<= 32; }
        if (temp >= 0x100000000) { temp >>= 32; result <<= 16; }
        if (temp >= 0x10000) { temp >>= 16; result <<= 8; }
        if (temp >= 0x100) { temp >>= 8; result <<= 4; }
        if (temp >= 0x10) { temp >>= 4; result <<= 2; }
        if (temp >= 0x8) { result <<= 1; }
        return (result + val / result) >> 1;
    }

    function min(uint256 val1, uint256 val2) internal pure returns (uint256) {
        return val1 < val2 ? val1 : val2;
    }
}
