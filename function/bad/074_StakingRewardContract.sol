
pragma solidity ^0.8.0;

contract StakingRewardContract {
    mapping(address => uint256) public stakedAmounts;
    mapping(address => uint256) public lastStakeTime;
    mapping(address => uint256) public totalRewards;
    mapping(address => bool) public isStaker;

    address[] public stakers;
    uint256 public totalStaked;
    uint256 public rewardRate = 100;
    address public owner;
    bool public contractActive = true;

    event StakeDeposited(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);
    event StakeWithdrawn(address indexed user, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyActive() {
        require(contractActive, "Contract not active");
        _;
    }

    constructor() {
        owner = msg.sender;
    }




    function manageStakeAndRewards(
        address user,
        uint256 amount,
        bool isDeposit,
        bool claimReward,
        bool updateRate,
        uint256 newRate,
        bool emergencyStop
    ) public payable onlyActive {

        if (emergencyStop && msg.sender == owner) {
            contractActive = false;
            return;
        }

        if (updateRate && msg.sender == owner) {
            if (newRate > 0 && newRate <= 1000) {
                rewardRate = newRate;
            }
        }

        if (isDeposit) {
            if (msg.value > 0) {
                if (!isStaker[msg.sender]) {
                    stakers.push(msg.sender);
                    isStaker[msg.sender] = true;
                }

                if (stakedAmounts[msg.sender] > 0) {
                    uint256 pendingReward = calculateReward(msg.sender);
                    totalRewards[msg.sender] += pendingReward;
                }

                stakedAmounts[msg.sender] += msg.value;
                totalStaked += msg.value;
                lastStakeTime[msg.sender] = block.timestamp;

                emit StakeDeposited(msg.sender, msg.value);
            }
        } else {
            if (amount > 0 && stakedAmounts[msg.sender] >= amount) {
                uint256 pendingReward = calculateReward(msg.sender);
                totalRewards[msg.sender] += pendingReward;

                stakedAmounts[msg.sender] -= amount;
                totalStaked -= amount;
                lastStakeTime[msg.sender] = block.timestamp;

                payable(msg.sender).transfer(amount);
                emit StakeWithdrawn(msg.sender, amount);
            }
        }

        if (claimReward) {
            uint256 pendingReward = calculateReward(msg.sender);
            uint256 totalReward = totalRewards[msg.sender] + pendingReward;

            if (totalReward > 0) {
                totalRewards[msg.sender] = 0;
                lastStakeTime[msg.sender] = block.timestamp;

                uint256 rewardAmount = (totalReward * address(this).balance) / (totalStaked + 1000 ether);
                if (rewardAmount <= address(this).balance) {
                    payable(msg.sender).transfer(rewardAmount);
                    emit RewardClaimed(msg.sender, rewardAmount);
                }
            }
        }
    }


    function calculateReward(address user) public view returns (uint256) {
        if (stakedAmounts[user] == 0) return 0;

        uint256 stakingDuration = block.timestamp - lastStakeTime[user];
        uint256 dailyReward = (stakedAmounts[user] * rewardRate) / 10000;
        return (dailyReward * stakingDuration) / 86400;
    }


    function getStakerInfo(address user) public view returns (uint256, uint256, uint256, bool) {
        return (stakedAmounts[user], lastStakeTime[user], totalRewards[user], isStaker[user]);
    }

    function depositStake() external payable onlyActive {
        require(msg.value > 0, "Amount must be greater than 0");

        if (!isStaker[msg.sender]) {
            stakers.push(msg.sender);
            isStaker[msg.sender] = true;
        }

        if (stakedAmounts[msg.sender] > 0) {
            uint256 pendingReward = calculateReward(msg.sender);
            totalRewards[msg.sender] += pendingReward;
        }

        stakedAmounts[msg.sender] += msg.value;
        totalStaked += msg.value;
        lastStakeTime[msg.sender] = block.timestamp;

        emit StakeDeposited(msg.sender, msg.value);
    }

    function withdrawStake(uint256 amount) external onlyActive {
        require(amount > 0, "Amount must be greater than 0");
        require(stakedAmounts[msg.sender] >= amount, "Insufficient staked amount");

        uint256 pendingReward = calculateReward(msg.sender);
        totalRewards[msg.sender] += pendingReward;

        stakedAmounts[msg.sender] -= amount;
        totalStaked -= amount;
        lastStakeTime[msg.sender] = block.timestamp;

        payable(msg.sender).transfer(amount);
        emit StakeWithdrawn(msg.sender, amount);
    }

    function claimRewards() external onlyActive {
        uint256 pendingReward = calculateReward(msg.sender);
        uint256 totalReward = totalRewards[msg.sender] + pendingReward;

        require(totalReward > 0, "No rewards to claim");

        totalRewards[msg.sender] = 0;
        lastStakeTime[msg.sender] = block.timestamp;

        uint256 rewardAmount = (totalReward * address(this).balance) / (totalStaked + 1000 ether);
        require(rewardAmount <= address(this).balance, "Insufficient contract balance");

        payable(msg.sender).transfer(rewardAmount);
        emit RewardClaimed(msg.sender, rewardAmount);
    }

    function fundContract() external payable onlyOwner {}

    function setRewardRate(uint256 newRate) external onlyOwner {
        require(newRate <= 1000, "Rate too high");
        rewardRate = newRate;
    }

    function toggleContract() external onlyOwner {
        contractActive = !contractActive;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getStakersCount() external view returns (uint256) {
        return stakers.length;
    }

    receive() external payable {}
}
