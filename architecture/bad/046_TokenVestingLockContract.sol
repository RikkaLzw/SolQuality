
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract TokenVestingLockContract {


    address public owner;
    IERC20 internal token;
    uint256 internal totalLocked;
    bool internal contractActive;


    mapping(address => uint256) public lockedAmounts;
    mapping(address => uint256) public lockStartTime;
    mapping(address => uint256) public lockDuration;
    mapping(address => uint256) public releasedAmounts;
    mapping(address => bool) public isLocked;

    event TokensLocked(address indexed user, uint256 amount, uint256 duration);
    event TokensReleased(address indexed user, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address _token) {

        require(msg.sender != address(0), "Owner cannot be zero address");
        owner = msg.sender;
        token = IERC20(_token);
        contractActive = true;
        totalLocked = 0;
    }

    function lockTokens(address user, uint256 amount, uint256 durationInSeconds) external {

        require(msg.sender == owner, "Only owner can lock tokens");
        require(contractActive == true, "Contract is not active");
        require(user != address(0), "User cannot be zero address");
        require(amount > 0, "Amount must be greater than zero");
        require(durationInSeconds >= 86400, "Duration must be at least 1 day");


        if (isLocked[user] == true) {
            require(block.timestamp >= lockStartTime[user] + lockDuration[user], "Previous lock still active");
        }

        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        lockedAmounts[user] = amount;
        lockStartTime[user] = block.timestamp;
        lockDuration[user] = durationInSeconds;
        releasedAmounts[user] = 0;
        isLocked[user] = true;
        totalLocked = totalLocked + amount;

        emit TokensLocked(user, amount, durationInSeconds);
    }

    function batchLockTokens(address[] memory users, uint256[] memory amounts, uint256[] memory durations) external {

        require(msg.sender == owner, "Only owner can lock tokens");
        require(contractActive == true, "Contract is not active");
        require(users.length == amounts.length && amounts.length == durations.length, "Arrays length mismatch");
        require(users.length <= 100, "Too many users");

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            uint256 amount = amounts[i];
            uint256 durationInSeconds = durations[i];


            require(user != address(0), "User cannot be zero address");
            require(amount > 0, "Amount must be greater than zero");
            require(durationInSeconds >= 86400, "Duration must be at least 1 day");

            if (isLocked[user] == true) {
                require(block.timestamp >= lockStartTime[user] + lockDuration[user], "Previous lock still active");
            }

            require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");

            lockedAmounts[user] = amount;
            lockStartTime[user] = block.timestamp;
            lockDuration[user] = durationInSeconds;
            releasedAmounts[user] = 0;
            isLocked[user] = true;
            totalLocked = totalLocked + amount;

            emit TokensLocked(user, amount, durationInSeconds);
        }
    }

    function releaseTokens() external {
        address user = msg.sender;


        require(isLocked[user] == true, "No tokens locked for user");
        require(block.timestamp >= lockStartTime[user] + lockDuration[user], "Tokens are still locked");

        uint256 amount = lockedAmounts[user];
        require(amount > 0, "No tokens to release");


        lockedAmounts[user] = 0;
        releasedAmounts[user] = releasedAmounts[user] + amount;
        isLocked[user] = false;
        totalLocked = totalLocked - amount;

        require(token.transfer(user, amount), "Transfer failed");

        emit TokensReleased(user, amount);
    }

    function forceReleaseTokens(address user) external {

        require(msg.sender == owner, "Only owner can force release");
        require(contractActive == true, "Contract is not active");


        require(isLocked[user] == true, "No tokens locked for user");

        uint256 amount = lockedAmounts[user];
        require(amount > 0, "No tokens to release");


        lockedAmounts[user] = 0;
        releasedAmounts[user] = releasedAmounts[user] + amount;
        isLocked[user] = false;
        totalLocked = totalLocked - amount;

        require(token.transfer(user, amount), "Transfer failed");

        emit TokensReleased(user, amount);
    }

    function partialReleaseTokens(uint256 releaseAmount) external {
        address user = msg.sender;


        require(isLocked[user] == true, "No tokens locked for user");
        require(block.timestamp >= lockStartTime[user] + lockDuration[user], "Tokens are still locked");
        require(releaseAmount > 0, "Release amount must be greater than zero");

        uint256 lockedAmount = lockedAmounts[user];
        require(lockedAmount >= releaseAmount, "Insufficient locked tokens");

        lockedAmounts[user] = lockedAmount - releaseAmount;
        releasedAmounts[user] = releasedAmounts[user] + releaseAmount;
        totalLocked = totalLocked - releaseAmount;

        if (lockedAmounts[user] == 0) {
            isLocked[user] = false;
        }

        require(token.transfer(user, releaseAmount), "Transfer failed");

        emit TokensReleased(user, releaseAmount);
    }

    function extendLockDuration(address user, uint256 additionalSeconds) external {

        require(msg.sender == owner, "Only owner can extend lock");
        require(contractActive == true, "Contract is not active");


        require(user != address(0), "User cannot be zero address");
        require(isLocked[user] == true, "No tokens locked for user");
        require(additionalSeconds > 0, "Additional seconds must be greater than zero");
        require(additionalSeconds <= 31536000, "Cannot extend more than 1 year");

        lockDuration[user] = lockDuration[user] + additionalSeconds;
    }

    function reduceLockDuration(address user, uint256 reduceSeconds) external {

        require(msg.sender == owner, "Only owner can reduce lock");
        require(contractActive == true, "Contract is not active");


        require(user != address(0), "User cannot be zero address");
        require(isLocked[user] == true, "No tokens locked for user");
        require(reduceSeconds > 0, "Reduce seconds must be greater than zero");

        uint256 currentDuration = lockDuration[user];
        require(currentDuration > reduceSeconds, "Cannot reduce below zero");

        uint256 newDuration = currentDuration - reduceSeconds;
        require(newDuration >= 86400, "Duration cannot be less than 1 day");

        lockDuration[user] = newDuration;
    }

    function emergencyWithdraw(address emergencyAddress) external {

        require(msg.sender == owner, "Only owner can emergency withdraw");
        require(emergencyAddress != address(0), "Emergency address cannot be zero");

        uint256 contractBalance = token.balanceOf(address(this));
        require(contractBalance > 0, "No tokens to withdraw");

        contractActive = false;

        require(token.transfer(emergencyAddress, contractBalance), "Emergency transfer failed");
    }

    function pauseContract() external {

        require(msg.sender == owner, "Only owner can pause");
        require(contractActive == true, "Contract already paused");

        contractActive = false;
    }

    function unpauseContract() external {

        require(msg.sender == owner, "Only owner can unpause");
        require(contractActive == false, "Contract already active");

        contractActive = true;
    }

    function transferOwnership(address newOwner) external {

        require(msg.sender == owner, "Only owner can transfer ownership");
        require(newOwner != address(0), "New owner cannot be zero address");
        require(newOwner != owner, "New owner cannot be current owner");

        address previousOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(previousOwner, newOwner);
    }


    function getUserLockInfo(address user) public view returns (uint256, uint256, uint256, uint256, bool) {
        return (
            lockedAmounts[user],
            lockStartTime[user],
            lockDuration[user],
            releasedAmounts[user],
            isLocked[user]
        );
    }

    function getRemainingLockTime(address user) public view returns (uint256) {
        if (!isLocked[user]) {
            return 0;
        }

        uint256 unlockTime = lockStartTime[user] + lockDuration[user];
        if (block.timestamp >= unlockTime) {
            return 0;
        }

        return unlockTime - block.timestamp;
    }

    function isTokensUnlocked(address user) public view returns (bool) {
        if (!isLocked[user]) {
            return false;
        }

        return block.timestamp >= lockStartTime[user] + lockDuration[user];
    }

    function getContractInfo() public view returns (address, address, uint256, bool) {
        return (owner, address(token), totalLocked, contractActive);
    }

    function calculateVestingAmount(address user, uint256 timestamp) public view returns (uint256) {
        if (!isLocked[user]) {
            return 0;
        }

        uint256 startTime = lockStartTime[user];
        uint256 duration = lockDuration[user];
        uint256 totalAmount = lockedAmounts[user];

        if (timestamp <= startTime) {
            return 0;
        }

        if (timestamp >= startTime + duration) {
            return totalAmount;
        }


        uint256 elapsedTime = timestamp - startTime;
        return (totalAmount * elapsedTime) / duration;
    }

    function getAvailableForRelease(address user) public view returns (uint256) {
        if (!isLocked[user]) {
            return 0;
        }

        uint256 vestedAmount = calculateVestingAmount(user, block.timestamp);
        uint256 alreadyReleased = releasedAmounts[user];

        if (vestedAmount <= alreadyReleased) {
            return 0;
        }

        return vestedAmount - alreadyReleased;
    }
}
