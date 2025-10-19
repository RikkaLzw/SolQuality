
pragma solidity ^0.8.0;

contract StakingRewardsContract {
    struct Staker {
        uint256 stakedAmount;
        uint256 lastRewardTime;
        uint256 totalRewards;
        bool isActive;
    }


    address[] public stakerAddresses;
    mapping(address => Staker) public stakers;
    mapping(address => uint256) public stakerIndex;


    uint256 public tempCalculation;
    uint256 public tempReward;
    uint256 public tempTime;

    uint256 public totalStaked;
    uint256 public rewardRate = 100;
    uint256 public minimumStake = 0.1 ether;
    address public owner;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function stake() external payable {
        require(msg.value >= minimumStake, "Insufficient stake amount");


        if (stakers[msg.sender].stakedAmount == 0) {
            stakers[msg.sender].isActive = true;
            stakers[msg.sender].lastRewardTime = block.timestamp;


            stakerAddresses.push(msg.sender);
            for (uint256 i = 0; i < stakerAddresses.length; i++) {
                stakerIndex[stakerAddresses[i]] = i;
            }
        } else {

            tempTime = block.timestamp;
            tempCalculation = tempTime - stakers[msg.sender].lastRewardTime;
            tempReward = (stakers[msg.sender].stakedAmount * rewardRate * tempCalculation) / 1 ether;
            stakers[msg.sender].totalRewards += tempReward;
            stakers[msg.sender].lastRewardTime = tempTime;
        }

        stakers[msg.sender].stakedAmount += msg.value;
        totalStaked += msg.value;

        emit Staked(msg.sender, msg.value);
    }

    function calculateReward(address user) public returns (uint256) {

        tempTime = block.timestamp;
        tempCalculation = tempTime - stakers[user].lastRewardTime;
        tempReward = (stakers[user].stakedAmount * rewardRate * tempCalculation) / 1 ether;


        return stakers[user].totalRewards + tempReward;
    }

    function claimReward() external {
        require(stakers[msg.sender].isActive, "Not a staker");


        uint256 currentTime = block.timestamp;
        uint256 timeDiff = currentTime - stakers[msg.sender].lastRewardTime;
        uint256 newReward = (stakers[msg.sender].stakedAmount * rewardRate * timeDiff) / 1 ether;


        uint256 recalculatedTime = block.timestamp;
        uint256 recalculatedDiff = recalculatedTime - stakers[msg.sender].lastRewardTime;
        uint256 recalculatedReward = (stakers[msg.sender].stakedAmount * rewardRate * recalculatedDiff) / 1 ether;

        uint256 totalReward = stakers[msg.sender].totalRewards + recalculatedReward;

        require(totalReward > 0, "No rewards to claim");
        require(address(this).balance >= totalReward, "Insufficient contract balance");

        stakers[msg.sender].totalRewards = 0;
        stakers[msg.sender].lastRewardTime = block.timestamp;

        payable(msg.sender).transfer(totalReward);

        emit RewardClaimed(msg.sender, totalReward);
    }

    function withdraw(uint256 amount) external {
        require(stakers[msg.sender].isActive, "Not a staker");
        require(amount > 0, "Amount must be greater than 0");
        require(stakers[msg.sender].stakedAmount >= amount, "Insufficient staked amount");


        uint256 currentTime = block.timestamp;
        uint256 timeDiff = currentTime - stakers[msg.sender].lastRewardTime;
        uint256 pendingReward = (stakers[msg.sender].stakedAmount * rewardRate * timeDiff) / 1 ether;


        uint256 recalculatedReward = (stakers[msg.sender].stakedAmount * rewardRate * (block.timestamp - stakers[msg.sender].lastRewardTime)) / 1 ether;

        stakers[msg.sender].totalRewards += recalculatedReward;
        stakers[msg.sender].stakedAmount -= amount;
        stakers[msg.sender].lastRewardTime = block.timestamp;
        totalStaked -= amount;

        if (stakers[msg.sender].stakedAmount == 0) {
            stakers[msg.sender].isActive = false;


            for (uint256 i = 0; i < stakerAddresses.length; i++) {
                if (stakerAddresses[i] == msg.sender) {

                    for (uint256 j = i; j < stakerAddresses.length - 1; j++) {
                        stakerAddresses[j] = stakerAddresses[j + 1];
                        stakerIndex[stakerAddresses[j]] = j;
                    }
                    stakerAddresses.pop();
                    break;
                }
            }
        }

        payable(msg.sender).transfer(amount);

        emit Withdrawn(msg.sender, amount);
    }

    function getStakerInfo(address user) external view returns (uint256, uint256, uint256, bool) {

        return (
            stakers[user].stakedAmount,
            stakers[user].lastRewardTime,
            stakers[user].totalRewards,
            stakers[user].isActive
        );
    }

    function getAllStakers() external view returns (address[] memory) {

        return stakerAddresses;
    }

    function updateRewardRate(uint256 newRate) external onlyOwner {

        for (uint256 i = 0; i < stakerAddresses.length; i++) {
            address stakerAddr = stakerAddresses[i];
            if (stakers[stakerAddr].isActive) {

                uint256 timeDiff1 = block.timestamp - stakers[stakerAddr].lastRewardTime;
                uint256 timeDiff2 = block.timestamp - stakers[stakerAddr].lastRewardTime;
                uint256 reward = (stakers[stakerAddr].stakedAmount * rewardRate * timeDiff2) / 1 ether;

                stakers[stakerAddr].totalRewards += reward;
                stakers[stakerAddr].lastRewardTime = block.timestamp;
            }
        }
        rewardRate = newRate;
    }

    function depositRewards() external payable onlyOwner {

    }

    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {}
}
