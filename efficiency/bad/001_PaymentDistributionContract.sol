
pragma solidity ^0.8.0;

contract PaymentDistributionContract {
    address public owner;
    uint256 public totalFunds;
    uint256 public distributionCount;


    address[] public recipients;
    uint256[] public shares;
    uint256[] public claimedAmounts;


    uint256 public tempCalculation;
    uint256 public tempPercentage;
    uint256 public tempAmount;

    event FundsDeposited(address indexed depositor, uint256 amount);
    event PaymentDistributed(address indexed recipient, uint256 amount);
    event RecipientAdded(address indexed recipient, uint256 share);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
        totalFunds = 0;
        distributionCount = 0;
    }

    function depositFunds() external payable {
        require(msg.value > 0, "Must deposit positive amount");
        totalFunds += msg.value;
        emit FundsDeposited(msg.sender, msg.value);
    }

    function addRecipient(address _recipient, uint256 _share) external onlyOwner {
        require(_recipient != address(0), "Invalid recipient address");
        require(_share > 0, "Share must be positive");

        recipients.push(_recipient);
        shares.push(_share);
        claimedAmounts.push(0);

        emit RecipientAdded(_recipient, _share);
    }

    function distributeFunds() external onlyOwner {
        require(recipients.length > 0, "No recipients configured");
        require(totalFunds > 0, "No funds to distribute");


        for (uint256 i = 0; i < recipients.length; i++) {

            tempCalculation = totalFunds;
            tempCalculation = tempCalculation * shares[i];


            uint256 totalShares = 0;
            for (uint256 j = 0; j < shares.length; j++) {
                totalShares += shares[j];
            }

            tempAmount = tempCalculation / totalShares;
            tempPercentage = (shares[i] * 100) / totalShares;


            distributionCount++;

            if (tempAmount > 0) {

                require(totalFunds >= tempAmount, "Insufficient funds");

                payable(recipients[i]).transfer(tempAmount);
                claimedAmounts[i] += tempAmount;
                totalFunds -= tempAmount;

                emit PaymentDistributed(recipients[i], tempAmount);
            }
        }
    }

    function getRecipientInfo(uint256 _index) external view returns (
        address recipient,
        uint256 share,
        uint256 claimed,
        uint256 pendingAmount
    ) {
        require(_index < recipients.length, "Invalid index");


        uint256 totalShares = 0;
        for (uint256 i = 0; i < shares.length; i++) {
            totalShares += shares[i];
        }

        recipient = recipients[_index];
        share = shares[_index];
        claimed = claimedAmounts[_index];


        uint256 totalEntitlement = (totalFunds * shares[_index]) / totalShares;
        pendingAmount = totalEntitlement > claimed ? totalEntitlement - claimed : 0;
    }

    function getTotalShares() external view returns (uint256) {

        uint256 total = 0;
        for (uint256 i = 0; i < shares.length; i++) {
            total += shares[i];
        }
        return total;
    }

    function getRecipientsCount() external view returns (uint256) {
        return recipients.length;
    }

    function emergencyWithdraw() external onlyOwner {
        require(totalFunds > 0, "No funds to withdraw");


        uint256 amount = totalFunds;
        totalFunds = 0;

        payable(owner).transfer(amount);
    }

    function updateRecipientShare(uint256 _index, uint256 _newShare) external onlyOwner {
        require(_index < recipients.length, "Invalid index");
        require(_newShare > 0, "Share must be positive");


        tempCalculation = _newShare;
        shares[_index] = tempCalculation;
    }

    receive() external payable {
        totalFunds += msg.value;
        emit FundsDeposited(msg.sender, msg.value);
    }
}
