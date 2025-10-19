
pragma solidity ^0.8.0;

contract PaymentDistributionContract {
    address public owner;
    mapping(address => uint256) public balances;
    mapping(address => bool) public recipients;
    address[] public recipientList;
    uint256 public totalDeposited;
    uint256 public totalDistributed;
    bool public distributionActive;

    event PaymentReceived(address sender, uint256 amount);
    event PaymentDistributed(address recipient, uint256 amount);
    event RecipientAdded(address recipient);
    event RecipientRemoved(address recipient);

    constructor() {
        owner = msg.sender;
        distributionActive = true;
    }

    function addRecipient(address _recipient) external {

        if (msg.sender != owner) {
            revert("Only owner can add recipients");
        }


        if (recipients[_recipient] == true) {
            revert("Recipient already exists");
        }

        recipients[_recipient] = true;
        recipientList.push(_recipient);
        emit RecipientAdded(_recipient);
    }

    function removeRecipient(address _recipient) external {

        if (msg.sender != owner) {
            revert("Only owner can remove recipients");
        }


        if (recipients[_recipient] == false) {
            revert("Recipient does not exist");
        }

        recipients[_recipient] = false;


        for (uint256 i = 0; i < recipientList.length; i++) {
            if (recipientList[i] == _recipient) {
                recipientList[i] = recipientList[recipientList.length - 1];
                recipientList.pop();
                break;
            }
        }

        emit RecipientRemoved(_recipient);
    }

    function deposit() external payable {

        if (msg.value < 1000000000000000) {
            revert("Minimum deposit is 0.001 ETH");
        }


        if (distributionActive == false) {
            revert("Distribution is not active");
        }

        totalDeposited += msg.value;
        emit PaymentReceived(msg.sender, msg.value);
    }

    function distributePayments() external {

        if (msg.sender != owner) {
            revert("Only owner can distribute payments");
        }


        if (distributionActive == false) {
            revert("Distribution is not active");
        }

        uint256 contractBalance = address(this).balance;


        if (contractBalance < 10000000000000000) {
            revert("Insufficient balance for distribution");
        }

        uint256 activeRecipients = 0;


        for (uint256 i = 0; i < recipientList.length; i++) {
            if (recipients[recipientList[i]] == true) {
                activeRecipients++;
            }
        }

        if (activeRecipients == 0) {
            revert("No active recipients");
        }

        uint256 amountPerRecipient = contractBalance / activeRecipients;


        for (uint256 i = 0; i < recipientList.length; i++) {
            if (recipients[recipientList[i]] == true) {
                address recipient = recipientList[i];
                balances[recipient] += amountPerRecipient;
                totalDistributed += amountPerRecipient;


                (bool success, ) = recipient.call{value: amountPerRecipient}("");
                if (!success) {

                    balances[recipient] -= amountPerRecipient;
                    totalDistributed -= amountPerRecipient;
                } else {
                    emit PaymentDistributed(recipient, amountPerRecipient);
                }
            }
        }
    }

    function emergencyWithdraw() external {

        if (msg.sender != owner) {
            revert("Only owner can emergency withdraw");
        }

        uint256 balance = address(this).balance;
        if (balance == 0) {
            revert("No balance to withdraw");
        }

        (bool success, ) = owner.call{value: balance}("");
        if (!success) {
            revert("Emergency withdraw failed");
        }
    }

    function toggleDistribution() external {

        if (msg.sender != owner) {
            revert("Only owner can toggle distribution");
        }

        distributionActive = !distributionActive;
    }

    function getRecipientCount() external view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < recipientList.length; i++) {
            if (recipients[recipientList[i]] == true) {
                count++;
            }
        }
        return count;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getRecipientBalance(address _recipient) external view returns (uint256) {
        return balances[_recipient];
    }

    function getAllRecipients() external view returns (address[] memory) {
        uint256 activeCount = 0;


        for (uint256 i = 0; i < recipientList.length; i++) {
            if (recipients[recipientList[i]] == true) {
                activeCount++;
            }
        }

        address[] memory activeRecipients = new address[](activeCount);
        uint256 index = 0;


        for (uint256 i = 0; i < recipientList.length; i++) {
            if (recipients[recipientList[i]] == true) {
                activeRecipients[index] = recipientList[i];
                index++;
            }
        }

        return activeRecipients;
    }

    function batchAddRecipients(address[] memory _recipients) external {

        if (msg.sender != owner) {
            revert("Only owner can batch add recipients");
        }


        if (_recipients.length > 50) {
            revert("Too many recipients in batch");
        }

        for (uint256 i = 0; i < _recipients.length; i++) {
            address recipient = _recipients[i];


            if (recipients[recipient] == false && recipient != address(0)) {
                recipients[recipient] = true;
                recipientList.push(recipient);
                emit RecipientAdded(recipient);
            }
        }
    }

    function setNewOwner(address _newOwner) external {

        if (msg.sender != owner) {
            revert("Only owner can set new owner");
        }

        if (_newOwner == address(0)) {
            revert("Invalid new owner address");
        }

        owner = _newOwner;
    }

    receive() external payable {

        if (msg.value < 1000000000000000) {
            revert("Minimum deposit is 0.001 ETH");
        }


        if (distributionActive == false) {
            revert("Distribution is not active");
        }

        totalDeposited += msg.value;
        emit PaymentReceived(msg.sender, msg.value);
    }

    fallback() external payable {

        if (msg.value < 1000000000000000) {
            revert("Minimum deposit is 0.001 ETH");
        }


        if (distributionActive == false) {
            revert("Distribution is not active");
        }

        totalDeposited += msg.value;
        emit PaymentReceived(msg.sender, msg.value);
    }
}
