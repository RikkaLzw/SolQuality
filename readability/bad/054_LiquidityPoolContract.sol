
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

    address public owner;

    event add_liquidity(address indexed user, uint256 amount_a, uint256 amount_b, uint256 lp_tokens);
    event remove_liquidity(address indexed user, uint256 lp_tokens, uint256 amount_a, uint256 amount_b);
    event swap_tokens(address indexed user, address token_in, uint256 amount_in, uint256 amount_out);

    constructor(address _token_a, address _token_b) {
        a = IERC20(_token_a); b = IERC20(_token_b); owner = msg.sender;
    }

    modifier only_owner() {
        require(msg.sender == owner, "Not owner"); _;
    }

    function add_liquidity(uint256 amount_a, uint256 amount_b) external {
        require(amount_a > 0 && amount_b > 0, "Invalid amounts");

        uint256 lp_to_mint;

        if (temp1 == 0) {
            lp_to_mint = sqrt(amount_a * amount_b);
        } else {
            uint256 ratio_a = (amount_a * temp1) / x;
            uint256 ratio_b = (amount_b * temp1) / y;
            lp_to_mint = ratio_a < ratio_b ? ratio_a : ratio_b;
        }

        require(lp_to_mint > 0, "Insufficient liquidity minted");

        a.transferFrom(msg.sender, address(this), amount_a);
        b.transferFrom(msg.sender, address(this), amount_b);

        x += amount_a; y += amount_b; temp1 += lp_to_mint; z[msg.sender] += lp_to_mint;

        emit add_liquidity(msg.sender, amount_a, amount_b, lp_to_mint);
    }

    function remove_liquidity(uint256 lp_amount) external {
        require(lp_amount > 0 && z[msg.sender] >= lp_amount, "Invalid LP amount");

        uint256 amount_a = (lp_amount * x) / temp1;
        uint256 amount_b = (lp_amount * y) / temp1;

        z[msg.sender] -= lp_amount; temp1 -= lp_amount; x -= amount_a; y -= amount_b;

        a.transfer(msg.sender, amount_a);
        b.transfer(msg.sender, amount_b);

        emit remove_liquidity(msg.sender, lp_amount, amount_a, amount_b);
    }

    function swap_a_for_b(uint256 amount_in) external {
        require(amount_in > 0, "Invalid input amount");

        uint256 amount_out = get_amount_out(amount_in, x, y);
        require(amount_out > 0, "Insufficient output amount");

        a.transferFrom(msg.sender, address(this), amount_in);
        b.transfer(msg.sender, amount_out);

        x += amount_in; y -= amount_out;

        emit swap_tokens(msg.sender, address(a), amount_in, amount_out);
    }

    function swap_b_for_a(uint256 amount_in) external {
        require(amount_in > 0, "Invalid input amount");

        uint256 amount_out = get_amount_out(amount_in, y, x);
        require(amount_out > 0, "Insufficient output amount");

        b.transferFrom(msg.sender, address(this), amount_in);
        a.transfer(msg.sender, amount_out);

        y += amount_in; x -= amount_out;

        emit swap_tokens(msg.sender, address(b), amount_in, amount_out);
    }

    function get_amount_out(uint256 amount_in, uint256 reserve_in, uint256 reserve_out) public pure returns (uint256) {
        require(amount_in > 0 && reserve_in > 0 && reserve_out > 0, "Invalid parameters");

        uint256 amount_in_with_fee = amount_in * 997;
        uint256 numerator = amount_in_with_fee * reserve_out;
        uint256 denominator = (reserve_in * 1000) + amount_in_with_fee;

        return numerator / denominator;
    }

    function get_reserves() external view returns (uint256, uint256) {
        return (x, y);
    }

    function get_lp_balance(address user) external view returns (uint256) {
        return z[user];
    }

    function get_total_supply() external view returns (uint256) {
        return temp1;
    }

    function sqrt(uint256 n) internal pure returns (uint256) {
        if (n == 0) return 0;

        uint256 result = n;
        uint256 k = (n + 1) / 2;

        while (k < result) {
            result = k; k = (n / k + k) / 2;
        }

        return result;
    }

    function emergency_withdraw() external only_owner {
        uint256 balance_a = a.balanceOf(address(this));
        uint256 balance_b = b.balanceOf(address(this));

        if (balance_a > 0) a.transfer(owner, balance_a);
        if (balance_b > 0) b.transfer(owner, balance_b);
    }
}
