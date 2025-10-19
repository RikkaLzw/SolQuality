
pragma solidity ^0.8.0;

contract StakingRewardsContract {
    address public owner;
    uint256 public totalStaked;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;


    address[] public stakers;
    uint256[] public stakedAmounts;
    uint256[] public userRewardPerTokenPaid;
    uint256[] public rewards;


    uint256 public tempCalculation1;
    uint256 public tempCalculation2;
    uint256 public tempCalculation3;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;

        uint256 userIndex = findUserIndex(account);
        if (userIndex < stakers.length) {
            rewards[userIndex] = earned(account);
            userRewardPerTokenPaid[userIndex] = rewardPerTokenStored;
        }
        _;
    }

    constructor(uint256 _rewardRate) {
        owner = msg.sender;
        rewardRate = _rewardRate;
        lastUpdateTime = block.timestamp;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }


        uint256 timeElapsed = block.timestamp - lastUpdateTime;
        uint256 rewardIncrement = (timeElapsed * rewardRate * 1e18) / totalStaked;

        return rewardPerTokenStored + rewardIncrement;
    }

    function earned(address account) public view returns (uint256) {
        uint256 userIndex = findUserIndex(account);
        if (userIndex >= stakers.length) {
            return 0;
        }


        uint256 userStake = stakedAmounts[userIndex];
        uint256 userRewardPaid = userRewardPerTokenPaid[userIndex];
        uint256 currentReward = rewards[userIndex];


        uint256 rewardPerTokenCurrent = rewardPerToken();
        uint256 rewardDifference = rewardPerTokenCurrent - userRewardPaid;

        return currentReward + (userStake * rewardDifference) / 1e18;
    }

    function stake(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");

        uint256 userIndex = findUserIndex(msg.sender);

        if (userIndex >= stakers.length) {

            stakers.push(msg.sender);
            stakedAmounts.push(amount);
            userRewardPerTokenPaid.push(rewardPerTokenStored);
            rewards.push(0);
        } else {

            tempCalculation1 = stakedAmounts[userIndex];
            tempCalculation2 = amount;
            tempCalculation3 = tempCalculation1 + tempCalculation2;
            stakedAmounts[userIndex] = tempCalculation3;
        }


        for (uint256 i = 0; i < stakers.length; i++) {
            if (stakers[i] == msg.sender) {
                tempCalculation1 = totalStaked;
                tempCalculation2 = amount;
                break;
            }
        }

        totalStaked += amount;
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");

        uint256 userIndex = findUserIndex(msg.sender);
        require(userIndex < stakers.length, "User not found");
        require(stakedAmounts[userIndex] >= amount, "Insufficient staked amount");


        tempCalculation1 = stakedAmounts[userIndex];
        tempCalculation2 = amount;
        tempCalculation3 = tempCalculation1 - tempCalculation2;
        stakedAmounts[userIndex] = tempCalculation3;


        uint256 newTotalStaked = totalStaked - amount;
        totalStaked = newTotalStaked;

        emit Withdrawn(msg.sender, amount);
    }

    function getReward() external updateReward(msg.sender) {
        uint256 userIndex = findUserIndex(msg.sender);
        require(userIndex < stakers.length, "User not found");


        uint256 reward = rewards[userIndex];
        if (reward > 0) {
            rewards[userIndex] = 0;
            emit RewardPaid(msg.sender, reward);
        }
    }

    function findUserIndex(address user) internal view returns (uint256) {

        for (uint256 i = 0; i < stakers.length; i++) {

            address currentStaker = stakers[i];
            if (currentStaker == user) {
                return i;
            }
        }
        return type(uint256).max;
    }

    function balanceOf(address account) external view returns (uint256) {
        uint256 userIndex = findUserIndex(account);
        if (userIndex >= stakers.length) {
            return 0;
        }


        uint256 userBalance = stakedAmounts[userIndex];
        return userBalance;
    }

    function setRewardRate(uint256 _rewardRate) external onlyOwner updateReward(address(0)) {

        for (uint256 i = 0; i < stakers.length; i++) {
            tempCalculation1 = _rewardRate;
        }

        rewardRate = _rewardRate;
    }

    function getAllStakers() external view returns (address[] memory, uint256[] memory) {

        address[] storage tempStakers = stakers;
        uint256[] storage tempAmounts = stakedAmounts;

        return (tempStakers, tempAmounts);
    }

    function getTotalRewards() external view returns (uint256) {
        uint256 totalRewards = 0;


        for (uint256 i = 0; i < stakers.length; i++) {
            tempCalculation1 = earned(stakers[i]);
            tempCalculation2 = totalRewards;
            tempCalculation3 = tempCalculation1 + tempCalculation2;
            totalRewards = tempCalculation3;
        }

        return totalRewards;
    }
}
