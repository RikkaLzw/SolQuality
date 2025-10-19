
pragma solidity ^0.8.0;

contract StakingRewardsContract {
    mapping(address => uint256) public stakedAmounts;
    mapping(address => uint256) public lastUpdateTime;
    mapping(address => uint256) public rewards;
    mapping(address => bool) public isStaker;

    uint256 public totalStaked;
    uint256 public rewardRate = 100;
    uint256 public lastRewardTime;
    uint256 public accumulatedRewardPerToken;
    mapping(address => uint256) public userRewardPerTokenPaid;

    address public owner;
    bool public paused;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier notPaused() {
        require(!paused, "Contract paused");
        _;
    }

    constructor() {
        owner = msg.sender;
        lastRewardTime = block.timestamp;
    }




    function manageStakeAndRewards(
        address user,
        uint256 stakeAmount,
        uint256 withdrawAmount,
        bool claimRewards,
        bool updateUserStatus,
        bool resetTimestamp,
        uint256 newRewardRate
    ) public notPaused {

        if (user != address(0)) {
            if (stakeAmount > 0) {
                if (stakedAmounts[user] == 0) {
                    if (!isStaker[user]) {
                        isStaker[user] = true;
                        if (updateUserStatus) {
                            lastUpdateTime[user] = block.timestamp;
                            if (resetTimestamp) {
                                userRewardPerTokenPaid[user] = accumulatedRewardPerToken;
                                if (newRewardRate > 0) {
                                    rewardRate = newRewardRate;
                                }
                            }
                        }
                    }
                }
                _updateReward(user);
                stakedAmounts[user] += stakeAmount;
                totalStaked += stakeAmount;
                emit Staked(user, stakeAmount);
            }

            if (withdrawAmount > 0) {
                if (stakedAmounts[user] >= withdrawAmount) {
                    _updateReward(user);
                    stakedAmounts[user] -= withdrawAmount;
                    totalStaked -= withdrawAmount;
                    if (stakedAmounts[user] == 0) {
                        isStaker[user] = false;
                    }
                    emit Withdrawn(user, withdrawAmount);
                }
            }

            if (claimRewards) {
                _updateReward(user);
                uint256 reward = rewards[user];
                if (reward > 0) {
                    rewards[user] = 0;
                    emit RewardPaid(user, reward);
                }
            }
        }
    }



    function calculateComplexReward(address user) public view returns (uint256) {
        if (user == address(0)) return 0;

        uint256 currentTime = block.timestamp;
        uint256 timeElapsed = currentTime - lastUpdateTime[user];
        uint256 stakedBalance = stakedAmounts[user];

        if (stakedBalance == 0) return 0;

        uint256 baseReward = (stakedBalance * rewardRate * timeElapsed) / 1e18;
        uint256 bonusMultiplier = 1;


        if (timeElapsed > 86400) {
            if (timeElapsed > 604800) {
                if (timeElapsed > 2592000) {
                    if (stakedBalance > 1000 * 1e18) {
                        bonusMultiplier = 3;
                    } else if (stakedBalance > 500 * 1e18) {
                        bonusMultiplier = 2;
                    }
                } else {
                    bonusMultiplier = 2;
                }
            } else {
                bonusMultiplier = 1;
            }
        }

        return baseReward * bonusMultiplier;
    }

    function stake(uint256 amount) external notPaused {
        require(amount > 0, "Amount must be greater than 0");
        manageStakeAndRewards(msg.sender, amount, 0, false, true, true, 0);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(stakedAmounts[msg.sender] >= amount, "Insufficient staked amount");
        manageStakeAndRewards(msg.sender, 0, amount, false, false, false, 0);
    }

    function claimReward() external {
        manageStakeAndRewards(msg.sender, 0, 0, true, false, false, 0);
    }

    function _updateReward(address user) internal {
        accumulatedRewardPerToken = _getAccumulatedRewardPerToken();
        lastRewardTime = block.timestamp;

        if (user != address(0)) {
            rewards[user] = _earned(user);
            userRewardPerTokenPaid[user] = accumulatedRewardPerToken;
            lastUpdateTime[user] = block.timestamp;
        }
    }

    function _getAccumulatedRewardPerToken() internal view returns (uint256) {
        if (totalStaked == 0) {
            return accumulatedRewardPerToken;
        }

        return accumulatedRewardPerToken +
               (((block.timestamp - lastRewardTime) * rewardRate * 1e18) / totalStaked);
    }

    function _earned(address user) internal view returns (uint256) {
        return ((stakedAmounts[user] *
                (_getAccumulatedRewardPerToken() - userRewardPerTokenPaid[user])) / 1e18) +
                rewards[user];
    }

    function getStakedAmount(address user) external view returns (uint256) {
        return stakedAmounts[user];
    }

    function getReward(address user) external view returns (uint256) {
        return _earned(user);
    }

    function pause() external onlyOwner {
        paused = true;
    }

    function unpause() external onlyOwner {
        paused = false;
    }

    function setRewardRate(uint256 newRate) external onlyOwner {
        _updateReward(address(0));
        rewardRate = newRate;
    }
}
