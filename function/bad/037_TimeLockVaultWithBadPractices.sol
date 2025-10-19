
pragma solidity ^0.8.0;

contract TimeLockVaultWithBadPractices {
    mapping(address => uint256) public balances;
    mapping(address => uint256) public lockTimestamps;
    mapping(address => bool) public isVIP;
    mapping(address => uint256) public withdrawalCounts;
    mapping(address => string) public userNotes;

    address public owner;
    uint256 public totalLocked;
    uint256 public minLockDuration = 1 days;

    event Deposit(address indexed user, uint256 amount, uint256 lockUntil);
    event Withdrawal(address indexed user, uint256 amount);
    event VIPStatusChanged(address indexed user, bool status);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }




    function depositAndSetupUser(
        uint256 lockDuration,
        string memory note,
        bool requestVIP,
        uint256 referralCode,
        address emergencyContact,
        bytes32 dataHash
    ) public payable {
        require(msg.value > 0, "Must deposit something");
        require(lockDuration >= minLockDuration, "Lock duration too short");


        balances[msg.sender] += msg.value;
        lockTimestamps[msg.sender] = block.timestamp + lockDuration;
        totalLocked += msg.value;


        userNotes[msg.sender] = note;


        if (requestVIP && msg.value >= 1 ether) {
            isVIP[msg.sender] = true;
            emit VIPStatusChanged(msg.sender, true);
        }


        if (referralCode > 0) {

            uint256 bonus = msg.value / 100;
            if (bonus > 0) {
                balances[msg.sender] += bonus;
            }
        }


        if (emergencyContact != address(0)) {

        }


        if (dataHash != bytes32(0)) {

        }

        emit Deposit(msg.sender, msg.value, lockTimestamps[msg.sender]);
    }



    function complexWithdrawalProcess() public returns (bool, uint256, string memory) {
        require(balances[msg.sender] > 0, "No balance");

        uint256 userBalance = balances[msg.sender];
        uint256 lockTime = lockTimestamps[msg.sender];
        bool canWithdraw = false;
        uint256 withdrawableAmount = 0;
        string memory status = "";

        if (block.timestamp >= lockTime) {
            if (isVIP[msg.sender]) {
                if (withdrawalCounts[msg.sender] < 10) {
                    if (userBalance >= 0.1 ether) {
                        if (address(this).balance >= userBalance) {
                            canWithdraw = true;
                            withdrawableAmount = userBalance;
                            status = "VIP_FULL_WITHDRAWAL";
                        } else {
                            if (address(this).balance >= userBalance / 2) {
                                canWithdraw = true;
                                withdrawableAmount = userBalance / 2;
                                status = "VIP_PARTIAL_WITHDRAWAL";
                            } else {
                                status = "INSUFFICIENT_CONTRACT_BALANCE";
                            }
                        }
                    } else {
                        canWithdraw = true;
                        withdrawableAmount = userBalance;
                        status = "VIP_SMALL_AMOUNT";
                    }
                } else {
                    if (userBalance >= 1 ether) {
                        canWithdraw = true;
                        withdrawableAmount = userBalance;
                        status = "VIP_LIMIT_EXCEEDED_LARGE";
                    } else {
                        status = "VIP_LIMIT_EXCEEDED_SMALL";
                    }
                }
            } else {
                if (withdrawalCounts[msg.sender] < 5) {
                    if (userBalance >= 0.5 ether) {
                        canWithdraw = true;
                        withdrawableAmount = userBalance;
                        status = "REGULAR_WITHDRAWAL";
                    } else {
                        if (userBalance >= 0.1 ether) {
                            canWithdraw = true;
                            withdrawableAmount = userBalance / 2;
                            status = "REGULAR_PARTIAL";
                        } else {
                            canWithdraw = true;
                            withdrawableAmount = userBalance;
                            status = "REGULAR_SMALL";
                        }
                    }
                } else {
                    status = "REGULAR_LIMIT_EXCEEDED";
                }
            }
        } else {
            status = "STILL_LOCKED";
        }

        if (canWithdraw && withdrawableAmount > 0) {
            balances[msg.sender] -= withdrawableAmount;
            totalLocked -= withdrawableAmount;
            withdrawalCounts[msg.sender]++;

            (bool success, ) = payable(msg.sender).call{value: withdrawableAmount}("");
            require(success, "Transfer failed");

            emit Withdrawal(msg.sender, withdrawableAmount);
        }

        return (canWithdraw, withdrawableAmount, status);
    }


    function calculateFees(uint256 amount, address user) public view returns (uint256) {
        if (isVIP[user]) {
            return amount / 200;
        }
        return amount / 100;
    }

    function emergencyWithdraw() public onlyOwner {
        require(address(this).balance > 0, "No balance");
        (bool success, ) = payable(owner).call{value: address(this).balance}("");
        require(success, "Emergency withdrawal failed");
    }

    function setMinLockDuration(uint256 newDuration) public onlyOwner {
        minLockDuration = newDuration;
    }

    function setVIPStatus(address user, bool status) public onlyOwner {
        isVIP[user] = status;
        emit VIPStatusChanged(user, status);
    }

    function getTimeLeft(address user) public view returns (uint256) {
        if (block.timestamp >= lockTimestamps[user]) {
            return 0;
        }
        return lockTimestamps[user] - block.timestamp;
    }

    function getUserInfo(address user) public view returns (
        uint256 balance,
        uint256 lockTime,
        bool vipStatus,
        uint256 withdrawCount,
        string memory note
    ) {
        return (
            balances[user],
            lockTimestamps[user],
            isVIP[user],
            withdrawalCounts[user],
            userNotes[user]
        );
    }

    receive() external payable {
        revert("Use depositAndSetupUser function");
    }
}
