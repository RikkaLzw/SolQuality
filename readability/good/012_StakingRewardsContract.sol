
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


    uint256 public annualPercentageYield;


    uint256 public minimumStakeAmount;


    uint256 public lockupPeriod;


    uint256 public totalStakedAmount;


    uint256 public rewardPoolBalance;


    struct StakeInfo {
        uint256 stakedAmount;
        uint256 stakeTimestamp;
        uint256 lastRewardTimestamp;
        uint256 accumulatedRewards;
    }


    mapping(address => StakeInfo) public userStakeInfo;


    address[] public stakedUsers;


    mapping(address => bool) public hasStaked;


    event TokensStaked(address indexed user, uint256 amount, uint256 timestamp);
    event TokensUnstaked(address indexed user, uint256 amount, uint256 timestamp);
    event RewardsClaimed(address indexed user, uint256 rewardAmount, uint256 timestamp);
    event RewardPoolFunded(uint256 amount, uint256 timestamp);
    event AnnualPercentageYieldUpdated(uint256 oldAPY, uint256 newAPY);
    event MinimumStakeAmountUpdated(uint256 oldAmount, uint256 newAmount);
    event LockupPeriodUpdated(uint256 oldPeriod, uint256 newPeriod);


    constructor(
        address _stakingToken,
        address _rewardsToken,
        uint256 _annualPercentageYield,
        uint256 _minimumStakeAmount,
        uint256 _lockupPeriod
    ) {
        require(_stakingToken != address(0), "StakingRewardsContract: Invalid staking token address");
        require(_rewardsToken != address(0), "StakingRewardsContract: Invalid rewards token address");
        require(_annualPercentageYield > 0 && _annualPercentageYield <= 10000, "StakingRewardsContract: Invalid APY");
        require(_minimumStakeAmount > 0, "StakingRewardsContract: Invalid minimum stake amount");

        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
        annualPercentageYield = _annualPercentageYield;
        minimumStakeAmount = _minimumStakeAmount;
        lockupPeriod = _lockupPeriod;
    }


    function stakeTokens(uint256 _amount) external nonReentrant whenNotPaused {
        require(_amount >= minimumStakeAmount, "StakingRewardsContract: Amount below minimum stake");
        require(stakingToken.balanceOf(msg.sender) >= _amount, "StakingRewardsContract: Insufficient balance");


        if (userStakeInfo[msg.sender].stakedAmount > 0) {
            _updateUserRewards(msg.sender);
        } else {

            stakedUsers.push(msg.sender);
            hasStaked[msg.sender] = true;
        }


        stakingToken.safeTransferFrom(msg.sender, address(this), _amount);


        userStakeInfo[msg.sender].stakedAmount += _amount;
        userStakeInfo[msg.sender].stakeTimestamp = block.timestamp;
        userStakeInfo[msg.sender].lastRewardTimestamp = block.timestamp;


        totalStakedAmount += _amount;

        emit TokensStaked(msg.sender, _amount, block.timestamp);
    }


    function unstakeTokens(uint256 _amount) external nonReentrant whenNotPaused {
        StakeInfo storage userStake = userStakeInfo[msg.sender];

        require(userStake.stakedAmount >= _amount, "StakingRewardsContract: Insufficient staked amount");
        require(
            block.timestamp >= userStake.stakeTimestamp + lockupPeriod,
            "StakingRewardsContract: Tokens still locked"
        );


        _updateUserRewards(msg.sender);


        userStake.stakedAmount -= _amount;


        if (userStake.stakedAmount == 0) {
            hasStaked[msg.sender] = false;
            _removeUserFromList(msg.sender);
        }


        totalStakedAmount -= _amount;


        stakingToken.safeTransfer(msg.sender, _amount);

        emit TokensUnstaked(msg.sender, _amount, block.timestamp);
    }


    function claimRewards() external nonReentrant whenNotPaused {
        require(userStakeInfo[msg.sender].stakedAmount > 0, "StakingRewardsContract: No staked tokens");


        _updateUserRewards(msg.sender);

        uint256 rewardAmount = userStakeInfo[msg.sender].accumulatedRewards;
        require(rewardAmount > 0, "StakingRewardsContract: No rewards to claim");
        require(rewardPoolBalance >= rewardAmount, "StakingRewardsContract: Insufficient reward pool");


        userStakeInfo[msg.sender].accumulatedRewards = 0;


        rewardPoolBalance -= rewardAmount;


        rewardsToken.safeTransfer(msg.sender, rewardAmount);

        emit RewardsClaimed(msg.sender, rewardAmount, block.timestamp);
    }


    function calculatePendingRewards(address _user) external view returns (uint256) {
        StakeInfo memory userStake = userStakeInfo[_user];

        if (userStake.stakedAmount == 0) {
            return userStake.accumulatedRewards;
        }

        uint256 timeDifference = block.timestamp - userStake.lastRewardTimestamp;
        uint256 newRewards = (userStake.stakedAmount * annualPercentageYield * timeDifference) / (365 days * 10000);

        return userStake.accumulatedRewards + newRewards;
    }


    function getUserStakeInfo(address _user) external view returns (
        uint256 stakedAmount,
        uint256 stakeTimestamp,
        uint256 pendingRewards,
        bool canUnstake
    ) {
        StakeInfo memory userStake = userStakeInfo[_user];

        stakedAmount = userStake.stakedAmount;
        stakeTimestamp = userStake.stakeTimestamp;
        pendingRewards = this.calculatePendingRewards(_user);
        canUnstake = block.timestamp >= userStake.stakeTimestamp + lockupPeriod;
    }


    function getStakedUsersCount() external view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < stakedUsers.length; i++) {
            if (hasStaked[stakedUsers[i]]) {
                count++;
            }
        }
        return count;
    }


    function fundRewardPool(uint256 _amount) external onlyOwner {
        require(_amount > 0, "StakingRewardsContract: Amount must be greater than 0");

        rewardsToken.safeTransferFrom(msg.sender, address(this), _amount);
        rewardPoolBalance += _amount;

        emit RewardPoolFunded(_amount, block.timestamp);
    }


    function updateAnnualPercentageYield(uint256 _newAPY) external onlyOwner {
        require(_newAPY > 0 && _newAPY <= 10000, "StakingRewardsContract: Invalid APY");

        uint256 oldAPY = annualPercentageYield;
        annualPercentageYield = _newAPY;

        emit AnnualPercentageYieldUpdated(oldAPY, _newAPY);
    }


    function updateMinimumStakeAmount(uint256 _newMinimumAmount) external onlyOwner {
        require(_newMinimumAmount > 0, "StakingRewardsContract: Invalid minimum amount");

        uint256 oldAmount = minimumStakeAmount;
        minimumStakeAmount = _newMinimumAmount;

        emit MinimumStakeAmountUpdated(oldAmount, _newMinimumAmount);
    }


    function updateLockupPeriod(uint256 _newLockupPeriod) external onlyOwner {
        uint256 oldPeriod = lockupPeriod;
        lockupPeriod = _newLockupPeriod;

        emit LockupPeriodUpdated(oldPeriod, _newLockupPeriod);
    }


    function pauseContract() external onlyOwner {
        _pause();
    }


    function unpauseContract() external onlyOwner {
        _unpause();
    }


    function emergencyWithdraw(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).safeTransfer(owner(), _amount);
    }


    function _updateUserRewards(address _user) internal {
        StakeInfo storage userStake = userStakeInfo[_user];

        if (userStake.stakedAmount > 0) {
            uint256 timeDifference = block.timestamp - userStake.lastRewardTimestamp;
            uint256 newRewards = (userStake.stakedAmount * annualPercentageYield * timeDifference) / (365 days * 10000);

            userStake.accumulatedRewards += newRewards;
            userStake.lastRewardTimestamp = block.timestamp;
        }
    }


    function _removeUserFromList(address _user) internal {
        for (uint256 i = 0; i < stakedUsers.length; i++) {
            if (stakedUsers[i] == _user) {
                stakedUsers[i] = stakedUsers[stakedUsers.length - 1];
                stakedUsers.pop();
                break;
            }
        }
    }
}
