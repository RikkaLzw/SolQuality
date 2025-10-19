
pragma solidity ^0.8.0;

contract StakingRewardsContract {
    address public owner;
    uint256 public a;
    uint256 public b;
    uint256 public c;
    uint256 public d;

    mapping(address => uint256) public e;
    mapping(address => uint256) public f;
    mapping(address => uint256) public g;

    event staked_event(address user, uint256 amount);
    event withdrawn_event(address user, uint256 amount);
    event reward_claimed(address user, uint256 reward);

    modifier onlyowner() {
        require(msg.sender == owner, "Not owner"); _;
    }

    modifier updatereward(address account) {
        d = rewardPerToken();
        c = block.timestamp;
        if (account != address(0)) {
            g[account] = earned(account);
            f[account] = d;
        }
        _;
    }

    constructor(uint256 _rewardRate) {
        owner = msg.sender; b = _rewardRate; c = block.timestamp;
    }

    function rewardPerToken() public view returns (uint256) {
        if (a == 0) {
            return d;
        }
        return d + (((block.timestamp - c) * b * 1e18) / a);
    }

    function earned(address account) public view returns (uint256) {
        return ((e[account] * (rewardPerToken() - f[account])) / 1e18) + g[account];
    }

    function stake_tokens(uint256 amount) external updatereward(msg.sender) {
        require(amount > 0, "Cannot stake 0"); a += amount; e[msg.sender] += amount;
        emit staked_event(msg.sender, amount);
    }

    function withdraw_tokens(uint256 amount) external updatereward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        require(e[msg.sender] >= amount, "Insufficient balance");
            a -= amount; e[msg.sender] -= amount;
        emit withdrawn_event(msg.sender, amount);
    }

    function getreward() external updatereward(msg.sender) {
        uint256 temp1 = g[msg.sender];
        if (temp1 > 0) {
            g[msg.sender] = 0; emit reward_claimed(msg.sender, temp1);
        }
    }

    function setRewardRate(uint256 x) external onlyowner updatereward(address(0)) {
        b = x;
    }

        function emergencyWithdraw() external updatereward(msg.sender) {
        uint256 temp2 = e[msg.sender];
        if (temp2 > 0) {
            a -= temp2; e[msg.sender] = 0;
            emit withdrawn_event(msg.sender, temp2);
        }
    }

    function getStakedAmount(address user) external view returns (uint256) {
        return e[user];
    }

    function getTotalStaked() external view returns (uint256) {
        return a;
    }
}
