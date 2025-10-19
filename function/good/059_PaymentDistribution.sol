
pragma solidity ^0.8.0;

contract PaymentDistribution {
    address public owner;

    struct Recipient {
        address payable wallet;
        uint256 percentage;
        bool active;
    }

    mapping(uint256 => Recipient) public recipients;
    uint256 public recipientCount;
    uint256 public totalPercentage;

    event RecipientAdded(uint256 indexed id, address indexed wallet, uint256 percentage);
    event RecipientUpdated(uint256 indexed id, address indexed wallet, uint256 percentage);
    event RecipientRemoved(uint256 indexed id);
    event PaymentDistributed(uint256 amount, uint256 timestamp);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier validPercentage(uint256 _percentage) {
        require(_percentage > 0 && _percentage <= 100, "Invalid percentage");
        _;
    }

    modifier recipientExists(uint256 _id) {
        require(_id < recipientCount && recipients[_id].active, "Recipient does not exist");
        _;
    }

    constructor() {
        owner = msg.sender;
        recipientCount = 0;
        totalPercentage = 0;
    }

    function addRecipient(address payable _wallet, uint256 _percentage)
        external
        onlyOwner
        validPercentage(_percentage)
    {
        require(_wallet != address(0), "Invalid wallet address");
        require(totalPercentage + _percentage <= 100, "Total percentage exceeds 100%");

        recipients[recipientCount] = Recipient({
            wallet: _wallet,
            percentage: _percentage,
            active: true
        });

        totalPercentage += _percentage;
        emit RecipientAdded(recipientCount, _wallet, _percentage);
        recipientCount++;
    }

    function updateRecipient(uint256 _id, uint256 _newPercentage)
        external
        onlyOwner
        recipientExists(_id)
        validPercentage(_newPercentage)
    {
        uint256 currentPercentage = recipients[_id].percentage;
        uint256 newTotalPercentage = totalPercentage - currentPercentage + _newPercentage;
        require(newTotalPercentage <= 100, "Total percentage exceeds 100%");

        recipients[_id].percentage = _newPercentage;
        totalPercentage = newTotalPercentage;

        emit RecipientUpdated(_id, recipients[_id].wallet, _newPercentage);
    }

    function removeRecipient(uint256 _id) external onlyOwner recipientExists(_id) {
        totalPercentage -= recipients[_id].percentage;
        recipients[_id].active = false;

        emit RecipientRemoved(_id);
    }

    function distributePayment() external payable {
        require(msg.value > 0, "Payment amount must be greater than 0");
        require(totalPercentage > 0, "No active recipients");

        uint256 totalDistributed = 0;

        for (uint256 i = 0; i < recipientCount; i++) {
            if (recipients[i].active) {
                uint256 amount = _calculateAmount(msg.value, recipients[i].percentage);
                totalDistributed += amount;
                _transferPayment(recipients[i].wallet, amount);
            }
        }

        _handleRemainder(msg.value, totalDistributed);
        emit PaymentDistributed(msg.value, block.timestamp);
    }

    function getRecipientInfo(uint256 _id) external view returns (address, uint256, bool) {
        require(_id < recipientCount, "Invalid recipient ID");
        Recipient memory recipient = recipients[_id];
        return (recipient.wallet, recipient.percentage, recipient.active);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        address previousOwner = owner;
        owner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    function _calculateAmount(uint256 _totalAmount, uint256 _percentage)
        private
        pure
        returns (uint256)
    {
        return (_totalAmount * _percentage) / 100;
    }

    function _transferPayment(address payable _recipient, uint256 _amount) private {
        require(_amount > 0, "Amount must be greater than 0");
        (bool success, ) = _recipient.call{value: _amount}("");
        require(success, "Payment transfer failed");
    }

    function _handleRemainder(uint256 _totalAmount, uint256 _distributed) private {
        uint256 remainder = _totalAmount - _distributed;
        if (remainder > 0) {
            (bool success, ) = payable(owner).call{value: remainder}("");
            require(success, "Remainder transfer to owner failed");
        }
    }

    receive() external payable {
        distributePayment();
    }

    fallback() external payable {
        distributePayment();
    }
}
