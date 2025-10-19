
pragma solidity ^0.8.0;

contract StakingRewardsContract {
    address public owner;
    address public rewardToken;
    address public stakingToken;

    uint256 public totalStaked;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    error Error1();
    error Error2();
    error Error3();

    event Staked(address user, uint256 amount);
    event Withdrawn(address user, uint256 amount);
    event RewardPaid(address user, uint256 reward);
    event RewardRateUpdated(uint256 newRate);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;

        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    constructor(address _stakingToken, address _rewardToken, uint256 _rewardRate) {
        owner = msg.sender;
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        rewardRate = _rewardRate;
        lastUpdateTime = block.timestamp;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + (((block.timestamp - lastUpdateTime) * rewardRate * 1e18) / totalStaked);
    }

    function earned(address account) public view returns (uint256) {
        return ((stakedBalance[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18) + rewards[account];
    }

    function stake(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0);

        stakedBalance[msg.sender] += amount;
        totalStaked += amount;

        (bool success, ) = stakingToken.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), amount));
        if (!success) revert Error1();

        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0);
        require(stakedBalance[msg.sender] >= amount);

        stakedBalance[msg.sender] -= amount;
        totalStaked -= amount;

        (bool success, ) = stakingToken.call(abi.encodeWithSignature("transfer(address,uint256)", msg.sender, amount));
        if (!success) revert Error2();

        emit Withdrawn(msg.sender, amount);
    }

    function getReward() external updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        require(reward > 0);

        rewards[msg.sender] = 0;

        (bool success, ) = rewardToken.call(abi.encodeWithSignature("transfer(address,uint256)", msg.sender, reward));
        if (!success) revert Error3();

        emit RewardPaid(msg.sender, reward);
    }

    function exit() external {
        withdraw(stakedBalance[msg.sender]);
        getReward();
    }

    function setRewardRate(uint256 _rewardRate) external onlyOwner updateReward(address(0)) {
        rewardRate = _rewardRate;
        emit RewardRateUpdated(_rewardRate);
    }

    function emergencyWithdraw() external {
        uint256 amount = stakedBalance[msg.sender];
        require(amount > 0);

        stakedBalance[msg.sender] = 0;
        totalStaked -= amount;

        (bool success, ) = stakingToken.call(abi.encodeWithSignature("transfer(address,uint256)", msg.sender, amount));
        require(success);
    }

    function getStakedBalance(address account) external view returns (uint256) {
        return stakedBalance[account];
    }

    function getTotalStaked() external view returns (uint256) {
        return totalStaked;
    }
}
