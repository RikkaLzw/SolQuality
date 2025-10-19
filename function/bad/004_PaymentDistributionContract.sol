
pragma solidity ^0.8.0;

contract PaymentDistributionContract {
    mapping(address => uint256) public balances;
    mapping(address => bool) public authorizedRecipients;
    address public owner;
    uint256 public totalDistributed;
    uint256 public distributionCount;
    bool public contractActive;

    event PaymentReceived(address sender, uint256 amount);
    event PaymentDistributed(address recipient, uint256 amount);
    event RecipientAuthorized(address recipient);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        contractActive = true;
    }





    function processComplexPaymentDistribution(
        address recipient1,
        address recipient2,
        address recipient3,
        uint256 amount1,
        uint256 amount2,
        uint256 amount3,
        bool shouldAuthorize,
        bool shouldUpdateStats
    ) public payable onlyOwner {
        require(contractActive, "Contract inactive");
        require(msg.value > 0, "No payment sent");


        emit PaymentReceived(msg.sender, msg.value);


        if (shouldAuthorize) {
            if (!authorizedRecipients[recipient1]) {
                authorizedRecipients[recipient1] = true;
                emit RecipientAuthorized(recipient1);
            }
            if (!authorizedRecipients[recipient2]) {
                authorizedRecipients[recipient2] = true;
                emit RecipientAuthorized(recipient2);
            }
            if (!authorizedRecipients[recipient3]) {
                authorizedRecipients[recipient3] = true;
                emit RecipientAuthorized(recipient3);
            }
        }


        uint256 totalToDistribute = amount1 + amount2 + amount3;
        require(totalToDistribute <= msg.value, "Insufficient funds");

        if (authorizedRecipients[recipient1]) {
            if (amount1 > 0) {
                if (address(this).balance >= amount1) {
                    balances[recipient1] += amount1;
                    (bool success1,) = recipient1.call{value: amount1}("");
                    require(success1, "Transfer failed");
                    emit PaymentDistributed(recipient1, amount1);

                    if (shouldUpdateStats) {
                        totalDistributed += amount1;
                        distributionCount++;
                    }
                }
            }
        }

        if (authorizedRecipients[recipient2]) {
            if (amount2 > 0) {
                if (address(this).balance >= amount2) {
                    balances[recipient2] += amount2;
                    (bool success2,) = recipient2.call{value: amount2}("");
                    require(success2, "Transfer failed");
                    emit PaymentDistributed(recipient2, amount2);

                    if (shouldUpdateStats) {
                        totalDistributed += amount2;
                        distributionCount++;
                    }
                }
            }
        }

        if (authorizedRecipients[recipient3]) {
            if (amount3 > 0) {
                if (address(this).balance >= amount3) {
                    balances[recipient3] += amount3;
                    (bool success3,) = recipient3.call{value: amount3}("");
                    require(success3, "Transfer failed");
                    emit PaymentDistributed(recipient3, amount3);

                    if (shouldUpdateStats) {
                        totalDistributed += amount3;
                        distributionCount++;
                    }
                }
            }
        }


        if (address(this).balance < 1000 wei) {
            contractActive = false;
        }
    }


    function calculateDistributionPercentage(uint256 amount, uint256 total) public pure returns (uint256) {
        require(total > 0, "Total cannot be zero");
        return (amount * 100) / total;
    }


    function validateRecipient(address recipient) public view returns (bool) {
        return recipient != address(0) && authorizedRecipients[recipient];
    }


    function getContractInfo() public view returns (uint256, uint256, bool, address) {
        return (totalDistributed, distributionCount, contractActive, owner);
    }

    function authorizeRecipient(address recipient) public onlyOwner {
        require(recipient != address(0), "Invalid address");
        authorizedRecipients[recipient] = true;
        emit RecipientAuthorized(recipient);
    }

    function toggleContractStatus() public onlyOwner {
        contractActive = !contractActive;
    }

    function emergencyWithdraw() public onlyOwner {
        require(!contractActive, "Contract still active");
        (bool success,) = owner.call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }

    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }
}
