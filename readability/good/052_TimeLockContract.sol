
pragma solidity ^0.8.0;


contract TimeLockContract {


    struct DepositRecord {
        uint256 amount;
        uint256 unlockTime;
        bool isWithdrawn;
    }


    mapping(address => DepositRecord[]) public userDeposits;
    mapping(address => uint256) public totalLockedAmount;

    uint256 public constant MINIMUM_LOCK_DURATION = 1 days;
    uint256 public constant MAXIMUM_LOCK_DURATION = 365 days;


    event DepositMade(
        address indexed depositor,
        uint256 amount,
        uint256 unlockTime,
        uint256 depositIndex
    );

    event WithdrawalMade(
        address indexed withdrawer,
        uint256 amount,
        uint256 depositIndex
    );


    modifier validLockDuration(uint256 _lockDuration) {
        require(
            _lockDuration >= MINIMUM_LOCK_DURATION &&
            _lockDuration <= MAXIMUM_LOCK_DURATION,
            "TimeLock: Invalid lock duration"
        );
        _;
    }


    modifier validDepositIndex(uint256 _depositIndex) {
        require(
            _depositIndex < userDeposits[msg.sender].length,
            "TimeLock: Invalid deposit index"
        );
        _;
    }


    function depositWithTimeLock(uint256 _lockDuration)
        external
        payable
        validLockDuration(_lockDuration)
    {
        require(msg.value > 0, "TimeLock: Deposit amount must be greater than 0");

        uint256 unlockTime = block.timestamp + _lockDuration;


        DepositRecord memory newDeposit = DepositRecord({
            amount: msg.value,
            unlockTime: unlockTime,
            isWithdrawn: false
        });


        userDeposits[msg.sender].push(newDeposit);


        totalLockedAmount[msg.sender] += msg.value;


        emit DepositMade(
            msg.sender,
            msg.value,
            unlockTime,
            userDeposits[msg.sender].length - 1
        );
    }


    function withdrawDeposit(uint256 _depositIndex)
        external
        validDepositIndex(_depositIndex)
    {
        DepositRecord storage deposit = userDeposits[msg.sender][_depositIndex];

        require(!deposit.isWithdrawn, "TimeLock: Deposit already withdrawn");
        require(
            block.timestamp >= deposit.unlockTime,
            "TimeLock: Funds are still locked"
        );
        require(deposit.amount > 0, "TimeLock: No funds to withdraw");

        uint256 withdrawAmount = deposit.amount;


        deposit.isWithdrawn = true;


        totalLockedAmount[msg.sender] -= withdrawAmount;


        (bool success, ) = payable(msg.sender).call{value: withdrawAmount}("");
        require(success, "TimeLock: Transfer failed");


        emit WithdrawalMade(msg.sender, withdrawAmount, _depositIndex);
    }


    function getUserDepositCount(address _user) external view returns (uint256) {
        return userDeposits[_user].length;
    }


    function getDepositDetails(address _user, uint256 _depositIndex)
        external
        view
        returns (
            uint256 amount,
            uint256 unlockTime,
            bool isWithdrawn
        )
    {
        require(
            _depositIndex < userDeposits[_user].length,
            "TimeLock: Invalid deposit index"
        );

        DepositRecord storage deposit = userDeposits[_user][_depositIndex];
        return (deposit.amount, deposit.unlockTime, deposit.isWithdrawn);
    }


    function canWithdraw(address _user, uint256 _depositIndex)
        external
        view
        returns (bool)
    {
        if (_depositIndex >= userDeposits[_user].length) {
            return false;
        }

        DepositRecord storage deposit = userDeposits[_user][_depositIndex];
        return !deposit.isWithdrawn && block.timestamp >= deposit.unlockTime;
    }


    function getWithdrawableDeposits(address _user)
        external
        view
        returns (uint256[] memory)
    {
        uint256 depositCount = userDeposits[_user].length;
        uint256[] memory tempArray = new uint256[](depositCount);
        uint256 withdrawableCount = 0;


        for (uint256 i = 0; i < depositCount; i++) {
            DepositRecord storage deposit = userDeposits[_user][i];
            if (!deposit.isWithdrawn && block.timestamp >= deposit.unlockTime) {
                tempArray[withdrawableCount] = i;
                withdrawableCount++;
            }
        }


        uint256[] memory withdrawableIndexes = new uint256[](withdrawableCount);
        for (uint256 i = 0; i < withdrawableCount; i++) {
            withdrawableIndexes[i] = tempArray[i];
        }

        return withdrawableIndexes;
    }


    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }


    receive() external payable {
        revert("TimeLock: Direct transfers not allowed, use depositWithTimeLock");
    }

    fallback() external payable {
        revert("TimeLock: Function not found");
    }
}
