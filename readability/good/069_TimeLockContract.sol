
pragma solidity ^0.8.19;


contract TimeLockContract {

    struct LockRecord {
        uint256 amount;
        uint256 unlockTime;
        bool isWithdrawn;
        address beneficiary;
    }


    address public owner;


    uint256 public minimumLockDuration;


    uint256 public maximumLockDuration;


    mapping(address => mapping(uint256 => LockRecord)) public lockRecords;


    mapping(address => uint256) public userLockCount;


    uint256 public totalLockedAmount;


    event FundsLocked(
        address indexed user,
        address indexed beneficiary,
        uint256 indexed lockId,
        uint256 amount,
        uint256 unlockTime
    );

    event FundsWithdrawn(
        address indexed user,
        address indexed beneficiary,
        uint256 indexed lockId,
        uint256 amount
    );

    event LockDurationUpdated(
        uint256 newMinimumDuration,
        uint256 newMaximumDuration
    );

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );


    modifier onlyOwner() {
        require(msg.sender == owner, "TimeLock: caller is not the owner");
        _;
    }


    modifier validLockDuration(uint256 lockDuration) {
        require(
            lockDuration >= minimumLockDuration &&
            lockDuration <= maximumLockDuration,
            "TimeLock: invalid lock duration"
        );
        _;
    }


    modifier validAddress(address addr) {
        require(addr != address(0), "TimeLock: invalid address");
        _;
    }


    constructor(
        uint256 _minimumLockDuration,
        uint256 _maximumLockDuration
    ) {
        require(
            _minimumLockDuration > 0 &&
            _maximumLockDuration > _minimumLockDuration,
            "TimeLock: invalid lock duration parameters"
        );

        owner = msg.sender;
        minimumLockDuration = _minimumLockDuration;
        maximumLockDuration = _maximumLockDuration;
    }


    function lockFunds(
        address beneficiary,
        uint256 lockDuration
    )
        external
        payable
        validAddress(beneficiary)
        validLockDuration(lockDuration)
    {
        require(msg.value > 0, "TimeLock: amount must be greater than 0");

        uint256 lockId = userLockCount[msg.sender];
        uint256 unlockTime = block.timestamp + lockDuration;


        lockRecords[msg.sender][lockId] = LockRecord({
            amount: msg.value,
            unlockTime: unlockTime,
            isWithdrawn: false,
            beneficiary: beneficiary
        });


        userLockCount[msg.sender]++;
        totalLockedAmount += msg.value;


        emit FundsLocked(
            msg.sender,
            beneficiary,
            lockId,
            msg.value,
            unlockTime
        );
    }


    function withdrawFunds(uint256 lockId) external {
        LockRecord storage record = lockRecords[msg.sender][lockId];

        require(record.amount > 0, "TimeLock: lock record does not exist");
        require(!record.isWithdrawn, "TimeLock: funds already withdrawn");
        require(
            block.timestamp >= record.unlockTime,
            "TimeLock: funds are still locked"
        );

        uint256 amount = record.amount;
        address beneficiary = record.beneficiary;


        record.isWithdrawn = true;


        totalLockedAmount -= amount;


        (bool success, ) = payable(beneficiary).call{value: amount}("");
        require(success, "TimeLock: transfer failed");


        emit FundsWithdrawn(msg.sender, beneficiary, lockId, amount);
    }


    function batchWithdrawFunds(uint256[] calldata lockIds) external {
        require(lockIds.length > 0, "TimeLock: empty lock IDs array");
        require(lockIds.length <= 50, "TimeLock: too many lock IDs");

        for (uint256 i = 0; i < lockIds.length; i++) {
            uint256 lockId = lockIds[i];
            LockRecord storage record = lockRecords[msg.sender][lockId];


            if (record.amount == 0 || record.isWithdrawn) {
                continue;
            }


            if (block.timestamp < record.unlockTime) {
                continue;
            }

            uint256 amount = record.amount;
            address beneficiary = record.beneficiary;


            record.isWithdrawn = true;


            totalLockedAmount -= amount;


            (bool success, ) = payable(beneficiary).call{value: amount}("");
            require(success, "TimeLock: transfer failed");


            emit FundsWithdrawn(msg.sender, beneficiary, lockId, amount);
        }
    }


    function getLockRecord(
        address user,
        uint256 lockId
    )
        external
        view
        returns (
            uint256 amount,
            uint256 unlockTime,
            bool isWithdrawn,
            address beneficiary
        )
    {
        LockRecord memory record = lockRecords[user][lockId];
        return (
            record.amount,
            record.unlockTime,
            record.isWithdrawn,
            record.beneficiary
        );
    }


    function isWithdrawable(
        address user,
        uint256 lockId
    ) external view returns (bool) {
        LockRecord memory record = lockRecords[user][lockId];
        return (
            record.amount > 0 &&
            !record.isWithdrawn &&
            block.timestamp >= record.unlockTime
        );
    }


    function getRemainingLockTime(
        address user,
        uint256 lockId
    ) external view returns (uint256) {
        LockRecord memory record = lockRecords[user][lockId];

        if (record.amount == 0 || record.isWithdrawn) {
            return 0;
        }

        if (block.timestamp >= record.unlockTime) {
            return 0;
        }

        return record.unlockTime - block.timestamp;
    }


    function updateLockDuration(
        uint256 newMinimumDuration,
        uint256 newMaximumDuration
    ) external onlyOwner {
        require(
            newMinimumDuration > 0 &&
            newMaximumDuration > newMinimumDuration,
            "TimeLock: invalid duration parameters"
        );

        minimumLockDuration = newMinimumDuration;
        maximumLockDuration = newMaximumDuration;

        emit LockDurationUpdated(newMinimumDuration, newMaximumDuration);
    }


    function transferOwnership(
        address newOwner
    ) external onlyOwner validAddress(newOwner) {
        address previousOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(previousOwner, newOwner);
    }


    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }


    function emergencyPause() external onlyOwner {


    }
}
