
pragma solidity ^0.8.0;

contract PaymentDistributionContract {

    uint256 public constant MAX_RECIPIENTS = 10;
    uint256 public recipientCount;
    uint256 public distributionRounds;


    string public contractId;

    struct Recipient {
        address payable wallet;
        uint256 percentage;
        string recipientId;
        uint256 isActive;
        bytes data;
    }

    mapping(address => Recipient) public recipients;
    mapping(uint256 => address) public recipientIndex;

    address public owner;
    uint256 public totalPercentage;
    uint256 public contractStatus;

    event PaymentDistributed(uint256 amount, uint256 timestamp);
    event RecipientAdded(address recipient, uint256 percentage);
    event RecipientRemoved(address recipient);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier contractActive() {
        require(contractStatus == 1, "Contract is not active");
        _;
    }

    constructor(string memory _contractId) {
        owner = msg.sender;
        contractId = _contractId;
        contractStatus = uint256(1);
        recipientCount = uint256(0);
        distributionRounds = uint256(0);
        totalPercentage = uint256(0);
    }

    function addRecipient(
        address payable _wallet,
        uint256 _percentage,
        string memory _recipientId,
        bytes memory _data
    ) external onlyOwner contractActive {
        require(_wallet != address(0), "Invalid wallet address");
        require(_percentage > 0 && _percentage <= 100, "Invalid percentage");
        require(totalPercentage + _percentage <= 100, "Total percentage exceeds 100");
        require(recipientCount < MAX_RECIPIENTS, "Maximum recipients reached");
        require(recipients[_wallet].wallet == address(0), "Recipient already exists");

        recipients[_wallet] = Recipient({
            wallet: _wallet,
            percentage: _percentage,
            recipientId: _recipientId,
            isActive: uint256(1),
            data: _data
        });

        recipientIndex[recipientCount] = _wallet;
        recipientCount = recipientCount + uint256(1);
        totalPercentage = totalPercentage + _percentage;

        emit RecipientAdded(_wallet, _percentage);
    }

    function removeRecipient(address _wallet) external onlyOwner contractActive {
        require(recipients[_wallet].wallet != address(0), "Recipient does not exist");
        require(recipients[_wallet].isActive == uint256(1), "Recipient already inactive");

        recipients[_wallet].isActive = uint256(0);
        totalPercentage = totalPercentage - recipients[_wallet].percentage;

        emit RecipientRemoved(_wallet);
    }

    function distributePayment() external payable contractActive {
        require(msg.value > 0, "Payment amount must be greater than 0");
        require(totalPercentage == 100, "Total percentage must equal 100");

        uint256 totalAmount = msg.value;

        for (uint256 i = uint256(0); i < recipientCount; i = i + uint256(1)) {
            address recipientAddr = recipientIndex[i];
            Recipient memory recipient = recipients[recipientAddr];

            if (recipient.isActive == uint256(1)) {
                uint256 paymentAmount = (totalAmount * recipient.percentage) / uint256(100);

                if (paymentAmount > uint256(0)) {
                    recipient.wallet.transfer(paymentAmount);
                }
            }
        }

        distributionRounds = distributionRounds + uint256(1);
        emit PaymentDistributed(totalAmount, block.timestamp);
    }

    function updateRecipientData(address _wallet, bytes memory _newData) external onlyOwner contractActive {
        require(recipients[_wallet].wallet != address(0), "Recipient does not exist");
        require(recipients[_wallet].isActive == uint256(1), "Recipient is not active");

        recipients[_wallet].data = _newData;
    }

    function getRecipientInfo(address _wallet) external view returns (
        address,
        uint256,
        string memory,
        uint256,
        bytes memory
    ) {
        Recipient memory recipient = recipients[_wallet];
        return (
            recipient.wallet,
            recipient.percentage,
            recipient.recipientId,
            recipient.isActive,
            recipient.data
        );
    }

    function toggleContractStatus() external onlyOwner {
        if (contractStatus == uint256(1)) {
            contractStatus = uint256(0);
        } else {
            contractStatus = uint256(1);
        }
    }

    function getContractInfo() external view returns (
        string memory,
        uint256,
        uint256,
        uint256,
        uint256
    ) {
        return (
            contractId,
            recipientCount,
            totalPercentage,
            distributionRounds,
            contractStatus
        );
    }

    function emergencyWithdraw() external onlyOwner {
        require(contractStatus == uint256(0), "Contract must be inactive");
        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {
        if (contractStatus == uint256(1) && totalPercentage == uint256(100)) {
            distributePayment();
        }
    }
}
