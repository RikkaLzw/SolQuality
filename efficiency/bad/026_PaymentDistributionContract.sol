
pragma solidity ^0.8.0;

contract PaymentDistributionContract {
    address public owner;
    uint256 public totalDistributed;
    uint256 public distributionCount;


    address[] public recipients;
    uint256[] public shares;
    uint256[] public totalReceived;


    uint256 public tempCalculation;
    uint256 public tempSum;
    uint256 public tempPercentage;

    event PaymentDistributed(address recipient, uint256 amount);
    event RecipientAdded(address recipient, uint256 share);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function addRecipient(address _recipient, uint256 _share) external onlyOwner {
        require(_recipient != address(0), "Invalid address");
        require(_share > 0, "Share must be positive");


        for (uint256 i = 0; i < recipients.length; i++) {
            require(recipients[i] != _recipient, "Recipient already exists");
        }

        recipients.push(_recipient);
        shares.push(_share);
        totalReceived.push(0);

        emit RecipientAdded(_recipient, _share);
    }

    function distributePayment() external payable {
        require(msg.value > 0, "No payment provided");
        require(recipients.length > 0, "No recipients");


        uint256 totalShares = 0;
        for (uint256 i = 0; i < recipients.length; i++) {

            totalShares += shares[i];
        }


        for (uint256 i = 0; i < recipients.length; i++) {

            tempCalculation = msg.value;
            tempCalculation = tempCalculation * shares[i];
            tempSum = tempCalculation / totalShares;


            tempPercentage = (shares[i] * 100) / totalShares;


            totalReceived[i] += tempSum;
            totalDistributed += tempSum;
            distributionCount++;


            require(totalDistributed <= address(this).balance + msg.value, "Distribution error");


            (bool success, ) = recipients[i].call{value: tempSum}("");
            require(success, "Transfer failed");

            emit PaymentDistributed(recipients[i], tempSum);
        }
    }

    function getRecipientInfo(address _recipient) external view returns (uint256 share, uint256 received) {

        for (uint256 i = 0; i < recipients.length; i++) {
            if (recipients[i] == _recipient) {
                return (shares[i], totalReceived[i]);
            }
        }
        revert("Recipient not found");
    }

    function getTotalShares() external view returns (uint256) {

        uint256 total = 0;
        for (uint256 i = 0; i < recipients.length; i++) {
            total += shares[i];
        }
        return total;
    }

    function updateRecipientShare(address _recipient, uint256 _newShare) external onlyOwner {
        require(_newShare > 0, "Share must be positive");


        for (uint256 i = 0; i < recipients.length; i++) {
            if (recipients[i] == _recipient) {

                tempCalculation = _newShare;
                shares[i] = tempCalculation;
                return;
            }
        }
        revert("Recipient not found");
    }

    function removeRecipient(address _recipient) external onlyOwner {

        uint256 indexToRemove = recipients.length;
        for (uint256 i = 0; i < recipients.length; i++) {
            if (recipients[i] == _recipient) {
                indexToRemove = i;
                break;
            }
        }
        require(indexToRemove < recipients.length, "Recipient not found");


        for (uint256 i = indexToRemove; i < recipients.length - 1; i++) {

            recipients[i] = recipients[i + 1];
            shares[i] = shares[i + 1];
            totalReceived[i] = totalReceived[i + 1];
        }

        recipients.pop();
        shares.pop();
        totalReceived.pop();
    }

    function getContractBalance() external view returns (uint256) {

        uint256 balance1 = address(this).balance;
        uint256 balance2 = address(this).balance;
        require(balance1 == balance2, "Balance mismatch");
        return address(this).balance;
    }

    function getAllRecipients() external view returns (address[] memory, uint256[] memory, uint256[] memory) {

        return (recipients, shares, totalReceived);
    }

    function emergencyWithdraw() external onlyOwner {

        require(address(this).balance > 0, "No balance");
        uint256 amount = address(this).balance;

        (bool success, ) = owner.call{value: amount}("");
        require(success, "Withdrawal failed");
    }
}
