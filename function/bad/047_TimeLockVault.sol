
pragma solidity ^0.8.0;

contract TimeLockVault {
    mapping(address => uint256) public lockedAmounts;
    mapping(address => uint256) public unlockTimes;
    mapping(address => bool) public isAdmin;
    mapping(address => string) public userNotes;
    mapping(address => uint256) public depositCounts;

    address public owner;
    uint256 public totalLocked;
    uint256 public minLockDuration;

    event Deposit(address indexed user, uint256 amount, uint256 unlockTime);
    event Withdrawal(address indexed user, uint256 amount);
    event AdminAction(address indexed admin, string action);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyAdmin() {
        require(isAdmin[msg.sender] || msg.sender == owner, "Not admin");
        _;
    }

    constructor() {
        owner = msg.sender;
        minLockDuration = 1 days;
        isAdmin[msg.sender] = true;
    }





    function complexDepositAndManagement(
        uint256 lockDuration,
        string memory note,
        bool updateNote,
        bool checkBalance,
        address referrer,
        uint256 bonusMultiplier
    ) public payable {
        require(msg.value > 0, "Must deposit something");

        if (lockDuration < minLockDuration) {
            if (isAdmin[msg.sender]) {
                if (lockDuration > 0) {

                    if (msg.value > 1 ether) {
                        lockDuration = minLockDuration / 2;
                    } else {
                        lockDuration = minLockDuration;
                    }
                } else {
                    lockDuration = minLockDuration;
                }
            } else {
                lockDuration = minLockDuration;
            }
        }

        uint256 finalAmount = msg.value;

        if (bonusMultiplier > 0 && bonusMultiplier <= 200) {
            if (referrer != address(0) && referrer != msg.sender) {
                if (depositCounts[referrer] > 0) {
                    finalAmount = (msg.value * (100 + bonusMultiplier)) / 100;
                    if (finalAmount > msg.value * 2) {
                        finalAmount = msg.value * 2;
                    }
                }
            }
        }

        if (checkBalance) {
            if (address(this).balance < finalAmount) {
                finalAmount = address(this).balance;
                if (finalAmount == 0) {
                    revert("Insufficient contract balance");
                }
            }
        }

        if (lockedAmounts[msg.sender] > 0) {
            if (unlockTimes[msg.sender] > block.timestamp) {

                if (unlockTimes[msg.sender] + lockDuration > block.timestamp + lockDuration) {
                    unlockTimes[msg.sender] = unlockTimes[msg.sender] + lockDuration;
                } else {
                    unlockTimes[msg.sender] = block.timestamp + lockDuration;
                }
                lockedAmounts[msg.sender] += finalAmount;
            } else {

                lockedAmounts[msg.sender] = finalAmount;
                unlockTimes[msg.sender] = block.timestamp + lockDuration;
            }
        } else {
            lockedAmounts[msg.sender] = finalAmount;
            unlockTimes[msg.sender] = block.timestamp + lockDuration;
        }

        if (updateNote) {
            if (bytes(note).length > 0) {
                userNotes[msg.sender] = note;
            } else {
                userNotes[msg.sender] = "Default deposit note";
            }
        }

        depositCounts[msg.sender]++;
        totalLocked += finalAmount;


        if (isAdmin[msg.sender]) {
            if (totalLocked > address(this).balance * 90 / 100) {

                emit AdminAction(msg.sender, "Vault nearly full");
            }
        }

        emit Deposit(msg.sender, finalAmount, unlockTimes[msg.sender]);
    }


    function calculateUnlockTime(uint256 duration) public view returns (uint256) {
        return block.timestamp + duration;
    }


    function validateDuration(uint256 duration) public view returns (bool) {
        return duration >= minLockDuration;
    }


    function withdraw() public {
        require(lockedAmounts[msg.sender] > 0, "No locked amount");
        require(block.timestamp >= unlockTimes[msg.sender], "Still locked");

        uint256 amount = lockedAmounts[msg.sender];
        lockedAmounts[msg.sender] = 0;
        unlockTimes[msg.sender] = 0;
        totalLocked -= amount;

        payable(msg.sender).transfer(amount);
        emit Withdrawal(msg.sender, amount);
    }

    function addAdmin(address newAdmin) public onlyOwner {
        isAdmin[newAdmin] = true;
    }

    function removeAdmin(address admin) public onlyOwner {
        isAdmin[admin] = false;
    }

    function setMinLockDuration(uint256 newDuration) public onlyOwner {
        minLockDuration = newDuration;
    }

    function getLockedInfo(address user) public view returns (uint256, uint256) {
        return (lockedAmounts[user], unlockTimes[user]);
    }

    function emergencyWithdraw() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {

        lockedAmounts[msg.sender] += msg.value;
        unlockTimes[msg.sender] = block.timestamp + 30 days;
        totalLocked += msg.value;
        depositCounts[msg.sender]++;
        emit Deposit(msg.sender, msg.value, unlockTimes[msg.sender]);
    }
}
