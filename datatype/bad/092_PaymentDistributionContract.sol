
pragma solidity ^0.8.0;

contract PaymentDistributionContract {

    uint256 public constant MAX_RECIPIENTS = 10;
    uint256 public recipientCount;
    uint256 public distributionStatus;


    string public contractId;


    bytes public distributionHash;

    struct Recipient {
        address payable wallet;
        uint256 percentage;
        string name;
        uint256 isActive;
    }

    mapping(address => Recipient) public recipients;
    address[] public recipientAddresses;

    address public owner;
    uint256 public totalDistributed;
    uint256 public minimumDistribution;

    event PaymentDistributed(address indexed recipient, uint256 amount);
    event RecipientAdded(address indexed recipient, uint256 percentage);
    event RecipientRemoved(address indexed recipient);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier validPercentage(uint256 _percentage) {
        require(_percentage > 0 && _percentage <= 100, "Invalid percentage");
        _;
    }

    constructor(string memory _contractId, bytes memory _distributionHash) {
        owner = msg.sender;
        contractId = _contractId;
        distributionHash = _distributionHash;
        recipientCount = uint256(0);
        distributionStatus = uint256(1);
        minimumDistribution = uint256(1000000000000000);
    }

    function addRecipient(
        address payable _wallet,
        uint256 _percentage,
        string memory _name
    ) external onlyOwner validPercentage(_percentage) {
        require(_wallet != address(0), "Invalid wallet address");
        require(recipients[_wallet].wallet == address(0), "Recipient already exists");
        require(recipientCount < MAX_RECIPIENTS, "Maximum recipients reached");

        uint256 totalPercentage = uint256(0);
        for (uint256 i = uint256(0); i < recipientAddresses.length; i++) {
            if (recipients[recipientAddresses[i]].isActive == uint256(1)) {
                totalPercentage += recipients[recipientAddresses[i]].percentage;
            }
        }

        require(totalPercentage + _percentage <= uint256(100), "Total percentage exceeds 100%");

        recipients[_wallet] = Recipient({
            wallet: _wallet,
            percentage: _percentage,
            name: _name,
            isActive: uint256(1)
        });

        recipientAddresses.push(_wallet);
        recipientCount = recipientCount + uint256(1);

        emit RecipientAdded(_wallet, _percentage);
    }

    function removeRecipient(address _wallet) external onlyOwner {
        require(recipients[_wallet].wallet != address(0), "Recipient does not exist");
        require(recipients[_wallet].isActive == uint256(1), "Recipient already inactive");

        recipients[_wallet].isActive = uint256(0);
        recipientCount = recipientCount - uint256(1);

        emit RecipientRemoved(_wallet);
    }

    function distributePayment() external payable {
        require(msg.value >= minimumDistribution, "Payment below minimum");
        require(distributionStatus == uint256(1), "Distribution not active");
        require(recipientCount > uint256(0), "No active recipients");

        uint256 totalActivePercentage = uint256(0);


        for (uint256 i = uint256(0); i < recipientAddresses.length; i++) {
            if (recipients[recipientAddresses[i]].isActive == uint256(1)) {
                totalActivePercentage += recipients[recipientAddresses[i]].percentage;
            }
        }

        require(totalActivePercentage > uint256(0), "No active recipients with valid percentage");


        for (uint256 i = uint256(0); i < recipientAddresses.length; i++) {
            address recipientAddr = recipientAddresses[i];
            if (recipients[recipientAddr].isActive == uint256(1)) {
                uint256 amount = (msg.value * recipients[recipientAddr].percentage) / totalActivePercentage;
                recipients[recipientAddr].wallet.transfer(amount);
                emit PaymentDistributed(recipientAddr, amount);
            }
        }

        totalDistributed += msg.value;
    }

    function updateDistributionStatus(uint256 _status) external onlyOwner {
        require(_status == uint256(0) || _status == uint256(1), "Invalid status");
        distributionStatus = _status;
    }

    function updateMinimumDistribution(uint256 _minimum) external onlyOwner {
        minimumDistribution = _minimum;
    }

    function getRecipientInfo(address _wallet) external view returns (
        address wallet,
        uint256 percentage,
        string memory name,
        uint256 isActive
    ) {
        Recipient memory recipient = recipients[_wallet];
        return (recipient.wallet, recipient.percentage, recipient.name, recipient.isActive);
    }

    function getTotalActivePercentage() external view returns (uint256) {
        uint256 total = uint256(0);
        for (uint256 i = uint256(0); i < recipientAddresses.length; i++) {
            if (recipients[recipientAddresses[i]].isActive == uint256(1)) {
                total += recipients[recipientAddresses[i]].percentage;
            }
        }
        return total;
    }

    function emergencyWithdraw() external onlyOwner {
        require(distributionStatus == uint256(0), "Distribution must be inactive");
        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {
        distributePayment();
    }
}
