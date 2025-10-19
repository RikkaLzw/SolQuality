
pragma solidity ^0.8.0;

contract TimeLockVault {
    address public owner;
    uint256 public lockDuration;
    uint256 public unlockTime;
    bool public isLocked;
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public lockEndTimes;

    error Error1();
    error Error2();
    error Error3();

    event Deposit(address user, uint256 amount);
    event Withdrawal(address user, uint256 amount);
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
        lockEndTimes[msg.sender] = block.timestamp + lockDuration;

        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        require(deposits[msg.sender] >= amount);
        require(block.timestamp >= lockEndTimes[msg.sender]);

        deposits[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);

        emit Withdrawal(msg.sender, amount);
    }

    function emergencyLock() external onlyOwner {
        require(!isLocked);

        isLocked = true;
        unlockTime = block.timestamp + 7 days;

        emit LockSet(7 days);
    }

    function unlock() external onlyOwner {
        if (!isLocked) {
            revert Error1();
        }
        if (block.timestamp < unlockTime) {
            revert Error2();
        }

        isLocked = false;
        unlockTime = 0;
    }

    function setLockDuration(uint256 newDuration) external onlyOwner notLocked {
        require(newDuration > 0);
        require(newDuration <= 365 days);

        lockDuration = newDuration;
    }

    function emergencyWithdraw() external onlyOwner {
        require(isLocked);
        require(block.timestamp >= unlockTime + 30 days);

        uint256 balance = address(this).balance;
        payable(owner).transfer(balance);
    }

    function getDepositInfo(address user) external view returns (uint256 amount, uint256 lockEnd) {
        return (deposits[user], lockEndTimes[user]);
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0));

        owner = newOwner;
    }

    receive() external payable {
        if (msg.value == 0) {
            revert Error3();
        }

        deposits[msg.sender] += msg.value;
        lockEndTimes[msg.sender] = block.timestamp + lockDuration;

        emit Deposit(msg.sender, msg.value);
    }
}
