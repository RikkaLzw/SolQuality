
pragma solidity ^0.8.0;

contract TimeLockContract {
    struct LockedFunds {
        uint256 amount;
        uint256 unlockTime;
        bool withdrawn;
    }

    mapping(address => LockedFunds[]) private userLocks;
    mapping(address => uint256) private userLockCount;

    event FundsLocked(address indexed user, uint256 amount, uint256 unlockTime, uint256 lockId);
    event FundsWithdrawn(address indexed user, uint256 amount, uint256 lockId);

    error InsufficientAmount();
    error InvalidUnlockTime();
    error FundsStillLocked();
    error AlreadyWithdrawn();
    error InvalidLockId();
    error TransferFailed();

    function lockFunds(uint256 unlockTime) external payable {
        if (msg.value == 0) revert InsufficientAmount();
        if (unlockTime <= block.timestamp) revert InvalidUnlockTime();

        uint256 lockId = userLockCount[msg.sender];

        userLocks[msg.sender].push(LockedFunds({
            amount: msg.value,
            unlockTime: unlockTime,
            withdrawn: false
        }));

        userLockCount[msg.sender]++;

        emit FundsLocked(msg.sender, msg.value, unlockTime, lockId);
    }

    function withdrawFunds(uint256 lockId) external {
        if (lockId >= userLockCount[msg.sender]) revert InvalidLockId();

        LockedFunds storage lock = userLocks[msg.sender][lockId];

        if (lock.withdrawn) revert AlreadyWithdrawn();
        if (block.timestamp < lock.unlockTime) revert FundsStillLocked();

        lock.withdrawn = true;
        uint256 amount = lock.amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit FundsWithdrawn(msg.sender, amount, lockId);
    }

    function getLockInfo(address user, uint256 lockId) external view returns (uint256, uint256, bool) {
        if (lockId >= userLockCount[user]) revert InvalidLockId();

        LockedFunds memory lock = userLocks[user][lockId];
        return (lock.amount, lock.unlockTime, lock.withdrawn);
    }

    function getUserLockCount(address user) external view returns (uint256) {
        return userLockCount[user];
    }

    function getTimeRemaining(address user, uint256 lockId) external view returns (uint256) {
        if (lockId >= userLockCount[user]) revert InvalidLockId();

        LockedFunds memory lock = userLocks[user][lockId];

        if (block.timestamp >= lock.unlockTime) {
            return 0;
        }

        return lock.unlockTime - block.timestamp;
    }

    function canWithdraw(address user, uint256 lockId) external view returns (bool) {
        if (lockId >= userLockCount[user]) return false;

        LockedFunds memory lock = userLocks[user][lockId];
        return !lock.withdrawn && block.timestamp >= lock.unlockTime;
    }
}
