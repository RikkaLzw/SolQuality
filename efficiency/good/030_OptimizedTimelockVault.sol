
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract OptimizedTimelockVault is ReentrancyGuard, Ownable {
    struct TimeLock {
        uint256 amount;
        uint256 unlockTime;
        bool withdrawn;
    }


    struct UserInfo {
        uint128 totalLocked;
        uint128 lockCount;
    }

    mapping(address => UserInfo) public userInfo;
    mapping(address => mapping(uint256 => TimeLock)) public userLocks;


    event TokensLocked(address indexed user, uint256 indexed lockId, uint256 amount, uint256 unlockTime);
    event TokensWithdrawn(address indexed user, uint256 indexed lockId, uint256 amount);


    uint256 private constant MIN_LOCK_DURATION = 1 days;
    uint256 private constant MAX_LOCK_DURATION = 365 days;

    constructor() {}

    function lockTokens(uint256 duration) external payable nonReentrant {
        require(msg.value > 0, "Amount must be greater than 0");
        require(duration >= MIN_LOCK_DURATION && duration <= MAX_LOCK_DURATION, "Invalid duration");


        UserInfo memory cachedUserInfo = userInfo[msg.sender];
        uint256 lockId = cachedUserInfo.lockCount;
        uint256 unlockTime = block.timestamp + duration;


        userLocks[msg.sender][lockId] = TimeLock({
            amount: msg.value,
            unlockTime: unlockTime,
            withdrawn: false
        });


        userInfo[msg.sender] = UserInfo({
            totalLocked: cachedUserInfo.totalLocked + uint128(msg.value),
            lockCount: cachedUserInfo.lockCount + 1
        });

        emit TokensLocked(msg.sender, lockId, msg.value, unlockTime);
    }

    function withdrawTokens(uint256 lockId) external nonReentrant {
        TimeLock storage lock = userLocks[msg.sender][lockId];

        require(lock.amount > 0, "Lock does not exist");
        require(!lock.withdrawn, "Already withdrawn");
        require(block.timestamp >= lock.unlockTime, "Tokens still locked");


        uint256 amount = lock.amount;


        lock.withdrawn = true;


        UserInfo storage info = userInfo[msg.sender];
        info.totalLocked -= uint128(amount);


        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");

        emit TokensWithdrawn(msg.sender, lockId, amount);
    }

    function batchWithdraw(uint256[] calldata lockIds) external nonReentrant {
        uint256 totalAmount = 0;
        uint256 currentTime = block.timestamp;


        for (uint256 i = 0; i < lockIds.length; ) {
            TimeLock storage lock = userLocks[msg.sender][lockIds[i]];

            require(lock.amount > 0, "Lock does not exist");
            require(!lock.withdrawn, "Already withdrawn");
            require(currentTime >= lock.unlockTime, "Tokens still locked");

            totalAmount += lock.amount;

            unchecked { ++i; }
        }


        for (uint256 i = 0; i < lockIds.length; ) {
            TimeLock storage lock = userLocks[msg.sender][lockIds[i]];
            lock.withdrawn = true;
            emit TokensWithdrawn(msg.sender, lockIds[i], lock.amount);

            unchecked { ++i; }
        }


        UserInfo storage info = userInfo[msg.sender];
        info.totalLocked -= uint128(totalAmount);


        (bool success, ) = payable(msg.sender).call{value: totalAmount}("");
        require(success, "Transfer failed");
    }

    function getLockInfo(address user, uint256 lockId) external view returns (
        uint256 amount,
        uint256 unlockTime,
        bool withdrawn,
        bool canWithdraw
    ) {
        TimeLock memory lock = userLocks[user][lockId];
        return (
            lock.amount,
            lock.unlockTime,
            lock.withdrawn,
            !lock.withdrawn && block.timestamp >= lock.unlockTime
        );
    }

    function getUserTotalLocked(address user) external view returns (uint256) {
        return userInfo[user].totalLocked;
    }

    function getUserLockCount(address user) external view returns (uint256) {
        return userInfo[user].lockCount;
    }

    function getWithdrawableAmount(address user) external view returns (uint256) {
        UserInfo memory info = userInfo[user];
        uint256 withdrawable = 0;
        uint256 currentTime = block.timestamp;

        for (uint256 i = 0; i < info.lockCount; ) {
            TimeLock memory lock = userLocks[user][i];
            if (!lock.withdrawn && currentTime >= lock.unlockTime) {
                withdrawable += lock.amount;
            }
            unchecked { ++i; }
        }

        return withdrawable;
    }


    function emergencyWithdraw() external onlyOwner {
        require(address(this).balance > 0, "No balance to withdraw");

        (bool success, ) = payable(owner()).call{value: address(this).balance}("");
        require(success, "Emergency withdraw failed");
    }

    receive() external payable {
        revert("Direct payments not allowed");
    }
}
