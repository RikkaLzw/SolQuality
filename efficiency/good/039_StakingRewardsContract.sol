
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
    uint256 public totalSupply;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) private _balances;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 newRate);

    modifier updateReward(address account) {
        uint256 _rewardPerTokenStored = rewardPerToken();
        rewardPerTokenStored = _rewardPerTokenStored;
        lastUpdateTime = block.timestamp;

        if (account != address(0)) {
            uint256 _earned = earned(account);
            rewards[account] = _earned;
            userRewardPerTokenPaid[account] = _rewardPerTokenStored;
        }
        _;
    }

    constructor(
        address _stakingToken,
        address _rewardsToken,
        uint256 _rewardRate
    ) {
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
                (((block.timestamp - lastUpdateTime) * rewardRate * 1e18) / totalSupply);
        }
    }

    function earned(address account) public view returns (uint256) {
        uint256 balance = _balances[account];
        if (balance == 0) {
            return rewards[account];
        }

        unchecked {
            return ((balance * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18) +
                   rewards[account];
        }
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function stake(uint256 amount)
        external
        nonReentrant
        whenNotPaused
        updateReward(msg.sender)
    {
        require(amount > 0, "Cannot stake 0");

        uint256 _totalSupply = totalSupply;
        uint256 _balance = _balances[msg.sender];

        totalSupply = _totalSupply + amount;
        _balances[msg.sender] = _balance + amount;

        stakingToken.transferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount)
        external
        nonReentrant
        updateReward(msg.sender)
    {
        require(amount > 0, "Cannot withdraw 0");

        uint256 _balance = _balances[msg.sender];
        require(_balance >= amount, "Insufficient balance");

        totalSupply -= amount;
        _balances[msg.sender] = _balance - amount;

        stakingToken.transfer(msg.sender, amount);
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
            rewardsToken.transfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit() external {
        uint256 balance = _balances[msg.sender];
        if (balance > 0) {
            withdraw(balance);
        }
        getReward();
    }

    function setRewardRate(uint256 _rewardRate)
        external
        onlyOwner
        updateReward(address(0))
    {
        rewardRate = _rewardRate;
        emit RewardRateUpdated(_rewardRate);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function emergencyWithdraw() external onlyOwner {
        uint256 stakingBalance = stakingToken.balanceOf(address(this));
        uint256 rewardsBalance = rewardsToken.balanceOf(address(this));

        if (stakingBalance > 0) {
            stakingToken.transfer(owner(), stakingBalance);
        }
        if (rewardsBalance > 0) {
            rewardsToken.transfer(owner(), rewardsBalance);
        }
    }
}
