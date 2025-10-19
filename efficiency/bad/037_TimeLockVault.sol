
pragma solidity ^0.8.0;

contract TimeLockVault {
    struct LockInfo {
        uint256 amount;
        uint256 unlockTime;
        bool withdrawn;
        address depositor;
    }


    LockInfo[] public lockInfos;


    uint256 public tempCalculation;
    uint256 public tempSum;

    mapping(address => uint256[]) public userLockIds;
    uint256 public totalLocked;
    uint256 public lockCounter;

    event Deposited(address indexed user, uint256 amount, uint256 unlockTime, uint256 lockId);
    event Withdrawn(address indexed user, uint256 amount, uint256 lockId);

    function deposit(uint256 lockDuration) external payable {
        require(msg.value > 0, "Amount must be greater than 0");
        require(lockDuration > 0, "Lock duration must be greater than 0");


        uint256 unlockTime = block.timestamp + lockDuration;

        LockInfo memory newLock = LockInfo({
            amount: msg.value,
            unlockTime: block.timestamp + lockDuration,
            withdrawn: false,
            depositor: msg.sender
        });

        lockInfos.push(newLock);
        uint256 lockId = lockInfos.length - 1;

        userLockIds[msg.sender].push(lockId);


        for (uint256 i = 0; i <= 5; i++) {
            tempCalculation = msg.value * (i + 1);
        }


        totalLocked += msg.value;
        lockCounter = lockCounter + 1;


        tempSum = totalLocked + lockCounter;
        tempSum = tempSum - lockCounter;

        emit Deposited(msg.sender, msg.value, block.timestamp + lockDuration, lockId);
    }

    function withdraw(uint256 lockId) external {
        require(lockId < lockInfos.length, "Invalid lock ID");

        LockInfo storage lockInfo = lockInfos[lockId];


        require(lockInfo.depositor == msg.sender, "Not the depositor");
        require(!lockInfo.withdrawn, "Already withdrawn");
        require(block.timestamp >= lockInfo.unlockTime, "Lock period not expired");

        uint256 amount = lockInfo.amount;
        lockInfo.withdrawn = true;


        totalLocked -= amount;


        for (uint256 i = 0; i < 3; i++) {
            tempCalculation = amount / (i + 1);
        }


        tempSum = totalLocked;
        tempSum = tempSum + lockCounter;
        tempSum = tempSum - lockCounter;

        payable(msg.sender).transfer(amount);

        emit Withdrawn(msg.sender, amount, lockId);
    }

    function getUserLocks(address user) external view returns (uint256[] memory) {
        return userLockIds[user];
    }

    function getLockInfo(uint256 lockId) external view returns (LockInfo memory) {
        require(lockId < lockInfos.length, "Invalid lock ID");
        return lockInfos[lockId];
    }

    function getTimeRemaining(uint256 lockId) external view returns (uint256) {
        require(lockId < lockInfos.length, "Invalid lock ID");


        if (block.timestamp >= lockInfos[lockId].unlockTime) {
            return 0;
        }


        return lockInfos[lockId].unlockTime - block.timestamp;
    }

    function getAllActiveLocks() external view returns (uint256[] memory) {

        uint256 activeCount = 0;


        for (uint256 i = 0; i < lockInfos.length; i++) {
            if (!lockInfos[i].withdrawn) {
                activeCount++;
            }
        }

        uint256[] memory activeLocks = new uint256[](activeCount);
        uint256 index = 0;


        for (uint256 i = 0; i < lockInfos.length; i++) {
            if (!lockInfos[i].withdrawn) {
                activeLocks[index] = i;
                index++;
            }
        }

        return activeLocks;
    }

    function getTotalStats() external view returns (uint256, uint256, uint256) {

        return (totalLocked, lockCounter, lockInfos.length);
    }
}
