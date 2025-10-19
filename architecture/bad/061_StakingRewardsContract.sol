
pragma solidity ^0.8.0;

contract StakingRewardsContract {
    address public owner;
    uint256 public totalStaked;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public stakingTimestamp;
    mapping(address => bool) public hasStaked;
    mapping(address => bool) public isStaking;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    constructor() {
        owner = msg.sender;
        rewardRate = 100;
        lastUpdateTime = block.timestamp;
    }

    function stake(uint256 _amount) external payable {

        if (_amount <= 0) {
            revert("Amount must be greater than 0");
        }
        if (msg.value != _amount) {
            revert("Sent value must equal amount");
        }


        uint256 currentTime = block.timestamp;
        if (totalStaked > 0) {
            rewardPerTokenStored = rewardPerTokenStored + (((currentTime - lastUpdateTime) * rewardRate * 1e18) / totalStaked);
        }
        lastUpdateTime = currentTime;

        if (balances[msg.sender] > 0) {
            rewards[msg.sender] = rewards[msg.sender] + ((balances[msg.sender] * (rewardPerTokenStored - userRewardPerTokenPaid[msg.sender])) / 1e18);
        }
        userRewardPerTokenPaid[msg.sender] = rewardPerTokenStored;


        balances[msg.sender] = balances[msg.sender] + _amount;
        totalStaked = totalStaked + _amount;
        stakingTimestamp[msg.sender] = block.timestamp;
        hasStaked[msg.sender] = true;
        isStaking[msg.sender] = true;

        emit Staked(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external {

        if (_amount <= 0) {
            revert("Amount must be greater than 0");
        }
        if (balances[msg.sender] < _amount) {
            revert("Insufficient balance");
        }
        if (block.timestamp < stakingTimestamp[msg.sender] + 86400) {
            revert("Minimum staking period not met");
        }


        uint256 currentTime = block.timestamp;
        if (totalStaked > 0) {
            rewardPerTokenStored = rewardPerTokenStored + (((currentTime - lastUpdateTime) * rewardRate * 1e18) / totalStaked);
        }
        lastUpdateTime = currentTime;

        if (balances[msg.sender] > 0) {
            rewards[msg.sender] = rewards[msg.sender] + ((balances[msg.sender] * (rewardPerTokenStored - userRewardPerTokenPaid[msg.sender])) / 1e18);
        }
        userRewardPerTokenPaid[msg.sender] = rewardPerTokenStored;


        balances[msg.sender] = balances[msg.sender] - _amount;
        totalStaked = totalStaked - _amount;

        if (balances[msg.sender] == 0) {
            isStaking[msg.sender] = false;
        }

        payable(msg.sender).transfer(_amount);

        emit Withdrawn(msg.sender, _amount);
    }

    function claimReward() external {

        if (balances[msg.sender] == 0) {
            revert("No staked amount");
        }
        if (block.timestamp < stakingTimestamp[msg.sender] + 86400) {
            revert("Minimum staking period not met");
        }


        uint256 currentTime = block.timestamp;
        if (totalStaked > 0) {
            rewardPerTokenStored = rewardPerTokenStored + (((currentTime - lastUpdateTime) * rewardRate * 1e18) / totalStaked);
        }
        lastUpdateTime = currentTime;

        if (balances[msg.sender] > 0) {
            rewards[msg.sender] = rewards[msg.sender] + ((balances[msg.sender] * (rewardPerTokenStored - userRewardPerTokenPaid[msg.sender])) / 1e18);
        }
        userRewardPerTokenPaid[msg.sender] = rewardPerTokenStored;

        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            payable(msg.sender).transfer(reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function emergencyWithdraw() external {

        if (balances[msg.sender] == 0) {
            revert("No staked amount");
        }

        uint256 amount = balances[msg.sender];
        balances[msg.sender] = 0;
        totalStaked = totalStaked - amount;
        isStaking[msg.sender] = false;


        rewards[msg.sender] = 0;

        payable(msg.sender).transfer(amount);

        emit Withdrawn(msg.sender, amount);
    }

    function setRewardRate(uint256 _rewardRate) external {

        if (msg.sender != owner) {
            revert("Only owner can call this function");
        }
        if (_rewardRate == 0) {
            revert("Reward rate must be greater than 0");
        }


        uint256 currentTime = block.timestamp;
        if (totalStaked > 0) {
            rewardPerTokenStored = rewardPerTokenStored + (((currentTime - lastUpdateTime) * rewardRate * 1e18) / totalStaked);
        }
        lastUpdateTime = currentTime;

        rewardRate = _rewardRate;
    }

    function addRewardFunds() external payable {

        if (msg.sender != owner) {
            revert("Only owner can call this function");
        }
        if (msg.value == 0) {
            revert("Must send some ETH");
        }


    }

    function getStakerInfo(address _staker) external view returns (uint256, uint256, uint256, bool, bool) {

        uint256 currentRewardPerToken = rewardPerTokenStored;
        if (totalStaked > 0) {
            currentRewardPerToken = currentRewardPerToken + (((block.timestamp - lastUpdateTime) * rewardRate * 1e18) / totalStaked);
        }

        uint256 earnedReward = rewards[_staker];
        if (balances[_staker] > 0) {
            earnedReward = earnedReward + ((balances[_staker] * (currentRewardPerToken - userRewardPerTokenPaid[_staker])) / 1e18);
        }

        return (
            balances[_staker],
            earnedReward,
            stakingTimestamp[_staker],
            hasStaked[_staker],
            isStaking[_staker]
        );
    }

    function getTotalRewards(address _staker) external view returns (uint256) {

        uint256 currentRewardPerToken = rewardPerTokenStored;
        if (totalStaked > 0) {
            currentRewardPerToken = currentRewardPerToken + (((block.timestamp - lastUpdateTime) * rewardRate * 1e18) / totalStaked);
        }

        uint256 earnedReward = rewards[_staker];
        if (balances[_staker] > 0) {
            earnedReward = earnedReward + ((balances[_staker] * (currentRewardPerToken - userRewardPerTokenPaid[_staker])) / 1e18);
        }

        return earnedReward;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function transferOwnership(address _newOwner) external {

        if (msg.sender != owner) {
            revert("Only owner can call this function");
        }
        if (_newOwner == address(0)) {
            revert("New owner cannot be zero address");
        }

        owner = _newOwner;
    }

    function pause() external {

        if (msg.sender != owner) {
            revert("Only owner can call this function");
        }


        rewardRate = 0;
    }

    function unpause() external {

        if (msg.sender != owner) {
            revert("Only owner can call this function");
        }


        rewardRate = 100;
    }
}
