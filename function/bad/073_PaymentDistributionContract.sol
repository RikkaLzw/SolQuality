
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
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier contractIsActive() {
        require(contractActive, "Contract inactive");
        _;
    }

    constructor() {
        owner = msg.sender;
        contractActive = true;
    }


    function processPaymentAndManageRecipientsWithComplexLogic(
        address recipient1,
        address recipient2,
        address recipient3,
        uint256 amount1,
        uint256 amount2,
        uint256 percentage,
        bool addNewRecipient,
        bool removeOldRecipient
    ) public payable onlyOwner contractIsActive {

        require(msg.value > 0, "No payment sent");
        emit PaymentReceived(msg.sender, msg.value);


        if (addNewRecipient) {
            if (recipient1 != address(0)) {
                if (!authorizedRecipients[recipient1]) {
                    if (recipientList.length < 50) {
                        authorizedRecipients[recipient1] = true;
                        recipientList.push(recipient1);
                        emit RecipientAdded(recipient1);

                        if (recipient2 != address(0)) {
                            if (!authorizedRecipients[recipient2]) {
                                if (recipientList.length < 50) {
                                    authorizedRecipients[recipient2] = true;
                                    recipientList.push(recipient2);
                                    emit RecipientAdded(recipient2);

                                    if (recipient3 != address(0)) {
                                        if (!authorizedRecipients[recipient3]) {
                                            if (recipientList.length < 50) {
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
                }
            }
        }


        uint256 totalAmount = msg.value;
        if (percentage > 0 && percentage <= 100) {
            uint256 distributionAmount = (totalAmount * percentage) / 100;

            if (authorizedRecipients[recipient1] && amount1 > 0) {
                if (distributionAmount >= amount1) {
                    balances[recipient1] += amount1;
                    distributionAmount -= amount1;
                    totalDistributed += amount1;
                    emit PaymentDistributed(recipient1, amount1);

                    if (authorizedRecipients[recipient2] && amount2 > 0) {
                        if (distributionAmount >= amount2) {
                            balances[recipient2] += amount2;
                            distributionAmount -= amount2;
                            totalDistributed += amount2;
                            emit PaymentDistributed(recipient2, amount2);

                            if (authorizedRecipients[recipient3] && distributionAmount > 0) {
                                balances[recipient3] += distributionAmount;
                                totalDistributed += distributionAmount;
                                emit PaymentDistributed(recipient3, distributionAmount);
                            }
                        }
                    }
                }
            }
        }


        if (removeOldRecipient) {
            if (recipient1 != address(0)) {
                if (authorizedRecipients[recipient1]) {
                    authorizedRecipients[recipient1] = false;
                    for (uint i = 0; i < recipientList.length; i++) {
                        if (recipientList[i] == recipient1) {
                            if (i < recipientList.length - 1) {
                                recipientList[i] = recipientList[recipientList.length - 1];
                            }
                            recipientList.pop();
                            break;
                        }
                    }
                }
            }
        }

        distributionCount++;
    }


    function getRecipientInfo(address recipient) public view returns (uint256, bool, uint256) {
        return (balances[recipient], authorizedRecipients[recipient], block.timestamp);
    }


    function calculateDistributionAmount(uint256 total, uint256 percentage) public pure returns (uint256) {
        return (total * percentage) / 100;
    }

    function withdraw() public {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance");
        balances[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function addRecipient(address recipient) public onlyOwner {
        require(!authorizedRecipients[recipient], "Already authorized");
        authorizedRecipients[recipient] = true;
        recipientList.push(recipient);
        emit RecipientAdded(recipient);
    }

    function distributeEvenly() public payable onlyOwner contractIsActive {
        require(msg.value > 0, "No payment");
        require(recipientList.length > 0, "No recipients");

        uint256 amountPerRecipient = msg.value / recipientList.length;

        for (uint i = 0; i < recipientList.length; i++) {
            if (authorizedRecipients[recipientList[i]]) {
                balances[recipientList[i]] += amountPerRecipient;
                totalDistributed += amountPerRecipient;
                emit PaymentDistributed(recipientList[i], amountPerRecipient);
            }
        }

        distributionCount++;
        emit PaymentReceived(msg.sender, msg.value);
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getRecipientCount() public view returns (uint256) {
        return recipientList.length;
    }

    function toggleContractStatus() public onlyOwner {
        contractActive = !contractActive;
    }

    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }
}
