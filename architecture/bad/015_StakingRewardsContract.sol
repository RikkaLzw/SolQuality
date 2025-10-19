
pragma solidity ^0.8.0;

contract StakingRewardsContract {
    address public owner;
    mapping(address => uint256) public stakedBalances;
    mapping(address => uint256) public rewardBalances;
    mapping(address => uint256) public lastStakeTime;
    mapping(address => uint256) public lastRewardTime;
    uint256 public totalStaked;
    uint256 public rewardPool;
    bool public contractActive;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardPoolFunded(uint256 amount);

    constructor() {
        owner = msg.sender;
        contractActive = true;
    }

    function stake(uint256 amount) external payable {

        if (!contractActive) {
            revert("Contract is not active");
        }
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }


        if (amount == 0) {
            revert("Amount must be greater than 0");
        }
        if (msg.value != amount) {
            revert("Sent value does not match amount");
        }


        if (stakedBalances[msg.sender] > 0) {
            uint256 timeStaked = block.timestamp - lastRewardTime[msg.sender];
            if (timeStaked > 0) {
                uint256 reward = (stakedBalances[msg.sender] * timeStaked * 5) / (365 * 24 * 3600 * 100);
                rewardBalances[msg.sender] += reward;
            }
        }

        stakedBalances[msg.sender] += amount;
        totalStaked += amount;
        lastStakeTime[msg.sender] = block.timestamp;
        lastRewardTime[msg.sender] = block.timestamp;

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external {

        if (!contractActive) {
            revert("Contract is not active");
        }
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }


        if (stakedBalances[msg.sender] < amount) {
            revert("Insufficient staked balance");
        }
        if (amount == 0) {
            revert("Amount must be greater than 0");
        }


        if (block.timestamp - lastStakeTime[msg.sender] < 604800) {
            revert("Minimum stake period not met");
        }


        uint256 timeStaked = block.timestamp - lastRewardTime[msg.sender];
        if (timeStaked > 0) {
            uint256 reward = (stakedBalances[msg.sender] * timeStaked * 5) / (365 * 24 * 3600 * 100);
            rewardBalances[msg.sender] += reward;
        }

        stakedBalances[msg.sender] -= amount;
        totalStaked -= amount;
        lastRewardTime[msg.sender] = block.timestamp;


        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) {
            revert("Transfer failed");
        }

        emit Unstaked(msg.sender, amount);
    }

    function claimRewards() external {

        if (!contractActive) {
            revert("Contract is not active");
        }
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }


        uint256 timeStaked = block.timestamp - lastRewardTime[msg.sender];
        if (timeStaked > 0 && stakedBalances[msg.sender] > 0) {
            uint256 newReward = (stakedBalances[msg.sender] * timeStaked * 5) / (365 * 24 * 3600 * 100);
            rewardBalances[msg.sender] += newReward;
        }

        uint256 totalReward = rewardBalances[msg.sender];
        if (totalReward == 0) {
            revert("No rewards to claim");
        }


        if (rewardPool < totalReward) {
            revert("Insufficient reward pool");
        }

        rewardBalances[msg.sender] = 0;
        rewardPool -= totalReward;
        lastRewardTime[msg.sender] = block.timestamp;


        (bool success, ) = msg.sender.call{value: totalReward}("");
        if (!success) {
            revert("Transfer failed");
        }

        emit RewardClaimed(msg.sender, totalReward);
    }

    function fundRewardPool() external payable {

        if (!contractActive) {
            revert("Contract is not active");
        }
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }


        if (msg.value == 0) {
            revert("Amount must be greater than 0");
        }

        rewardPool += msg.value;
        emit RewardPoolFunded(msg.value);
    }

    function getStakedBalance(address user) external view returns (uint256) {
        return stakedBalances[user];
    }

    function getPendingRewards(address user) external view returns (uint256) {
        uint256 currentRewards = rewardBalances[user];

        if (stakedBalances[user] > 0) {
            uint256 timeStaked = block.timestamp - lastRewardTime[user];
            if (timeStaked > 0) {
                uint256 newReward = (stakedBalances[user] * timeStaked * 5) / (365 * 24 * 3600 * 100);
                currentRewards += newReward;
            }
        }

        return currentRewards;
    }

    function emergencyWithdraw() external {

        if (!contractActive) {
            revert("Contract is not active");
        }
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }


        if (stakedBalances[msg.sender] == 0) {
            revert("No staked balance");
        }

        uint256 amount = stakedBalances[msg.sender];
        stakedBalances[msg.sender] = 0;
        totalStaked -= amount;


        rewardBalances[msg.sender] = 0;
        lastRewardTime[msg.sender] = block.timestamp;


        uint256 fee = (amount * 10) / 100;
        uint256 withdrawAmount = amount - fee;


        (bool success, ) = msg.sender.call{value: withdrawAmount}("");
        if (!success) {
            revert("Transfer failed");
        }

        emit Unstaked(msg.sender, withdrawAmount);
    }

    function setContractStatus(bool status) external {
        if (msg.sender != owner) {
            revert("Only owner can call this function");
        }
        contractActive = status;
    }

    function ownerWithdrawFees() external {
        if (msg.sender != owner) {
            revert("Only owner can call this function");
        }

        uint256 contractBalance = address(this).balance;
        uint256 lockedFunds = totalStaked + rewardPool;

        if (contractBalance <= lockedFunds) {
            revert("No fees to withdraw");
        }

        uint256 fees = contractBalance - lockedFunds;

        (bool success, ) = owner.call{value: fees}("");
        if (!success) {
            revert("Transfer failed");
        }
    }

    function transferOwnership(address newOwner) external {
        if (msg.sender != owner) {
            revert("Only owner can call this function");
        }
        if (newOwner == address(0)) {
            revert("Invalid new owner address");
        }
        owner = newOwner;
    }

    function getContractInfo() external view returns (
        uint256 _totalStaked,
        uint256 _rewardPool,
        uint256 _contractBalance,
        bool _isActive
    ) {
        return (
            totalStaked,
            rewardPool,
            address(this).balance,
            contractActive
        );
    }

    receive() external payable {
        rewardPool += msg.value;
        emit RewardPoolFunded(msg.value);
    }

    fallback() external payable {
        revert("Function not found");
    }
}
