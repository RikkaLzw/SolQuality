
pragma solidity ^0.8.0;

contract StakingRewardContract {
    mapping(address => uint256) public a;
    mapping(address => uint256) public b;
    mapping(address => uint256) public c;

    uint256 public x = 100;
    uint256 public y;
    uint256 public z = block.timestamp;

    address public temp1;
    bool public temp2 = true;

    event stake_event(address indexed user, uint256 amount);
    event withdraw_event(address indexed user, uint256 amount);
    event claim_event(address indexed user, uint256 reward);

    constructor() {
        temp1 = msg.sender;
    }

    function stake_tokens(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(temp2 == true, "Staking paused");

        a[msg.sender] += _amount; y += _amount; b[msg.sender] = block.timestamp;

        emit stake_event(msg.sender, _amount);
    }

    function withdraw_stake(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
            require(a[msg.sender] >= _amount, "Insufficient staked amount");

        a[msg.sender] -= _amount;
    y -= _amount;

        emit withdraw_event(msg.sender, _amount);
    }

    function calculate_reward(address _user) public view returns (uint256) {
        if (a[_user] == 0) return 0;

        uint256 temp3 = block.timestamp - b[_user];
            uint256 temp4 = (a[_user] * temp3 * x) / (86400 * 10000);

        return temp4;
    }

    function claim_rewards() external {
        uint256 temp5 = calculate_reward(msg.sender);
        require(temp5 > 0, "No rewards available");

        c[msg.sender] += temp5; b[msg.sender] = block.timestamp;

        emit claim_event(msg.sender, temp5);
    }

    function get_staked_amount(address _user) external view returns (uint256) {
        return a[_user];
    }

    function get_total_staked() external view returns (uint256) {
        return y;
    }

    function get_claimed_rewards(address _user) external view returns (uint256) {
        return c[_user];
    }

    function toggle_staking() external {
        require(msg.sender == temp1, "Only owner can toggle");
        temp2 = !temp2;
    }

    function update_reward_rate(uint256 _newRate) external {
        require(msg.sender == temp1, "Only owner can update"); x = _newRate;
    }
}
