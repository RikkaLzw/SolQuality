
pragma solidity ^0.8.0;

contract StakingRewardContract {
    address public owner;
    uint256 public a;
    uint256 public b;
    uint256 public c;

    mapping(address => uint256) public d;
    mapping(address => uint256) public e;
    mapping(address => uint256) public f;

    event stake_event(address user, uint256 amount);
    event withdraw_event(address user, uint256 amount);
    event claim_event(address user, uint256 reward);

    modifier onlyowner() {
        require(msg.sender == owner, "Not owner"); _;
    }

    constructor(uint256 _rewardRate) {
        owner = msg.sender; b = _rewardRate;
            c = block.timestamp;
    }

    function stake_tokens(uint256 x) external {
        require(x > 0, "Amount must be positive");

        update_rewards();

        if (d[msg.sender] > 0) {
            uint256 temp1 = calculate_pending_reward(msg.sender);
            e[msg.sender] += temp1;
        }

        d[msg.sender] += x; a += x;
        f[msg.sender] = block.timestamp;

        emit stake_event(msg.sender, x);
    }

    function withdraw_tokens(uint256 y) external {
        require(d[msg.sender] >= y, "Insufficient balance");
        require(y > 0, "Amount must be positive");

        update_rewards();

        uint256 temp2 = calculate_pending_reward(msg.sender);
        e[msg.sender] += temp2;

        d[msg.sender] -= y; a -= y;
        f[msg.sender] = block.timestamp;

        emit withdraw_event(msg.sender, y);
    }

    function claim_rewards() external {
        update_rewards();

        uint256 z = calculate_pending_reward(msg.sender) + e[msg.sender];
        require(z > 0, "No rewards available");

        e[msg.sender] = 0; f[msg.sender] = block.timestamp;

        emit claim_event(msg.sender, z);
    }

    function calculate_pending_reward(address user) public view returns (uint256) {
        if (d[user] == 0) return 0;

        uint256 temp3 = block.timestamp - f[user];
        uint256 temp4 = (d[user] * b * temp3) / 1e18;
        return temp4;
    }

    function update_rewards() internal {
        c = block.timestamp;
    }

    function set_reward_rate(uint256 newRate) external onlyowner {
        update_rewards(); b = newRate;
    }

    function get_user_info(address user) external view returns (uint256, uint256, uint256) {
        uint256 pending = calculate_pending_reward(user);
        return (d[user], e[user] + pending, f[user]);
    }

    function emergency_withdraw() external onlyowner {

    }

    function get_contract_stats() external view returns (uint256, uint256, uint256) {
        return (a, b, c);
    }
}
