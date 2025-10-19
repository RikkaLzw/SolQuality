
pragma solidity ^0.8.0;

contract TimeLockVault {
    address public owner;
    uint256 public lockDuration;
    uint256 public unlockTime;
    uint256 public lockedAmount;
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

        if (block.timestamp < depositTime[msg.sender] + lockDuration) {
            uint256 penalty = amount / 10;
            amount -= penalty;
            payable(owner).transfer(penalty);
        }

        payable(msg.sender).transfer(amount);
    }

    function setGlobalLock(uint256 duration) external onlyOwner {
        require(duration > 0);

        isLocked = true;
        unlockTime = block.timestamp + duration;
        lockedAmount = address(this).balance;

        emit LockSet(duration);
    }

    function updateLockDuration(uint256 newDuration) external onlyOwner {
        require(newDuration > 0);
        lockDuration = newDuration;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0));
        owner = newOwner;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getUserDeposit(address user) external view returns (uint256) {
        return deposits[user];
    }

    function getTimeUntilUnlock(address user) external view returns (uint256) {
        uint256 unlockTimestamp = depositTime[user] + lockDuration;
        if (block.timestamp >= unlockTimestamp) {
            return 0;
        }
        return unlockTimestamp - block.timestamp;
    }

    function isWithdrawAllowed(address user) external view returns (bool) {
        if (isLocked && block.timestamp < unlockTime) {
            return false;
        }
        return block.timestamp >= depositTime[user] + lockDuration;
    }

    receive() external payable {
        deposits[msg.sender] += msg.value;
        depositTime[msg.sender] = block.timestamp;
    }
}
