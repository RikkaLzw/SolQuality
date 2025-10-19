
pragma solidity ^0.8.0;

contract TimeLockContract {
    struct LockedFunds {
        uint256 amount;
        uint64 unlockTime;
        address beneficiary;
        bool withdrawn;
    }

    mapping(bytes32 => LockedFunds) public lockedFunds;
    mapping(address => bytes32[]) public userLocks;

    address public immutable owner;
    uint32 public constant MIN_LOCK_DURATION = 1 hours;
    uint32 public constant MAX_LOCK_DURATION = 365 days;

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

    error InsufficientFunds();
    error InvalidLockDuration();
    error LockNotFound();
    error FundsStillLocked();
    error AlreadyWithdrawn();
    error UnauthorizedWithdrawal();
    error TransferFailed();

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function lockFunds(
        address beneficiary,
        uint32 lockDuration
    ) external payable returns (bytes32 lockId) {
        if (msg.value == 0) revert InsufficientFunds();
        if (lockDuration < MIN_LOCK_DURATION || lockDuration > MAX_LOCK_DURATION) {
            revert InvalidLockDuration();
        }

        uint64 unlockTime = uint64(block.timestamp) + lockDuration;
        lockId = keccak256(abi.encodePacked(
            msg.sender,
            beneficiary,
            msg.value,
            unlockTime,
            block.timestamp
        ));

        lockedFunds[lockId] = LockedFunds({
            amount: msg.value,
            unlockTime: unlockTime,
            beneficiary: beneficiary,
            withdrawn: false
        });

        userLocks[msg.sender].push(lockId);

        emit FundsLocked(lockId, msg.sender, beneficiary, msg.value, unlockTime);
    }

    function withdrawFunds(bytes32 lockId) external {
        LockedFunds storage lock = lockedFunds[lockId];

        if (lock.amount == 0) revert LockNotFound();
        if (lock.withdrawn) revert AlreadyWithdrawn();
        if (msg.sender != lock.beneficiary) revert UnauthorizedWithdrawal();
        if (block.timestamp < lock.unlockTime) revert FundsStillLocked();

        lock.withdrawn = true;
        uint256 amount = lock.amount;

        (bool success, ) = payable(lock.beneficiary).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit FundsWithdrawn(lockId, lock.beneficiary, amount);
    }

    function getLockInfo(bytes32 lockId) external view returns (
        uint256 amount,
        uint64 unlockTime,
        address beneficiary,
        bool withdrawn,
        bool canWithdraw
    ) {
        LockedFunds memory lock = lockedFunds[lockId];
        return (
            lock.amount,
            lock.unlockTime,
            lock.beneficiary,
            lock.withdrawn,
            !lock.withdrawn && block.timestamp >= lock.unlockTime
        );
    }

    function getUserLocks(address user) external view returns (bytes32[] memory) {
        return userLocks[user];
    }

    function getTimeRemaining(bytes32 lockId) external view returns (uint64) {
        LockedFunds memory lock = lockedFunds[lockId];
        if (lock.amount == 0) revert LockNotFound();

        if (block.timestamp >= lock.unlockTime) {
            return 0;
        }
        return lock.unlockTime - uint64(block.timestamp);
    }

    function emergencyWithdraw(bytes32 lockId) external onlyOwner {
        LockedFunds storage lock = lockedFunds[lockId];

        if (lock.amount == 0) revert LockNotFound();
        if (lock.withdrawn) revert AlreadyWithdrawn();

        lock.withdrawn = true;
        uint256 amount = lock.amount;

        (bool success, ) = payable(lock.beneficiary).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit FundsWithdrawn(lockId, lock.beneficiary, amount);
    }

    receive() external payable {
        revert("Use lockFunds function");
    }
}
