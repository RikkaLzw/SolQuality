
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TimeLockContract is Ownable, ReentrancyGuard {
    struct LockedFunds {
        uint256 amount;
        uint256 unlockTime;
        bool withdrawn;
    }

    mapping(address => LockedFunds[]) private userLocks;
    mapping(address => uint256) private totalLocked;

    uint256 public constant MIN_LOCK_DURATION = 1 days;
    uint256 public constant MAX_LOCK_DURATION = 365 days;

    event FundsLocked(address indexed user, uint256 amount, uint256 unlockTime, uint256 lockId);
    event FundsWithdrawn(address indexed user, uint256 amount, uint256 lockId);
    event EmergencyWithdrawal(address indexed user, uint256 amount);

    error InvalidLockDuration();
    error InsufficientFunds();
    error FundsStillLocked();
    error AlreadyWithdrawn();
    error InvalidLockId();
    error NoFundsToWithdraw();

    constructor() {}

    function lockFunds(uint256 duration) external payable {
        if (msg.value == 0) revert InsufficientFunds();
        if (duration < MIN_LOCK_DURATION || duration > MAX_LOCK_DURATION) {
            revert InvalidLockDuration();
        }

        uint256 unlockTime = block.timestamp + duration;
        uint256 lockId = userLocks[msg.sender].length;

        userLocks[msg.sender].push(LockedFunds({
            amount: msg.value,
            unlockTime: unlockTime,
            withdrawn: false
        }));

        totalLocked[msg.sender] += msg.value;

        emit FundsLocked(msg.sender, msg.value, unlockTime, lockId);
    }

    function withdrawFunds(uint256 lockId) external nonReentrant {
        if (lockId >= userLocks[msg.sender].length) revert InvalidLockId();

        LockedFunds storage lock = userLocks[msg.sender][lockId];

        if (lock.withdrawn) revert AlreadyWithdrawn();
        if (block.timestamp < lock.unlockTime) revert FundsStillLocked();

        uint256 amount = lock.amount;
        lock.withdrawn = true;
        totalLocked[msg.sender] -= amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");

        emit FundsWithdrawn(msg.sender, amount, lockId);
    }

    function getUserLocks(address user) external view returns (LockedFunds[] memory) {
        return userLocks[user];
    }

    function getLockInfo(address user, uint256 lockId) external view returns (uint256, uint256, bool) {
        if (lockId >= userLocks[user].length) revert InvalidLockId();

        LockedFunds memory lock = userLocks[user][lockId];
        return (lock.amount, lock.unlockTime, lock.withdrawn);
    }

    function getTotalLocked(address user) external view returns (uint256) {
        return totalLocked[user];
    }

    function getWithdrawableAmount(address user) external view returns (uint256) {
        uint256 withdrawable = 0;
        LockedFunds[] memory locks = userLocks[user];

        for (uint256 i = 0; i < locks.length; i++) {
            if (!locks[i].withdrawn && block.timestamp >= locks[i].unlockTime) {
                withdrawable += locks[i].amount;
            }
        }

        return withdrawable;
    }

    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) revert NoFundsToWithdraw();

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Emergency withdrawal failed");

        emit EmergencyWithdrawal(owner(), balance);
    }

    receive() external payable {
        revert("Use lockFunds function");
    }
}
