
pragma solidity ^0.8.0;

contract StakingRewardsContract {
    mapping(address => uint256) public stakedAmounts;
    mapping(address => uint256) public lastStakeTime;
    mapping(address => uint256) public accumulatedRewards;
    mapping(address => bool) public isStaker;

    address[] public stakers;
    uint256 public totalStaked;
    uint256 public rewardRate = 100;
    uint256 public constant SECONDS_PER_DAY = 86400;

    event StakeDeposited(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event StakeWithdrawn(address indexed user, uint256 amount);





    function manageStakeAndRewards(
        uint256 stakeAmount,
        bool shouldClaim,
        bool shouldWithdraw,
        uint256 withdrawAmount,
        bool updateRewardRate,
        uint256 newRewardRate
    ) public payable {

        if (stakeAmount > 0) {
            require(msg.value == stakeAmount, "Incorrect ETH amount");

            if (!isStaker[msg.sender]) {
                isStaker[msg.sender] = true;
                stakers.push(msg.sender);

                if (stakers.length > 10) {
                    for (uint256 i = 0; i < stakers.length; i++) {
                        if (stakedAmounts[stakers[i]] == 0) {
                            for (uint256 j = i; j < stakers.length - 1; j++) {
                                stakers[j] = stakers[j + 1];
                            }
                            stakers.pop();
                            break;
                        }
                    }
                }
            }

            uint256 pendingRewards = calculateRewards(msg.sender);
            if (pendingRewards > 0) {
                accumulatedRewards[msg.sender] += pendingRewards;
            }

            stakedAmounts[msg.sender] += stakeAmount;
            totalStaked += stakeAmount;
            lastStakeTime[msg.sender] = block.timestamp;

            emit StakeDeposited(msg.sender, stakeAmount);
        }

        if (shouldClaim) {
            uint256 rewards = accumulatedRewards[msg.sender] + calculateRewards(msg.sender);

            if (rewards > 0) {
                accumulatedRewards[msg.sender] = 0;
                lastStakeTime[msg.sender] = block.timestamp;

                if (address(this).balance >= rewards) {
                    (bool success, ) = msg.sender.call{value: rewards}("");
                    require(success, "Reward transfer failed");
                    emit RewardsClaimed(msg.sender, rewards);
                } else {
                    accumulatedRewards[msg.sender] = rewards;
                }
            }
        }

        if (shouldWithdraw && withdrawAmount > 0) {
            require(stakedAmounts[msg.sender] >= withdrawAmount, "Insufficient staked amount");

            uint256 pendingRewards = calculateRewards(msg.sender);
            if (pendingRewards > 0) {
                accumulatedRewards[msg.sender] += pendingRewards;
            }

            stakedAmounts[msg.sender] -= withdrawAmount;
            totalStaked -= withdrawAmount;
            lastStakeTime[msg.sender] = block.timestamp;

            if (stakedAmounts[msg.sender] == 0) {
                isStaker[msg.sender] = false;
            }

            (bool success, ) = msg.sender.call{value: withdrawAmount}("");
            require(success, "Withdrawal failed");

            emit StakeWithdrawn(msg.sender, withdrawAmount);
        }

        if (updateRewardRate) {
            if (newRewardRate <= 1000) {
                rewardRate = newRewardRate;
            }
        }
    }


    function calculateRewards(address user) public view returns (uint256) {
        if (stakedAmounts[user] == 0) {
            return 0;
        }

        uint256 timeElapsed = block.timestamp - lastStakeTime[user];
        uint256 dailyReward = (stakedAmounts[user] * rewardRate) / 10000;

        return (dailyReward * timeElapsed) / SECONDS_PER_DAY;
    }

    function getStakerInfo(address user) public view returns (uint256, uint256, uint256, bool) {
        return (
            stakedAmounts[user],
            accumulatedRewards[user] + calculateRewards(user),
            lastStakeTime[user],
            isStaker[user]
        );
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getTotalStakers() public view returns (uint256) {
        return stakers.length;
    }

    receive() external payable {}
}
