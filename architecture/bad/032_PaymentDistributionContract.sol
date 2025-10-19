
pragma solidity ^0.8.0;

contract PaymentDistributionContract {
    address public owner;
    mapping(address => uint256) public balances;
    mapping(address => bool) public recipients;
    address[] public recipientList;
    uint256 public totalDistributed;
    uint256 public contractBalance;

    event PaymentReceived(address sender, uint256 amount);
    event PaymentDistributed(address recipient, uint256 amount);
    event RecipientAdded(address recipient);
    event RecipientRemoved(address recipient);

    constructor() {
        owner = msg.sender;
        contractBalance = 0;
        totalDistributed = 0;
    }

    function addRecipient(address _recipient) external {

        if (msg.sender != owner) {
            revert("Only owner can add recipients");
        }
        if (_recipient == address(0)) {
            revert("Invalid recipient address");
        }


        bool exists = false;
        for (uint256 i = 0; i < recipientList.length; i++) {
            if (recipientList[i] == _recipient) {
                exists = true;
                break;
            }
        }
        if (exists) {
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
        if (_recipient == address(0)) {
            revert("Invalid recipient address");
        }


        bool exists = false;
        uint256 index = 0;
        for (uint256 i = 0; i < recipientList.length; i++) {
            if (recipientList[i] == _recipient) {
                exists = true;
                index = i;
                break;
            }
        }
        if (!exists) {
            revert("Recipient does not exist");
        }

        recipients[_recipient] = false;
        recipientList[index] = recipientList[recipientList.length - 1];
        recipientList.pop();
        emit RecipientRemoved(_recipient);
    }

    function distributePayment() external {

        if (msg.sender != owner) {
            revert("Only owner can distribute payments");
        }

        uint256 balance = address(this).balance;
        if (balance == 0) {
            revert("No funds to distribute");
        }

        if (recipientList.length == 0) {
            revert("No recipients available");
        }


        uint256 amountPerRecipient = balance / recipientList.length;
        uint256 remainder = balance % recipientList.length;

        for (uint256 i = 0; i < recipientList.length; i++) {
            address recipient = recipientList[i];
            uint256 amount = amountPerRecipient;


            if (i == 0) {
                amount += remainder;
            }

            balances[recipient] += amount;
            totalDistributed += amount;


            (bool success, ) = payable(recipient).call{value: amount}("");
            if (!success) {
                revert("Transfer failed");
            }

            emit PaymentDistributed(recipient, amount);
        }

        contractBalance = 0;
    }

    function distributeCustomAmount(uint256 _amount) external {

        if (msg.sender != owner) {
            revert("Only owner can distribute payments");
        }

        if (_amount == 0) {
            revert("Amount must be greater than 0");
        }

        if (address(this).balance < _amount) {
            revert("Insufficient contract balance");
        }

        if (recipientList.length == 0) {
            revert("No recipients available");
        }


        uint256 amountPerRecipient = _amount / recipientList.length;
        uint256 remainder = _amount % recipientList.length;

        for (uint256 i = 0; i < recipientList.length; i++) {
            address recipient = recipientList[i];
            uint256 amount = amountPerRecipient;


            if (i == 0) {
                amount += remainder;
            }

            balances[recipient] += amount;
            totalDistributed += amount;


            (bool success, ) = payable(recipient).call{value: amount}("");
            if (!success) {
                revert("Transfer failed");
            }

            emit PaymentDistributed(recipient, amount);
        }
    }

    function emergencyWithdraw() external {

        if (msg.sender != owner) {
            revert("Only owner can withdraw");
        }

        uint256 balance = address(this).balance;
        if (balance == 0) {
            revert("No funds to withdraw");
        }


        (bool success, ) = payable(owner).call{value: balance}("");
        if (!success) {
            revert("Transfer failed");
        }

        contractBalance = 0;
    }

    function changeOwner(address _newOwner) external {

        if (msg.sender != owner) {
            revert("Only owner can change ownership");
        }
        if (_newOwner == address(0)) {
            revert("Invalid new owner address");
        }

        owner = _newOwner;
    }

    function getRecipientCount() external view returns (uint256) {
        return recipientList.length;
    }

    function getRecipientAtIndex(uint256 _index) external view returns (address) {
        if (_index >= recipientList.length) {
            revert("Index out of bounds");
        }
        return recipientList[_index];
    }

    function getAllRecipients() external view returns (address[] memory) {
        return recipientList;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getRecipientBalance(address _recipient) external view returns (uint256) {
        return balances[_recipient];
    }

    function isRecipient(address _recipient) external view returns (bool) {
        return recipients[_recipient];
    }

    function getTotalDistributed() external view returns (uint256) {
        return totalDistributed;
    }


    function addMultipleRecipients(address[] memory _recipients) external {

        if (msg.sender != owner) {
            revert("Only owner can add recipients");
        }


        if (_recipients.length > 50) {
            revert("Too many recipients at once");
        }

        for (uint256 i = 0; i < _recipients.length; i++) {
            address recipient = _recipients[i];

            if (recipient == address(0)) {
                continue;
            }


            bool exists = false;
            for (uint256 j = 0; j < recipientList.length; j++) {
                if (recipientList[j] == recipient) {
                    exists = true;
                    break;
                }
            }

            if (!exists) {
                recipients[recipient] = true;
                recipientList.push(recipient);
                emit RecipientAdded(recipient);
            }
        }
    }


    function distributeByWeight(address[] memory _recipients, uint256[] memory _weights) external {

        if (msg.sender != owner) {
            revert("Only owner can distribute payments");
        }

        if (_recipients.length != _weights.length) {
            revert("Recipients and weights length mismatch");
        }

        if (_recipients.length == 0) {
            revert("No recipients provided");
        }

        uint256 balance = address(this).balance;
        if (balance == 0) {
            revert("No funds to distribute");
        }


        uint256 totalWeight = 0;
        for (uint256 i = 0; i < _weights.length; i++) {
            totalWeight += _weights[i];
        }

        if (totalWeight == 0) {
            revert("Total weight cannot be zero");
        }

        for (uint256 i = 0; i < _recipients.length; i++) {
            address recipient = _recipients[i];
            uint256 weight = _weights[i];

            if (recipient == address(0)) {
                continue;
            }

            uint256 amount = (balance * weight) / totalWeight;

            if (amount > 0) {
                balances[recipient] += amount;
                totalDistributed += amount;


                (bool success, ) = payable(recipient).call{value: amount}("");
                if (!success) {
                    revert("Transfer failed");
                }

                emit PaymentDistributed(recipient, amount);
            }
        }
    }

    receive() external payable {
        contractBalance += msg.value;
        emit PaymentReceived(msg.sender, msg.value);
    }

    fallback() external payable {
        contractBalance += msg.value;
        emit PaymentReceived(msg.sender, msg.value);
    }
}
