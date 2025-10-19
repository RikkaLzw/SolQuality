
pragma solidity ^0.8.0;

contract StakingRewardsContract {
    mapping(address => uint256) public stakedAmounts;
    mapping(address => uint256) public rewardBalances;
    mapping(address => uint256) public lastStakeTime;
    mapping(address => bool) public isStaker;

    uint256 public totalStaked;
    uint256 public rewardRate = 100;
    uint256 public constant SECONDS_PER_DAY = 86400;
    address public owner;
    bool public contractActive = true;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier contractIsActive() {
        require(contractActive, "Contract inactive");
        _;
    }

    constructor() {
        owner = msg.sender;
    }





    function manageStakingOperations(
        uint256 stakeAmount,
        bool shouldStake,
        bool shouldWithdraw,
        uint256 withdrawAmount,
        bool shouldClaimRewards,
        bool shouldUpdateRewardRate,
        uint256 newRewardRate
    ) public payable contractIsActive {

        if (shouldStake && stakeAmount > 0) {
            if (msg.value >= stakeAmount) {
                if (!isStaker[msg.sender]) {
                    if (stakeAmount >= 1 ether) {
                        isStaker[msg.sender] = true;
                        stakedAmounts[msg.sender] += stakeAmount;
                        lastStakeTime[msg.sender] = block.timestamp;
                        totalStaked += stakeAmount;
                        emit Staked(msg.sender, stakeAmount);

                        if (msg.value > stakeAmount) {
                            payable(msg.sender).transfer(msg.value - stakeAmount);
                        }
                    } else {
                        revert("Minimum stake is 1 ETH");
                    }
                } else {
                    uint256 pendingReward = calculateReward(msg.sender);
                    if (pendingReward > 0) {
                        rewardBalances[msg.sender] += pendingReward;
                    }
                    stakedAmounts[msg.sender] += stakeAmount;
                    lastStakeTime[msg.sender] = block.timestamp;
                    totalStaked += stakeAmount;
                    emit Staked(msg.sender, stakeAmount);

                    if (msg.value > stakeAmount) {
                        payable(msg.sender).transfer(msg.value - stakeAmount);
                    }
                }
            } else {
                revert("Insufficient ETH sent");
            }
        }

        if (shouldWithdraw && withdrawAmount > 0) {
            if (isStaker[msg.sender]) {
                if (stakedAmounts[msg.sender] >= withdrawAmount) {
                    if (block.timestamp >= lastStakeTime[msg.sender] + 1 days) {
                        uint256 pendingReward = calculateReward(msg.sender);
                        if (pendingReward > 0) {
                            rewardBalances[msg.sender] += pendingReward;
                        }

                        stakedAmounts[msg.sender] -= withdrawAmount;
                        totalStaked -= withdrawAmount;
                        lastStakeTime[msg.sender] = block.timestamp;

                        if (stakedAmounts[msg.sender] == 0) {
                            isStaker[msg.sender] = false;
                        }

                        payable(msg.sender).transfer(withdrawAmount);
                        emit Withdrawn(msg.sender, withdrawAmount);
                    } else {
                        revert("Must wait 24 hours before withdrawal");
                    }
                } else {
                    revert("Insufficient staked amount");
                }
            } else {
                revert("Not a staker");
            }
        }

        if (shouldClaimRewards) {
            if (isStaker[msg.sender]) {
                uint256 pendingReward = calculateReward(msg.sender);
                uint256 totalReward = rewardBalances[msg.sender] + pendingReward;

                if (totalReward > 0) {
                    if (address(this).balance >= totalReward) {
                        rewardBalances[msg.sender] = 0;
                        lastStakeTime[msg.sender] = block.timestamp;
                        payable(msg.sender).transfer(totalReward);
                        emit RewardClaimed(msg.sender, totalReward);
                    } else {
                        revert("Insufficient contract balance for rewards");
                    }
                } else {
                    revert("No rewards to claim");
                }
            } else {
                revert("Not a staker");
            }
        }

        if (shouldUpdateRewardRate && msg.sender == owner) {
            if (newRewardRate > 0 && newRewardRate <= 1000) {
                rewardRate = newRewardRate;
            } else {
                revert("Invalid reward rate");
            }
        }
    }


    function calculateReward(address user) public view returns (uint256) {
        if (!isStaker[user] || stakedAmounts[user] == 0) {
            return 0;
        }

        uint256 timeStaked = block.timestamp - lastStakeTime[user];
        uint256 daysStaked = timeStaked / SECONDS_PER_DAY;

        return (stakedAmounts[user] * rewardRate * daysStaked) / 10000;
    }


    function getStakerInfo(address user) public view returns (uint256, uint256, uint256, bool) {
        return (
            stakedAmounts[user],
            rewardBalances[user],
            lastStakeTime[user],
            isStaker[user]
        );
    }

    function addRewardFunds() external payable onlyOwner {
        require(msg.value > 0, "Must send ETH");
    }

    function emergencyWithdraw() external onlyOwner {
        contractActive = false;
        payable(owner).transfer(address(this).balance);
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {}
}
