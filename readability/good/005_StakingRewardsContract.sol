
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


    mapping(address => uint256) public balances;


    uint256 public totalSupply;


    uint256 public minimumStakeAmount;


    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardAdded(uint256 reward);
    event RewardsDurationUpdated(uint256 newDuration);
    event MinimumStakeAmountUpdated(uint256 newAmount);


    constructor(
        address _stakingToken,
        address _rewardsToken,
        uint256 _rewardsDuration,
        uint256 _minimumStakeAmount
    ) {
        require(_stakingToken != address(0), "Invalid staking token address");
        require(_rewardsToken != address(0), "Invalid rewards token address");
        require(_rewardsDuration > 0, "Rewards duration must be greater than 0");

        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
        rewardsDuration = _rewardsDuration;
        minimumStakeAmount = _minimumStakeAmount;
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
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }

        return rewardPerTokenStored + (
            (lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18 / totalSupply
        );
    }


    function earned(address account) public view returns (uint256) {
        return (balances[account] * (rewardPerToken() - userRewardPerTokenPaid[account]) / 1e18) + rewards[account];
    }


    function getRewardForDuration() external view returns (uint256) {
        return rewardRate * rewardsDuration;
    }


    function stake(uint256 amount)
        external
        nonReentrant
        whenNotPaused
        updateReward(msg.sender)
    {
        require(amount > 0, "Cannot stake 0");
        require(amount >= minimumStakeAmount, "Amount below minimum stake");

        totalSupply += amount;
        balances[msg.sender] += amount;

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount);
    }


    function withdraw(uint256 amount)
        external
        nonReentrant
        updateReward(msg.sender)
    {
        require(amount > 0, "Cannot withdraw 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        totalSupply -= amount;
        balances[msg.sender] -= amount;

        stakingToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }


    function getReward()
        external
        nonReentrant
        updateReward(msg.sender)
    {
        uint256 reward = rewards[msg.sender];

        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }


    function exit() external {
        withdraw(balances[msg.sender]);
        getReward();
    }


    function notifyRewardAmount(uint256 reward)
        external
        onlyOwner
        updateReward(address(0))
    {
        require(reward > 0, "Reward must be greater than 0");

        if (block.timestamp >= periodFinish) {
            rewardRate = reward / rewardsDuration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / rewardsDuration;
        }


        uint256 balance = rewardsToken.balanceOf(address(this));
        require(rewardRate <= balance / rewardsDuration, "Provided reward too high");

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;

        emit RewardAdded(reward);
    }


    function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {
        require(
            block.timestamp > periodFinish,
            "Previous rewards period must be complete before changing the duration"
        );
        require(_rewardsDuration > 0, "Rewards duration must be greater than 0");

        rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(_rewardsDuration);
    }


    function setMinimumStakeAmount(uint256 _minimumStakeAmount) external onlyOwner {
        minimumStakeAmount = _minimumStakeAmount;
        emit MinimumStakeAmountUpdated(_minimumStakeAmount);
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
    }


    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        require(token != address(stakingToken), "Cannot withdraw staking token");
        IERC20(token).safeTransfer(owner(), amount);
    }
}
