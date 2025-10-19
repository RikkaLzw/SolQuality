
pragma solidity ^0.8.0;

contract TimeLockContract {
    struct LockedFunds {
        uint256 amount;
        uint64 unlockTime;
        address beneficiary;
        bool withdrawn;
    }

    mapping(bytes32 => LockedFunds) public lockedDeposits;
    mapping(address => bytes32[]) public userDeposits;

    address public immutable owner;
    uint32 public constant MIN_LOCK_DURATION = 1 hours;
    uint32 public constant MAX_LOCK_DURATION = 365 days;

    event FundsLocked(
        bytes32 indexed depositId,
        address indexed depositor,
        address indexed beneficiary,
        uint256 amount,
        uint64 unlockTime
    );

    event FundsWithdrawn(
        bytes32 indexed depositId,
        address indexed beneficiary,
        uint256 amount
    );

    error InsufficientAmount();
    error InvalidLockDuration();
    error InvalidBeneficiary();
    error DepositNotFound();
    error FundsStillLocked();
    error AlreadyWithdrawn();
    error UnauthorizedWithdrawal();
    error TransferFailed();

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function lockFunds(
        address beneficiary,
        uint32 lockDuration
    ) external payable returns (bytes32 depositId) {
        if (msg.value == 0) revert InsufficientAmount();
        if (lockDuration < MIN_LOCK_DURATION || lockDuration > MAX_LOCK_DURATION) {
            revert InvalidLockDuration();
        }
        if (beneficiary == address(0)) revert InvalidBeneficiary();

        uint64 unlockTime = uint64(block.timestamp) + lockDuration;
        depositId = keccak256(
            abi.encodePacked(
                msg.sender,
                beneficiary,
                msg.value,
                block.timestamp,
                block.number
            )
        );

        lockedDeposits[depositId] = LockedFunds({
            amount: msg.value,
            unlockTime: unlockTime,
            beneficiary: beneficiary,
            withdrawn: false
        });

        userDeposits[msg.sender].push(depositId);

        emit FundsLocked(depositId, msg.sender, beneficiary, msg.value, unlockTime);
    }

    function withdrawFunds(bytes32 depositId) external {
        LockedFunds storage deposit = lockedDeposits[depositId];

        if (deposit.amount == 0) revert DepositNotFound();
        if (deposit.withdrawn) revert AlreadyWithdrawn();
        if (msg.sender != deposit.beneficiary) revert UnauthorizedWithdrawal();
        if (block.timestamp < deposit.unlockTime) revert FundsStillLocked();

        deposit.withdrawn = true;
        uint256 amount = deposit.amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit FundsWithdrawn(depositId, msg.sender, amount);
    }

    function getDepositInfo(bytes32 depositId)
        external
        view
        returns (
            uint256 amount,
            uint64 unlockTime,
            address beneficiary,
            bool withdrawn,
            bool canWithdraw
        )
    {
        LockedFunds memory deposit = lockedDeposits[depositId];
        if (deposit.amount == 0) revert DepositNotFound();

        return (
            deposit.amount,
            deposit.unlockTime,
            deposit.beneficiary,
            deposit.withdrawn,
            !deposit.withdrawn && block.timestamp >= deposit.unlockTime
        );
    }

    function getUserDeposits(address user)
        external
        view
        returns (bytes32[] memory)
    {
        return userDeposits[user];
    }

    function getTimeRemaining(bytes32 depositId)
        external
        view
        returns (uint64 timeRemaining)
    {
        LockedFunds memory deposit = lockedDeposits[depositId];
        if (deposit.amount == 0) revert DepositNotFound();

        if (block.timestamp >= deposit.unlockTime) {
            return 0;
        }

        return deposit.unlockTime - uint64(block.timestamp);
    }

    function emergencyWithdraw(bytes32 depositId) external onlyOwner {
        LockedFunds storage deposit = lockedDeposits[depositId];

        if (deposit.amount == 0) revert DepositNotFound();
        if (deposit.withdrawn) revert AlreadyWithdrawn();

        deposit.withdrawn = true;
        uint256 amount = deposit.amount;
        address beneficiary = deposit.beneficiary;

        (bool success, ) = payable(beneficiary).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit FundsWithdrawn(depositId, beneficiary, amount);
    }

    receive() external payable {
        revert("Use lockFunds function");
    }
}
