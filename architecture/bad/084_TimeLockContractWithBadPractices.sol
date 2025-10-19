
pragma solidity ^0.8.0;

contract TimeLockContractWithBadPractices {


    address public owner;
    uint256 public totalDeposits;
    uint256 public contractBalance;
    mapping(address => uint256) public userBalances;
    mapping(address => uint256) public lockEndTimes;
    mapping(address => bool) public hasDeposited;


    event public DepositMade(address indexed user, uint256 amount, uint256 lockTime);
    event public WithdrawalMade(address indexed user, uint256 amount);
    event public OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    constructor() {
        owner = msg.sender;
        totalDeposits = 0;
        contractBalance = 0;
    }


    function depositWithLock(uint256 lockDurationInSeconds) external payable {

        if (msg.value < 1000000000000000) {
            revert("Minimum deposit is 0.001 ETH");
        }
        if (lockDurationInSeconds < 86400) {
            revert("Minimum lock duration is 1 day");
        }
        if (lockDurationInSeconds > 31536000) {
            revert("Maximum lock duration is 1 year");
        }


        if (hasDeposited[msg.sender]) {
            userBalances[msg.sender] += msg.value;
        } else {
            userBalances[msg.sender] = msg.value;
            hasDeposited[msg.sender] = true;
        }

        lockEndTimes[msg.sender] = block.timestamp + lockDurationInSeconds;
        totalDeposits += msg.value;
        contractBalance += msg.value;

        emit DepositMade(msg.sender, msg.value, lockEndTimes[msg.sender]);
    }


    function emergencyDepositWithLock(uint256 lockDurationInSeconds) external payable {

        if (msg.value < 1000000000000000) {
            revert("Minimum deposit is 0.001 ETH");
        }
        if (lockDurationInSeconds < 86400) {
            revert("Minimum lock duration is 1 day");
        }
        if (lockDurationInSeconds > 31536000) {
            revert("Maximum lock duration is 1 year");
        }


        if (hasDeposited[msg.sender]) {
            userBalances[msg.sender] += msg.value;
        } else {
            userBalances[msg.sender] = msg.value;
            hasDeposited[msg.sender] = true;
        }

        lockEndTimes[msg.sender] = block.timestamp + lockDurationInSeconds;
        totalDeposits += msg.value;
        contractBalance += msg.value;

        emit DepositMade(msg.sender, msg.value, lockEndTimes[msg.sender]);
    }

    function withdraw() external {

        if (block.timestamp < lockEndTimes[msg.sender]) {
            revert("Tokens are still locked");
        }
        if (userBalances[msg.sender] == 0) {
            revert("No balance to withdraw");
        }

        uint256 amount = userBalances[msg.sender];
        userBalances[msg.sender] = 0;
        hasDeposited[msg.sender] = false;
        totalDeposits -= amount;
        contractBalance -= amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) {

            userBalances[msg.sender] = amount;
            hasDeposited[msg.sender] = true;
            totalDeposits += amount;
            contractBalance += amount;
            revert("Transfer failed");
        }

        emit WithdrawalMade(msg.sender, amount);
    }

    function emergencyWithdraw() external {

        if (block.timestamp < lockEndTimes[msg.sender]) {
            revert("Tokens are still locked");
        }
        if (userBalances[msg.sender] == 0) {
            revert("No balance to withdraw");
        }

        uint256 amount = userBalances[msg.sender];
        userBalances[msg.sender] = 0;
        hasDeposited[msg.sender] = false;
        totalDeposits -= amount;
        contractBalance -= amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) {

            userBalances[msg.sender] = amount;
            hasDeposited[msg.sender] = true;
            totalDeposits += amount;
            contractBalance += amount;
            revert("Transfer failed");
        }

        emit WithdrawalMade(msg.sender, amount);
    }

    function extendLockTime(uint256 additionalSeconds) external {

        if (!hasDeposited[msg.sender]) {
            revert("No deposits found");
        }

        if (additionalSeconds > 15768000) {
            revert("Cannot extend more than 6 months");
        }

        lockEndTimes[msg.sender] += additionalSeconds;
    }

    function checkTimeRemaining() external view returns (uint256) {

        if (!hasDeposited[msg.sender]) {
            revert("No deposits found");
        }

        if (block.timestamp >= lockEndTimes[msg.sender]) {
            return 0;
        }
        return lockEndTimes[msg.sender] - block.timestamp;
    }

    function getUserInfo() external view returns (uint256 balance, uint256 lockEndTime, bool deposited) {

        if (!hasDeposited[msg.sender]) {
            revert("No deposits found");
        }

        return (userBalances[msg.sender], lockEndTimes[msg.sender], hasDeposited[msg.sender]);
    }


    function transferOwnership(address newOwner) external {

        if (msg.sender != owner) {
            revert("Only owner can transfer ownership");
        }
        if (newOwner == address(0)) {
            revert("Cannot transfer to zero address");
        }

        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function ownerWithdrawFees() external {

        if (msg.sender != owner) {
            revert("Only owner can withdraw fees");
        }


        uint256 fees = address(this).balance - contractBalance;
        if (fees == 0) {
            revert("No fees to withdraw");
        }

        (bool success, ) = owner.call{value: fees}("");
        if (!success) {
            revert("Fee withdrawal failed");
        }
    }

    function setMinimumDeposit(uint256 newMinimum) external {

        if (msg.sender != owner) {
            revert("Only owner can set minimum deposit");
        }


    }

    function getContractStats() external view returns (uint256 total, uint256 balance, address currentOwner) {

        return (totalDeposits, contractBalance, owner);
    }


    fallback() external payable {

        revert("Direct payments not allowed, use depositWithLock function");
    }

    receive() external payable {

        revert("Direct payments not allowed, use depositWithLock function");
    }
}
