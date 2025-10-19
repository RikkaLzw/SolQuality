
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract StakingRewardsContract is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 lastStakeTime;
    }

    struct PoolInfo {
        IERC20 stakingToken;
        IERC20 rewardToken;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accRewardPerShare;
        uint256 totalStaked;
        uint256 rewardPerBlock;
        uint256 startBlock;
        uint256 endBlock;
        uint256 minStakeAmount;
        uint256 lockupPeriod;
    }

    PoolInfo[] public poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    mapping(address => bool) public authorizedCallers;

    uint256 public totalAllocPoint;
    uint256 private constant ACC_PRECISION = 1e18;
    uint256 private constant MAX_POOLS = 50;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event Harvest(address indexed user, uint256 indexed pid, uint256 reward);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event PoolAdded(uint256 indexed pid, address stakingToken, address rewardToken, uint256 allocPoint);
    event PoolUpdated(uint256 indexed pid, uint256 allocPoint);
    event RewardPerBlockUpdated(uint256 indexed pid, uint256 rewardPerBlock);

    modifier validPool(uint256 _pid) {
        require(_pid < poolInfo.length, "Invalid pool ID");
        _;
    }

    modifier onlyAuthorized() {
        require(authorizedCallers[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }

    constructor() {}

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function addPool(
        IERC20 _stakingToken,
        IERC20 _rewardToken,
        uint256 _allocPoint,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _minStakeAmount,
        uint256 _lockupPeriod
    ) external onlyOwner {
        require(poolInfo.length < MAX_POOLS, "Too many pools");
        require(_startBlock < _endBlock, "Invalid block range");
        require(_startBlock >= block.number, "Start block in past");

        massUpdatePools();

        totalAllocPoint += _allocPoint;

        poolInfo.push(PoolInfo({
            stakingToken: _stakingToken,
            rewardToken: _rewardToken,
            allocPoint: _allocPoint,
            lastRewardBlock: _startBlock,
            accRewardPerShare: 0,
            totalStaked: 0,
            rewardPerBlock: _rewardPerBlock,
            startBlock: _startBlock,
            endBlock: _endBlock,
            minStakeAmount: _minStakeAmount,
            lockupPeriod: _lockupPeriod
        }));

        emit PoolAdded(poolInfo.length - 1, address(_stakingToken), address(_rewardToken), _allocPoint);
    }

    function setPool(uint256 _pid, uint256 _allocPoint) external onlyOwner validPool(_pid) {
        massUpdatePools();

        totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;

        emit PoolUpdated(_pid, _allocPoint);
    }

    function setRewardPerBlock(uint256 _pid, uint256 _rewardPerBlock) external onlyOwner validPool(_pid) {
        updatePool(_pid);
        poolInfo[_pid].rewardPerBlock = _rewardPerBlock;
        emit RewardPerBlockUpdated(_pid, _rewardPerBlock);
    }

    function getMultiplier(uint256 _from, uint256 _to, uint256 _endBlock) public pure returns (uint256) {
        if (_from >= _endBlock) return 0;
        return _to > _endBlock ? _endBlock - _from : _to - _from;
    }

    function pendingReward(uint256 _pid, address _user) external view validPool(_pid) returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        uint256 accRewardPerShare = pool.accRewardPerShare;

        if (block.number > pool.lastRewardBlock && pool.totalStaked > 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number, pool.endBlock);
            uint256 reward = (multiplier * pool.rewardPerBlock * pool.allocPoint) / totalAllocPoint;
            accRewardPerShare += (reward * ACC_PRECISION) / pool.totalStaked;
        }

        return (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;
    }

    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function updatePool(uint256 _pid) public validPool(_pid) {
        PoolInfo storage pool = poolInfo[_pid];

        if (block.number <= pool.lastRewardBlock) return;

        if (pool.totalStaked == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number, pool.endBlock);
        uint256 reward = (multiplier * pool.rewardPerBlock * pool.allocPoint) / totalAllocPoint;

        pool.accRewardPerShare += (reward * ACC_PRECISION) / pool.totalStaked;
        pool.lastRewardBlock = block.number;
    }

    function deposit(uint256 _pid, uint256 _amount) external nonReentrant whenNotPaused validPool(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        require(_amount >= pool.minStakeAmount, "Amount below minimum");
        require(block.number >= pool.startBlock, "Pool not started");
        require(block.number < pool.endBlock, "Pool ended");

        updatePool(_pid);

        uint256 pending = (user.amount * pool.accRewardPerShare) / ACC_PRECISION - user.rewardDebt;
        if (pending > 0) {
            _safeRewardTransfer(pool.rewardToken, msg.sender, pending);
            emit Harvest(msg.sender, _pid, pending);
        }

        if (_amount > 0) {
            pool.stakingToken.safeTransferFrom(msg.sender, address(this), _amount);
            user.amount += _amount;
            user.lastStakeTime = block.timestamp;
            pool.totalStaked += _amount;
        }

        user.rewardDebt = (user.amount * pool.accRewardPerShare) / ACC_PRECISION;

        emit Deposit(msg.sender, _pid, _amount);
    }

    function withdraw(uint256 _pid, uint256 _amount) external nonReentrant validPool(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        require(user.amount >= _amount, "Insufficient balance");
        require(
            block.timestamp >= user.lastStakeTime + pool.lockupPeriod,
            "Lockup period not met"
        );

        updatePool(_pid);

        uint256 pending = (user.amount * pool.accRewardPerShare) / ACC_PRECISION - user.rewardDebt;
        if (pending > 0) {
            _safeRewardTransfer(pool.rewardToken, msg.sender, pending);
            emit Harvest(msg.sender, _pid, pending);
        }

        if (_amount > 0) {
            user.amount -= _amount;
            pool.totalStaked -= _amount;
            pool.stakingToken.safeTransfer(msg.sender, _amount);
        }

        user.rewardDebt = (user.amount * pool.accRewardPerShare) / ACC_PRECISION;

        emit Withdraw(msg.sender, _pid, _amount);
    }

    function harvest(uint256 _pid) external nonReentrant whenNotPaused validPool(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        updatePool(_pid);

        uint256 pending = (user.amount * pool.accRewardPerShare) / ACC_PRECISION - user.rewardDebt;
        require(pending > 0, "No rewards to harvest");

        user.rewardDebt = (user.amount * pool.accRewardPerShare) / ACC_PRECISION;
        _safeRewardTransfer(pool.rewardToken, msg.sender, pending);

        emit Harvest(msg.sender, _pid, pending);
    }

    function emergencyWithdraw(uint256 _pid) external nonReentrant validPool(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 amount = user.amount;
        require(amount > 0, "No stake to withdraw");

        user.amount = 0;
        user.rewardDebt = 0;
        pool.totalStaked -= amount;

        pool.stakingToken.safeTransfer(msg.sender, amount);

        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    function _safeRewardTransfer(IERC20 _rewardToken, address _to, uint256 _amount) internal {
        uint256 rewardBalance = _rewardToken.balanceOf(address(this));
        if (_amount > rewardBalance) {
            _rewardToken.safeTransfer(_to, rewardBalance);
        } else {
            _rewardToken.safeTransfer(_to, _amount);
        }
    }

    function setAuthorizedCaller(address _caller, bool _authorized) external onlyOwner {
        authorizedCallers[_caller] = _authorized;
    }

    function emergencyRewardWithdraw(uint256 _pid, uint256 _amount) external onlyOwner validPool(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        pool.rewardToken.safeTransfer(owner(), _amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getUserInfo(uint256 _pid, address _user)
        external
        view
        validPool(_pid)
        returns (uint256 amount, uint256 rewardDebt, uint256 lastStakeTime)
    {
        UserInfo storage user = userInfo[_pid][_user];
        return (user.amount, user.rewardDebt, user.lastStakeTime);
    }

    function getPoolInfo(uint256 _pid)
        external
        view
        validPool(_pid)
        returns (
            address stakingToken,
            address rewardToken,
            uint256 allocPoint,
            uint256 lastRewardBlock,
            uint256 accRewardPerShare,
            uint256 totalStaked,
            uint256 rewardPerBlock,
            uint256 startBlock,
            uint256 endBlock,
            uint256 minStakeAmount,
            uint256 lockupPeriod
        )
    {
        PoolInfo storage pool = poolInfo[_pid];
        return (
            address(pool.stakingToken),
            address(pool.rewardToken),
            pool.allocPoint,
            pool.lastRewardBlock,
            pool.accRewardPerShare,
            pool.totalStaked,
            pool.rewardPerBlock,
            pool.startBlock,
            pool.endBlock,
            pool.minStakeAmount,
            pool.lockupPeriod
        );
    }
}
