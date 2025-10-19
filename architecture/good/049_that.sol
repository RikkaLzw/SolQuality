
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract StakingRewardsContract is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;


    uint256 public constant PRECISION = 1e18;
    uint256 public constant MIN_STAKE_AMOUNT = 1e18;
    uint256 public constant MAX_REWARD_RATE = 1000;
    uint256 public constant SECONDS_PER_DAY = 86400;


    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;

    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public totalStaked;
    uint256 public rewardsDuration;
    uint256 public periodFinish;


    struct UserInfo {
        uint256 stakedAmount;
        uint256 userRewardPerTokenPaid;
        uint256 rewards;
        uint256 lastStakeTime;
    }

    mapping(address => UserInfo) public userInfo;


    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 newRate);
    event RewardsDurationUpdated(uint256 newDuration);


    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            UserInfo storage user = userInfo[account];
            user.rewards = earned(account);
            user.userRewardPerTokenPaid = rewardPerTokenStored;
        }
        _;
    }

    modifier onlyValidAmount(uint256 amount) {
        require(amount >= MIN_STAKE_AMOUNT, "Amount too small");
        _;
    }

    modifier onlyStaker(address account) {
        require(userInfo[account].stakedAmount > 0, "Not a staker");
        _;
    }


    constructor(
        address _stakingToken,
        address _rewardToken,
        uint256 _rewardRate,
        uint256 _rewardsDuration
    ) {
        require(_stakingToken != address(0), "Invalid staking token");
        require(_rewardToken != address(0), "Invalid reward token");
        require(_rewardRate <= MAX_REWARD_RATE, "Reward rate too high");
        require(_rewardsDuration > 0, "Invalid duration");

        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        rewardRate = _rewardRate;
        rewardsDuration = _rewardsDuration;
        lastUpdateTime = block.timestamp;
    }


    function stake(uint256 amount)
        external
        nonReentrant
        whenNotPaused
        onlyValidAmount(amount)
        updateReward(msg.sender)
    {
        UserInfo storage user = userInfo[msg.sender];

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        user.stakedAmount += amount;
        user.lastStakeTime = block.timestamp;
        totalStaked += amount;

        emit Staked(msg.sender, amount);
    }


    function withdraw(uint256 amount)
        external
        nonReentrant
        onlyStaker(msg.sender)
        updateReward(msg.sender)
    {
        UserInfo storage user = userInfo[msg.sender];
        require(amount <= user.stakedAmount, "Insufficient staked amount");

        user.stakedAmount -= amount;
        totalStaked -= amount;

        stakingToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }


    function claimReward()
        external
        nonReentrant
        onlyStaker(msg.sender)
        updateReward(msg.sender)
    {
        UserInfo storage user = userInfo[msg.sender];
        uint256 reward = user.rewards;

        if (reward > 0) {
            user.rewards = 0;
            rewardToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }


    function exit() external {
        UserInfo storage user = userInfo[msg.sender];
        uint256 stakedAmount = user.stakedAmount;

        if (stakedAmount > 0) {
            withdraw(stakedAmount);
        }
        claimReward();
    }


    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }

        return rewardPerTokenStored +
            ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * PRECISION) / totalStaked;
    }


    function earned(address account) public view returns (uint256) {
        UserInfo memory user = userInfo[account];
        return (user.stakedAmount * (rewardPerToken() - user.userRewardPerTokenPaid)) / PRECISION + user.rewards;
    }


    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }


    function getUserInfo(address account) external view returns (
        uint256 stakedAmount,
        uint256 earnedRewards,
        uint256 lastStakeTime
    ) {
        UserInfo memory user = userInfo[account];
        return (
            user.stakedAmount,
            earned(account),
            user.lastStakeTime
        );
    }




    function setRewardRate(uint256 _rewardRate)
        external
        onlyOwner
        updateReward(address(0))
    {
        require(_rewardRate <= MAX_REWARD_RATE, "Reward rate too high");
        rewardRate = _rewardRate;
        emit RewardRateUpdated(_rewardRate);
    }


    function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {
        require(block.timestamp > periodFinish, "Previous rewards period not finished");
        require(_rewardsDuration > 0, "Invalid duration");

        rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(_rewardsDuration);
    }


    function notifyRewardAmount(uint256 reward)
        external
        onlyOwner
        updateReward(address(0))
    {
        if (block.timestamp >= periodFinish) {
            rewardRate = reward / rewardsDuration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / rewardsDuration;
        }

        require(rewardRate > 0, "Reward rate must be greater than 0");
        require(
            rewardRate <= rewardToken.balanceOf(address(this)) / rewardsDuration,
            "Provided reward too high"
        );

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;
    }


    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
    }
}
