
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

    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public totalStaked;
    uint256 public rewardsDuration = 7 days;
    uint256 public periodFinish;
    uint256 public minimumStakeAmount = 1e18;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public balances;


    event Staked(address indexed user, uint256 amount, uint256 timestamp);
    event Withdrawn(address indexed user, uint256 amount, uint256 timestamp);
    event RewardPaid(address indexed user, uint256 reward, uint256 timestamp);
    event RewardAdded(uint256 reward, uint256 duration, uint256 timestamp);
    event RewardRateUpdated(uint256 newRate, uint256 timestamp);
    event MinimumStakeAmountUpdated(uint256 newAmount, uint256 timestamp);
    event EmergencyWithdraw(address indexed user, uint256 amount, uint256 timestamp);


    error InsufficientStakeAmount(uint256 provided, uint256 required);
    error InsufficientBalance(uint256 requested, uint256 available);
    error InvalidAmount(uint256 amount);
    error InvalidDuration(uint256 duration);
    error RewardPeriodNotFinished(uint256 currentTime, uint256 periodFinish);
    error NoRewardsAvailable();
    error TransferFailed();

    constructor(
        address _stakingToken,
        address _rewardsToken,
        address _owner
    ) {
        require(_stakingToken != address(0), "StakingRewardsContract: Invalid staking token address");
        require(_rewardsToken != address(0), "StakingRewardsContract: Invalid rewards token address");
        require(_owner != address(0), "StakingRewardsContract: Invalid owner address");

        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
        _transferOwnership(_owner);
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


    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored +
            (((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18) / totalStaked);
    }

    function earned(address account) public view returns (uint256) {
        return (balances[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18 + rewards[account];
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate * rewardsDuration;
    }


    function stake(uint256 amount) external nonReentrant whenNotPaused updateReward(msg.sender) {
        if (amount == 0) {
            revert InvalidAmount(amount);
        }
        if (amount < minimumStakeAmount) {
            revert InsufficientStakeAmount(amount, minimumStakeAmount);
        }

        totalStaked += amount;
        balances[msg.sender] += amount;

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount, block.timestamp);
    }

    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        if (amount == 0) {
            revert InvalidAmount(amount);
        }
        if (amount > balances[msg.sender]) {
            revert InsufficientBalance(amount, balances[msg.sender]);
        }

        totalStaked -= amount;
        balances[msg.sender] -= amount;

        stakingToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount, block.timestamp);
    }

    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward == 0) {
            revert NoRewardsAvailable();
        }

        rewards[msg.sender] = 0;
        rewardsToken.safeTransfer(msg.sender, reward);

        emit RewardPaid(msg.sender, reward, block.timestamp);
    }

    function exit() external {
        withdraw(balances[msg.sender]);
        getReward();
    }


    function emergencyWithdraw() external nonReentrant {
        uint256 amount = balances[msg.sender];
        if (amount == 0) {
            revert InvalidAmount(amount);
        }

        totalStaked -= amount;
        balances[msg.sender] = 0;
        rewards[msg.sender] = 0;
        userRewardPerTokenPaid[msg.sender] = 0;

        stakingToken.safeTransfer(msg.sender, amount);

        emit EmergencyWithdraw(msg.sender, amount, block.timestamp);
    }


    function notifyRewardAmount(uint256 reward) external onlyOwner updateReward(address(0)) {
        if (reward == 0) {
            revert InvalidAmount(reward);
        }

        if (block.timestamp >= periodFinish) {
            rewardRate = reward / rewardsDuration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / rewardsDuration;
        }


        uint256 balance = rewardsToken.balanceOf(address(this));
        require(rewardRate <= balance / rewardsDuration, "StakingRewardsContract: Provided reward too high");

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;

        emit RewardAdded(reward, rewardsDuration, block.timestamp);
        emit RewardRateUpdated(rewardRate, block.timestamp);
    }

    function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {
        if (_rewardsDuration == 0) {
            revert InvalidDuration(_rewardsDuration);
        }
        if (block.timestamp <= periodFinish) {
            revert RewardPeriodNotFinished(block.timestamp, periodFinish);
        }

        rewardsDuration = _rewardsDuration;
    }

    function setMinimumStakeAmount(uint256 _minimumStakeAmount) external onlyOwner {
        minimumStakeAmount = _minimumStakeAmount;
        emit MinimumStakeAmountUpdated(_minimumStakeAmount, block.timestamp);
    }

    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        require(tokenAddress != address(stakingToken), "StakingRewardsContract: Cannot withdraw the staking token");
        IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
