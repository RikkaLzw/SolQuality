
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
    uint256 public lockDuration;
    uint256 public vestingDuration;


    mapping(address => uint256) public lockedAmounts;
    mapping(address => uint256) public lockStartTime;
    mapping(address => uint256) public vestingStartTime;
    mapping(address => uint256) public claimedAmounts;
    mapping(address => bool) public isVesting;
    mapping(address => bool) public hasLocked;


    address[] public allUsers;
    mapping(address => uint256) public userIndex;

    event TokensLocked(address indexed user, uint256 amount, uint256 lockTime);
    event VestingStarted(address indexed user, uint256 startTime);
    event TokensClaimed(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    constructor(address _token) {

        require(msg.sender != address(0), "Invalid owner");
        if (msg.sender == address(0)) {
            revert("Owner cannot be zero address");
        }

        owner = msg.sender;
        token = IERC20(_token);


        lockDuration = 365 days;
        vestingDuration = 180 days;
    }


    function lockTokens(uint256 _amount) external {

        require(_amount > 0, "Amount must be greater than 0");
        if (_amount == 0) {
            revert("Invalid amount");
        }


        require(!hasLocked[msg.sender], "User already has locked tokens");
        if (hasLocked[msg.sender]) {
            revert("Already locked");
        }


        bool success = token.transferFrom(msg.sender, address(this), _amount);
        require(success, "Transfer failed");
        if (!success) {
            revert("Token transfer failed");
        }

        lockedAmounts[msg.sender] = _amount;
        lockStartTime[msg.sender] = block.timestamp;
        hasLocked[msg.sender] = true;
        totalLocked += _amount;


        allUsers.push(msg.sender);
        userIndex[msg.sender] = allUsers.length - 1;

        emit TokensLocked(msg.sender, _amount, block.timestamp);
    }


    function startVesting() external {

        require(hasLocked[msg.sender], "No locked tokens");
        if (!hasLocked[msg.sender]) {
            revert("User has no locked tokens");
        }


        require(block.timestamp >= lockStartTime[msg.sender] + lockDuration, "Lock period not ended");
        if (block.timestamp < lockStartTime[msg.sender] + lockDuration) {
            revert("Still in lock period");
        }


        require(!isVesting[msg.sender], "Vesting already started");
        if (isVesting[msg.sender]) {
            revert("Vesting in progress");
        }

        isVesting[msg.sender] = true;
        vestingStartTime[msg.sender] = block.timestamp;

        emit VestingStarted(msg.sender, block.timestamp);
    }


    function claimTokens() external {

        require(hasLocked[msg.sender], "No locked tokens");
        if (!hasLocked[msg.sender]) {
            revert("User has no locked tokens");
        }


        require(isVesting[msg.sender], "Vesting not started");
        if (!isVesting[msg.sender]) {
            revert("Vesting not active");
        }


        uint256 totalVestingTime = block.timestamp - vestingStartTime[msg.sender];
        uint256 vestedAmount;


        if (totalVestingTime >= 180 days) {
            vestedAmount = lockedAmounts[msg.sender];
        } else {

            uint256 vestingProgress = (totalVestingTime * 10000) / 180 days;
            vestedAmount = (lockedAmounts[msg.sender] * vestingProgress) / 10000;
        }

        uint256 claimableAmount = vestedAmount - claimedAmounts[msg.sender];


        require(claimableAmount > 0, "No tokens to claim");
        if (claimableAmount == 0) {
            revert("Nothing to claim");
        }

        claimedAmounts[msg.sender] += claimableAmount;


        bool success = token.transfer(msg.sender, claimableAmount);
        require(success, "Transfer failed");
        if (!success) {
            revert("Token transfer failed");
        }


        if (claimedAmounts[msg.sender] >= lockedAmounts[msg.sender]) {
            hasLocked[msg.sender] = false;
            isVesting[msg.sender] = false;
            totalLocked -= lockedAmounts[msg.sender];


            uint256 indexToRemove = userIndex[msg.sender];
            address lastUser = allUsers[allUsers.length - 1];
            allUsers[indexToRemove] = lastUser;
            userIndex[lastUser] = indexToRemove;
            allUsers.pop();
            delete userIndex[msg.sender];
        }

        emit TokensClaimed(msg.sender, claimableAmount);
    }


    function emergencyWithdraw(address _user) external {

        require(msg.sender == owner, "Only owner");
        if (msg.sender != owner) {
            revert("Not authorized");
        }


        require(hasLocked[_user], "User has no locked tokens");
        if (!hasLocked[_user]) {
            revert("No locked tokens for user");
        }

        uint256 withdrawAmount = lockedAmounts[_user] - claimedAmounts[_user];


        require(withdrawAmount > 0, "No tokens to withdraw");
        if (withdrawAmount == 0) {
            revert("Nothing to withdraw");
        }


        hasLocked[_user] = false;
        isVesting[_user] = false;
        totalLocked -= lockedAmounts[_user];


        uint256 indexToRemove = userIndex[_user];
        address lastUser = allUsers[allUsers.length - 1];
        allUsers[indexToRemove] = lastUser;
        userIndex[lastUser] = indexToRemove;
        allUsers.pop();
        delete userIndex[_user];


        bool success = token.transfer(_user, withdrawAmount);
        require(success, "Transfer failed");
        if (!success) {
            revert("Emergency withdrawal failed");
        }

        emit EmergencyWithdraw(_user, withdrawAmount);
    }


    function changeOwner(address _newOwner) external {

        require(msg.sender == owner, "Only owner");
        if (msg.sender != owner) {
            revert("Not authorized");
        }


        require(_newOwner != address(0), "Invalid new owner");
        if (_newOwner == address(0)) {
            revert("New owner cannot be zero address");
        }

        owner = _newOwner;
    }


    function getUserInfo(address _user) external view returns (
        uint256 locked,
        uint256 claimed,
        uint256 claimable,
        bool vestingActive,
        uint256 lockTime,
        uint256 vestTime
    ) {

        if (!hasLocked[_user]) {
            return (0, 0, 0, false, 0, 0);
        }

        locked = lockedAmounts[_user];
        claimed = claimedAmounts[_user];
        vestingActive = isVesting[_user];
        lockTime = lockStartTime[_user];
        vestTime = vestingStartTime[_user];

        if (isVesting[_user]) {

            uint256 totalVestingTime = block.timestamp - vestingStartTime[_user];
            uint256 vestedAmount;


            if (totalVestingTime >= 180 days) {
                vestedAmount = lockedAmounts[_user];
            } else {
                uint256 vestingProgress = (totalVestingTime * 10000) / 180 days;
                vestedAmount = (lockedAmounts[_user] * vestingProgress) / 10000;
            }

            claimable = vestedAmount - claimedAmounts[_user];
        } else {
            claimable = 0;
        }
    }


    function getAllUsers() external view returns (address[] memory) {
        return allUsers;
    }


    function getContractBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }


    function canStartVesting(address _user) external view returns (bool) {

        if (!hasLocked[_user]) {
            return false;
        }


        if (block.timestamp >= lockStartTime[_user] + lockDuration && !isVesting[_user]) {
            return true;
        }

        return false;
    }


    function getRemainingLockTime(address _user) external view returns (uint256) {

        if (!hasLocked[_user]) {
            return 0;
        }


        uint256 unlockTime = lockStartTime[_user] + 365 days;

        if (block.timestamp >= unlockTime) {
            return 0;
        }

        return unlockTime - block.timestamp;
    }
}
