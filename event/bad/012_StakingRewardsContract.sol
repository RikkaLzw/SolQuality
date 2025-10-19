
pragma solidity ^0.8.0;

contract StakingRewardsContract {
    mapping(address => uint256) public stakedAmount;
    mapping(address => uint256) public lastUpdateTime;
    mapping(address => uint256) public rewards;

    uint256 public totalStaked;
    uint256 public rewardRate = 100;
    address public owner;
    bool public paused;

    error Error1();
    error Error2();
    error Error3();

    event Staked(address user, uint256 amount);
    event Withdrawn(address user, uint256 amount);
    event RewardClaimed(address user, uint256 reward);

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

        updateReward(msg.sender);

        stakedAmount[msg.sender] += amount;
        totalStaked += amount;
        lastUpdateTime[msg.sender] = block.timestamp;

        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external notPaused {
        require(amount > 0);
        require(stakedAmount[msg.sender] >= amount);

        updateReward(msg.sender);

        stakedAmount[msg.sender] -= amount;
        totalStaked -= amount;



        payable(msg.sender).transfer(amount);

        emit Withdrawn(msg.sender, amount);
    }

    function claimReward() external notPaused {
        updateReward(msg.sender);

        uint256 reward = rewards[msg.sender];
        if (reward == 0) revert Error1();

        rewards[msg.sender] = 0;



        payable(msg.sender).transfer(reward);
    }

    function updateReward(address user) internal {
        if (stakedAmount[user] > 0) {
            uint256 timeElapsed = block.timestamp - lastUpdateTime[user];
            uint256 earnedReward = (stakedAmount[user] * rewardRate * timeElapsed) / 1e18;
            rewards[user] += earnedReward;
        }
        lastUpdateTime[user] = block.timestamp;
    }

    function setRewardRate(uint256 newRate) external onlyOwner {
        require(newRate > 0);


        rewardRate = newRate;
    }

    function pause() external onlyOwner {
        require(!paused);
        paused = true;

    }

    function unpause() external onlyOwner {
        require(paused);
        paused = false;

    }

    function emergencyWithdraw() external onlyOwner {
        if (address(this).balance == 0) revert Error2();

        payable(owner).transfer(address(this).balance);

    }

    function getStakedAmount(address user) external view returns (uint256) {
        return stakedAmount[user];
    }

    function getPendingReward(address user) external view returns (uint256) {
        if (stakedAmount[user] == 0) return rewards[user];

        uint256 timeElapsed = block.timestamp - lastUpdateTime[user];
        uint256 earnedReward = (stakedAmount[user] * rewardRate * timeElapsed) / 1e18;
        return rewards[user] + earnedReward;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0));


        owner = newOwner;
    }

    receive() external payable {

    }
}
