
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
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


    mapping(address => bool) public authorizedUsers;

    event TokensLocked(address indexed user, uint256 indexed lockId, uint256 amount, uint256 unlockTime);
    event TokensWithdrawn(address indexed user, uint256 indexed lockId, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address _token) {

        require(msg.sender != address(0), "Invalid owner");
        owner = msg.sender;


        require(_token != address(0), "Invalid token address");
        token = IERC20(_token);

        lockCounter = 0;
        totalLocked = 0;
    }

    function lockTokens(uint256 _amount, uint256 _lockDuration) external {

        require(msg.sender != address(0), "Invalid sender");
        require(_amount > 0, "Amount must be greater than 0");


        require(_lockDuration >= 86400, "Lock duration must be at least 1 day");


        require(_lockDuration <= 31536000, "Lock duration cannot exceed 1 year");


        require(token.transferFrom(msg.sender, address(this), _amount), "Transfer failed");

        lockCounter++;
        uint256 unlockTime = block.timestamp + _lockDuration;

        lockIdToUser[lockCounter] = msg.sender;
        lockIdToAmount[lockCounter] = _amount;
        lockIdToUnlockTime[lockCounter] = unlockTime;
        lockIdToWithdrawn[lockCounter] = false;

        userLockIds[msg.sender].push(lockCounter);
        totalLocked += _amount;

        emit TokensLocked(msg.sender, lockCounter, _amount, unlockTime);
    }

    function lockTokensForUser(address _user, uint256 _amount, uint256 _lockDuration) external {

        require(msg.sender == owner, "Only owner can call this function");


        require(_user != address(0), "Invalid user address");
        require(_amount > 0, "Amount must be greater than 0");


        require(_lockDuration >= 86400, "Lock duration must be at least 1 day");
        require(_lockDuration <= 31536000, "Lock duration cannot exceed 1 year");


        require(token.transferFrom(msg.sender, address(this), _amount), "Transfer failed");

        lockCounter++;
        uint256 unlockTime = block.timestamp + _lockDuration;

        lockIdToUser[lockCounter] = _user;
        lockIdToAmount[lockCounter] = _amount;
        lockIdToUnlockTime[lockCounter] = unlockTime;
        lockIdToWithdrawn[lockCounter] = false;

        userLockIds[_user].push(lockCounter);
        totalLocked += _amount;

        emit TokensLocked(_user, lockCounter, _amount, unlockTime);
    }

    function withdrawTokens(uint256 _lockId) external {

        require(msg.sender != address(0), "Invalid sender");
        require(_lockId > 0 && _lockId <= lockCounter, "Invalid lock ID");


        require(lockIdToUser[_lockId] == msg.sender, "Not your lock");
        require(!lockIdToWithdrawn[_lockId], "Already withdrawn");
        require(block.timestamp >= lockIdToUnlockTime[_lockId], "Tokens still locked");

        uint256 amount = lockIdToAmount[_lockId];
        lockIdToWithdrawn[_lockId] = true;
        totalLocked -= amount;


        require(token.transfer(msg.sender, amount), "Transfer failed");

        emit TokensWithdrawn(msg.sender, _lockId, amount);
    }

    function emergencyWithdraw(uint256 _lockId) external {

        require(msg.sender == owner, "Only owner can call this function");


        require(_lockId > 0 && _lockId <= lockCounter, "Invalid lock ID");
        require(!lockIdToWithdrawn[_lockId], "Already withdrawn");

        address user = lockIdToUser[_lockId];
        uint256 amount = lockIdToAmount[_lockId];

        lockIdToWithdrawn[_lockId] = true;
        totalLocked -= amount;


        require(token.transfer(user, amount), "Transfer failed");

        emit TokensWithdrawn(user, _lockId, amount);
    }

    function batchLockTokens(uint256[] memory _amounts, uint256[] memory _lockDurations) external {

        require(msg.sender != address(0), "Invalid sender");
        require(_amounts.length == _lockDurations.length, "Arrays length mismatch");


        require(_amounts.length <= 50, "Too many locks in batch");

        for (uint256 i = 0; i < _amounts.length; i++) {

            require(_amounts[i] > 0, "Amount must be greater than 0");


            require(_lockDurations[i] >= 86400, "Lock duration must be at least 1 day");
            require(_lockDurations[i] <= 31536000, "Lock duration cannot exceed 1 year");


            require(token.transferFrom(msg.sender, address(this), _amounts[i]), "Transfer failed");

            lockCounter++;
            uint256 unlockTime = block.timestamp + _lockDurations[i];

            lockIdToUser[lockCounter] = msg.sender;
            lockIdToAmount[lockCounter] = _amounts[i];
            lockIdToUnlockTime[lockCounter] = unlockTime;
            lockIdToWithdrawn[lockCounter] = false;

            userLockIds[msg.sender].push(lockCounter);
            totalLocked += _amounts[i];

            emit TokensLocked(msg.sender, lockCounter, _amounts[i], unlockTime);
        }
    }

    function batchWithdrawTokens(uint256[] memory _lockIds) external {

        require(msg.sender != address(0), "Invalid sender");


        require(_lockIds.length <= 50, "Too many withdrawals in batch");

        for (uint256 i = 0; i < _lockIds.length; i++) {
            uint256 lockId = _lockIds[i];


            require(lockId > 0 && lockId <= lockCounter, "Invalid lock ID");


            require(lockIdToUser[lockId] == msg.sender, "Not your lock");
            require(!lockIdToWithdrawn[lockId], "Already withdrawn");
            require(block.timestamp >= lockIdToUnlockTime[lockId], "Tokens still locked");

            uint256 amount = lockIdToAmount[lockId];
            lockIdToWithdrawn[lockId] = true;
            totalLocked -= amount;


            require(token.transfer(msg.sender, amount), "Transfer failed");

            emit TokensWithdrawn(msg.sender, lockId, amount);
        }
    }

    function extendLockDuration(uint256 _lockId, uint256 _additionalDuration) external {

        require(msg.sender != address(0), "Invalid sender");
        require(_lockId > 0 && _lockId <= lockCounter, "Invalid lock ID");


        require(lockIdToUser[_lockId] == msg.sender, "Not your lock");
        require(!lockIdToWithdrawn[_lockId], "Already withdrawn");


        require(_additionalDuration >= 3600, "Additional duration must be at least 1 hour");

        uint256 newUnlockTime = lockIdToUnlockTime[_lockId] + _additionalDuration;


        require(newUnlockTime <= block.timestamp + 31536000, "Total lock duration cannot exceed 1 year from now");

        lockIdToUnlockTime[_lockId] = newUnlockTime;
    }

    function transferOwnership(address _newOwner) external {

        require(msg.sender == owner, "Only owner can call this function");


        require(_newOwner != address(0), "Invalid new owner address");
        require(_newOwner != owner, "New owner cannot be the same as current owner");

        address previousOwner = owner;
        owner = _newOwner;

        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    function authorizeUser(address _user) external {

        require(msg.sender == owner, "Only owner can call this function");


        require(_user != address(0), "Invalid user address");

        authorizedUsers[_user] = true;
    }

    function revokeUserAuthorization(address _user) external {

        require(msg.sender == owner, "Only owner can call this function");


        require(_user != address(0), "Invalid user address");

        authorizedUsers[_user] = false;
    }

    function getLockInfo(uint256 _lockId) external view returns (
        address user,
        uint256 amount,
        uint256 unlockTime,
        bool withdrawn
    ) {

        require(_lockId > 0 && _lockId <= lockCounter, "Invalid lock ID");

        return (
            lockIdToUser[_lockId],
            lockIdToAmount[_lockId],
            lockIdToUnlockTime[_lockId],
            lockIdToWithdrawn[_lockId]
        );
    }

    function getUserLocks(address _user) external view returns (uint256[] memory) {

        require(_user != address(0), "Invalid user address");

        return userLockIds[_user];
    }

    function getWithdrawableAmount(address _user) external view returns (uint256) {

        require(_user != address(0), "Invalid user address");

        uint256[] memory lockIds = userLockIds[_user];
        uint256 withdrawableAmount = 0;

        for (uint256 i = 0; i < lockIds.length; i++) {
            uint256 lockId = lockIds[i];
            if (!lockIdToWithdrawn[lockId] && block.timestamp >= lockIdToUnlockTime[lockId]) {
                withdrawableAmount += lockIdToAmount[lockId];
            }
        }

        return withdrawableAmount;
    }

    function getLockedAmount(address _user) external view returns (uint256) {

        require(_user != address(0), "Invalid user address");

        uint256[] memory lockIds = userLockIds[_user];
        uint256 lockedAmount = 0;

        for (uint256 i = 0; i < lockIds.length; i++) {
            uint256 lockId = lockIds[i];
            if (!lockIdToWithdrawn[lockId]) {
                lockedAmount += lockIdToAmount[lockId];
            }
        }

        return lockedAmount;
    }

    function emergencyTokenRecovery(address _tokenAddress, uint256 _amount) external {

        require(msg.sender == owner, "Only owner can call this function");


        require(_tokenAddress != address(0), "Invalid token address");
        require(_amount > 0, "Amount must be greater than 0");


        if (_tokenAddress == address(token)) {
            uint256 contractBalance = token.balanceOf(address(this));
            require(_amount <= contractBalance - totalLocked, "Cannot withdraw locked tokens");
        }

        IERC20(_tokenAddress).transfer(owner, _amount);
    }

    function updateTokenAddress(address _newToken) external {

        require(msg.sender == owner, "Only owner can call this function");


        require(_newToken != address(0), "Invalid token address");
        require(_newToken != address(token), "New token cannot be the same as current token");


        require(totalLocked == 0, "Cannot change token while tokens are locked");

        token = IERC20(_newToken);
    }
}
