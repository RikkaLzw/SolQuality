
pragma solidity ^0.8.0;

contract PaymentDistributionContract {

    uint256 public totalRecipients;
    uint256 public distributionPercentage;
    uint256 public isActive;


    string public contractId;


    bytes public contractHash;

    address public owner;

    struct Recipient {
        address payable wallet;
        uint256 percentage;
        uint256 isEligible;
        string recipientId;
    }

    mapping(address => Recipient) public recipients;
    address[] public recipientAddresses;

    event PaymentDistributed(address indexed recipient, uint256 amount);
    event RecipientAdded(address indexed recipient, uint256 percentage);
    event RecipientRemoved(address indexed recipient);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyActive() {
        require(isActive == uint256(1), "Contract is not active");
        _;
    }

    constructor(string memory _contractId, bytes memory _contractHash) {
        owner = msg.sender;
        contractId = _contractId;
        contractHash = _contractHash;
        totalRecipients = uint256(0);
        distributionPercentage = uint256(0);
        isActive = uint256(1);
    }

    function addRecipient(
        address payable _wallet,
        uint256 _percentage,
        string memory _recipientId
    ) external onlyOwner {
        require(_wallet != address(0), "Invalid wallet address");
        require(_percentage > 0 && _percentage <= 100, "Invalid percentage");
        require(recipients[_wallet].wallet == address(0), "Recipient already exists");
        require(distributionPercentage + _percentage <= 100, "Total percentage exceeds 100%");

        recipients[_wallet] = Recipient({
            wallet: _wallet,
            percentage: _percentage,
            isEligible: uint256(1),
            recipientId: _recipientId
        });

        recipientAddresses.push(_wallet);
        totalRecipients = totalRecipients + uint256(1);
        distributionPercentage = distributionPercentage + _percentage;

        emit RecipientAdded(_wallet, _percentage);
    }

    function removeRecipient(address _wallet) external onlyOwner {
        require(recipients[_wallet].wallet != address(0), "Recipient does not exist");

        uint256 removedPercentage = recipients[_wallet].percentage;
        delete recipients[_wallet];


        for (uint256 i = uint256(0); i < recipientAddresses.length; i++) {
            if (recipientAddresses[i] == _wallet) {
                recipientAddresses[i] = recipientAddresses[recipientAddresses.length - 1];
                recipientAddresses.pop();
                break;
            }
        }

        totalRecipients = totalRecipients - uint256(1);
        distributionPercentage = distributionPercentage - removedPercentage;

        emit RecipientRemoved(_wallet);
    }

    function updateRecipientEligibility(address _wallet, uint256 _isEligible) external onlyOwner {
        require(recipients[_wallet].wallet != address(0), "Recipient does not exist");
        require(_isEligible == uint256(0) || _isEligible == uint256(1), "Invalid eligibility value");

        recipients[_wallet].isEligible = _isEligible;
    }

    function distributePayment() external payable onlyActive {
        require(msg.value > 0, "No payment to distribute");
        require(totalRecipients > uint256(0), "No recipients available");

        uint256 totalAmount = msg.value;

        for (uint256 i = uint256(0); i < recipientAddresses.length; i++) {
            address recipientAddr = recipientAddresses[i];
            Recipient memory recipient = recipients[recipientAddr];

            if (recipient.isEligible == uint256(1)) {
                uint256 amount = (totalAmount * recipient.percentage) / uint256(100);

                if (amount > uint256(0)) {
                    recipient.wallet.transfer(amount);
                    emit PaymentDistributed(recipientAddr, amount);
                }
            }
        }
    }

    function setContractStatus(uint256 _isActive) external onlyOwner {
        require(_isActive == uint256(0) || _isActive == uint256(1), "Invalid status value");
        isActive = _isActive;
    }

    function updateContractId(string memory _newId) external onlyOwner {
        contractId = _newId;
    }

    function updateContractHash(bytes memory _newHash) external onlyOwner {
        contractHash = _newHash;
    }

    function getRecipientInfo(address _wallet) external view returns (
        address wallet,
        uint256 percentage,
        uint256 isEligible,
        string memory recipientId
    ) {
        Recipient memory recipient = recipients[_wallet];
        return (recipient.wallet, recipient.percentage, recipient.isEligible, recipient.recipientId);
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {

    }
}
