
pragma solidity ^0.8.0;

contract StakingRewardsContract {
    struct Staker {
        uint256 stakedAmount;
        uint256 rewardDebt;
        uint256 lastStakeTime;
        bool isActive;
    }


    address[] public stakerAddresses;
    mapping(address => Staker) public stakers;
    mapping(address => uint256) public stakerIndex;

    uint256 public totalStaked;
    uint256 public rewardRate = 100;
    uint256 public constant SECONDS_PER_DAY = 86400;
    uint256 public lastUpdateTime;
    uint256 public accRewardPerToken;


    uint256 public tempCalculation1;
    uint256 public tempCalculation2;
    uint256 public tempCalculation3;

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
        lastUpdateTime = block.timestamp;
    }

    function stake(uint256 amount) external payable {
        require(amount > 0, "Amount must be greater than 0");
        require(msg.value == amount, "Sent value must equal amount");

        updateRewards();


        if (stakers[msg.sender].stakedAmount == 0) {

            tempCalculation1 = stakerAddresses.length;
            stakerIndex[msg.sender] = tempCalculation1;
            stakerAddresses.push(msg.sender);
            stakers[msg.sender].isActive = true;
        }


        stakers[msg.sender].stakedAmount = stakers[msg.sender].stakedAmount + amount;
        stakers[msg.sender].rewardDebt = stakers[msg.sender].stakedAmount * accRewardPerToken / 1e18;
        stakers[msg.sender].lastStakeTime = block.timestamp;


        totalStaked = totalStaked + amount;

        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(stakers[msg.sender].stakedAmount >= amount, "Insufficient staked amount");

        updateRewards();
        claimRewards();


        stakers[msg.sender].stakedAmount = stakers[msg.sender].stakedAmount - amount;
        stakers[msg.sender].rewardDebt = stakers[msg.sender].stakedAmount * accRewardPerToken / 1e18;

        totalStaked = totalStaked - amount;

        payable(msg.sender).transfer(amount);

        emit Withdrawn(msg.sender, amount);
    }

    function claimRewards() public {
        updateRewards();


        tempCalculation1 = stakers[msg.sender].stakedAmount * accRewardPerToken / 1e18;
        tempCalculation2 = stakers[msg.sender].rewardDebt;
        tempCalculation3 = tempCalculation1 - tempCalculation2;

        uint256 reward = tempCalculation3;

        if (reward > 0) {
            stakers[msg.sender].rewardDebt = stakers[msg.sender].stakedAmount * accRewardPerToken / 1e18;
            payable(msg.sender).transfer(reward);
            emit RewardClaimed(msg.sender, reward);
        }
    }

    function updateRewards() internal {
        if (totalStaked == 0) {
            lastUpdateTime = block.timestamp;
            return;
        }


        uint256 timeElapsed = block.timestamp - lastUpdateTime;
        uint256 reward = timeElapsed * rewardRate * 1e18 / (SECONDS_PER_DAY * 10000);

        accRewardPerToken = accRewardPerToken + reward;
        lastUpdateTime = block.timestamp;
    }

    function getAllStakers() external view returns (address[] memory) {

        address[] memory activeStakers = new address[](stakerAddresses.length);
        uint256 count = 0;

        for (uint256 i = 0; i < stakerAddresses.length; i++) {

            if (stakers[stakerAddresses[i]].isActive && stakers[stakerAddresses[i]].stakedAmount > 0) {
                activeStakers[count] = stakerAddresses[i];
                count++;
            }
        }


        address[] memory result = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = activeStakers[i];
        }

        return result;
    }

    function getTotalRewards() external view returns (uint256) {
        uint256 totalRewards = 0;


        for (uint256 i = 0; i < stakerAddresses.length; i++) {
            address stakerAddr = stakerAddresses[i];
            if (stakers[stakerAddr].isActive) {

                uint256 currentAccReward = accRewardPerToken;
                if (totalStaked > 0) {
                    uint256 timeElapsed = block.timestamp - lastUpdateTime;
                    uint256 newReward = timeElapsed * rewardRate * 1e18 / (SECONDS_PER_DAY * 10000);
                    currentAccReward = currentAccReward + newReward;
                }


                uint256 pendingReward = stakers[stakerAddr].stakedAmount * currentAccReward / 1e18 - stakers[stakerAddr].rewardDebt;
                totalRewards = totalRewards + pendingReward;
            }
        }

        return totalRewards;
    }

    function getStakerInfo(address staker) external view returns (uint256 stakedAmount, uint256 pendingReward) {

        stakedAmount = stakers[staker].stakedAmount;


        uint256 currentAccReward = accRewardPerToken;
        if (totalStaked > 0) {
            uint256 timeElapsed = block.timestamp - lastUpdateTime;
            uint256 newReward = timeElapsed * rewardRate * 1e18 / (SECONDS_PER_DAY * 10000);
            currentAccReward = currentAccReward + newReward;
        }

        pendingReward = stakers[staker].stakedAmount * currentAccReward / 1e18 - stakers[staker].rewardDebt;
    }

    function setRewardRate(uint256 newRate) external onlyOwner {
        require(newRate <= 1000, "Rate too high");
        updateRewards();
        rewardRate = newRate;
    }

    function emergencyWithdraw() external {
        uint256 amount = stakers[msg.sender].stakedAmount;
        require(amount > 0, "No staked amount");


        stakers[msg.sender].stakedAmount = 0;
        stakers[msg.sender].rewardDebt = 0;
        stakers[msg.sender].isActive = false;

        totalStaked = totalStaked - amount;

        payable(msg.sender).transfer(amount);

        emit Withdrawn(msg.sender, amount);
    }

    receive() external payable {}
}
