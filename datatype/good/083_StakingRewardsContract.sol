
pragma solidity ^0.8.19;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract StakingRewardsContract {
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardsToken;

    address public owner;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public totalSupply;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) private _balances;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 newRate);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
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

    constructor(
        address _stakingToken,
        address _rewardsToken,
        uint256 _rewardRate
    ) {
        require(_stakingToken != address(0), "Invalid staking token");
        require(_rewardsToken != address(0), "Invalid rewards token");

        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
        owner = msg.sender;
        rewardRate = _rewardRate;
        lastUpdateTime = block.timestamp;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }

        return rewardPerTokenStored +
            (((block.timestamp - lastUpdateTime) * rewardRate * 1e18) / totalSupply);
    }

    function earned(address account) public view returns (uint256) {
        return ((_balances[account] *
            (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18) +
            rewards[account];
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function stake(uint256 _amount) external updateReward(msg.sender) {
        require(_amount > 0, "Cannot stake 0");

        totalSupply += _amount;
        _balances[msg.sender] += _amount;

        bool success = stakingToken.transferFrom(msg.sender, address(this), _amount);
        require(success, "Transfer failed");

        emit Staked(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) public updateReward(msg.sender) {
        require(_amount > 0, "Cannot withdraw 0");
        require(_balances[msg.sender] >= _amount, "Insufficient balance");

        totalSupply -= _amount;
        _balances[msg.sender] -= _amount;

        bool success = stakingToken.transfer(msg.sender, _amount);
        require(success, "Transfer failed");

        emit Withdrawn(msg.sender, _amount);
    }

    function getReward() public updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            bool success = rewardsToken.transfer(msg.sender, reward);
            require(success, "Reward transfer failed");
            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit() external {
        withdraw(_balances[msg.sender]);
        getReward();
    }

    function setRewardRate(uint256 _rewardRate) external onlyOwner updateReward(address(0)) {
        rewardRate = _rewardRate;
        emit RewardRateUpdated(_rewardRate);
    }

    function emergencyWithdraw() external onlyOwner {
        uint256 stakingBalance = stakingToken.balanceOf(address(this));
        uint256 rewardBalance = rewardsToken.balanceOf(address(this));

        if (stakingBalance > 0) {
            stakingToken.transfer(owner, stakingBalance);
        }

        if (rewardBalance > 0) {
            rewardsToken.transfer(owner, rewardBalance);
        }
    }
}
