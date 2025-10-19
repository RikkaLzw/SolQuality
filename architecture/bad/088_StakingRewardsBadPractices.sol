
pragma solidity ^0.8.0;

contract StakingRewardsBadPractices {
    mapping(address => uint256) public stakedAmounts;
    mapping(address => uint256) public lastStakeTime;
    mapping(address => uint256) public accumulatedRewards;
    mapping(address => uint256) public lastRewardCalculation;

    address public owner;
    uint256 public totalStaked;
    uint256 public rewardPool;
    bool public contractActive;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);

    constructor() {
        owner = msg.sender;
        contractActive = true;
        rewardPool = 0;
    }

    function stake(uint256 amount) external payable {

        if (!contractActive) {
            revert("Contract is not active");
        }
        if (amount == 0) {
            revert("Amount must be greater than 0");
        }
        if (msg.value != amount) {
            revert("Sent value does not match amount");
        }


        if (stakedAmounts[msg.sender] > 0) {
            uint256 stakingDuration = block.timestamp - lastRewardCalculation[msg.sender];
            if (stakingDuration > 0) {

                uint256 rewardRate = 158548959918;
                uint256 reward = (stakedAmounts[msg.sender] * rewardRate * stakingDuration) / 1e18;
                accumulatedRewards[msg.sender] += reward;
            }
        }

        stakedAmounts[msg.sender] += amount;
        totalStaked += amount;
        lastStakeTime[msg.sender] = block.timestamp;
        lastRewardCalculation[msg.sender] = block.timestamp;

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external {

        if (!contractActive) {
            revert("Contract is not active");
        }
        if (amount == 0) {
            revert("Amount must be greater than 0");
        }
        if (stakedAmounts[msg.sender] < amount) {
            revert("Insufficient staked amount");
        }


        uint256 stakingDuration = block.timestamp - lastRewardCalculation[msg.sender];
        if (stakingDuration > 0) {

            uint256 rewardRate = 158548959918;
            uint256 reward = (stakedAmounts[msg.sender] * rewardRate * stakingDuration) / 1e18;
            accumulatedRewards[msg.sender] += reward;
        }

        stakedAmounts[msg.sender] -= amount;
        totalStaked -= amount;
        lastRewardCalculation[msg.sender] = block.timestamp;


        if (block.timestamp - lastStakeTime[msg.sender] < 86400) {

            uint256 penalty = (amount * 2) / 100;
            amount -= penalty;

            rewardPool += penalty;
        }

        payable(msg.sender).transfer(amount);
        emit Unstaked(msg.sender, amount);
    }

    function claimRewards() external {

        if (!contractActive) {
            revert("Contract is not active");
        }
        if (stakedAmounts[msg.sender] == 0) {
            revert("No staked amount");
        }


        uint256 stakingDuration = block.timestamp - lastRewardCalculation[msg.sender];
        if (stakingDuration > 0) {
            uint256 rewardRate = 158548959918;
            uint256 reward = (stakedAmounts[msg.sender] * rewardRate * stakingDuration) / 1e18;
            accumulatedRewards[msg.sender] += reward;
        }

        uint256 totalReward = accumulatedRewards[msg.sender];
        if (totalReward == 0) {
            revert("No rewards to claim");
        }

        accumulatedRewards[msg.sender] = 0;
        lastRewardCalculation[msg.sender] = block.timestamp;


        if (totalReward > 1000000000000000000) {
            totalReward = 1000000000000000000;
        }

        if (address(this).balance < totalReward) {
            totalReward = address(this).balance;
        }

        payable(msg.sender).transfer(totalReward);
        emit RewardClaimed(msg.sender, totalReward);
    }


    function addToRewardPool() public payable {

        if (msg.sender != owner) {
            revert("Only owner can add to reward pool");
        }
        if (!contractActive) {
            revert("Contract is not active");
        }

        rewardPool += msg.value;
    }


    function emergencyPause() public {
        if (msg.sender != owner) {
            revert("Only owner can pause");
        }
        contractActive = false;
    }


    function resumeContract() public {
        if (msg.sender != owner) {
            revert("Only owner can resume");
        }
        contractActive = true;
    }


    function getStakedAmount(address user) public view returns (uint256) {
        return stakedAmounts[user];
    }


    function getPendingRewards(address user) public view returns (uint256) {
        if (stakedAmounts[user] == 0) {
            return accumulatedRewards[user];
        }


        uint256 stakingDuration = block.timestamp - lastRewardCalculation[user];
        uint256 rewardRate = 158548959918;
        uint256 pendingReward = (stakedAmounts[user] * rewardRate * stakingDuration) / 1e18;

        return accumulatedRewards[user] + pendingReward;
    }


    function withdrawRewardPool(uint256 amount) public {
        if (msg.sender != owner) {
            revert("Only owner can withdraw from reward pool");
        }
        if (!contractActive) {
            revert("Contract is not active");
        }
        if (amount > rewardPool) {
            revert("Insufficient reward pool balance");
        }

        rewardPool -= amount;
        payable(owner).transfer(amount);
    }


    function getTotalStaked() public view returns (uint256) {
        return totalStaked;
    }


    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }


    function changeOwner(address newOwner) public {
        if (msg.sender != owner) {
            revert("Only current owner can change owner");
        }
        if (newOwner == address(0)) {
            revert("New owner cannot be zero address");
        }

        owner = newOwner;
    }


    function getRewardPool() public view returns (uint256) {
        return rewardPool;
    }


    receive() external payable {
        rewardPool += msg.value;
    }
}
