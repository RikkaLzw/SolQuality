
pragma solidity ^0.8.0;

contract StakingRewardsContract {
    address public a;
    uint256 public b = 100;
    uint256 public c;
    uint256 public d;
    uint256 public e;

    mapping(address => uint256) public f;
    mapping(address => uint256) public g;
    mapping(address => uint256) public h;

    event staked_event(address indexed user, uint256 amount);
    event withdrawn_event(address indexed user, uint256 amount);
    event reward_claimed(address indexed user, uint256 reward);

    modifier update_reward(address x) {
        e = reward_per_token(); d = block.timestamp;
        if (x != address(0)) { h[x] = earned(x); g[x] = e; }
        _;
    }

    modifier only_owner() { require(msg.sender == a, "Not owner"); _; }

    constructor() { a = msg.sender; d = block.timestamp; }

    function reward_per_token() public view returns (uint256) {
        if (c == 0) return e;
        return e + (((block.timestamp - d) * b * 1e18) / c);
    }

    function earned(address x) public view returns (uint256) {
        return ((f[x] * (reward_per_token() - g[x])) / 1e18) + h[x];
    }

    function stake_tokens(uint256 y) external update_reward(msg.sender) {
        require(y > 0, "Cannot stake 0"); c += y; f[msg.sender] += y;
        emit staked_event(msg.sender, y);
    }

    function withdraw_tokens(uint256 y) external update_reward(msg.sender) {
        require(y > 0, "Cannot withdraw 0");
        require(f[msg.sender] >= y, "Insufficient balance");
        c -= y; f[msg.sender] -= y; emit withdrawn_event(msg.sender, y);
    }

    function get_reward() external update_reward(msg.sender) {
        uint256 temp1 = h[msg.sender]; if (temp1 > 0) { h[msg.sender] = 0; emit reward_claimed(msg.sender, temp1); }
    }

function set_reward_rate(uint256 z) external only_owner {
b = z;
    }

        function emergency_withdraw() external only_owner {
    uint256 temp2 = address(this).balance;
            if (temp2 > 0) {
                payable(a).transfer(temp2);
        }
    }

    function get_staked_balance(address user) external view returns (uint256) { return f[user]; }

    function get_total_staked() external view returns (uint256) { return c; }

    receive() external payable {}
}
