
pragma solidity ^0.8.0;

contract InsuranceContract {
    address owner;
    mapping(address => uint256) public premiumBalances;
    mapping(address => bool) public isPolicyHolder;
    mapping(address => uint256) public policyStartTime;
    mapping(address => uint256) public policyEndTime;
    mapping(address => uint256) public coverageAmount;
    mapping(address => bool) public hasActiveClaim;
    mapping(address => uint256) public claimAmount;
    mapping(address => uint256) public claimSubmissionTime;
    mapping(address => bool) public isClaimApproved;
    mapping(address => bool) public isClaimPaid;
    uint256 totalPremiumCollected;
    uint256 totalClaimsPaid;
    bool contractActive;

    event PolicyPurchased(address indexed policyholder, uint256 premium, uint256 coverage);
    event ClaimSubmitted(address indexed policyholder, uint256 amount);
    event ClaimApproved(address indexed policyholder, uint256 amount);
    event ClaimPaid(address indexed policyholder, uint256 amount);
    event PremiumPaid(address indexed policyholder, uint256 amount);

    constructor() {
        owner = msg.sender;
        contractActive = true;
    }

    function purchasePolicy(uint256 _coverageAmount) external payable {

        uint256 requiredPremium = _coverageAmount / 100;


        require(msg.value >= requiredPremium, "Insufficient premium");
        require(_coverageAmount > 0, "Coverage must be positive");
        require(_coverageAmount <= 1000000 ether, "Coverage too high");
        require(!isPolicyHolder[msg.sender], "Already has policy");
        require(contractActive == true, "Contract not active");

        isPolicyHolder[msg.sender] = true;
        premiumBalances[msg.sender] = msg.value;
        policyStartTime[msg.sender] = block.timestamp;
        policyEndTime[msg.sender] = block.timestamp + 31536000;
        coverageAmount[msg.sender] = _coverageAmount;
        totalPremiumCollected += msg.value;

        emit PolicyPurchased(msg.sender, msg.value, _coverageAmount);
    }

    function payAdditionalPremium() external payable {

        require(isPolicyHolder[msg.sender], "Not a policy holder");
        require(msg.value > 0, "Premium must be positive");
        require(contractActive == true, "Contract not active");
        require(block.timestamp <= policyEndTime[msg.sender], "Policy expired");

        premiumBalances[msg.sender] += msg.value;
        totalPremiumCollected += msg.value;

        emit PremiumPaid(msg.sender, msg.value);
    }

    function submitClaim(uint256 _claimAmount) external {

        require(isPolicyHolder[msg.sender], "Not a policy holder");
        require(_claimAmount > 0, "Claim must be positive");
        require(_claimAmount <= coverageAmount[msg.sender], "Claim exceeds coverage");
        require(!hasActiveClaim[msg.sender], "Already has active claim");
        require(contractActive == true, "Contract not active");
        require(block.timestamp >= policyStartTime[msg.sender], "Policy not started");
        require(block.timestamp <= policyEndTime[msg.sender], "Policy expired");

        hasActiveClaim[msg.sender] = true;
        claimAmount[msg.sender] = _claimAmount;
        claimSubmissionTime[msg.sender] = block.timestamp;
        isClaimApproved[msg.sender] = false;
        isClaimPaid[msg.sender] = false;

        emit ClaimSubmitted(msg.sender, _claimAmount);
    }

    function approveClaim(address _policyholder) external {

        require(msg.sender == owner, "Only owner can approve");
        require(isPolicyHolder[_policyholder], "Not a policy holder");
        require(hasActiveClaim[_policyholder], "No active claim");
        require(!isClaimApproved[_policyholder], "Already approved");
        require(contractActive == true, "Contract not active");
        require(block.timestamp <= policyEndTime[_policyholder], "Policy expired");
        require(block.timestamp >= claimSubmissionTime[_policyholder] + 86400, "Wait 24 hours");

        isClaimApproved[_policyholder] = true;

        emit ClaimApproved(_policyholder, claimAmount[_policyholder]);
    }

    function payClaim(address _policyholder) external {

        require(msg.sender == owner, "Only owner can pay");
        require(isPolicyHolder[_policyholder], "Not a policy holder");
        require(hasActiveClaim[_policyholder], "No active claim");
        require(isClaimApproved[_policyholder], "Claim not approved");
        require(!isClaimPaid[_policyholder], "Already paid");
        require(contractActive == true, "Contract not active");
        require(address(this).balance >= claimAmount[_policyholder], "Insufficient funds");

        uint256 payoutAmount = claimAmount[_policyholder];
        isClaimPaid[_policyholder] = true;
        hasActiveClaim[_policyholder] = false;
        totalClaimsPaid += payoutAmount;

        payable(_policyholder).transfer(payoutAmount);

        emit ClaimPaid(_policyholder, payoutAmount);
    }

    function renewPolicy() external payable {

        require(isPolicyHolder[msg.sender], "Not a policy holder");
        require(contractActive == true, "Contract not active");


        uint256 renewalPremium = coverageAmount[msg.sender] / 100;
        require(msg.value >= renewalPremium, "Insufficient renewal premium");

        policyEndTime[msg.sender] = policyEndTime[msg.sender] + 31536000;
        premiumBalances[msg.sender] += msg.value;
        totalPremiumCollected += msg.value;

        emit PremiumPaid(msg.sender, msg.value);
    }

    function cancelPolicy() external {

        require(isPolicyHolder[msg.sender], "Not a policy holder");
        require(contractActive == true, "Contract not active");
        require(!hasActiveClaim[msg.sender], "Cannot cancel with active claim");


        uint256 cancellationFee = premiumBalances[msg.sender] / 10;
        uint256 refundAmount = premiumBalances[msg.sender] - cancellationFee;

        isPolicyHolder[msg.sender] = false;
        premiumBalances[msg.sender] = 0;
        policyStartTime[msg.sender] = 0;
        policyEndTime[msg.sender] = 0;
        coverageAmount[msg.sender] = 0;

        if (refundAmount > 0 && address(this).balance >= refundAmount) {
            payable(msg.sender).transfer(refundAmount);
        }
    }

    function updateCoverageAmount(uint256 _newCoverageAmount) external payable {

        require(isPolicyHolder[msg.sender], "Not a policy holder");
        require(_newCoverageAmount > 0, "Coverage must be positive");
        require(_newCoverageAmount <= 1000000 ether, "Coverage too high");
        require(contractActive == true, "Contract not active");
        require(block.timestamp <= policyEndTime[msg.sender], "Policy expired");
        require(!hasActiveClaim[msg.sender], "Cannot update with active claim");

        uint256 currentCoverage = coverageAmount[msg.sender];

        if (_newCoverageAmount > currentCoverage) {

            uint256 additionalPremium = (_newCoverageAmount - currentCoverage) / 100;
            require(msg.value >= additionalPremium, "Insufficient additional premium");
            premiumBalances[msg.sender] += msg.value;
            totalPremiumCollected += msg.value;
        }

        coverageAmount[msg.sender] = _newCoverageAmount;
    }

    function withdrawOwnerFunds(uint256 _amount) external {

        require(msg.sender == owner, "Only owner can withdraw");
        require(_amount > 0, "Amount must be positive");
        require(address(this).balance >= _amount, "Insufficient balance");
        require(contractActive == true, "Contract not active");


        uint256 minimumReserve = totalPremiumCollected / 4;
        require(address(this).balance - _amount >= minimumReserve, "Must maintain reserve");

        payable(owner).transfer(_amount);
    }

    function emergencyPause() external {

        require(msg.sender == owner, "Only owner can pause");
        require(contractActive == true, "Already paused");

        contractActive = false;
    }

    function emergencyUnpause() external {

        require(msg.sender == owner, "Only owner can unpause");
        require(contractActive == false, "Already active");

        contractActive = true;
    }

    function transferOwnership(address _newOwner) external {

        require(msg.sender == owner, "Only owner can transfer");
        require(_newOwner != address(0), "Invalid address");
        require(_newOwner != owner, "Same owner");
        require(contractActive == true, "Contract not active");

        owner = _newOwner;
    }

    function getPolicyDetails(address _policyholder) external view returns (
        bool _isPolicyHolder,
        uint256 _premiumBalance,
        uint256 _policyStart,
        uint256 _policyEnd,
        uint256 _coverage,
        bool _hasActiveClaim,
        uint256 _claimAmount,
        bool _isClaimApproved
    ) {
        return (
            isPolicyHolder[_policyholder],
            premiumBalances[_policyholder],
            policyStartTime[_policyholder],
            policyEndTime[_policyholder],
            coverageAmount[_policyholder],
            hasActiveClaim[_policyholder],
            claimAmount[_policyholder],
            isClaimApproved[_policyholder]
        );
    }

    function getContractStats() external view returns (
        uint256 _totalPremiumCollected,
        uint256 _totalClaimsPaid,
        uint256 _contractBalance,
        bool _isActive
    ) {
        return (
            totalPremiumCollected,
            totalClaimsPaid,
            address(this).balance,
            contractActive
        );
    }

    function checkPolicyExpiry(address _policyholder) external view returns (bool) {

        if (!isPolicyHolder[_policyholder]) {
            return true;
        }
        if (block.timestamp > policyEndTime[_policyholder]) {
            return true;
        }
        return false;
    }

    function calculateRenewalPremium(address _policyholder) external view returns (uint256) {

        require(isPolicyHolder[_policyholder], "Not a policy holder");


        return coverageAmount[_policyholder] / 100;
    }

    receive() external payable {

        if (isPolicyHolder[msg.sender]) {
            premiumBalances[msg.sender] += msg.value;
            totalPremiumCollected += msg.value;
            emit PremiumPaid(msg.sender, msg.value);
        }
    }
}
