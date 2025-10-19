
pragma solidity ^0.8.0;

contract PaymentDistributionContract {

    uint256 public totalRecipients;
    uint256 public distributionPercentage;
    uint256 public isActive;


    string public contractId;
    string public version;


    bytes public adminHash;
    bytes public contractMetadata;

    address public owner;
    mapping(address => uint256) public recipientShares;
    mapping(address => uint256) public pendingWithdrawals;
    address[] public recipients;

    event PaymentReceived(address sender, uint256 amount);
    event PaymentDistributed(uint256 totalAmount);
    event RecipientAdded(address recipient, uint256 share);
    event WithdrawalMade(address recipient, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyActive() {
        require(isActive == uint256(1), "Contract is not active");
        _;
    }

    constructor(
        string memory _contractId,
        string memory _version,
        bytes memory _adminHash,
        bytes memory _metadata
    ) {
        owner = msg.sender;
        contractId = _contractId;
        version = _version;
        adminHash = _adminHash;
        contractMetadata = _metadata;
        totalRecipients = uint256(0);
        distributionPercentage = uint256(100);
        isActive = uint256(1);
    }

    function addRecipient(address _recipient, uint256 _share) external onlyOwner {
        require(_recipient != address(0), "Invalid recipient address");
        require(_share > 0, "Share must be greater than 0");
        require(recipientShares[_recipient] == 0, "Recipient already exists");

        recipientShares[_recipient] = _share;
        recipients.push(_recipient);
        totalRecipients = uint256(totalRecipients + 1);

        emit RecipientAdded(_recipient, _share);
    }

    function removeRecipient(address _recipient) external onlyOwner {
        require(recipientShares[_recipient] > 0, "Recipient does not exist");

        recipientShares[_recipient] = 0;


        for (uint256 i = 0; i < recipients.length; i++) {
            if (recipients[i] == _recipient) {
                recipients[i] = recipients[recipients.length - 1];
                recipients.pop();
                break;
            }
        }

        totalRecipients = uint256(totalRecipients - 1);


        if (pendingWithdrawals[_recipient] > 0) {
            pendingWithdrawals[_recipient] = 0;
        }
    }

    function distributePayment() external onlyActive {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "No funds to distribute");
        require(totalRecipients > uint256(0), "No recipients");

        uint256 totalShares = getTotalShares();
        require(totalShares > 0, "No valid shares");

        for (uint256 i = uint256(0); i < recipients.length; i++) {
            address recipient = recipients[i];
            uint256 share = recipientShares[recipient];

            if (share > 0) {
                uint256 payment = (contractBalance * share) / totalShares;
                pendingWithdrawals[recipient] += payment;
            }
        }

        emit PaymentDistributed(contractBalance);
    }

    function withdraw() external onlyActive {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds available for withdrawal");

        pendingWithdrawals[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");

        emit WithdrawalMade(msg.sender, amount);
    }

    function getTotalShares() public view returns (uint256) {
        uint256 total = uint256(0);

        for (uint256 i = uint256(0); i < recipients.length; i++) {
            total += recipientShares[recipients[i]];
        }

        return total;
    }

    function setActive(uint256 _isActive) external onlyOwner {
        require(_isActive == uint256(0) || _isActive == uint256(1), "Invalid status");
        isActive = _isActive;
    }

    function updateMetadata(
        bytes memory _newMetadata,
        string memory _newVersion
    ) external onlyOwner {
        contractMetadata = _newMetadata;
        version = _newVersion;
    }

    function getRecipientCount() external view returns (uint256) {
        return uint256(recipients.length);
    }

    function isRecipientActive(address _recipient) external view returns (uint256) {
        if (recipientShares[_recipient] > 0) {
            return uint256(1);
        }
        return uint256(0);
    }

    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }

    fallback() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }
}
