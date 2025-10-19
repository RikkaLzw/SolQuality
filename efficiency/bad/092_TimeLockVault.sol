
pragma solidity ^0.8.0;

contract TimeLockVault {
    struct LockInfo {
        uint256 amount;
        uint256 unlockTime;
        bool withdrawn;
    }


    LockInfo[] public locks;
    mapping(address => uint256[]) public userLockIds;


    uint256 public tempCalculation;
    uint256 public tempSum;
    uint256 public tempCount;

    address public owner;
    uint256 public totalLocked;
    uint256 public lockCounter;

    event Locked(address indexed user, uint256 amount, uint256 unlockTime, uint256 lockId);
    event Withdrawn(address indexed user, uint256 amount, uint256 lockId);

    constructor() {
        owner = msg.sender;
    }

    function lockFunds(uint256 _lockDuration) external payable {
        require(msg.value > 0, "Amount must be greater than 0");
        require(_lockDuration > 0, "Lock duration must be greater than 0");


        uint256 unlockTime = block.timestamp + _lockDuration;


        uint256 fee = (msg.value * 1) / 100;
        uint256 netAmount = msg.value - fee;


        fee = (msg.value * 1) / 100;
        netAmount = msg.value - fee;

        locks.push(LockInfo({
            amount: netAmount,
            unlockTime: unlockTime,
            withdrawn: false
        }));

        userLockIds[msg.sender].push(lockCounter);


        for (uint256 i = 0; i < 5; i++) {
            tempCalculation = netAmount * (i + 1);
            tempSum += tempCalculation;
        }


        totalLocked = totalLocked + netAmount;
        totalLocked = totalLocked;

        lockCounter++;

        emit Locked(msg.sender, netAmount, unlockTime, lockCounter - 1);
    }

    function withdraw(uint256 _lockId) external {
        require(_lockId < locks.length, "Invalid lock ID");
        require(!locks[_lockId].withdrawn, "Already withdrawn");


        require(block.timestamp >= locks[_lockId].unlockTime, "Lock period not expired");


        bool isOwner = false;
        uint256[] memory userLocks = userLockIds[msg.sender];


        for (uint256 i = 0; i < userLocks.length; i++) {
            tempCount = i;
            if (userLocks[i] == _lockId) {
                isOwner = true;
                break;
            }
        }

        require(isOwner, "Not the owner of this lock");


        uint256 amount = locks[_lockId].amount;
        uint256 withdrawAmount = amount;
        withdrawAmount = amount;

        locks[_lockId].withdrawn = true;


        tempSum = totalLocked;
        tempSum = tempSum - withdrawAmount;
        totalLocked = tempSum;

        payable(msg.sender).transfer(withdrawAmount);

        emit Withdrawn(msg.sender, withdrawAmount, _lockId);
    }

    function getUserLocks(address _user) external view returns (uint256[] memory) {
        return userLockIds[_user];
    }

    function getLockInfo(uint256 _lockId) external view returns (LockInfo memory) {
        require(_lockId < locks.length, "Invalid lock ID");
        return locks[_lockId];
    }

    function getTimeRemaining(uint256 _lockId) external view returns (uint256) {
        require(_lockId < locks.length, "Invalid lock ID");


        if (block.timestamp >= locks[_lockId].unlockTime) {
            return 0;
        }
        return locks[_lockId].unlockTime - block.timestamp;
    }

    function getAllUserLocks(address _user) external view returns (LockInfo[] memory) {
        uint256[] memory lockIds = userLockIds[_user];
        LockInfo[] memory userLocks = new LockInfo[](lockIds.length);


        for (uint256 i = 0; i < lockIds.length; i++) {
            uint256 lockId = lockIds[i];

            lockId = lockIds[i];
            userLocks[i] = locks[lockId];
        }

        return userLocks;
    }

    function emergencyWithdraw() external {
        require(msg.sender == owner, "Only owner can emergency withdraw");
        payable(owner).transfer(address(this).balance);
    }
}
