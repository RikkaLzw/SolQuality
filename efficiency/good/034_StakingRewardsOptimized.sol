
pragma solidity ^0.8.19;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract StakingRewardsOptimized {
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardsToken;

    address public owner;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 newRate);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier updateReward(address account) {
        uint256 _rewardPerToken = rewardPerToken();
        rewardPerTokenStored = _rewardPerToken;
        lastUpdateTime = block.timestamp;

        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = _rewardPerToken;
        }
        _;
    }

    constructor(address _stakingToken, address _rewardsToken, uint256 _rewardRate) {
        owner = msg.sender;
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
        rewardRate = _rewardRate;
        lastUpdateTime = block.timestamp;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }

        unchecked {
            return rewardPerTokenStored +
                   ((block.timestamp - lastUpdateTime) * rewardRate * 1e18) / totalSupply;
        }
    }

    function earned(address account) public view returns (uint256) {
        uint256 balance = balanceOf[account];
        if (balance == 0) return rewards[account];

        unchecked {
            return (balance * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18 +
                   rewards[account];
        }
    }

    function stake(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");

        totalSupply += amount;
        balanceOf[msg.sender] += amount;

        require(stakingToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");

        totalSupply -= amount;
        balanceOf[msg.sender] -= amount;

        require(stakingToken.transfer(msg.sender, amount), "Transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    function getReward() external updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            require(rewardsToken.transfer(msg.sender, reward), "Transfer failed");
            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit() external {
        withdraw(balanceOf[msg.sender]);
        getReward();
    }

    function setRewardRate(uint256 _rewardRate) external onlyOwner updateReward(address(0)) {
        rewardRate = _rewardRate;
        emit RewardRateUpdated(_rewardRate);
    }

    function emergencyWithdraw() external updateReward(msg.sender) {
        uint256 balance = balanceOf[msg.sender];
        require(balance > 0, "No balance");

        totalSupply -= balance;
        balanceOf[msg.sender] = 0;

        require(stakingToken.transfer(msg.sender, balance), "Transfer failed");

        emit Withdrawn(msg.sender, balance);
    }

    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        require(tokenAddress != address(stakingToken), "Cannot recover staking token");
        require(IERC20(tokenAddress).transfer(owner, tokenAmount), "Transfer failed");
    }
}
