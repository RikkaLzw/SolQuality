
pragma solidity ^0.8.0;


contract TimeLockContract {
    struct Deposit {
        uint256 amount;
        uint256 unlockTime;
        bool withdrawn;
    }

    mapping(address => Deposit[]) private userDeposits;
    mapping(address => uint256) private userDepositCount;

    event DepositMade(address indexed user, uint256 amount, uint256 unlockTime, uint256 depositId);
    event WithdrawalMade(address indexed user, uint256 amount, uint256 depositId);

    error InsufficientAmount();
    error InvalidLockDuration();
    error DepositNotFound();
    error StillLocked();
    error AlreadyWithdrawn();
    error WithdrawalFailed();


    function deposit(uint256 lockDuration) external payable {
        if (msg.value == 0) revert InsufficientAmount();
        if (lockDuration == 0) revert InvalidLockDuration();

        uint256 unlockTime = block.timestamp + lockDuration;
        uint256 depositId = userDepositCount[msg.sender];

        userDeposits[msg.sender].push(Deposit({
            amount: msg.value,
            unlockTime: unlockTime,
            withdrawn: false
        }));

        userDepositCount[msg.sender]++;

        emit DepositMade(msg.sender, msg.value, unlockTime, depositId);
    }


    function withdraw(uint256 depositId) external {
        if (depositId >= userDeposits[msg.sender].length) revert DepositNotFound();

        Deposit storage userDeposit = userDeposits[msg.sender][depositId];

        if (userDeposit.withdrawn) revert AlreadyWithdrawn();
        if (block.timestamp < userDeposit.unlockTime) revert StillLocked();

        uint256 amount = userDeposit.amount;
        userDeposit.withdrawn = true;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert WithdrawalFailed();

        emit WithdrawalMade(msg.sender, amount, depositId);
    }


    function getDeposit(address user, uint256 depositId)
        external
        view
        returns (uint256 amount, uint256 unlockTime, bool withdrawn)
    {
        if (depositId >= userDeposits[user].length) revert DepositNotFound();

        Deposit memory userDeposit = userDeposits[user][depositId];
        return (userDeposit.amount, userDeposit.unlockTime, userDeposit.withdrawn);
    }


    function getDepositCount(address user) external view returns (uint256 count) {
        return userDepositCount[user];
    }


    function isUnlocked(address user, uint256 depositId) external view returns (bool isUnlocked) {
        if (depositId >= userDeposits[user].length) return false;

        Deposit memory userDeposit = userDeposits[user][depositId];
        return block.timestamp >= userDeposit.unlockTime && !userDeposit.withdrawn;
    }


    function getRemainingLockTime(address user, uint256 depositId)
        external
        view
        returns (uint256 remainingTime)
    {
        if (depositId >= userDeposits[user].length) revert DepositNotFound();

        Deposit memory userDeposit = userDeposits[user][depositId];

        if (block.timestamp >= userDeposit.unlockTime) {
            return 0;
        }

        return userDeposit.unlockTime - block.timestamp;
    }
}
