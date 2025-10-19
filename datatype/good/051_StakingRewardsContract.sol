
pragma solidity ^0.8.0;

contract StakingRewardsContract {

    uint256 public totalStaked;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint32 public stakingDuration;
    uint32 public lockPeriod;

    address public owner;
    address public rewardToken;
    bool public paused;


    bytes32 public contractHash;


    mapping(address => uint256) public stakedBalances;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint32) public stakingTimestamp;
    mapping(address => bool) public isStaker;


    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 newRate);
    event ContractPaused(bool isPaused);


    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier notPaused() {
        require(!paused, "Contract paused");
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
        address _rewardToken,
        uint256 _rewardRate,
        uint32 _stakingDuration,
        uint32 _lockPeriod
    ) {
        owner = msg.sender;
        rewardToken = _rewardToken;
        rewardRate = _rewardRate;
        stakingDuration = _stakingDuration;
        lockPeriod = _lockPeriod;
        lastUpdateTime = block.timestamp;
        paused = false;


        contractHash = keccak256(abi.encodePacked(
            address(this),
            _rewardToken,
            _rewardRate,
            block.timestamp
        ));
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }

        return rewardPerTokenStored + (
            ((block.timestamp - lastUpdateTime) * rewardRate * 1e18) / totalStaked
        );
    }

    function earned(address account) public view returns (uint256) {
        return (stakedBalances[account] *
            (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18 + rewards[account];
    }

    function stake(uint256 amount) external notPaused updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        require(amount <= type(uint256).max - totalStaked, "Overflow protection");


        (bool success, bytes memory data) = rewardToken.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)",
            msg.sender, address(this), amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer failed");

        totalStaked += amount;
        stakedBalances[msg.sender] += amount;
        stakingTimestamp[msg.sender] = uint32(block.timestamp);
        isStaker[msg.sender] = true;

        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external notPaused updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        require(stakedBalances[msg.sender] >= amount, "Insufficient balance");
        require(
            block.timestamp >= stakingTimestamp[msg.sender] + lockPeriod,
            "Still in lock period"
        );

        totalStaked -= amount;
        stakedBalances[msg.sender] -= amount;

        if (stakedBalances[msg.sender] == 0) {
            isStaker[msg.sender] = false;
        }


        (bool success, bytes memory data) = rewardToken.call(
            abi.encodeWithSignature("transfer(address,uint256)", msg.sender, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    function claimReward() external notPaused updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        require(reward > 0, "No reward available");

        rewards[msg.sender] = 0;


        (bool success, bytes memory data) = rewardToken.call(
            abi.encodeWithSignature("transfer(address,uint256)", msg.sender, reward)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Reward transfer failed");

        emit RewardPaid(msg.sender, reward);
    }

    function exit() external {
        withdraw(stakedBalances[msg.sender]);
        claimReward();
    }


    function setRewardRate(uint256 _rewardRate) external onlyOwner updateReward(address(0)) {
        rewardRate = _rewardRate;
        emit RewardRateUpdated(_rewardRate);
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit ContractPaused(_paused);
    }

    function emergencyWithdraw() external onlyOwner {
        (bool success, bytes memory data) = rewardToken.call(
            abi.encodeWithSignature("transfer(address,uint256)",
            owner, getContractBalance())
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Emergency withdraw failed");
    }


    function getContractBalance() public view returns (uint256) {
        (bool success, bytes memory data) = rewardToken.staticcall(
            abi.encodeWithSignature("balanceOf(address)", address(this))
        );
        require(success, "Balance query failed");
        return abi.decode(data, (uint256));
    }

    function getStakerInfo(address account) external view returns (
        uint256 stakedAmount,
        uint256 earnedReward,
        uint32 stakeTime,
        bool canWithdraw
    ) {
        stakedAmount = stakedBalances[account];
        earnedReward = earned(account);
        stakeTime = stakingTimestamp[account];
        canWithdraw = block.timestamp >= stakeTime + lockPeriod;
    }

    function getRemainingLockTime(address account) external view returns (uint32) {
        uint32 stakeTime = stakingTimestamp[account];
        if (block.timestamp >= stakeTime + lockPeriod) {
            return 0;
        }
        return uint32(stakeTime + lockPeriod - block.timestamp);
    }
}
