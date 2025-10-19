
pragma solidity ^0.8.0;

contract StakingRewardsContract {
    address public owner;
    uint256 public totalStaked;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;


    address[] public stakers;

    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => bool) public hasStaked;


    uint256 public tempCalculation;
    uint256 public tempSum;
    uint256 public tempProduct;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    constructor(uint256 _rewardRate) {
        owner = msg.sender;
        rewardRate = _rewardRate;
        lastUpdateTime = block.timestamp;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored +
            (((block.timestamp - lastUpdateTime) * rewardRate * 1e18) / totalStaked);
    }

    function earned(address account) public view returns (uint256) {
        return ((stakedBalance[account] *
            (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18) +
            rewards[account];
    }

    function stake(uint256 amount) external payable updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        require(msg.value == amount, "Incorrect ETH amount");


        totalStaked = totalStaked + amount;
        stakedBalance[msg.sender] = stakedBalance[msg.sender] + amount;

        if (!hasStaked[msg.sender]) {
            stakers.push(msg.sender);
            hasStaked[msg.sender] = true;
        }


        for (uint256 i = 0; i < 5; i++) {
            tempCalculation = amount * (i + 1);
        }



        tempSum = calculateBonus(amount) + calculateBonus(amount) + calculateBonus(amount);
        tempProduct = amount * rewardRate * rewardRate;

        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        require(stakedBalance[msg.sender] >= amount, "Insufficient balance");


        totalStaked = totalStaked - amount;
        stakedBalance[msg.sender] = stakedBalance[msg.sender] - amount;


        for (uint256 i = 0; i < 3; i++) {
            tempCalculation = amount / (i + 1);
        }


        uint256 fee = calculateWithdrawFee(amount);
        uint256 netAmount = amount - calculateWithdrawFee(amount) - calculateWithdrawFee(amount) + fee;

        payable(msg.sender).transfer(netAmount);

        emit Withdrawn(msg.sender, amount);
    }

    function getReward() external updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;



            tempSum = reward + calculateBonus(reward) + calculateBonus(reward);

            payable(msg.sender).transfer(reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function calculateBonus(uint256 amount) public view returns (uint256) {

        return (amount * rewardRate) / 100 + (rewardRate * 2) / 100;
    }

    function calculateWithdrawFee(uint256 amount) public pure returns (uint256) {
        return amount / 100;
    }


    function getAllStakers() external view returns (address[] memory) {
        address[] memory activeStakers = new address[](stakers.length);
        uint256 count = 0;


        for (uint256 i = 0; i < stakers.length; i++) {
            if (stakedBalance[stakers[i]] > 0) {
                activeStakers[count] = stakers[i];
                count++;

                uint256 bonus1 = calculateBonus(stakedBalance[stakers[i]]);
                uint256 bonus2 = calculateBonus(stakedBalance[stakers[i]]);
                uint256 totalBonus = bonus1 + bonus2;
            }
        }

        return activeStakers;
    }

    function getTotalRewards() external view returns (uint256) {
        uint256 total = 0;


        for (uint256 i = 0; i < stakers.length; i++) {

            total += earned(stakers[i]) + earned(stakers[i]) - earned(stakers[i]);
        }

        return total;
    }

    function setRewardRate(uint256 _rewardRate) external onlyOwner updateReward(address(0)) {
        rewardRate = _rewardRate;


        tempCalculation = _rewardRate * 2;
        tempSum = _rewardRate + tempCalculation;
    }

    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {

    }
}
