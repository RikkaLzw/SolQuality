
pragma solidity ^0.8.0;

contract PaymentDistributionContract {
    address public owner;
    mapping(address => uint256) public balances;
    mapping(address => bool) public authorizedRecipients;
    address[] public recipientList;
    uint256 public totalDistributed;
    uint256 public distributionCount;
    bool public contractActive;

    event PaymentReceived(address sender, uint256 amount);
    event PaymentDistributed(address recipient, uint256 amount);
    event RecipientAdded(address recipient);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier contractIsActive() {
        require(contractActive, "Contract is not active");
        _;
    }

    constructor() {
        owner = msg.sender;
        contractActive = true;
    }





    function processPaymentAndManageRecipients(
        address recipient1,
        address recipient2,
        address recipient3,
        uint256 amount1,
        uint256 amount2,
        uint256 amount3,
        bool addNewRecipient,
        bool removeOldRecipient
    ) public payable onlyOwner contractIsActive {
        require(msg.value > 0, "Payment amount must be greater than 0");

        if (addNewRecipient) {
            if (recipient1 != address(0)) {
                if (!authorizedRecipients[recipient1]) {
                    authorizedRecipients[recipient1] = true;
                    recipientList.push(recipient1);
                    emit RecipientAdded(recipient1);

                    if (recipient2 != address(0)) {
                        if (!authorizedRecipients[recipient2]) {
                            authorizedRecipients[recipient2] = true;
                            recipientList.push(recipient2);
                            emit RecipientAdded(recipient2);

                            if (recipient3 != address(0)) {
                                if (!authorizedRecipients[recipient3]) {
                                    authorizedRecipients[recipient3] = true;
                                    recipientList.push(recipient3);
                                    emit RecipientAdded(recipient3);
                                }
                            }
                        }
                    }
                }
            }
        }

        uint256 totalAmount = msg.value;
        emit PaymentReceived(msg.sender, totalAmount);

        if (amount1 > 0 && recipient1 != address(0)) {
            if (authorizedRecipients[recipient1]) {
                if (totalAmount >= amount1) {
                    balances[recipient1] += amount1;
                    totalAmount -= amount1;
                    totalDistributed += amount1;
                    emit PaymentDistributed(recipient1, amount1);

                    if (amount2 > 0 && recipient2 != address(0)) {
                        if (authorizedRecipients[recipient2]) {
                            if (totalAmount >= amount2) {
                                balances[recipient2] += amount2;
                                totalAmount -= amount2;
                                totalDistributed += amount2;
                                emit PaymentDistributed(recipient2, amount2);

                                if (amount3 > 0 && recipient3 != address(0)) {
                                    if (authorizedRecipients[recipient3]) {
                                        if (totalAmount >= amount3) {
                                            balances[recipient3] += amount3;
                                            totalAmount -= amount3;
                                            totalDistributed += amount3;
                                            emit PaymentDistributed(recipient3, amount3);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        if (removeOldRecipient) {
            for (uint256 i = 0; i < recipientList.length; i++) {
                if (recipientList[i] == recipient1 || recipientList[i] == recipient2 || recipientList[i] == recipient3) {
                    if (balances[recipientList[i]] == 0) {
                        authorizedRecipients[recipientList[i]] = false;
                        for (uint256 j = i; j < recipientList.length - 1; j++) {
                            recipientList[j] = recipientList[j + 1];
                        }
                        recipientList.pop();
                        break;
                    }
                }
            }
        }

        distributionCount++;

        if (totalAmount > 0) {
            balances[owner] += totalAmount;
        }
    }


    function calculateDistributionPercentage(uint256 amount, uint256 total) public pure returns (uint256) {
        if (total == 0) return 0;
        return (amount * 100) / total;
    }


    function validateRecipientAddress(address recipient) public pure returns (bool) {
        return recipient != address(0);
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance to withdraw");

        balances[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
    }

    function addRecipient(address recipient) external onlyOwner {
        require(recipient != address(0), "Invalid recipient address");
        require(!authorizedRecipients[recipient], "Recipient already exists");

        authorizedRecipients[recipient] = true;
        recipientList.push(recipient);
        emit RecipientAdded(recipient);
    }

    function getRecipientCount() external view returns (uint256) {
        return recipientList.length;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function toggleContractStatus() external onlyOwner {
        contractActive = !contractActive;
    }

    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }

    fallback() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }
}
