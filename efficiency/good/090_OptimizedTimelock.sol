
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract OptimizedTimelock is ReentrancyGuard, Ownable {
    struct TimeLock {
        uint256 amount;
        uint256 unlockTime;
        bool withdrawn;
    }

    mapping(address => TimeLock[]) private userLocks;
    mapping(address => uint256) private userLockCount;

    uint256 private constant MIN_LOCK_DURATION = 1 minutes;
    uint256 private constant MAX_LOCK_DURATION = 365 days;

    event TokensLocked(address indexed user, uint256 indexed lockId, uint256 amount, uint256 unlockTime);
    event TokensWithdrawn(address indexed user, uint256 indexed lockId, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    error InvalidLockDuration();
    error InvalidAmount();
    error LockNotFound();
    error TokensStillLocked();
    error AlreadyWithdrawn();
    error InsufficientBalance();
    error TransferFailed();

    constructor() {}

    function lockTokens(uint256 duration) external payable nonReentrant {
        if (msg.value == 0) revert InvalidAmount();
        if (duration < MIN_LOCK_DURATION || duration > MAX_LOCK_DURATION) {
            revert InvalidLockDuration();
        }

        uint256 unlockTime = block.timestamp + duration;
        uint256 lockId = userLockCount[msg.sender];

        userLocks[msg.sender].push(TimeLock({
            amount: msg.value,
            unlockTime: unlockTime,
            withdrawn: false
        }));

        unchecked {
            userLockCount[msg.sender] = lockId + 1;
        }

        emit TokensLocked(msg.sender, lockId, msg.value, unlockTime);
    }

    function withdrawTokens(uint256 lockId) external nonReentrant {
        TimeLock[] storage locks = userLocks[msg.sender];

        if (lockId >= locks.length) revert LockNotFound();

        TimeLock storage lock = locks[lockId];

        if (lock.withdrawn) revert AlreadyWithdrawn();
        if (block.timestamp < lock.unlockTime) revert TokensStillLocked();

        uint256 amount = lock.amount;
        lock.withdrawn = true;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit TokensWithdrawn(msg.sender, lockId, amount);
    }

    function batchWithdraw(uint256[] calldata lockIds) external nonReentrant {
        uint256 totalAmount;
        uint256 currentTime = block.timestamp;
        TimeLock[] storage locks = userLocks[msg.sender];
        uint256 locksLength = locks.length;

        for (uint256 i = 0; i < lockIds.length;) {
            uint256 lockId = lockIds[i];

            if (lockId >= locksLength) revert LockNotFound();

            TimeLock storage lock = locks[lockId];

            if (!lock.withdrawn && currentTime >= lock.unlockTime) {
                totalAmount += lock.amount;
                lock.withdrawn = true;
                emit TokensWithdrawn(msg.sender, lockId, lock.amount);
            }

            unchecked {
                ++i;
            }
        }

        if (totalAmount > 0) {
            (bool success, ) = payable(msg.sender).call{value: totalAmount}("");
            if (!success) revert TransferFailed();
        }
    }

    function getUserLocks(address user) external view returns (TimeLock[] memory) {
        return userLocks[user];
    }

    function getUserLockCount(address user) external view returns (uint256) {
        return userLockCount[user];
    }

    function getAvailableWithdrawals(address user) external view returns (uint256[] memory, uint256) {
        TimeLock[] storage locks = userLocks[user];
        uint256 locksLength = locks.length;
        uint256[] memory availableLockIds = new uint256[](locksLength);
        uint256 totalAvailable;
        uint256 availableCount;
        uint256 currentTime = block.timestamp;

        for (uint256 i = 0; i < locksLength;) {
            TimeLock storage lock = locks[i];
            if (!lock.withdrawn && currentTime >= lock.unlockTime) {
                availableLockIds[availableCount] = i;
                totalAvailable += lock.amount;
                unchecked {
                    ++availableCount;
                }
            }
            unchecked {
                ++i;
            }
        }

        uint256[] memory result = new uint256[](availableCount);
        for (uint256 i = 0; i < availableCount;) {
            result[i] = availableLockIds[i];
            unchecked {
                ++i;
            }
        }

        return (result, totalAvailable);
    }

    function getLockInfo(address user, uint256 lockId) external view returns (uint256 amount, uint256 unlockTime, bool withdrawn) {
        TimeLock[] storage locks = userLocks[user];
        if (lockId >= locks.length) revert LockNotFound();

        TimeLock storage lock = locks[lockId];
        return (lock.amount, lock.unlockTime, lock.withdrawn);
    }

    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) revert InsufficientBalance();

        (bool success, ) = payable(owner()).call{value: balance}("");
        if (!success) revert TransferFailed();

        emit EmergencyWithdraw(owner(), balance);
    }

    receive() external payable {
        revert("Direct transfers not allowed");
    }
}
