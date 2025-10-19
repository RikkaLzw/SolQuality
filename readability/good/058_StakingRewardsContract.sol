
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract StakingRewardsContract is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;


    IERC20 public immutable stakingToken;


    IERC20 public immutable rewardsToken;


    uint256 public rewardsDuration;


    uint256 public periodFinish;


    uint256 public rewardRate;


    uint256 public lastUpdateTime;


    uint256 public rewardPerTokenStored;


    mapping(address => uint256) public userRewardPerTokenPaid;


    mapping(address => uint256) public rewards;


    uint256 private _totalSupply;


    mapping(address => uint256) private _balances;


    uint256 public minimumStakeAmount;


    uint256 public maximumStakeAmount;


    event Staked(address indexed user, uint256 amount);


    event Withdrawn(address indexed user, uint256 amount);


    event RewardPaid(address indexed user, uint256 reward);


    event RewardAdded(uint256 reward);


    event RewardsDurationUpdated(uint256 newDuration);


    constructor(
        address _stakingToken,
        address _rewardsToken,
        uint256 _rewardsDuration
    ) {
        require(_stakingToken != address(0), "StakingRewards: staking token cannot be zero address");
        require(_rewardsToken != address(0), "StakingRewards: rewards token cannot be zero address");
        require(_rewardsDuration > 0, "StakingRewards: rewards duration must be greater than zero");

        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
        rewardsDuration = _rewardsDuration;
        minimumStakeAmount = 1e18;
        maximumStakeAmount = 1000000e18;
    }


    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }


    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }


    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }


    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            (((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18) / _totalSupply);
    }


    function earned(address account) public view returns (uint256) {
        return
            ((_balances[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18) +
            rewards[account];
    }


    function getRewardForDuration() external view returns (uint256) {
        return rewardRate * rewardsDuration;
    }


    function stake(uint256 amount) external nonReentrant whenNotPaused updateReward(msg.sender) {
        require(amount > 0, "StakingRewards: cannot stake 0");
        require(amount >= minimumStakeAmount, "StakingRewards: amount below minimum stake");
        require(_balances[msg.sender] + amount <= maximumStakeAmount, "StakingRewards: amount exceeds maximum stake");

        _totalSupply += amount;
        _balances[msg.sender] += amount;

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount);
    }


    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "StakingRewards: cannot withdraw 0");
        require(_balances[msg.sender] >= amount, "StakingRewards: insufficient balance");

        _totalSupply -= amount;
        _balances[msg.sender] -= amount;

        stakingToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }


    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }


    function exit() external {
        withdraw(_balances[msg.sender]);
        getReward();
    }


    function notifyRewardAmount(uint256 reward) external onlyOwner updateReward(address(0)) {
        require(reward > 0, "StakingRewards: reward must be greater than zero");

        if (block.timestamp >= periodFinish) {
            rewardRate = reward / rewardsDuration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / rewardsDuration;
        }


        uint256 balance = rewardsToken.balanceOf(address(this));
        require(rewardRate <= balance / rewardsDuration, "StakingRewards: provided reward too high");

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;

        emit RewardAdded(reward);
    }


    function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {
        require(
            block.timestamp > periodFinish,
            "StakingRewards: previous rewards period must be complete before changing the duration"
        );
        require(_rewardsDuration > 0, "StakingRewards: rewards duration must be greater than zero");

        rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(rewardsDuration);
    }


    function setMinimumStakeAmount(uint256 _minimumStakeAmount) external onlyOwner {
        require(_minimumStakeAmount > 0, "StakingRewards: minimum stake amount must be greater than zero");
        minimumStakeAmount = _minimumStakeAmount;
    }


    function setMaximumStakeAmount(uint256 _maximumStakeAmount) external onlyOwner {
        require(_maximumStakeAmount > minimumStakeAmount, "StakingRewards: maximum stake amount must be greater than minimum");
        maximumStakeAmount = _maximumStakeAmount;
    }


    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        require(token != address(stakingToken), "StakingRewards: cannot withdraw staking token");
        IERC20(token).safeTransfer(owner(), amount);
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
    }


    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }
}
