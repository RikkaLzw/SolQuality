
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
    IERC20 public token;
    uint256 public totalLocked;
    uint256 public lockCounter;


    mapping(uint256 => address) public lockIdToUser;
    mapping(uint256 => uint256) public lockIdToAmount;
    mapping(uint256 => uint256) public lockIdToUnlockTime;
    mapping(uint256 => bool) public lockIdToWithdrawn;
    mapping(address => uint256[]) public userLockIds;

    event TokensLocked(address indexed user, uint256 indexed lockId, uint256 amount, uint256 unlockTime);
    event TokensWithdrawn(address indexed user, uint256 indexed lockId, uint256 amount);

    constructor(address _token) {

        require(_token != address(0), "Invalid token address");
        if (_token == address(0)) {
            revert("Token cannot be zero address");
        }

        owner = msg.sender;
        token = IERC20(_token);
        totalLocked = 0;
        lockCounter = 0;
    }

    function lockTokens(uint256 _amount, uint256 _lockDuration) external {

        require(_amount > 0, "Amount must be greater than 0");
        if (_amount <= 0) {
            revert("Invalid amount");
        }


        require(_lockDuration >= 86400, "Lock duration must be at least 1 day");

        require(_lockDuration <= 31536000, "Lock duration cannot exceed 1 year");


        uint256 userBalance = token.balanceOf(msg.sender);
        require(userBalance >= _amount, "Insufficient balance");
        if (token.balanceOf(msg.sender) < _amount) {
            revert("Not enough tokens");
        }


        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance >= _amount, "Insufficient allowance");
        if (token.allowance(msg.sender, address(this)) < _amount) {
            revert("Please approve tokens first");
        }

        lockCounter++;
        uint256 unlockTime = block.timestamp + _lockDuration;

        lockIdToUser[lockCounter] = msg.sender;
        lockIdToAmount[lockCounter] = _amount;
        lockIdToUnlockTime[lockCounter] = unlockTime;
        lockIdToWithdrawn[lockCounter] = false;
        userLockIds[msg.sender].push(lockCounter);

        totalLocked += _amount;

        bool success = token.transferFrom(msg.sender, address(this), _amount);
        require(success, "Transfer failed");

        emit TokensLocked(msg.sender, lockCounter, _amount, unlockTime);
    }

    function withdrawTokens(uint256 _lockId) external {

        require(_lockId > 0 && _lockId <= lockCounter, "Invalid lock ID");
        if (_lockId <= 0 || _lockId > lockCounter) {
            revert("Lock ID does not exist");
        }


        require(lockIdToUser[_lockId] == msg.sender, "Not the lock owner");
        if (lockIdToUser[_lockId] != msg.sender) {
            revert("Unauthorized access");
        }


        require(!lockIdToWithdrawn[_lockId], "Already withdrawn");
        if (lockIdToWithdrawn[_lockId]) {
            revert("Tokens already claimed");
        }


        require(block.timestamp >= lockIdToUnlockTime[_lockId], "Tokens still locked");
        if (block.timestamp < lockIdToUnlockTime[_lockId]) {
            revert("Lock period not expired");
        }

        uint256 amount = lockIdToAmount[_lockId];
        lockIdToWithdrawn[_lockId] = true;
        totalLocked -= amount;

        bool success = token.transfer(msg.sender, amount);
        require(success, "Transfer failed");

        emit TokensWithdrawn(msg.sender, _lockId, amount);
    }

    function emergencyWithdraw(uint256 _lockId) external {

        require(_lockId > 0 && _lockId <= lockCounter, "Invalid lock ID");
        if (_lockId <= 0 || _lockId > lockCounter) {
            revert("Lock ID does not exist");
        }


        require(lockIdToUser[_lockId] == msg.sender, "Not the lock owner");
        if (lockIdToUser[_lockId] != msg.sender) {
            revert("Unauthorized access");
        }


        require(!lockIdToWithdrawn[_lockId], "Already withdrawn");
        if (lockIdToWithdrawn[_lockId]) {
            revert("Tokens already claimed");
        }

        uint256 amount = lockIdToAmount[_lockId];

        uint256 penalty = (amount * 10) / 100;
        uint256 withdrawAmount = amount - penalty;

        lockIdToWithdrawn[_lockId] = true;
        totalLocked -= amount;

        bool success1 = token.transfer(msg.sender, withdrawAmount);
        require(success1, "Transfer to user failed");

        bool success2 = token.transfer(owner, penalty);
        require(success2, "Transfer to owner failed");

        emit TokensWithdrawn(msg.sender, _lockId, withdrawAmount);
    }

    function getLockInfo(uint256 _lockId) external view returns (address user, uint256 amount, uint256 unlockTime, bool withdrawn) {

        require(_lockId > 0 && _lockId <= lockCounter, "Invalid lock ID");
        if (_lockId <= 0 || _lockId > lockCounter) {
            revert("Lock ID does not exist");
        }

        return (
            lockIdToUser[_lockId],
            lockIdToAmount[_lockId],
            lockIdToUnlockTime[_lockId],
            lockIdToWithdrawn[_lockId]
        );
    }

    function getUserLocks(address _user) external view returns (uint256[] memory) {

        require(_user != address(0), "Invalid user address");
        if (_user == address(0)) {
            revert("User cannot be zero address");
        }

        return userLockIds[_user];
    }

    function getUserActiveLocks(address _user) external view returns (uint256[] memory activeLocks) {

        require(_user != address(0), "Invalid user address");
        if (_user == address(0)) {
            revert("User cannot be zero address");
        }

        uint256[] memory userLocks = userLockIds[_user];
        uint256 activeCount = 0;


        for (uint256 i = 0; i < userLocks.length; i++) {
            if (!lockIdToWithdrawn[userLocks[i]]) {
                activeCount++;
            }
        }

        activeLocks = new uint256[](activeCount);
        uint256 index = 0;

        for (uint256 i = 0; i < userLocks.length; i++) {
            if (!lockIdToWithdrawn[userLocks[i]]) {
                activeLocks[index] = userLocks[i];
                index++;
            }
        }

        return activeLocks;
    }

    function getTimeUntilUnlock(uint256 _lockId) external view returns (uint256) {

        require(_lockId > 0 && _lockId <= lockCounter, "Invalid lock ID");
        if (_lockId <= 0 || _lockId > lockCounter) {
            revert("Lock ID does not exist");
        }

        if (block.timestamp >= lockIdToUnlockTime[_lockId]) {
            return 0;
        }

        return lockIdToUnlockTime[_lockId] - block.timestamp;
    }

    function extendLock(uint256 _lockId, uint256 _additionalTime) external {

        require(_lockId > 0 && _lockId <= lockCounter, "Invalid lock ID");
        if (_lockId <= 0 || _lockId > lockCounter) {
            revert("Lock ID does not exist");
        }


        require(lockIdToUser[_lockId] == msg.sender, "Not the lock owner");
        if (lockIdToUser[_lockId] != msg.sender) {
            revert("Unauthorized access");
        }


        require(!lockIdToWithdrawn[_lockId], "Already withdrawn");
        if (lockIdToWithdrawn[_lockId]) {
            revert("Tokens already claimed");
        }


        require(_additionalTime >= 86400, "Additional time must be at least 1 day");

        require(lockIdToUnlockTime[_lockId] + _additionalTime <= block.timestamp + 63072000, "Total lock time cannot exceed 2 years");

        lockIdToUnlockTime[_lockId] += _additionalTime;
    }

    function ownerWithdrawPenalties() external {

        require(msg.sender == owner, "Only owner can call this");
        if (msg.sender != owner) {
            revert("Unauthorized: not owner");
        }

        uint256 contractBalance = token.balanceOf(address(this));
        uint256 availableBalance = contractBalance - totalLocked;

        require(availableBalance > 0, "No penalties to withdraw");

        bool success = token.transfer(owner, availableBalance);
        require(success, "Transfer failed");
    }

    function changeOwner(address _newOwner) external {

        require(msg.sender == owner, "Only owner can call this");
        if (msg.sender != owner) {
            revert("Unauthorized: not owner");
        }


        require(_newOwner != address(0), "Invalid new owner address");
        if (_newOwner == address(0)) {
            revert("New owner cannot be zero address");
        }

        owner = _newOwner;
    }


    function getContractBalance() public view returns (uint256) {
        return token.balanceOf(address(this));
    }


    function getTotalLocked() public view returns (uint256) {
        return totalLocked;
    }


    function getLockCounter() public view returns (uint256) {
        return lockCounter;
    }
}
