
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
    address[] public recipientAddresses;
    address public owner;
    uint256 public totalDistributed;
    bool public contractActive;

    event PaymentReceived(address sender, uint256 amount);
    event PaymentDistributed(address recipient, uint256 amount);
    event RecipientAdded(address recipient, uint256 percentage);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        contractActive = true;
    }




    function manageRecipientAndDistribute(
        address payable _recipient,
        uint256 _percentage,
        string memory _name,
        bool _shouldDistribute,
        uint256 _minAmount,
        bool _forceUpdate
    ) public payable returns (bool, uint256, address) {


        if (_shouldDistribute) {
            if (msg.value > 0) {
                if (_minAmount > 0) {
                    if (msg.value >= _minAmount) {
                        if (contractActive) {
                            if (recipientAddresses.length > 0) {
                                for (uint256 i = 0; i < recipientAddresses.length; i++) {
                                    if (recipients[recipientAddresses[i]].isActive) {
                                        if (recipients[recipientAddresses[i]].percentage > 0) {
                                            uint256 amount = (msg.value * recipients[recipientAddresses[i]].percentage) / 100;
                                            if (amount > 0) {
                                                recipients[recipientAddresses[i]].wallet.transfer(amount);
                                                recipients[recipientAddresses[i]].totalReceived += amount;
                                                totalDistributed += amount;
                                                emit PaymentDistributed(recipientAddresses[i], amount);
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


        if (_recipient != address(0)) {
            if (_forceUpdate || !recipients[_recipient].isActive) {
                if (!recipients[_recipient].isActive) {
                    recipientAddresses.push(_recipient);
                }
                recipients[_recipient] = Recipient({
                    wallet: _recipient,
                    percentage: _percentage,
                    isActive: true,
                    totalReceived: recipients[_recipient].totalReceived,
                    name: _name
                });
                emit RecipientAdded(_recipient, _percentage);
            }
        }

        emit PaymentReceived(msg.sender, msg.value);


        return (true, msg.value, _recipient);
    }


    function calculatePercentage(uint256 amount, uint256 percentage) public pure returns (uint256) {
        return (amount * percentage) / 100;
    }


    function validateRecipient(address _recipient) public view returns (bool) {
        return _recipient != address(0) && _recipient != owner;
    }



    function validateAndUpdateContract(bool _newStatus, address _newOwner) public onlyOwner {
        if (_newStatus != contractActive) {
            if (_newStatus == false) {
                if (address(this).balance > 0) {
                    if (recipientAddresses.length > 0) {
                        for (uint256 i = 0; i < recipientAddresses.length; i++) {
                            if (recipients[recipientAddresses[i]].isActive) {
                                recipients[recipientAddresses[i]].isActive = false;
                            }
                        }
                    }
                }
            }
            contractActive = _newStatus;
        }

        if (_newOwner != address(0)) {
            if (_newOwner != owner) {
                owner = _newOwner;
            }
        }
    }


    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }


    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }


    function getRecipientCount() public view returns (uint256) {
        return recipientAddresses.length;
    }


    function emergencyWithdraw() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
