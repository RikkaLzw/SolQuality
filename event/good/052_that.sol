
pragma solidity ^0.8.0;


contract TimeLockContract {
    struct Deposit {
        uint256 amount;
        uint256 unlockTime;
        bool withdrawn;
    }

    mapping(address => Deposit[]) public userDeposits;
    mapping(address => uint256) public totalLocked;

    uint256 public constant MIN_LOCK_DURATION = 1 minutes;
    uint256 public constant MAX_LOCK_DURATION = 365 days;


    event DepositCreated(
        address indexed user,
        uint256 indexed depositId,
        uint256 amount,
        uint256 unlockTime
    );

    event WithdrawalExecuted(
        address indexed user,
        uint256 indexed depositId,
        uint256 amount
    );

    event EmergencyWithdrawal(
        address indexed user,
        uint256 amount
    );


    error InsufficientDeposit();
    error InvalidLockDuration();
    error DepositNotFound();
    error FundsStillLocked(uint256 unlockTime);
    error AlreadyWithdrawn();
    error WithdrawalFailed();
    error NoFundsToWithdraw();

    modifier validLockDuration(uint256 _lockDuration) {
        if (_lockDuration < MIN_LOCK_DURATION || _lockDuration > MAX_LOCK_DURATION) {
            revert InvalidLockDuration();
        }
        _;
    }

    modifier validDepositId(address _user, uint256 _depositId) {
        if (_depositId >= userDeposits[_user].length) {
            revert DepositNotFound();
        }
        _;
    }


    function createDeposit(uint256 _lockDuration)
        external
        payable
        validLockDuration(_lockDuration)
    {
        if (msg.value == 0) {
            revert InsufficientDeposit();
        }

        uint256 unlockTime = block.timestamp + _lockDuration;
        uint256 depositId = userDeposits[msg.sender].length;

        userDeposits[msg.sender].push(Deposit({
            amount: msg.value,
            unlockTime: unlockTime,
            withdrawn: false
        }));

        totalLocked[msg.sender] += msg.value;

        emit DepositCreated(msg.sender, depositId, msg.value, unlockTime);
    }


    function withdraw(uint256 _depositId)
        external
        validDepositId(msg.sender, _depositId)
    {
        Deposit storage deposit = userDeposits[msg.sender][_depositId];

        if (deposit.withdrawn) {
            revert AlreadyWithdrawn();
        }

        if (block.timestamp < deposit.unlockTime) {
            revert FundsStillLocked(deposit.unlockTime);
        }

        deposit.withdrawn = true;
        totalLocked[msg.sender] -= deposit.amount;

        (bool success, ) = payable(msg.sender).call{value: deposit.amount}("");
        if (!success) {
            revert WithdrawalFailed();
        }

        emit WithdrawalExecuted(msg.sender, _depositId, deposit.amount);
    }


    function emergencyWithdraw() external {
        uint256 totalAmount = 0;

        for (uint256 i = 0; i < userDeposits[msg.sender].length; i++) {
            if (!userDeposits[msg.sender][i].withdrawn) {
                totalAmount += userDeposits[msg.sender][i].amount;
                userDeposits[msg.sender][i].withdrawn = true;
            }
        }

        if (totalAmount == 0) {
            revert NoFundsToWithdraw();
        }

        totalLocked[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: totalAmount}("");
        if (!success) {
            revert WithdrawalFailed();
        }

        emit EmergencyWithdrawal(msg.sender, totalAmount);
    }


    function getDepositCount(address _user) external view returns (uint256) {
        return userDeposits[_user].length;
    }


    function getDeposit(address _user, uint256 _depositId)
        external
        view
        validDepositId(_user, _depositId)
        returns (uint256 amount, uint256 unlockTime, bool withdrawn)
    {
        Deposit storage deposit = userDeposits[_user][_depositId];
        return (deposit.amount, deposit.unlockTime, deposit.withdrawn);
    }


    function canWithdraw(address _user, uint256 _depositId)
        external
        view
        validDepositId(_user, _depositId)
        returns (bool)
    {
        Deposit storage deposit = userDeposits[_user][_depositId];
        return !deposit.withdrawn && block.timestamp >= deposit.unlockTime;
    }


    function getRemainingLockTime(address _user, uint256 _depositId)
        external
        view
        validDepositId(_user, _depositId)
        returns (uint256)
    {
        Deposit storage deposit = userDeposits[_user][_depositId];
        if (block.timestamp >= deposit.unlockTime) {
            return 0;
        }
        return deposit.unlockTime - block.timestamp;
    }
}
