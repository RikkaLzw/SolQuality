
pragma solidity ^0.8.0;

contract TimeLockVaultContract {
    struct LockInfo {
        uint256 amount;
        uint256 unlockTime;
        bool withdrawn;
        address beneficiary;
        string description;
        uint8 lockType;
    }

    mapping(address => LockInfo[]) public userLocks;
    mapping(address => uint256) public totalLocked;
    address public owner;
    uint256 public minLockDuration;
    uint256 public maxLockDuration;
    uint256 public totalDeposits;

    event FundsLocked(address indexed user, uint256 amount, uint256 unlockTime);
    event FundsWithdrawn(address indexed user, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        minLockDuration = 1 days;
        maxLockDuration = 365 days;
    }




    function createLockAndUpdateSettingsAndValidate(
        uint256 lockDuration,
        address beneficiary,
        string memory description,
        uint8 lockType,
        bool updateMinDuration,
        uint256 newMinDuration,
        bool shouldValidateUser
    ) public payable returns (bool) {
        require(msg.value > 0, "Amount must be greater than 0");


        if (shouldValidateUser) {
            if (userLocks[msg.sender].length > 0) {
                for (uint i = 0; i < userLocks[msg.sender].length; i++) {
                    if (!userLocks[msg.sender][i].withdrawn) {
                        if (userLocks[msg.sender][i].lockType == lockType) {
                            if (block.timestamp < userLocks[msg.sender][i].unlockTime) {
                                if (userLocks[msg.sender][i].amount > msg.value) {
                                    revert("Similar lock exists with higher amount");
                                }
                            }
                        }
                    }
                }
            }
        }


        uint256 unlockTime = block.timestamp + lockDuration;
        require(unlockTime > block.timestamp, "Invalid unlock time");
        require(lockDuration >= minLockDuration && lockDuration <= maxLockDuration, "Invalid duration");

        LockInfo memory newLock = LockInfo({
            amount: msg.value,
            unlockTime: unlockTime,
            withdrawn: false,
            beneficiary: beneficiary,
            description: description,
            lockType: lockType
        });

        userLocks[msg.sender].push(newLock);
        totalLocked[msg.sender] += msg.value;
        totalDeposits += msg.value;


        if (updateMinDuration && msg.sender == owner) {
            if (newMinDuration > 0 && newMinDuration <= maxLockDuration) {
                minLockDuration = newMinDuration;
            }
        }

        emit FundsLocked(msg.sender, msg.value, unlockTime);
        return true;
    }


    function calculateUnlockTimeAndFees(uint256 lockIndex) public view returns (uint256, uint256, uint256) {
        require(lockIndex < userLocks[msg.sender].length, "Invalid lock index");

        LockInfo storage lock = userLocks[msg.sender][lockIndex];
        uint256 timeRemaining = lock.unlockTime > block.timestamp ?
            lock.unlockTime - block.timestamp : 0;

        uint256 earlyWithdrawalFee = 0;
        if (timeRemaining > 0) {
            earlyWithdrawalFee = (lock.amount * timeRemaining) / (365 days * 10);
        }

        return (lock.unlockTime, timeRemaining, earlyWithdrawalFee);
    }

    function withdraw(uint256 lockIndex) public {
        require(lockIndex < userLocks[msg.sender].length, "Invalid lock index");

        LockInfo storage lock = userLocks[msg.sender][lockIndex];
        require(!lock.withdrawn, "Already withdrawn");
        require(block.timestamp >= lock.unlockTime, "Lock period not expired");

        lock.withdrawn = true;
        totalLocked[msg.sender] -= lock.amount;

        payable(lock.beneficiary).transfer(lock.amount);
        emit FundsWithdrawn(msg.sender, lock.amount);
    }

    function getUserLockCount(address user) public view returns (uint256) {
        return userLocks[user].length;
    }

    function getUserLock(address user, uint256 index) public view returns (
        uint256 amount,
        uint256 unlockTime,
        bool withdrawn,
        address beneficiary,
        string memory description,
        uint8 lockType
    ) {
        require(index < userLocks[user].length, "Invalid index");
        LockInfo storage lock = userLocks[user][index];
        return (
            lock.amount,
            lock.unlockTime,
            lock.withdrawn,
            lock.beneficiary,
            lock.description,
            lock.lockType
        );
    }

    function updateLockDurations(uint256 newMin, uint256 newMax) public onlyOwner {
        require(newMin > 0 && newMax > newMin, "Invalid durations");
        minLockDuration = newMin;
        maxLockDuration = newMax;
    }
}
