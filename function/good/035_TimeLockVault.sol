
pragma solidity ^0.8.0;

contract TimeLockVault {
    struct LockedFunds {
        uint256 amount;
        uint256 unlockTime;
        bool withdrawn;
    }

    mapping(address => LockedFunds[]) private userLocks;
    mapping(address => uint256) private userLockCount;

    event FundsLocked(address indexed user, uint256 amount, uint256 unlockTime, uint256 lockId);
    event FundsWithdrawn(address indexed user, uint256 amount, uint256 lockId);

    error InsufficientBalance();
    error FundsStillLocked();
    error AlreadyWithdrawn();
    error InvalidLockId();
    error ZeroAmount();
    error InvalidUnlockTime();

    function lockFunds(uint256 _unlockTime) external payable {
        if (msg.value == 0) revert ZeroAmount();
        if (_unlockTime <= block.timestamp) revert InvalidUnlockTime();

        uint256 lockId = userLockCount[msg.sender];

        userLocks[msg.sender].push(LockedFunds({
            amount: msg.value,
            unlockTime: _unlockTime,
            withdrawn: false
        }));

        userLockCount[msg.sender]++;

        emit FundsLocked(msg.sender, msg.value, _unlockTime, lockId);
    }

    function withdrawFunds(uint256 _lockId) external {
        if (_lockId >= userLockCount[msg.sender]) revert InvalidLockId();

        LockedFunds storage lock = userLocks[msg.sender][_lockId];

        if (lock.withdrawn) revert AlreadyWithdrawn();
        if (block.timestamp < lock.unlockTime) revert FundsStillLocked();

        lock.withdrawn = true;
        uint256 amount = lock.amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert InsufficientBalance();

        emit FundsWithdrawn(msg.sender, amount, _lockId);
    }

    function getLockInfo(address _user, uint256 _lockId) external view returns (uint256, uint256, bool) {
        if (_lockId >= userLockCount[_user]) revert InvalidLockId();

        LockedFunds memory lock = userLocks[_user][_lockId];
        return (lock.amount, lock.unlockTime, lock.withdrawn);
    }

    function getUserLockCount(address _user) external view returns (uint256) {
        return userLockCount[_user];
    }

    function getTimeRemaining(address _user, uint256 _lockId) external view returns (uint256) {
        if (_lockId >= userLockCount[_user]) revert InvalidLockId();

        LockedFunds memory lock = userLocks[_user][_lockId];

        if (block.timestamp >= lock.unlockTime) {
            return 0;
        }

        return lock.unlockTime - block.timestamp;
    }

    function isUnlocked(address _user, uint256 _lockId) external view returns (bool) {
        if (_lockId >= userLockCount[_user]) revert InvalidLockId();

        return block.timestamp >= userLocks[_user][_lockId].unlockTime;
    }
}
