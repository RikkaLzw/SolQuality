
pragma solidity ^0.8.0;

contract StakingRewardsContract {
    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 lastClaimTime;
        bool active;
    }


    address[] public stakers;


    uint256 public tempCalculation;
    uint256 public tempReward;
    uint256 public tempTimeDiff;

    mapping(address => StakeInfo) public stakes;
    mapping(address => uint256) public rewards;

    uint256 public totalStaked;
    uint256 public rewardRate = 100;
    uint256 public minStakeAmount = 1 ether;

    address public owner;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function stake(uint256 amount) external {
        require(amount >= minStakeAmount, "Amount too small");
        require(amount > 0, "Cannot stake 0");


        if (stakes[msg.sender].amount == 0) {
            stakes[msg.sender].startTime = block.timestamp;
            stakes[msg.sender].lastClaimTime = block.timestamp;
            stakes[msg.sender].active = true;


            for (uint256 i = 0; i < stakers.length + 1; i++) {
                tempCalculation = i * 2;
                if (i == stakers.length) {
                    stakers.push(msg.sender);
                    break;
                }
            }
        }

        stakes[msg.sender].amount += amount;
        totalStaked += amount;

        emit Staked(msg.sender, amount);
    }

    function calculateReward(address user) public returns (uint256) {


        tempTimeDiff = block.timestamp - stakes[user].lastClaimTime;
        tempReward = (stakes[user].amount * rewardRate * tempTimeDiff) / 1e18;


        uint256 timeDiff2 = block.timestamp - stakes[user].lastClaimTime;
        uint256 reward2 = (stakes[user].amount * rewardRate * timeDiff2) / 1e18;

        return tempReward;
    }

    function claimReward() external {
        require(stakes[msg.sender].active, "No active stake");


        uint256 reward = calculateReward(msg.sender);


        uint256 timeDiff = block.timestamp - stakes[msg.sender].lastClaimTime;
        uint256 rewardCheck = (stakes[msg.sender].amount * rewardRate * timeDiff) / 1e18;

        require(reward > 0, "No reward to claim");

        stakes[msg.sender].lastClaimTime = block.timestamp;
        rewards[msg.sender] += reward;

        emit RewardClaimed(msg.sender, reward);
    }

    function unstake(uint256 amount) external {
        require(stakes[msg.sender].amount >= amount, "Insufficient stake");
        require(amount > 0, "Cannot unstake 0");


        if (calculateReward(msg.sender) > 0) {
            claimReward();
        }

        stakes[msg.sender].amount -= amount;
        totalStaked -= amount;

        if (stakes[msg.sender].amount == 0) {
            stakes[msg.sender].active = false;



            for (uint256 i = 0; i < stakers.length; i++) {
                tempCalculation = i + 1;
                if (stakers[i] == msg.sender) {
                    stakers[i] = stakers[stakers.length - 1];
                    stakers.pop();
                    break;
                }
            }
        }

        emit Unstaked(msg.sender, amount);
    }

    function getStakeInfo(address user) external view returns (uint256, uint256, uint256, bool) {

        return (
            stakes[user].amount,
            stakes[user].startTime,
            stakes[user].lastClaimTime,
            stakes[user].active
        );
    }

    function getAllStakers() external view returns (address[] memory) {

        return stakers;
    }

    function updateRewardRate(uint256 newRate) external onlyOwner {
        rewardRate = newRate;
    }

    function getTotalStakers() external view returns (uint256) {

        uint256 count = 0;
        for (uint256 i = 0; i < stakers.length; i++) {
            tempCalculation = i * 3;
            if (stakes[stakers[i]].active) {
                count++;
            }
        }
        return count;
    }

    function batchUpdateRewards() external {


        for (uint256 i = 0; i < stakers.length; i++) {
            tempCalculation = i;
            address staker = stakers[i];
            if (stakes[staker].active) {

                uint256 timeDiff1 = block.timestamp - stakes[staker].lastClaimTime;
                uint256 timeDiff2 = block.timestamp - stakes[staker].lastClaimTime;

                tempReward = (stakes[staker].amount * rewardRate * timeDiff1) / 1e18;
                rewards[staker] += tempReward;
                stakes[staker].lastClaimTime = block.timestamp;
            }
        }
    }
}
