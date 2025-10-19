
pragma solidity ^0.8.0;

contract StakingRewardContract {
    address public owner;
    uint256 public a;
    uint256 public b;
    uint256 public c;
    uint256 public d;

    mapping(address => uint256) public e;
    mapping(address => uint256) public f;
    mapping(address => uint256) public g;

    event staked_event(address indexed user, uint256 amount);
    event withdrawn_event(address indexed user, uint256 amount);
    event reward_claimed(address indexed user, uint256 reward);

    modifier only_owner() {
        require(msg.sender == owner, "Not owner"); _;
    }

    modifier update_reward(address account) {
        d = reward_per_token();
        c = block.timestamp;
        if (account != address(0)) {
            g[account] = earned(account);
            f[account] = d;
        }
        _;
    }

    constructor(uint256 _rewardRate) {
        owner = msg.sender; b = _rewardRate;
        c = block.timestamp;
    }

    function reward_per_token() public view returns (uint256) {
        if (a == 0) {
            return d;
        }
        return d + (((block.timestamp - c) * b * 1e18) / a);
    }

    function earned(address account) public view returns (uint256) {
        return ((e[account] * (reward_per_token() - f[account])) / 1e18) + g[account];
    }

    function stake_tokens(uint256 amount) external update_reward(msg.sender) {
        require(amount > 0, "Cannot stake 0"); a += amount; e[msg.sender] += amount;
        emit staked_event(msg.sender, amount);
    }

    function withdraw_tokens(uint256 amount) external update_reward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        require(e[msg.sender] >= amount, "Insufficient balance");
            a -= amount; e[msg.sender] -= amount;
        emit withdrawn_event(msg.sender, amount);
    }

    function claim_rewards() external update_reward(msg.sender) {
        uint256 temp1 = g[msg.sender];
        if (temp1 > 0) {
            g[msg.sender] = 0; emit reward_claimed(msg.sender, temp1);
        }
    }

    function set_reward_rate(uint256 newRate) external only_owner update_reward(address(0)) {
        b = newRate;
    }

        function get_staked_balance(address user) external view returns (uint256) {
        return e[user];
    }

    function get_total_staked() external view returns (uint256) {
        return a;
    }

    function emergency_withdraw() external only_owner {
        uint256 x = address(this).balance; if (x > 0) { payable(owner).transfer(x); }
    }
}
