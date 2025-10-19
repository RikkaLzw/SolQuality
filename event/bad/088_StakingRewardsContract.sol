
pragma solidity ^0.8.0;

contract StakingRewardsContract {
    mapping(address => uint256) public stakedAmount;
    mapping(address => uint256) public rewardDebt;
    mapping(address => uint256) public lastStakeTime;

    uint256 public totalStaked;
    uint256 public rewardRate = 100;
    uint256 public constant SECONDS_PER_DAY = 86400;

    address public owner;
    bool public paused;


    event Staked(address user, uint256 amount);
    event Unstaked(address user, uint256 amount);
    event RewardClaimed(address user, uint256 reward);


    error Failed();
    error NotAllowed();
    error BadInput();

    modifier onlyOwner() {

        require(msg.sender == owner);
        _;
    }

    modifier notPaused() {

        require(!paused);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function stake(uint256 amount) external payable notPaused {

        require(amount > 0);
        require(msg.value == amount);


        uint256 pendingReward = calculateReward(msg.sender);
        if (pendingReward > 0) {
            rewardDebt[msg.sender] += pendingReward;
        }

        stakedAmount[msg.sender] += amount;
        totalStaked += amount;
        lastStakeTime[msg.sender] = block.timestamp;

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external notPaused {

        require(amount > 0);
        require(stakedAmount[msg.sender] >= amount);


        uint256 pendingReward = calculateReward(msg.sender);
        if (pendingReward > 0) {
            rewardDebt[msg.sender] += pendingReward;
        }

        stakedAmount[msg.sender] -= amount;
        totalStaked -= amount;
        lastStakeTime[msg.sender] = block.timestamp;


        payable(msg.sender).transfer(amount);

        emit Unstaked(msg.sender, amount);
    }

    function claimRewards() external notPaused {
        uint256 totalReward = calculateReward(msg.sender) + rewardDebt[msg.sender];


        require(totalReward > 0);
        require(address(this).balance >= totalReward);

        rewardDebt[msg.sender] = 0;
        lastStakeTime[msg.sender] = block.timestamp;

        payable(msg.sender).transfer(totalReward);

        emit RewardClaimed(msg.sender, totalReward);
    }

    function calculateReward(address user) public view returns (uint256) {
        if (stakedAmount[user] == 0) {
            return 0;
        }

        uint256 stakingDuration = block.timestamp - lastStakeTime[user];
        uint256 dailyReward = (stakedAmount[user] * rewardRate) / 10000;

        return (dailyReward * stakingDuration) / SECONDS_PER_DAY;
    }

    function setRewardRate(uint256 newRate) external onlyOwner {

        rewardRate = newRate;
    }

    function setPaused(bool _paused) external onlyOwner {

        paused = _paused;
    }

    function emergencyWithdraw() external onlyOwner {

        payable(owner).transfer(address(this).balance);
    }

    function transferOwnership(address newOwner) external onlyOwner {

        require(newOwner != address(0));
        owner = newOwner;
    }

    function getStakedAmount(address user) external view returns (uint256) {
        return stakedAmount[user];
    }

    function getTotalStaked() external view returns (uint256) {
        return totalStaked;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }


    function addRewards() external payable onlyOwner {

        require(msg.value > 0);
    }


    function validateUser(address user) internal pure {
        require(user != address(0));
    }

    receive() external payable {

    }
}
