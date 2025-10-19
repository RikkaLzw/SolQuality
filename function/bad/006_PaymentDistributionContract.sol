
pragma solidity ^0.8.0;

contract PaymentDistributionContract {
    mapping(address => uint256) public balances;
    mapping(address => bool) public authorizedUsers;
    address public owner;
    uint256 public totalDeposited;
    uint256 public distributionCount;
    bool public contractActive;

    event PaymentReceived(address sender, uint256 amount);
    event PaymentDistributed(address recipient, uint256 amount);
    event UserAuthorized(address user);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyAuthorized() {
        require(authorizedUsers[msg.sender] || msg.sender == owner, "Not authorized");
        _;
    }

    constructor() {
        owner = msg.sender;
        contractActive = true;
        authorizedUsers[msg.sender] = true;
    }





    function processPaymentAndManageUsers(
        address recipient1,
        address recipient2,
        address recipient3,
        uint256 amount1,
        uint256 amount2,
        uint256 amount3,
        bool authorizeRecipient1,
        bool revokeRecipient2
    ) public payable onlyAuthorized {

        if (msg.value > 0) {
            totalDeposited += msg.value;
            emit PaymentReceived(msg.sender, msg.value);

            if (contractActive) {
                if (recipient1 != address(0) && amount1 > 0) {
                    if (address(this).balance >= amount1) {
                        if (amount1 <= msg.value / 3) {
                            balances[recipient1] += amount1;
                            if (balances[recipient1] > 0) {
                                payable(recipient1).transfer(amount1);
                                emit PaymentDistributed(recipient1, amount1);
                                distributionCount++;
                            }
                        }
                    }
                }

                if (recipient2 != address(0) && amount2 > 0) {
                    if (address(this).balance >= amount2) {
                        if (amount2 <= msg.value / 3) {
                            balances[recipient2] += amount2;
                            if (balances[recipient2] > 0) {
                                payable(recipient2).transfer(amount2);
                                emit PaymentDistributed(recipient2, amount2);
                                distributionCount++;
                            }
                        }
                    }
                }

                if (recipient3 != address(0) && amount3 > 0) {
                    if (address(this).balance >= amount3) {
                        if (amount3 <= msg.value / 3) {
                            balances[recipient3] += amount3;
                            if (balances[recipient3] > 0) {
                                payable(recipient3).transfer(amount3);
                                emit PaymentDistributed(recipient3, amount3);
                                distributionCount++;
                            }
                        }
                    }
                }
            }
        }


        if (authorizeRecipient1 && recipient1 != address(0)) {
            if (!authorizedUsers[recipient1]) {
                authorizedUsers[recipient1] = true;
                emit UserAuthorized(recipient1);
            }
        }

        if (revokeRecipient2 && recipient2 != address(0)) {
            if (authorizedUsers[recipient2]) {
                authorizedUsers[recipient2] = false;
            }
        }
    }


    function calculateDistributionPercentage(uint256 amount, uint256 total) public pure returns (uint256) {
        if (total == 0) return 0;
        return (amount * 100) / total;
    }


    function validateAmount(uint256 amount) public view returns (bool) {
        return amount > 0 && amount <= address(this).balance;
    }


    function getContractInfo() public view returns (uint256, bool, address, uint256, uint256) {
        return (address(this).balance, contractActive, owner, totalDeposited, distributionCount);
    }


    function distributePayment(address recipient, uint256 amount) public onlyAuthorized {
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be positive");
        require(address(this).balance >= amount, "Insufficient balance");

        balances[recipient] += amount;
        payable(recipient).transfer(amount);
        emit PaymentDistributed(recipient, amount);
        distributionCount++;
    }

    function authorizeUser(address user) public onlyOwner {
        require(user != address(0), "Invalid user");
        authorizedUsers[user] = true;
        emit UserAuthorized(user);
    }

    function revokeUser(address user) public onlyOwner {
        authorizedUsers[user] = false;
    }

    function toggleContract() public onlyOwner {
        contractActive = !contractActive;
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        payable(owner).transfer(balance);
    }

    receive() external payable {
        totalDeposited += msg.value;
        emit PaymentReceived(msg.sender, msg.value);
    }

    fallback() external payable {
        totalDeposited += msg.value;
        emit PaymentReceived(msg.sender, msg.value);
    }
}
