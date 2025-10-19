
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

    event EmergencyWithdraw(
        address indexed owner,
        uint256 amount
    );


    modifier onlyOwner() {
        require(msg.sender == contractOwner, "Only contract owner can call this function");
        _;
    }


    modifier validLockDuration(uint256 _lockDuration) {
        require(
            _lockDuration >= MIN_LOCK_DURATION && _lockDuration <= MAX_LOCK_DURATION,
            "Lock duration must be between 1 minute and 365 days"
        );
        _;
    }


    constructor() {
        contractOwner = msg.sender;
    }


    function lockFunds(uint256 _lockDuration)
        external
        payable
        validLockDuration(_lockDuration)
    {
        require(msg.value > 0, "Must send some Ether to lock");

        uint256 lockId = userLockCount[msg.sender];
        uint256 unlockTime = block.timestamp + _lockDuration;


        userLockRecords[msg.sender][lockId] = LockRecord({
            amount: msg.value,
            unlockTime: unlockTime,
            isWithdrawn: false
        });


        userLockCount[msg.sender]++;
        totalLockedAmount += msg.value;


        emit FundsLocked(msg.sender, lockId, msg.value, unlockTime);
    }


    function withdrawFunds(uint256 _lockId) external {
        require(_lockId < userLockCount[msg.sender], "Invalid lock ID");

        LockRecord storage lockRecord = userLockRecords[msg.sender][_lockId];

        require(!lockRecord.isWithdrawn, "Funds already withdrawn");
        require(block.timestamp >= lockRecord.unlockTime, "Funds are still locked");
        require(lockRecord.amount > 0, "No funds to withdraw");

        uint256 withdrawAmount = lockRecord.amount;


        lockRecord.isWithdrawn = true;


        totalLockedAmount -= withdrawAmount;


        (bool success, ) = payable(msg.sender).call{value: withdrawAmount}("");
        require(success, "Transfer failed");


        emit FundsWithdrawn(msg.sender, _lockId, withdrawAmount);
    }


    function getLockInfo(address _user, uint256 _lockId)
        external
        view
        returns (
            uint256 amount,
            uint256 unlockTime,
            bool isWithdrawn,
            bool canWithdraw
        )
    {
        require(_lockId < userLockCount[_user], "Invalid lock ID");

        LockRecord memory lockRecord = userLockRecords[_user][_lockId];

        return (
            lockRecord.amount,
            lockRecord.unlockTime,
            lockRecord.isWithdrawn,
            !lockRecord.isWithdrawn && block.timestamp >= lockRecord.unlockTime
        );
    }


    function getUserLockCount(address _user) external view returns (uint256) {
        return userLockCount[_user];
    }


    function getWithdrawableAmount(address _user) external view returns (uint256) {
        uint256 withdrawableAmount = 0;
        uint256 lockCount = userLockCount[_user];

        for (uint256 i = 0; i < lockCount; i++) {
            LockRecord memory lockRecord = userLockRecords[_user][i];

            if (!lockRecord.isWithdrawn && block.timestamp >= lockRecord.unlockTime) {
                withdrawableAmount += lockRecord.amount;
            }
        }

        return withdrawableAmount;
    }


    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }


    function emergencyWithdraw() external onlyOwner {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "No funds to withdraw");

        (bool success, ) = payable(contractOwner).call{value: contractBalance}("");
        require(success, "Emergency withdraw failed");

        emit EmergencyWithdraw(contractOwner, contractBalance);
    }


    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        require(_newOwner != contractOwner, "New owner must be different from current owner");

        contractOwner = _newOwner;
    }


    receive() external payable {
        revert("Use lockFunds function to deposit Ether");
    }


    fallback() external payable {
        revert("Function does not exist");
    }
}
