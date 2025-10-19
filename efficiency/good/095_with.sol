
pragma solidity ^0.8.0;


contract OptimizedTimeLock {

    struct TimeLockInfo {
        uint128 amount;
        uint64 releaseTime;
        uint64 lockDuration;
    }


    event TokensLocked(address indexed user, uint256 amount, uint256 releaseTime);
    event TokensReleased(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);


    address public immutable owner;
    uint256 public immutable minLockDuration;
    uint256 public immutable maxLockDuration;


    mapping(address => TimeLockInfo) private _locks;


    uint256 private constant SECONDS_IN_DAY = 86400;


    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier validDuration(uint256 duration) {
        require(duration >= minLockDuration && duration <= maxLockDuration, "Invalid duration");
        _;
    }

    constructor(uint256 _minLockDuration, uint256 _maxLockDuration) {
        require(_minLockDuration > 0 && _maxLockDuration > _minLockDuration, "Invalid durations");
        owner = msg.sender;
        minLockDuration = _minLockDuration;
        maxLockDuration = _maxLockDuration;
    }


    function lockTokens(uint256 duration) external payable validDuration(duration) {
        require(msg.value > 0, "Amount must be greater than 0");


        TimeLockInfo storage lockInfo = _locks[msg.sender];
        require(lockInfo.amount == 0, "Already has active lock");


        uint256 releaseTime = block.timestamp + duration;
        require(releaseTime > block.timestamp, "Overflow in release time");


        lockInfo.amount = uint128(msg.value);
        lockInfo.releaseTime = uint64(releaseTime);
        lockInfo.lockDuration = uint64(duration);

        emit TokensLocked(msg.sender, msg.value, releaseTime);
    }


    function releaseTokens() external {

        TimeLockInfo storage lockInfo = _locks[msg.sender];
        uint256 amount = lockInfo.amount;

        require(amount > 0, "No locked tokens");
        require(block.timestamp >= lockInfo.releaseTime, "Tokens still locked");


        delete _locks[msg.sender];


        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");

        emit TokensReleased(msg.sender, amount);
    }


    function getLockInfo(address user) external view returns (
        uint256 amount,
        uint256 releaseTime,
        uint256 lockDuration,
        bool isActive
    ) {

        TimeLockInfo memory lockInfo = _locks[user];
        return (
            lockInfo.amount,
            lockInfo.releaseTime,
            lockInfo.lockDuration,
            lockInfo.amount > 0
        );
    }


    function canRelease(address user) external view returns (bool) {
        TimeLockInfo memory lockInfo = _locks[user];
        return lockInfo.amount > 0 && block.timestamp >= lockInfo.releaseTime;
    }


    function getRemainingTime(address user) external view returns (uint256) {
        TimeLockInfo memory lockInfo = _locks[user];
        if (lockInfo.amount == 0 || block.timestamp >= lockInfo.releaseTime) {
            return 0;
        }
        return lockInfo.releaseTime - block.timestamp;
    }


    function emergencyWithdraw(address user) external onlyOwner {
        TimeLockInfo storage lockInfo = _locks[user];
        uint256 amount = lockInfo.amount;

        require(amount > 0, "No locked tokens");


        delete _locks[user];


        (bool success, ) = payable(user).call{value: amount}("");
        require(success, "Transfer failed");

        emit EmergencyWithdraw(user, amount);
    }


    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }


    function batchGetLockInfo(address[] memory users) external view returns (
        uint256[] memory amounts,
        uint256[] memory releaseTimes,
        bool[] memory canReleaseFlags
    ) {
        uint256 length = users.length;
        amounts = new uint256[](length);
        releaseTimes = new uint256[](length);
        canReleaseFlags = new bool[](length);


        uint256 currentTime = block.timestamp;

        for (uint256 i = 0; i < length;) {
            TimeLockInfo memory lockInfo = _locks[users[i]];
            amounts[i] = lockInfo.amount;
            releaseTimes[i] = lockInfo.releaseTime;
            canReleaseFlags[i] = lockInfo.amount > 0 && currentTime >= lockInfo.releaseTime;

            unchecked {
                ++i;
            }
        }
    }
}
