
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract StakingRewardsContract is ReentrancyGuard, Ownable, Pausable {
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardsToken;

    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public totalStaked;
    uint256 public rewardsDuration = 7 days;
    uint256 public periodFinish;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public balances;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardAdded(uint256 reward);
    event RewardsDurationUpdated(uint256 newDuration);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    constructor(
        address _stakingToken,
        address _rewardsToken
    ) {
        require(_stakingToken != address(0), "StakingRewards: staking token cannot be zero address");
        require(_rewardsToken != address(0), "StakingRewards: rewards token cannot be zero address");

        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            (((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18) / totalStaked);
    }

    function earned(address account) public view returns (uint256) {
        return
            ((balances[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18) +
            rewards[account];
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate * rewardsDuration;
    }

    function stake(uint256 amount) external nonReentrant whenNotPaused updateReward(msg.sender) {
        require(amount > 0, "StakingRewards: cannot stake 0 tokens");
        require(
            stakingToken.balanceOf(msg.sender) >= amount,
            "StakingRewards: insufficient balance to stake"
        );

        totalStaked += amount;
        balances[msg.sender] += amount;

        bool success = stakingToken.transferFrom(msg.sender, address(this), amount);
        require(success, "StakingRewards: stake transfer failed");

        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "StakingRewards: cannot withdraw 0 tokens");
        require(balances[msg.sender] >= amount, "StakingRewards: insufficient staked balance");

        totalStaked -= amount;
        balances[msg.sender] -= amount;

        bool success = stakingToken.transfer(msg.sender, amount);
        require(success, "StakingRewards: withdraw transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;

            require(
                rewardsToken.balanceOf(address(this)) >= reward,
                "StakingRewards: insufficient reward tokens in contract"
            );

            bool success = rewardsToken.transfer(msg.sender, reward);
            require(success, "StakingRewards: reward transfer failed");

            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit() external {
        withdraw(balances[msg.sender]);
        getReward();
    }

    function notifyRewardAmount(uint256 reward) external onlyOwner updateReward(address(0)) {
        require(reward > 0, "StakingRewards: reward amount must be greater than 0");

        if (block.timestamp >= periodFinish) {
            rewardRate = reward / rewardsDuration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / rewardsDuration;
        }

        require(
            rewardRate > 0,
            "StakingRewards: reward rate cannot be 0"
        );

        uint256 balance = rewardsToken.balanceOf(address(this));
        require(
            rewardRate <= balance / rewardsDuration,
            "StakingRewards: provided reward too high"
        );

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;

        emit RewardAdded(reward);
    }

    function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {
        require(
            block.timestamp > periodFinish,
            "StakingRewards: previous rewards period must be complete before changing duration"
        );
        require(
            _rewardsDuration > 0,
            "StakingRewards: rewards duration must be greater than 0"
        );

        rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(rewardsDuration);
    }

    function emergencyWithdraw() external nonReentrant {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "StakingRewards: no tokens to withdraw");

        totalStaked -= amount;
        balances[msg.sender] = 0;
        rewards[msg.sender] = 0;
        userRewardPerTokenPaid[msg.sender] = 0;

        bool success = stakingToken.transfer(msg.sender, amount);
        require(success, "StakingRewards: emergency withdraw transfer failed");

        emit EmergencyWithdraw(msg.sender, amount);
    }

    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        require(
            tokenAddress != address(stakingToken),
            "StakingRewards: cannot withdraw staking token"
        );
        require(
            tokenAddress != address(rewardsToken) ||
            (tokenAddress == address(rewardsToken) &&
             block.timestamp > periodFinish &&
             totalStaked == 0),
            "StakingRewards: cannot withdraw reward token while rewards are active or users are staked"
        );

        IERC20(tokenAddress).transfer(owner(), tokenAmount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
