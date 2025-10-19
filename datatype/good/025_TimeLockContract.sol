
pragma solidity ^0.8.0;

contract TimeLockContract {
    struct LockedFunds {
        uint256 amount;
        uint64 unlockTime;
        address beneficiary;
        bool withdrawn;
    }

    mapping(bytes32 => LockedFunds) private locks;
    mapping(address => bytes32[]) private userLocks;

    address private owner;
    uint32 private lockCounter;

    event FundsLocked(
        bytes32 indexed lockId,
        address indexed depositor,
        address indexed beneficiary,
        uint256 amount,
        uint64 unlockTime
    );

    event FundsWithdrawn(
        bytes32 indexed lockId,
        address indexed beneficiary,
        uint256 amount
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier validLock(bytes32 lockId) {
        require(locks[lockId].amount > 0, "Lock does not exist");
        _;
    }

    constructor() {
        owner = msg.sender;
        lockCounter = 0;
    }

    function lockFunds(
        address beneficiary,
        uint64 unlockTime
    ) external payable returns (bytes32) {
        require(msg.value > 0, "Amount must be greater than 0");
        require(beneficiary != address(0), "Invalid beneficiary address");
        require(unlockTime > block.timestamp, "Unlock time must be in the future");

        lockCounter++;
        bytes32 lockId = keccak256(
            abi.encodePacked(
                msg.sender,
                beneficiary,
                msg.value,
                unlockTime,
                lockCounter,
                block.timestamp
            )
        );

        locks[lockId] = LockedFunds({
            amount: msg.value,
            unlockTime: unlockTime,
            beneficiary: beneficiary,
            withdrawn: false
        });

        userLocks[beneficiary].push(lockId);

        emit FundsLocked(lockId, msg.sender, beneficiary, msg.value, unlockTime);

        return lockId;
    }

    function withdrawFunds(bytes32 lockId) external validLock(lockId) {
        LockedFunds storage lock = locks[lockId];

        require(msg.sender == lock.beneficiary, "Only beneficiary can withdraw");
        require(block.timestamp >= lock.unlockTime, "Funds are still locked");
        require(!lock.withdrawn, "Funds already withdrawn");

        lock.withdrawn = true;
        uint256 amount = lock.amount;

        (bool success, ) = payable(lock.beneficiary).call{value: amount}("");
        require(success, "Transfer failed");

        emit FundsWithdrawn(lockId, lock.beneficiary, amount);
    }

    function getLockInfo(bytes32 lockId) external view validLock(lockId) returns (
        uint256 amount,
        uint64 unlockTime,
        address beneficiary,
        bool withdrawn,
        bool canWithdraw
    ) {
        LockedFunds memory lock = locks[lockId];
        return (
            lock.amount,
            lock.unlockTime,
            lock.beneficiary,
            lock.withdrawn,
            block.timestamp >= lock.unlockTime && !lock.withdrawn
        );
    }

    function getUserLocks(address user) external view returns (bytes32[] memory) {
        return userLocks[user];
    }

    function getTimeRemaining(bytes32 lockId) external view validLock(lockId) returns (uint64) {
        LockedFunds memory lock = locks[lockId];
        if (block.timestamp >= lock.unlockTime) {
            return 0;
        }
        return lock.unlockTime - uint64(block.timestamp);
    }

    function emergencyWithdraw(bytes32 lockId) external onlyOwner validLock(lockId) {
        LockedFunds storage lock = locks[lockId];
        require(!lock.withdrawn, "Funds already withdrawn");

        lock.withdrawn = true;
        uint256 amount = lock.amount;

        (bool success, ) = payable(owner).call{value: amount}("");
        require(success, "Emergency transfer failed");

        emit FundsWithdrawn(lockId, owner, amount);
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {
        revert("Direct payments not allowed. Use lockFunds function.");
    }

    fallback() external payable {
        revert("Function not found. Use lockFunds function.");
    }
}
