
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

    event EmergencyWithdrawal(
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


        emit FundsLocked(msg.sender, lockId, msg.value, unlockTime);
    }


    function withdrawFunds(uint256 _lockId) external {
        require(_lockId < userLockCount[msg.sender], "Invalid lock ID");

        LockRecord storage lockRecord = userLockRecords[msg.sender][_lockId];

        require(!lockRecord.isWithdrawn, "Funds already withdrawn");
        require(block.timestamp >= lockRecord.unlockTime, "Funds are still locked");
        require(lockRecord.amount > 0, "No funds to withdraw");

        uint256 amountToWithdraw = lockRecord.amount;


        lockRecord.isWithdrawn = true;


        (bool success, ) = payable(msg.sender).call{value: amountToWithdraw}("");
        require(success, "Transfer failed");


        emit FundsWithdrawn(msg.sender, _lockId, amountToWithdraw);
    }


    function getLockInfo(address _user, uint256 _lockId)
        external
        view
        returns (
            uint256 amount,
            uint256 unlockTime,
            bool isWithdrawn,
            uint256 timeRemaining
        )
    {
        require(_lockId < userLockCount[_user], "Invalid lock ID");

        LockRecord memory lockRecord = userLockRecords[_user][_lockId];

        amount = lockRecord.amount;
        unlockTime = lockRecord.unlockTime;
        isWithdrawn = lockRecord.isWithdrawn;

        if (block.timestamp >= lockRecord.unlockTime) {
            timeRemaining = 0;
        } else {
            timeRemaining = lockRecord.unlockTime - block.timestamp;
        }
    }


    function canWithdrawFunds(address _user, uint256 _lockId)
        external
        view
        returns (bool canWithdraw)
    {
        if (_lockId >= userLockCount[_user]) {
            return false;
        }

        LockRecord memory lockRecord = userLockRecords[_user][_lockId];

        return (
            !lockRecord.isWithdrawn &&
            block.timestamp >= lockRecord.unlockTime &&
            lockRecord.amount > 0
        );
    }


    function getUserTotalAmounts(address _user)
        external
        view
        returns (uint256 totalLocked, uint256 totalWithdrawable)
    {
        uint256 lockCount = userLockCount[_user];

        for (uint256 i = 0; i < lockCount; i++) {
            LockRecord memory lockRecord = userLockRecords[_user][i];

            if (!lockRecord.isWithdrawn) {
                totalLocked += lockRecord.amount;

                if (block.timestamp >= lockRecord.unlockTime) {
                    totalWithdrawable += lockRecord.amount;
                }
            }
        }
    }


    function getContractBalance() external view returns (uint256 balance) {
        return address(this).balance;
    }


    function emergencyWithdraw(uint256 _amount) external onlyOwner {
        require(_amount <= address(this).balance, "Insufficient contract balance");

        (bool success, ) = payable(contractOwner).call{value: _amount}("");
        require(success, "Emergency withdrawal failed");

        emit EmergencyWithdrawal(contractOwner, _amount);
    }


    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        require(_newOwner != contractOwner, "New owner must be different from current owner");

        contractOwner = _newOwner;
    }


    receive() external payable {


    }
}
