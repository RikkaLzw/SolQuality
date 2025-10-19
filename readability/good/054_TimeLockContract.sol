
pragma solidity ^0.8.0;


contract TimeLockContract {

    struct LockRecord {
        uint256 amount;
        uint256 unlockTime;
        bool isWithdrawn;
    }


    address public contractOwner;


    mapping(address => mapping(uint256 => LockRecord)) public userLockRecords;


    mapping(address => uint256) public userLockCount;


    uint256 public totalLockedAmount;


    uint256 public constant MIN_LOCK_DURATION = 1 minutes;


    uint256 public constant MAX_LOCK_DURATION = 365 days;


    event FundsLocked(
        address indexed user,
        uint256 indexed lockId,
        uint256 amount,
        uint256 unlockTime
    );

    event FundsWithdrawn(
        address indexed user,
        uint256 indexed lockId,
        uint256 amount
    );

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );


    modifier onlyOwner() {
        require(msg.sender == contractOwner, "TimeLock: caller is not the owner");
        _;
    }


    modifier validLockDuration(uint256 lockDuration) {
        require(
            lockDuration >= MIN_LOCK_DURATION && lockDuration <= MAX_LOCK_DURATION,
            "TimeLock: invalid lock duration"
        );
        _;
    }


    constructor() {
        contractOwner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }


    function lockFunds(uint256 lockDuration)
        external
        payable
        validLockDuration(lockDuration)
    {
        require(msg.value > 0, "TimeLock: amount must be greater than 0");

        uint256 lockId = userLockCount[msg.sender];
        uint256 unlockTime = block.timestamp + lockDuration;


        userLockRecords[msg.sender][lockId] = LockRecord({
            amount: msg.value,
            unlockTime: unlockTime,
            isWithdrawn: false
        });


        userLockCount[msg.sender]++;
        totalLockedAmount += msg.value;

        emit FundsLocked(msg.sender, lockId, msg.value, unlockTime);
    }


    function withdrawFunds(uint256 lockId) external {
        require(lockId < userLockCount[msg.sender], "TimeLock: invalid lock ID");

        LockRecord storage lockRecord = userLockRecords[msg.sender][lockId];

        require(!lockRecord.isWithdrawn, "TimeLock: funds already withdrawn");
        require(
            block.timestamp >= lockRecord.unlockTime,
            "TimeLock: funds are still locked"
        );
        require(lockRecord.amount > 0, "TimeLock: no funds to withdraw");

        uint256 withdrawAmount = lockRecord.amount;


        lockRecord.isWithdrawn = true;


        totalLockedAmount -= withdrawAmount;


        (bool success, ) = payable(msg.sender).call{value: withdrawAmount}("");
        require(success, "TimeLock: withdrawal failed");

        emit FundsWithdrawn(msg.sender, lockId, withdrawAmount);
    }


    function getLockRecord(address user, uint256 lockId)
        external
        view
        returns (
            uint256 amount,
            uint256 unlockTime,
            bool isWithdrawn,
            bool canWithdraw
        )
    {
        require(lockId < userLockCount[user], "TimeLock: invalid lock ID");

        LockRecord memory lockRecord = userLockRecords[user][lockId];

        return (
            lockRecord.amount,
            lockRecord.unlockTime,
            lockRecord.isWithdrawn,
            !lockRecord.isWithdrawn && block.timestamp >= lockRecord.unlockTime
        );
    }


    function getWithdrawableLocks(address user)
        external
        view
        returns (uint256[] memory withdrawableLockIds, uint256[] memory withdrawableAmounts)
    {
        uint256 count = userLockCount[user];
        uint256[] memory tempIds = new uint256[](count);
        uint256[] memory tempAmounts = new uint256[](count);
        uint256 withdrawableCount = 0;


        for (uint256 i = 0; i < count; i++) {
            LockRecord memory lockRecord = userLockRecords[user][i];
            if (!lockRecord.isWithdrawn && block.timestamp >= lockRecord.unlockTime) {
                tempIds[withdrawableCount] = i;
                tempAmounts[withdrawableCount] = lockRecord.amount;
                withdrawableCount++;
            }
        }


        withdrawableLockIds = new uint256[](withdrawableCount);
        withdrawableAmounts = new uint256[](withdrawableCount);

        for (uint256 i = 0; i < withdrawableCount; i++) {
            withdrawableLockIds[i] = tempIds[i];
            withdrawableAmounts[i] = tempAmounts[i];
        }
    }


    function getUserTotalLocked(address user)
        external
        view
        returns (uint256 totalLocked, uint256 currentLocked)
    {
        uint256 count = userLockCount[user];

        for (uint256 i = 0; i < count; i++) {
            LockRecord memory lockRecord = userLockRecords[user][i];
            totalLocked += lockRecord.amount;

            if (!lockRecord.isWithdrawn) {
                currentLocked += lockRecord.amount;
            }
        }
    }


    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "TimeLock: new owner is the zero address");
        require(newOwner != contractOwner, "TimeLock: new owner is the same as current owner");

        address previousOwner = contractOwner;
        contractOwner = newOwner;

        emit OwnershipTransferred(previousOwner, newOwner);
    }


    function getContractInfo()
        external
        view
        returns (
            address owner,
            uint256 totalLocked,
            uint256 contractBalance
        )
    {
        return (contractOwner, totalLockedAmount, address(this).balance);
    }


    function emergencyWithdraw() external onlyOwner {
        require(address(this).balance > 0, "TimeLock: no funds to withdraw");

        uint256 balance = address(this).balance;
        (bool success, ) = payable(contractOwner).call{value: balance}("");
        require(success, "TimeLock: emergency withdrawal failed");
    }


    receive() external payable {

        revert("TimeLock: use lockFunds function to deposit");
    }


    fallback() external payable {
        revert("TimeLock: function not found");
    }
}
