
pragma solidity ^0.8.0;

contract OptimizedTimeLock {

    struct LockedFunds {
        uint128 amount;
        uint128 unlockTime;
    }


    event FundsLocked(address indexed user, uint256 amount, uint256 unlockTime);
    event FundsWithdrawn(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);


    address public immutable owner;
    mapping(address => LockedFunds) private userLocks;
    mapping(address => bool) private hasActiveLock;


    uint256 private constant MIN_LOCK_DURATION = 1 hours;
    uint256 private constant MAX_LOCK_DURATION = 365 days;


    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier hasLock() {
        require(hasActiveLock[msg.sender], "No active lock");
        _;
    }

    modifier noActiveLock() {
        require(!hasActiveLock[msg.sender], "Active lock exists");
        _;
    }

    constructor() {
        owner = msg.sender;
    }


    function lockFunds(uint256 duration) external payable noActiveLock {
        require(msg.value > 0, "Amount must be greater than 0");
        require(duration >= MIN_LOCK_DURATION && duration <= MAX_LOCK_DURATION, "Invalid duration");


        uint256 currentTime = block.timestamp;
        uint256 unlockTime = currentTime + duration;


        require(unlockTime > currentTime, "Overflow detected");


        userLocks[msg.sender] = LockedFunds({
            amount: uint128(msg.value),
            unlockTime: uint128(unlockTime)
        });

        hasActiveLock[msg.sender] = true;

        emit FundsLocked(msg.sender, msg.value, unlockTime);
    }


    function withdrawFunds() external hasLock {

        LockedFunds memory userLock = userLocks[msg.sender];

        require(block.timestamp >= userLock.unlockTime, "Funds still locked");

        uint256 amount = userLock.amount;


        delete userLocks[msg.sender];
        hasActiveLock[msg.sender] = false;


        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");

        emit FundsWithdrawn(msg.sender, amount);
    }


    function getLockInfo(address user) external view returns (uint256 amount, uint256 unlockTime, bool isLocked) {
        if (!hasActiveLock[user]) {
            return (0, 0, false);
        }

        LockedFunds memory userLock = userLocks[user];
        return (userLock.amount, userLock.unlockTime, true);
    }


    function isUnlocked(address user) external view returns (bool) {
        if (!hasActiveLock[user]) {
            return false;
        }
        return block.timestamp >= userLocks[user].unlockTime;
    }


    function getRemainingTime(address user) external view returns (uint256) {
        if (!hasActiveLock[user]) {
            return 0;
        }

        uint256 unlockTime = userLocks[user].unlockTime;
        if (block.timestamp >= unlockTime) {
            return 0;
        }

        return unlockTime - block.timestamp;
    }


    function emergencyWithdraw(address user) external onlyOwner {
        require(hasActiveLock[user], "No active lock for user");

        uint256 amount = userLocks[user].amount;


        delete userLocks[user];
        hasActiveLock[user] = false;


        (bool success, ) = payable(user).call{value: amount}("");
        require(success, "Transfer failed");

        emit EmergencyWithdraw(user, amount);
    }


    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
