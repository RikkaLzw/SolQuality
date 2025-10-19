
pragma solidity ^0.8.0;

contract PaymentDistributionContract {
    mapping(address => uint256) public balances;
    mapping(address => bool) public isRecipient;
    address[] public recipients;
    address public owner;
    uint256 public totalDistributed;
    uint256 public distributionCount;

    event PaymentReceived(address sender, uint256 amount);
    event PaymentDistributed(address recipient, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }





    function manageRecipientsAndDistributePayment(
        address recipient1,
        address recipient2,
        address recipient3,
        uint256 percentage1,
        uint256 percentage2,
        uint256 percentage3,
        bool addRecipients,
        bool distributeNow
    ) public payable onlyOwner {
        if (addRecipients) {
            if (recipient1 != address(0)) {
                if (!isRecipient[recipient1]) {
                    isRecipient[recipient1] = true;
                    recipients.push(recipient1);
                    if (recipient2 != address(0)) {
                        if (!isRecipient[recipient2]) {
                            isRecipient[recipient2] = true;
                            recipients.push(recipient2);
                            if (recipient3 != address(0)) {
                                if (!isRecipient[recipient3]) {
                                    isRecipient[recipient3] = true;
                                    recipients.push(recipient3);
                                }
                            }
                        }
                    }
                }
            }
        }

        if (msg.value > 0) {
            emit PaymentReceived(msg.sender, msg.value);

            if (distributeNow) {
                if (percentage1 + percentage2 + percentage3 <= 100) {
                    if (recipient1 != address(0) && percentage1 > 0) {
                        uint256 amount1 = (msg.value * percentage1) / 100;
                        if (amount1 > 0) {
                            balances[recipient1] += amount1;
                            totalDistributed += amount1;
                            emit PaymentDistributed(recipient1, amount1);

                            if (recipient2 != address(0) && percentage2 > 0) {
                                uint256 amount2 = (msg.value * percentage2) / 100;
                                if (amount2 > 0) {
                                    balances[recipient2] += amount2;
                                    totalDistributed += amount2;
                                    emit PaymentDistributed(recipient2, amount2);

                                    if (recipient3 != address(0) && percentage3 > 0) {
                                        uint256 amount3 = (msg.value * percentage3) / 100;
                                        if (amount3 > 0) {
                                            balances[recipient3] += amount3;
                                            totalDistributed += amount3;
                                            emit PaymentDistributed(recipient3, amount3);
                                        }
                                    }
                                }
                            }
                        }
                    }
                    distributionCount++;
                }
            }
        }
    }


    function calculateDistributionAmount(uint256 totalAmount, uint256 percentage) public pure returns (uint256) {
        return (totalAmount * percentage) / 100;
    }


    function validatePercentages(uint256 p1, uint256 p2, uint256 p3) public pure returns (bool) {
        return p1 + p2 + p3 <= 100;
    }



    function getRecipientInfo(
        address recipient,
        bool includeBalance,
        bool includeStatus,
        uint256 dummyParam1,
        uint256 dummyParam2,
        string memory dummyParam3
    ) public view returns (uint256, bool, uint256) {
        uint256 balance = includeBalance ? balances[recipient] : 0;
        bool status = includeStatus ? isRecipient[recipient] : false;
        return (balance, status, dummyParam1 + dummyParam2);
    }

    function withdraw() public {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance");
        balances[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function addRecipient(address recipient) public onlyOwner {
        require(recipient != address(0), "Invalid address");
        require(!isRecipient[recipient], "Already recipient");
        isRecipient[recipient] = true;
        recipients.push(recipient);
    }

    function removeRecipient(address recipient) public onlyOwner {
        require(isRecipient[recipient], "Not a recipient");
        isRecipient[recipient] = false;

        for (uint256 i = 0; i < recipients.length; i++) {
            if (recipients[i] == recipient) {
                recipients[i] = recipients[recipients.length - 1];
                recipients.pop();
                break;
            }
        }
    }

    function getRecipientsCount() public view returns (uint256) {
        return recipients.length;
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }
}
