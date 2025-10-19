
pragma solidity ^0.8.0;

contract StakingRewardContract {
    mapping(address => uint256) public stakedAmount;
    mapping(address => uint256) public lastStakeTime;
    mapping(address => uint256) public accumulatedRewards;

    uint256 public totalStaked;
    uint256 public rewardRate = 100;
    uint256 public constant SECONDS_PER_DAY = 86400;
    uint256 public minimumStakeAmount = 1 ether;

    address public owner;
    bool public contractActive = true;

    error InvalidAmount();
    error NotOwner();
    error ContractPaused();

    event Staked(address user, uint256 amount);
    event Unstaked(address user, uint256 amount);
    event RewardClaimed(address user, uint256 reward);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier contractIsActive() {
        require(contractActive);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function stake() external payable contractIsActive {
        require(msg.value >= minimumStakeAmount);

        if (stakedAmount[msg.sender] > 0) {
            _calculateAndUpdateRewards(msg.sender);
        }

        stakedAmount[msg.sender] += msg.value;
        totalStaked += msg.value;
        lastStakeTime[msg.sender] = block.timestamp;

        emit Staked(msg.sender, msg.value);
    }

    function unstake(uint256 amount) external contractIsActive {
        require(amount > 0);
        require(stakedAmount[msg.sender] >= amount);

        _calculateAndUpdateRewards(msg.sender);

        stakedAmount[msg.sender] -= amount;
        totalStaked -= amount;
        lastStakeTime[msg.sender] = block.timestamp;

        payable(msg.sender).transfer(amount);

        emit Unstaked(msg.sender, amount);
    }

    function claimRewards() external contractIsActive {
        _calculateAndUpdateRewards(msg.sender);

        uint256 reward = accumulatedRewards[msg.sender];
        require(reward > 0);

        accumulatedRewards[msg.sender] = 0;

        payable(msg.sender).transfer(reward);

        emit RewardClaimed(msg.sender, reward);
    }

    function _calculateAndUpdateRewards(address user) internal {
        if (stakedAmount[user] == 0) return;

        uint256 timeElapsed = block.timestamp - lastStakeTime[user];
        uint256 dailyReward = (stakedAmount[user] * rewardRate) / 10000;
        uint256 reward = (dailyReward * timeElapsed) / SECONDS_PER_DAY;

        accumulatedRewards[user] += reward;
    }

    function getStakeInfo(address user) external view returns (uint256 staked, uint256 pending, uint256 accumulated) {
        staked = stakedAmount[user];
        accumulated = accumulatedRewards[user];

        if (stakedAmount[user] > 0) {
            uint256 timeElapsed = block.timestamp - lastStakeTime[user];
            uint256 dailyReward = (stakedAmount[user] * rewardRate) / 10000;
            pending = (dailyReward * timeElapsed) / SECONDS_PER_DAY;
        }
    }

    function setRewardRate(uint256 newRate) external onlyOwner {
        rewardRate = newRate;
    }

    function setMinimumStakeAmount(uint256 newMinimum) external onlyOwner {
        minimumStakeAmount = newMinimum;
    }

    function pauseContract() external onlyOwner {
        contractActive = false;
    }

    function unpauseContract() external onlyOwner {
        contractActive = true;
    }

    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    function depositRewards() external payable onlyOwner {

    }

    receive() external payable {

    }
}
