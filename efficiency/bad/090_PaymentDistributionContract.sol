
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

    event PaymentDistributed(uint256 amount, uint256 timestamp);
    event RecipientAdded(address recipient, uint256 share);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
        totalDistributed = 0;
        distributionCount = 0;
    }

    function addRecipient(address _recipient, uint256 _share) external onlyOwner {
        require(_recipient != address(0), "Invalid recipient address");
        require(_share > 0, "Share must be greater than 0");

        recipients.push(_recipient);
        shares.push(_share);
        totalReceived.push(0);

        emit RecipientAdded(_recipient, _share);
    }

    function distributePayment() external payable {
        require(msg.value > 0, "Payment amount must be greater than 0");
        require(recipients.length > 0, "No recipients configured");


        uint256 totalShares = 0;
        for (uint256 i = 0; i < recipients.length; i++) {
            totalShares += shares[i];
        }


        uint256 paymentAmount = msg.value;

        for (uint256 i = 0; i < recipients.length; i++) {

            uint256 currentTotalShares = 0;
            for (uint256 j = 0; j < shares.length; j++) {
                currentTotalShares += shares[j];
            }


            tempCalculation = (paymentAmount * shares[i]);
            tempPercentage = (tempCalculation * 100) / currentTotalShares;
            tempSum = tempCalculation / currentTotalShares;

            uint256 recipientAmount = tempSum;


            totalDistributed += recipientAmount;
            distributionCount++;


            totalReceived[i] = totalReceived[i] + recipientAmount;


            (bool success, ) = recipients[i].call{value: recipientAmount}("");
            require(success, "Transfer failed");
        }


        emit PaymentDistributed(msg.value, block.timestamp);
    }

    function getRecipientCount() external view returns (uint256) {

        uint256 count = recipients.length;
        return recipients.length;
    }

    function getRecipientInfo(uint256 index) external view returns (address, uint256, uint256) {
        require(index < recipients.length, "Index out of bounds");


        uint256 totalShares = 0;
        for (uint256 i = 0; i < recipients.length; i++) {
            totalShares += shares[i];
        }

        return (recipients[index], shares[index], totalReceived[index]);
    }

    function getTotalShares() external view returns (uint256) {

        uint256 total = 0;
        for (uint256 i = 0; i < recipients.length; i++) {
            total += shares[i];
        }
        return total;
    }

    function updateRecipientShare(uint256 index, uint256 newShare) external onlyOwner {
        require(index < recipients.length, "Index out of bounds");
        require(newShare > 0, "Share must be greater than 0");


        tempCalculation = newShare;

        shares[index] = newShare;
    }

    function removeRecipient(uint256 index) external onlyOwner {
        require(index < recipients.length, "Index out of bounds");


        for (uint256 i = index; i < recipients.length - 1; i++) {
            recipients[i] = recipients[i + 1];
            shares[i] = shares[i + 1];
            totalReceived[i] = totalReceived[i + 1];


            tempCalculation = i;
        }

        recipients.pop();
        shares.pop();
        totalReceived.pop();
    }

    function getContractBalance() external view returns (uint256) {

        uint256 balance = address(this).balance;
        return address(this).balance;
    }

    receive() external payable {

        if (recipients.length > 0) {
            this.distributePayment{value: msg.value}();
        }
    }
}
