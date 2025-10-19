
pragma solidity ^0.8.0;

contract PaymentDistributionContract {
    struct Recipient {
        address payable wallet;
        uint256 percentage;
        bool isActive;
        uint256 totalReceived;
        string name;
    }

    mapping(address => Recipient) public recipients;
    address[] public recipientList;
    address public owner;
    uint256 public totalDistributed;
    bool public contractActive;

    event PaymentReceived(address sender, uint256 amount);
    event PaymentDistributed(address recipient, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    constructor() {
        owner = msg.sender;
        contractActive = true;
    }




    function manageRecipientAndDistributePayment(
        address payable recipientAddress,
        uint256 percentage,
        string memory name,
        bool shouldActivate,
        bool shouldDistribute,
        uint256 customAmount,
        bool updateExisting
    ) public payable onlyOwner {

        if (updateExisting || recipients[recipientAddress].wallet == address(0)) {
            if (recipients[recipientAddress].wallet == address(0)) {
                recipientList.push(recipientAddress);
            }
            recipients[recipientAddress] = Recipient({
                wallet: recipientAddress,
                percentage: percentage,
                isActive: shouldActivate,
                totalReceived: recipients[recipientAddress].totalReceived,
                name: name
            });
        }


        if (shouldDistribute && msg.value > 0) {

            for (uint i = 0; i < recipientList.length; i++) {
                if (recipients[recipientList[i]].isActive) {
                    if (customAmount > 0) {
                        if (address(this).balance >= customAmount) {
                            if (recipients[recipientList[i]].percentage > 0) {
                                uint256 amount = (customAmount * recipients[recipientList[i]].percentage) / 100;
                                if (amount > 0) {
                                    recipients[recipientList[i]].wallet.transfer(amount);
                                    recipients[recipientList[i]].totalReceived += amount;
                                    totalDistributed += amount;
                                    emit PaymentDistributed(recipientList[i], amount);
                                }
                            }
                        }
                    } else {
                        if (recipients[recipientList[i]].percentage > 0) {
                            uint256 amount = (msg.value * recipients[recipientList[i]].percentage) / 100;
                            if (amount > 0) {
                                recipients[recipientList[i]].wallet.transfer(amount);
                                recipients[recipientList[i]].totalReceived += amount;
                                totalDistributed += amount;
                                emit PaymentDistributed(recipientList[i], amount);
                            }
                        }
                    }
                }
            }
            emit PaymentReceived(msg.sender, msg.value);
        }


        if (!shouldActivate && recipientList.length == 0) {
            contractActive = false;
        }
    }


    function calculateDistributionAmount(uint256 totalAmount, uint256 percentage) public pure returns (uint256) {
        return (totalAmount * percentage) / 100;
    }


    function validateRecipientData(address recipientAddr, uint256 percentage) public pure returns (bool) {
        return recipientAddr != address(0) && percentage <= 100;
    }



    function getComplexRecipientInfo(address recipientAddr) public view returns (address, uint256, bool, uint256, string memory, bool, uint256) {
        Recipient memory recipient = recipients[recipientAddr];
        bool exists = recipient.wallet != address(0);
        uint256 contractBalance = address(this).balance;


        if (exists) {
            if (recipient.isActive) {
                if (recipient.percentage > 0) {
                    if (contractBalance > 0) {
                        uint256 potentialEarning = calculateDistributionAmount(contractBalance, recipient.percentage);
                        return (recipient.wallet, recipient.percentage, recipient.isActive, recipient.totalReceived, recipient.name, exists, potentialEarning);
                    } else {
                        return (recipient.wallet, recipient.percentage, recipient.isActive, recipient.totalReceived, recipient.name, exists, 0);
                    }
                } else {
                    return (recipient.wallet, recipient.percentage, false, recipient.totalReceived, recipient.name, exists, 0);
                }
            } else {
                return (recipient.wallet, recipient.percentage, recipient.isActive, recipient.totalReceived, recipient.name, exists, 0);
            }
        } else {
            return (address(0), 0, false, 0, "", false, 0);
        }
    }

    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }

    function distributeBalance() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to distribute");

        for (uint i = 0; i < recipientList.length; i++) {
            if (recipients[recipientList[i]].isActive && recipients[recipientList[i]].percentage > 0) {
                uint256 amount = calculateDistributionAmount(balance, recipients[recipientList[i]].percentage);
                if (amount > 0) {
                    recipients[recipientList[i]].wallet.transfer(amount);
                    recipients[recipientList[i]].totalReceived += amount;
                    totalDistributed += amount;
                    emit PaymentDistributed(recipientList[i], amount);
                }
            }
        }
    }

    function getRecipientCount() public view returns (uint256) {
        return recipientList.length;
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
