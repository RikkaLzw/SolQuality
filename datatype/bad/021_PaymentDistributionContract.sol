
pragma solidity ^0.8.0;

contract PaymentDistributionContract {

    uint256 public totalRecipients;
    uint256 public distributionPercentage;
    uint256 public isActive;


    string public contractId;


    bytes public distributionData;

    struct Recipient {
        address payable wallet;
        uint256 percentage;
        string recipientId;
        uint256 isEligible;
    }

    mapping(uint256 => Recipient) public recipients;
    mapping(address => uint256) public recipientIndex;

    address public owner;
    uint256 public totalDistributed;

    event PaymentDistributed(address recipient, uint256 amount);
    event RecipientAdded(address recipient, uint256 percentage);
    event RecipientUpdated(address recipient, uint256 newPercentage);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyActive() {
        require(isActive == 1, "Contract is not active");
        _;
    }

    constructor(string memory _contractId, bytes memory _distributionData) {
        owner = msg.sender;
        contractId = _contractId;
        distributionData = _distributionData;
        totalRecipients = uint256(0);
        distributionPercentage = uint256(100);
        isActive = uint256(1);
    }

    function addRecipient(
        address payable _wallet,
        uint256 _percentage,
        string memory _recipientId
    ) external onlyOwner {
        require(_wallet != address(0), "Invalid wallet address");
        require(_percentage > 0 && _percentage <= 100, "Invalid percentage");
        require(recipientIndex[_wallet] == 0, "Recipient already exists");

        uint256 currentTotal = uint256(0);

        for (uint256 i = uint256(1); i <= totalRecipients; i++) {
            if (recipients[i].isEligible == uint256(1)) {
                currentTotal += recipients[i].percentage;
            }
        }

        require(currentTotal + _percentage <= distributionPercentage, "Total percentage exceeds limit");

        totalRecipients += uint256(1);
        recipients[totalRecipients] = Recipient({
            wallet: _wallet,
            percentage: _percentage,
            recipientId: _recipientId,
            isEligible: uint256(1)
        });

        recipientIndex[_wallet] = totalRecipients;

        emit RecipientAdded(_wallet, _percentage);
    }

    function updateRecipientPercentage(address _wallet, uint256 _newPercentage) external onlyOwner {
        uint256 index = recipientIndex[_wallet];
        require(index > 0, "Recipient not found");
        require(_newPercentage > 0 && _newPercentage <= 100, "Invalid percentage");

        uint256 currentTotal = uint256(0);

        for (uint256 i = uint256(1); i <= totalRecipients; i++) {
            if (recipients[i].isEligible == uint256(1) && i != index) {
                currentTotal += recipients[i].percentage;
            }
        }

        require(currentTotal + _newPercentage <= distributionPercentage, "Total percentage exceeds limit");

        recipients[index].percentage = _newPercentage;

        emit RecipientUpdated(_wallet, _newPercentage);
    }

    function removeRecipient(address _wallet) external onlyOwner {
        uint256 index = recipientIndex[_wallet];
        require(index > 0, "Recipient not found");

        recipients[index].isEligible = uint256(0);
        recipientIndex[_wallet] = uint256(0);
    }

    function distributePayment() external payable onlyActive {
        require(msg.value > 0, "Payment amount must be greater than 0");

        uint256 totalAmount = msg.value;
        uint256 distributedAmount = uint256(0);

        for (uint256 i = uint256(1); i <= totalRecipients; i++) {
            if (recipients[i].isEligible == uint256(1)) {
                uint256 amount = (totalAmount * recipients[i].percentage) / uint256(100);

                if (amount > 0) {
                    recipients[i].wallet.transfer(amount);
                    distributedAmount += amount;
                    emit PaymentDistributed(recipients[i].wallet, amount);
                }
            }
        }

        totalDistributed += distributedAmount;


        uint256 remaining = totalAmount - distributedAmount;
        if (remaining > 0) {
            payable(msg.sender).transfer(remaining);
        }
    }

    function toggleContractStatus() external onlyOwner {
        if (isActive == uint256(1)) {
            isActive = uint256(0);
        } else {
            isActive = uint256(1);
        }
    }

    function updateDistributionData(bytes memory _newData) external onlyOwner {
        distributionData = _newData;
    }

    function getRecipientCount() external view returns (uint256) {
        uint256 count = uint256(0);

        for (uint256 i = uint256(1); i <= totalRecipients; i++) {
            if (recipients[i].isEligible == uint256(1)) {
                count += uint256(1);
            }
        }

        return count;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {

    }
}
