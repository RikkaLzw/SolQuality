
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract TimelockTreasury is ReentrancyGuard, Ownable {
    using SafeMath for uint256;


    uint256 public constant MIN_DELAY = 1 days;
    uint256 public constant MAX_DELAY = 365 days;
    uint256 public constant GRACE_PERIOD = 14 days;


    struct TimeLock {
        address beneficiary;
        uint256 amount;
        uint256 releaseTime;
        bool executed;
        string description;
    }


    mapping(bytes32 => TimeLock) private _timelocks;
    mapping(address => bytes32[]) private _userTimelocks;
    bytes32[] private _allTimelockIds;

    uint256 private _timelockCounter;
    uint256 public totalLocked;


    event TimelockCreated(
        bytes32 indexed timelockId,
        address indexed beneficiary,
        uint256 amount,
        uint256 releaseTime,
        string description
    );

    event TimelockExecuted(
        bytes32 indexed timelockId,
        address indexed beneficiary,
        uint256 amount
    );

    event TimelockCancelled(
        bytes32 indexed timelockId,
        address indexed beneficiary,
        uint256 amount
    );


    modifier validDelay(uint256 delay) {
        require(delay >= MIN_DELAY && delay <= MAX_DELAY, "Invalid delay period");
        _;
    }

    modifier timelockExists(bytes32 timelockId) {
        require(_timelocks[timelockId].beneficiary != address(0), "Timelock does not exist");
        _;
    }

    modifier onlyBeneficiary(bytes32 timelockId) {
        require(_timelocks[timelockId].beneficiary == msg.sender, "Not the beneficiary");
        _;
    }

    modifier notExecuted(bytes32 timelockId) {
        require(!_timelocks[timelockId].executed, "Timelock already executed");
        _;
    }

    modifier afterReleaseTime(bytes32 timelockId) {
        require(block.timestamp >= _timelocks[timelockId].releaseTime, "Release time not reached");
        _;
    }

    modifier withinGracePeriod(bytes32 timelockId) {
        uint256 deadline = _timelocks[timelockId].releaseTime.add(GRACE_PERIOD);
        require(block.timestamp <= deadline, "Grace period expired");
        _;
    }


    function createTimelock(
        address beneficiary,
        uint256 delay,
        string memory description
    )
        external
        payable
        validDelay(delay)
        returns (bytes32 timelockId)
    {
        require(beneficiary != address(0), "Invalid beneficiary address");
        require(msg.value > 0, "Amount must be greater than 0");
        require(bytes(description).length > 0, "Description cannot be empty");

        timelockId = _generateTimelockId(beneficiary, delay, description);
        require(_timelocks[timelockId].beneficiary == address(0), "Timelock already exists");

        uint256 releaseTime = block.timestamp.add(delay);

        _timelocks[timelockId] = TimeLock({
            beneficiary: beneficiary,
            amount: msg.value,
            releaseTime: releaseTime,
            executed: false,
            description: description
        });

        _userTimelocks[beneficiary].push(timelockId);
        _allTimelockIds.push(timelockId);
        totalLocked = totalLocked.add(msg.value);

        emit TimelockCreated(timelockId, beneficiary, msg.value, releaseTime, description);
    }


    function executeTimelock(bytes32 timelockId)
        external
        nonReentrant
        timelockExists(timelockId)
        onlyBeneficiary(timelockId)
        notExecuted(timelockId)
        afterReleaseTime(timelockId)
        withinGracePeriod(timelockId)
    {
        TimeLock storage timelock = _timelocks[timelockId];
        timelock.executed = true;

        uint256 amount = timelock.amount;
        totalLocked = totalLocked.sub(amount);

        (bool success, ) = payable(timelock.beneficiary).call{value: amount}("");
        require(success, "Transfer failed");

        emit TimelockExecuted(timelockId, timelock.beneficiary, amount);
    }


    function cancelTimelock(bytes32 timelockId)
        external
        onlyOwner
        timelockExists(timelockId)
        notExecuted(timelockId)
    {
        TimeLock storage timelock = _timelocks[timelockId];
        timelock.executed = true;

        uint256 amount = timelock.amount;
        totalLocked = totalLocked.sub(amount);

        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "Transfer failed");

        emit TimelockCancelled(timelockId, timelock.beneficiary, amount);
    }


    function getTimelock(bytes32 timelockId)
        external
        view
        timelockExists(timelockId)
        returns (
            address beneficiary,
            uint256 amount,
            uint256 releaseTime,
            bool executed,
            string memory description
        )
    {
        TimeLock storage timelock = _timelocks[timelockId];
        return (
            timelock.beneficiary,
            timelock.amount,
            timelock.releaseTime,
            timelock.executed,
            timelock.description
        );
    }


    function getUserTimelocks(address user) external view returns (bytes32[] memory) {
        return _userTimelocks[user];
    }


    function getTotalTimelocks() external view returns (uint256) {
        return _allTimelockIds.length;
    }


    function isReadyForExecution(bytes32 timelockId)
        external
        view
        timelockExists(timelockId)
        returns (bool)
    {
        TimeLock storage timelock = _timelocks[timelockId];
        return !timelock.executed &&
               block.timestamp >= timelock.releaseTime &&
               block.timestamp <= timelock.releaseTime.add(GRACE_PERIOD);
    }


    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Emergency withdraw failed");
    }


    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }


    function _generateTimelockId(
        address beneficiary,
        uint256 delay,
        string memory description
    ) private returns (bytes32) {
        _timelockCounter = _timelockCounter.add(1);
        return keccak256(
            abi.encodePacked(
                beneficiary,
                delay,
                description,
                block.timestamp,
                _timelockCounter
            )
        );
    }


    receive() external payable {

    }
}
