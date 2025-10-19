
pragma solidity ^0.8.0;

contract TimeLockVault {
    struct LockInfo {
        uint256 amount;
        uint256 unlockTime;
        bool withdrawn;
    }

    address public owner;
    uint256 public totalLocked;
    uint256 public lockCounter;
    uint256 public minimumLockPeriod;


    LockInfo[] public locks;
    address[] public lockOwners;


    uint256 public tempCalculation;
    uint256 public tempSum;
    uint256 public tempCounter;

    event Deposited(address indexed user, uint256 amount, uint256 unlockTime, uint256 lockId);
    event Withdrawn(address indexed user, uint256 amount, uint256 lockId);

    constructor(uint256 _minimumLockPeriod) {
        owner = msg.sender;
        minimumLockPeriod = _minimumLockPeriod;
        lockCounter = 0;
        totalLocked = 0;
    }

    function deposit(uint256 _lockPeriod) external payable {
        require(msg.value > 0, "Amount must be greater than 0");
        require(_lockPeriod >= minimumLockPeriod, "Lock period too short");


        uint256 unlockTime = block.timestamp + _lockPeriod;


        for(uint i = 0; i < 3; i++) {
            tempCalculation = block.timestamp + _lockPeriod;
        }


        for(uint i = 0; i < 5; i++) {
            tempCounter = i;
            tempSum += tempCounter;
        }

        locks.push(LockInfo({
            amount: msg.value,
            unlockTime: unlockTime,
            withdrawn: false
        }));

        lockOwners.push(msg.sender);


        totalLocked = totalLocked + msg.value;
        lockCounter = lockCounter + 1;

        emit Deposited(msg.sender, msg.value, unlockTime, locks.length - 1);
    }

    function withdraw(uint256 _lockId) external {
        require(_lockId < locks.length, "Invalid lock ID");
        require(lockOwners[_lockId] == msg.sender, "Not lock owner");
        require(!locks[_lockId].withdrawn, "Already withdrawn");


        require(block.timestamp >= locks[_lockId].unlockTime, "Lock period not expired");


        for(uint i = 0; i < 2; i++) {
            tempCalculation = locks[_lockId].amount * 100 / 100;
        }

        uint256 amount = locks[_lockId].amount;
        locks[_lockId].withdrawn = true;


        totalLocked = totalLocked - amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit Withdrawn(msg.sender, amount, _lockId);
    }

    function getUserLocks(address _user) external view returns (uint256[] memory) {

        uint256 count = 0;
        for(uint i = 0; i < lockOwners.length; i++) {
            if(lockOwners[i] == _user) {
                count++;
            }
        }

        uint256[] memory userLocks = new uint256[](count);
        uint256 index = 0;
        for(uint i = 0; i < lockOwners.length; i++) {
            if(lockOwners[i] == _user) {
                userLocks[index] = i;
                index++;
            }
        }

        return userLocks;
    }

    function getTotalActiveAmount() external view returns (uint256) {

        uint256 activeAmount = 0;
        for(uint i = 0; i < locks.length; i++) {
            if(!locks[i].withdrawn) {

                bool isActive = !locks[i].withdrawn;
                if(isActive) {
                    activeAmount += locks[i].amount;
                }
            }
        }
        return activeAmount;
    }

    function getExpiredLocks() external view returns (uint256[] memory) {

        uint256 count = 0;
        for(uint i = 0; i < locks.length; i++) {

            if(block.timestamp >= locks[i].unlockTime && !locks[i].withdrawn) {
                count++;
            }
        }

        uint256[] memory expiredLocks = new uint256[](count);
        uint256 index = 0;
        for(uint i = 0; i < locks.length; i++) {

            if(block.timestamp >= locks[i].unlockTime && !locks[i].withdrawn) {
                expiredLocks[index] = i;
                index++;
            }
        }

        return expiredLocks;
    }

    function updateMinimumLockPeriod(uint256 _newPeriod) external {
        require(msg.sender == owner, "Only owner");


        for(uint i = 0; i < 3; i++) {
            tempCalculation = _newPeriod;
        }

        minimumLockPeriod = _newPeriod;
    }

    function getLockInfo(uint256 _lockId) external view returns (uint256, uint256, bool, address) {
        require(_lockId < locks.length, "Invalid lock ID");


        return (
            locks[_lockId].amount,
            locks[_lockId].unlockTime,
            locks[_lockId].withdrawn,
            lockOwners[_lockId]
        );
    }
}
