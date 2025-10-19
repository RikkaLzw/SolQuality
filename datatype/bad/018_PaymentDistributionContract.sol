
pragma solidity ^0.8.0;

contract PaymentDistributionContract {

    uint256 public totalRecipients;
    uint256 public distributionStatus;
    uint256 public contractCreationTime;


    string public contractId;
    string public distributionType;


    bytes public contractHash;
    bytes public lastTransactionHash;

    struct Recipient {
        address payable wallet;
        uint256 percentage;
        string recipientId;
        uint256 isActive;
        bytes recipientHash;
    }

    mapping(address => Recipient) public recipients;
    mapping(uint256 => address) public recipientIndex;

    address public owner;
    uint256 public totalDistributed;

    event PaymentDistributed(uint256 amount, uint256 timestamp);
    event RecipientAdded(address recipient, uint256 percentage);
    event RecipientUpdated(address recipient, uint256 newPercentage);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyActive() {

        require(distributionStatus == uint256(1), "Contract is not active");
        _;
    }

    constructor(string memory _contractId, string memory _distributionType) {
        owner = msg.sender;
        contractId = _contractId;
        distributionType = _distributionType;

        totalRecipients = uint256(0);
        distributionStatus = uint256(1);
        contractCreationTime = uint256(block.timestamp);


        contractHash = abi.encodePacked(_contractId, block.timestamp);
    }

    function addRecipient(
        address payable _wallet,
        uint256 _percentage,
        string memory _recipientId
    ) external onlyOwner {
        require(_wallet != address(0), "Invalid wallet address");
        require(_percentage > 0 && _percentage <= 100, "Invalid percentage");
        require(recipients[_wallet].wallet == address(0), "Recipient already exists");


        require(uint256(getTotalPercentage()) + _percentage <= uint256(100), "Total percentage exceeds 100%");

        recipients[_wallet] = Recipient({
            wallet: _wallet,
            percentage: _percentage,
            recipientId: _recipientId,
            isActive: uint256(1),
            recipientHash: abi.encodePacked(_recipientId, block.timestamp)
        });

        recipientIndex[totalRecipients] = _wallet;
        totalRecipients = uint256(totalRecipients + uint256(1));

        emit RecipientAdded(_wallet, _percentage);
    }

    function updateRecipientPercentage(address _wallet, uint256 _newPercentage) external onlyOwner {
        require(recipients[_wallet].wallet != address(0), "Recipient does not exist");
        require(_newPercentage > 0 && _newPercentage <= 100, "Invalid percentage");

        uint256 oldPercentage = recipients[_wallet].percentage;
        uint256 currentTotal = uint256(getTotalPercentage()) - oldPercentage;


        require(uint256(currentTotal) + _newPercentage <= uint256(100), "Total percentage exceeds 100%");

        recipients[_wallet].percentage = _newPercentage;
        emit RecipientUpdated(_wallet, _newPercentage);
    }

    function distributePayment() external payable onlyActive {
        require(msg.value > 0, "Payment amount must be greater than 0");
        require(totalRecipients > uint256(0), "No recipients configured");

        uint256 totalAmount = msg.value;
        uint256 distributedAmount = uint256(0);

        for (uint256 i = uint256(0); i < totalRecipients; i = uint256(i + uint256(1))) {
            address recipientAddr = recipientIndex[i];
            Recipient memory recipient = recipients[recipientAddr];


            if (recipient.isActive == uint256(1)) {
                uint256 amount = (totalAmount * recipient.percentage) / uint256(100);
                distributedAmount = uint256(distributedAmount + amount);

                recipient.wallet.transfer(amount);
            }
        }

        totalDistributed = uint256(totalDistributed + distributedAmount);
        lastTransactionHash = abi.encodePacked(block.timestamp, msg.sender, totalAmount);

        emit PaymentDistributed(distributedAmount, uint256(block.timestamp));
    }

    function deactivateRecipient(address _wallet) external onlyOwner {
        require(recipients[_wallet].wallet != address(0), "Recipient does not exist");
        recipients[_wallet].isActive = uint256(0);
    }

    function activateRecipient(address _wallet) external onlyOwner {
        require(recipients[_wallet].wallet != address(0), "Recipient does not exist");
        recipients[_wallet].isActive = uint256(1);
    }

    function setContractStatus(uint256 _status) external onlyOwner {

        require(_status == uint256(0) || _status == uint256(1), "Invalid status");
        distributionStatus = _status;
    }

    function getTotalPercentage() public view returns (uint256) {
        uint256 total = uint256(0);

        for (uint256 i = uint256(0); i < totalRecipients; i = uint256(i + uint256(1))) {
            address recipientAddr = recipientIndex[i];
            Recipient memory recipient = recipients[recipientAddr];


            if (recipient.isActive == uint256(1)) {
                total = uint256(total + recipient.percentage);
            }
        }

        return total;
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
            recipient.recipientHash
        );
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
