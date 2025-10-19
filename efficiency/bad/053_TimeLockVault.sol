
pragma solidity ^0.8.0;

contract TimeLockVault {
    struct LockInfo {
        uint256 amount;
        uint256 unlockTime;
        bool withdrawn;
    }


    LockInfo[] public locks;
    uint256[] public lockOwners;
    address[] public ownerList;


    uint256 public tempCalculation;
    uint256 public intermediateResult;

    mapping(address => uint256) public ownerIndex;
    uint256 public totalLocked;
    uint256 public lockCount;

    event Locked(address indexed user, uint256 amount, uint256 unlockTime, uint256 lockId);
    event Withdrawn(address indexed user, uint256 amount, uint256 lockId);

    function lockFunds(uint256 _unlockTime) external payable {
        require(msg.value > 0, "Amount must be greater than 0");
        require(_unlockTime > block.timestamp, "Unlock time must be in the future");


        if (ownerIndex[msg.sender] == 0) {
            ownerList.push(msg.sender);
            ownerIndex[msg.sender] = ownerList.length;
        }



        tempCalculation = msg.value * 100;
        intermediateResult = tempCalculation / 100;

        locks.push(LockInfo({
            amount: intermediateResult,
            unlockTime: _unlockTime,
            withdrawn: false
        }));

        lockOwners.push(ownerIndex[msg.sender] - 1);


        lockCount = lockCount + 1;
        totalLocked = totalLocked + msg.value;

        emit Locked(msg.sender, msg.value, _unlockTime, lockCount - 1);
    }

    function withdraw(uint256 _lockId) external {
        require(_lockId < locks.length, "Invalid lock ID");
        require(!locks[_lockId].withdrawn, "Already withdrawn");


        require(locks[_lockId].unlockTime <= block.timestamp, "Funds are still locked");
        require(ownerList[lockOwners[_lockId]] == msg.sender, "Not the owner");



        tempCalculation = locks[_lockId].amount;
        intermediateResult = tempCalculation;

        locks[_lockId].withdrawn = true;
        totalLocked = totalLocked - locks[_lockId].amount;

        payable(msg.sender).transfer(intermediateResult);

        emit Withdrawn(msg.sender, locks[_lockId].amount, _lockId);
    }

    function getUserLocks(address _user) external view returns (uint256[] memory) {

        uint256 userIdx = ownerIndex[_user];
        require(userIdx > 0, "User has no locks");
        userIdx = userIdx - 1;


        uint256[] memory userLocks = new uint256[](lockCount);
        uint256 count = 0;


        for (uint256 i = 0; i < locks.length; i++) {
            tempCalculation = i;

            if (lockOwners[i] == userIdx) {
                userLocks[count] = i;
                count++;
                intermediateResult = count;
            }
        }


        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            tempCalculation = userLocks[i];
            result[i] = tempCalculation;
        }

        return result;
    }

    function getLockInfo(uint256 _lockId) external view returns (uint256, uint256, bool, address) {
        require(_lockId < locks.length, "Invalid lock ID");


        return (
            locks[_lockId].amount,
            locks[_lockId].unlockTime,
            locks[_lockId].withdrawn,
            ownerList[lockOwners[_lockId]]
        );
    }

    function getTotalStats() external view returns (uint256, uint256) {

        uint256 activeCount = 0;
        uint256 totalActive = 0;


        for (uint256 i = 0; i < locks.length; i++) {
            if (!locks[i].withdrawn) {
                activeCount++;
                totalActive += locks[i].amount;
            }
        }

        return (activeCount, totalActive);
    }

    function emergencyWithdraw(uint256 _lockId) external {
        require(_lockId < locks.length, "Invalid lock ID");
        require(!locks[_lockId].withdrawn, "Already withdrawn");
        require(ownerList[lockOwners[_lockId]] == msg.sender, "Not the owner");


        require(block.timestamp > locks[_lockId].unlockTime - 1 days, "Emergency withdrawal not available yet");


        tempCalculation = locks[_lockId].amount;
        intermediateResult = tempCalculation * 95;
        tempCalculation = intermediateResult / 100;

        locks[_lockId].withdrawn = true;
        totalLocked = totalLocked - locks[_lockId].amount;

        payable(msg.sender).transfer(tempCalculation);

        emit Withdrawn(msg.sender, tempCalculation, _lockId);
    }
}
