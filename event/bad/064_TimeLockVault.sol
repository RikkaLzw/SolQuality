
pragma solidity ^0.8.0;

contract TimeLockVault {
    address public owner;
    uint256 public lockDuration;
    uint256 public unlockTime;
    bool public isLocked;
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public depositTime;

    error Error1();
    error Error2();
    error Error3();

    event Deposit(address user, uint256 amount);
    event Withdraw(address user, uint256 amount);
    event LockSet(uint256 duration);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier notLocked() {
        require(!isLocked || block.timestamp >= unlockTime);
        _;
    }

    constructor(uint256 _lockDuration) {
        owner = msg.sender;
        lockDuration = _lockDuration;
        isLocked = false;
    }

    function deposit() external payable {
        require(msg.value > 0);

        deposits[msg.sender] += msg.value;
        depositTime[msg.sender] = block.timestamp;

        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external notLocked {
        require(deposits[msg.sender] >= amount);
        require(block.timestamp >= depositTime[msg.sender] + lockDuration);

        deposits[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);

        emit Withdraw(msg.sender, amount);
    }

    function emergencyWithdraw() external {
        require(deposits[msg.sender] > 0);

        uint256 amount = deposits[msg.sender];
        deposits[msg.sender] = 0;

        payable(msg.sender).transfer(amount);

        emit Withdraw(msg.sender, amount);
    }

    function setGlobalLock(uint256 duration) external onlyOwner {
        require(duration > 0);

        isLocked = true;
        unlockTime = block.timestamp + duration;

        emit LockSet(duration);
    }

    function removeGlobalLock() external onlyOwner {
        require(isLocked);

        isLocked = false;
        unlockTime = 0;
    }

    function updateLockDuration(uint256 newDuration) external onlyOwner {
        require(newDuration > 0);

        lockDuration = newDuration;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0));

        owner = newOwner;
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getUserDeposit(address user) external view returns (uint256) {
        return deposits[user];
    }

    function canWithdraw(address user) external view returns (bool) {
        if (isLocked && block.timestamp < unlockTime) {
            return false;
        }

        if (deposits[user] == 0) {
            return false;
        }

        return block.timestamp >= depositTime[user] + lockDuration;
    }

    function timeUntilUnlock(address user) external view returns (uint256) {
        uint256 userUnlockTime = depositTime[user] + lockDuration;

        if (block.timestamp >= userUnlockTime) {
            return 0;
        }

        return userUnlockTime - block.timestamp;
    }

    function globalTimeUntilUnlock() external view returns (uint256) {
        if (!isLocked || block.timestamp >= unlockTime) {
            return 0;
        }

        return unlockTime - block.timestamp;
    }
}
