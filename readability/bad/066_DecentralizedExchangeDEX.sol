
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

    event swap_executed(address indexed u, address t1, address t2, uint256 a1, uint256 a2);
    event liquidity_added(address indexed p, address t1, address t2, uint256 a1, uint256 a2);

    modifier only_owner() {
        require(msg.sender == o, "Not owner"); _;
    }

    constructor() { o = msg.sender; }

    function add_liquidity(address t1, address t2, uint256 a1, uint256 a2) external {
        require(t1 != t2, "Same token"); require(a1 > 0 && a2 > 0, "Invalid amounts");

        IERC20(t1).transferFrom(msg.sender, address(this), a1);
        IERC20(t2).transferFrom(msg.sender, address(this), a2);

        l[msg.sender][t1] += a1; l[msg.sender][t2] += a2;
        r[t1][t2] += a1; r[t2][t1] += a2;

        emit liquidity_added(msg.sender, t1, t2, a1, a2);
    }

    function remove_liquidity(address t1, address t2, uint256 a1, uint256 a2) external {
        require(l[msg.sender][t1] >= a1, "Insufficient liquidity");
        require(l[msg.sender][t2] >= a2, "Insufficient liquidity");

        l[msg.sender][t1] -= a1; l[msg.sender][t2] -= a2;
        r[t1][t2] -= a1; r[t2][t1] -= a2;

        IERC20(t1).transfer(msg.sender, a1);
        IERC20(t2).transfer(msg.sender, a2);
    }

    function swap_tokens(address t1, address t2, uint256 a) external {
        require(t1 != t2, "Same token"); require(a > 0, "Invalid amount");
        require(r[t1][t2] > 0 && r[t2][t1] > 0, "No liquidity");

        uint256 x = r[t1][t2]; uint256 y = r[t2][t1];
        uint256 temp1 = a * (DENOMINATOR - FEE) / DENOMINATOR;
        uint256 b = (y * temp1) / (x + temp1);

        require(b > 0, "Invalid output");

        IERC20(t1).transferFrom(msg.sender, address(this), a);
        IERC20(t2).transfer(msg.sender, b);

        r[t1][t2] += a; r[t2][t1] -= b;
        f[t1] += a - temp1;

        emit swap_executed(msg.sender, t1, t2, a, b);
    }

    function get_price(address t1, address t2, uint256 a) external view returns (uint256) {
        if (r[t1][t2] == 0 || r[t2][t1] == 0) return 0;

        uint256 x = r[t1][t2]; uint256 y = r[t2][t1];
        uint256 temp2 = a * (DENOMINATOR - FEE) / DENOMINATOR;
        return (y * temp2) / (x + temp2);
    }

        function withdraw_fees(address t) external only_owner {
        uint256 temp3 = f[t]; f[t] = 0;
        IERC20(t).transfer(o, temp3);
    }

    function emergency_withdraw(address t, uint256 a) external only_owner {
        IERC20(t).transfer(o, a);
    }

    function get_reserves(address t1, address t2) external view returns (uint256, uint256) {
        return (r[t1][t2], r[t2][t1]);
    }

    function get_user_liquidity(address u, address t) external view returns (uint256) {
        return l[u][t];
    }
}
