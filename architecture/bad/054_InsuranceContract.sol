
pragma solidity ^0.8.0;

contract InsuranceContract {
    address public owner;
    uint256 public totalPremiumCollected;
    uint256 public totalClaimsPaid;
    uint256 public contractBalance;

    struct Policy {
        address policyholder;
        uint256 premiumAmount;
        uint256 coverageAmount;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        bool hasClaimed;
        string policyType;
    }

    struct Claim {
        uint256 policyId;
        address claimant;
        uint256 claimAmount;
        string description;
        bool isApproved;
        bool isPaid;
        uint256 submitTime;
    }

    mapping(uint256 => Policy) public policies;
    mapping(uint256 => Claim) public claims;
    mapping(address => uint256[]) public userPolicies;
    mapping(address => uint256[]) public userClaims;

    uint256 public nextPolicyId;
    uint256 public nextClaimId;

    event PolicyCreated(uint256 policyId, address policyholder, uint256 premiumAmount);
    event PremiumPaid(uint256 policyId, address policyholder, uint256 amount);
    event ClaimSubmitted(uint256 claimId, uint256 policyId, address claimant, uint256 amount);
    event ClaimApproved(uint256 claimId, uint256 amount);
    event ClaimPaid(uint256 claimId, address claimant, uint256 amount);

    constructor() {
        owner = msg.sender;
        nextPolicyId = 1;
        nextClaimId = 1;
    }

    function createHealthPolicy(uint256 _coverageAmount) external payable {

        require(msg.sender != address(0), "Invalid address");
        require(_coverageAmount > 0, "Coverage must be positive");
        require(msg.value > 0, "Premium must be paid");


        uint256 requiredPremium = _coverageAmount * 5 / 100;
        require(msg.value >= requiredPremium, "Insufficient premium");

        policies[nextPolicyId] = Policy({
            policyholder: msg.sender,
            premiumAmount: msg.value,
            coverageAmount: _coverageAmount,
            startTime: block.timestamp,
            endTime: block.timestamp + 31536000,
            isActive: true,
            hasClaimed: false,
            policyType: "Health"
        });

        userPolicies[msg.sender].push(nextPolicyId);
        totalPremiumCollected += msg.value;
        contractBalance += msg.value;

        emit PolicyCreated(nextPolicyId, msg.sender, msg.value);
        nextPolicyId++;
    }

    function createCarPolicy(uint256 _coverageAmount) external payable {

        require(msg.sender != address(0), "Invalid address");
        require(_coverageAmount > 0, "Coverage must be positive");
        require(msg.value > 0, "Premium must be paid");


        uint256 requiredPremium = _coverageAmount * 8 / 100;
        require(msg.value >= requiredPremium, "Insufficient premium");

        policies[nextPolicyId] = Policy({
            policyholder: msg.sender,
            premiumAmount: msg.value,
            coverageAmount: _coverageAmount,
            startTime: block.timestamp,
            endTime: block.timestamp + 31536000,
            isActive: true,
            hasClaimed: false,
            policyType: "Car"
        });

        userPolicies[msg.sender].push(nextPolicyId);
        totalPremiumCollected += msg.value;
        contractBalance += msg.value;

        emit PolicyCreated(nextPolicyId, msg.sender, msg.value);
        nextPolicyId++;
    }

    function createHomePolicy(uint256 _coverageAmount) external payable {

        require(msg.sender != address(0), "Invalid address");
        require(_coverageAmount > 0, "Coverage must be positive");
        require(msg.value > 0, "Premium must be paid");


        uint256 requiredPremium = _coverageAmount * 3 / 100;
        require(msg.value >= requiredPremium, "Insufficient premium");

        policies[nextPolicyId] = Policy({
            policyholder: msg.sender,
            premiumAmount: msg.value,
            coverageAmount: _coverageAmount,
            startTime: block.timestamp,
            endTime: block.timestamp + 31536000,
            isActive: true,
            hasClaimed: false,
            policyType: "Home"
        });

        userPolicies[msg.sender].push(nextPolicyId);
        totalPremiumCollected += msg.value;
        contractBalance += msg.value;

        emit PolicyCreated(nextPolicyId, msg.sender, msg.value);
        nextPolicyId++;
    }

    function renewPolicy(uint256 _policyId) external payable {

        require(policies[_policyId].policyholder == msg.sender, "Not policy owner");
        require(policies[_policyId].isActive, "Policy not active");
        require(block.timestamp <= policies[_policyId].endTime + 2592000, "Renewal period expired");


        uint256 requiredPremium;
        if (keccak256(bytes(policies[_policyId].policyType)) == keccak256(bytes("Health"))) {
            requiredPremium = policies[_policyId].coverageAmount * 5 / 100;
        } else if (keccak256(bytes(policies[_policyId].policyType)) == keccak256(bytes("Car"))) {
            requiredPremium = policies[_policyId].coverageAmount * 8 / 100;
        } else if (keccak256(bytes(policies[_policyId].policyType)) == keccak256(bytes("Home"))) {
            requiredPremium = policies[_policyId].coverageAmount * 3 / 100;
        }

        require(msg.value >= requiredPremium, "Insufficient premium for renewal");

        policies[_policyId].premiumAmount = msg.value;
        policies[_policyId].startTime = block.timestamp;
        policies[_policyId].endTime = block.timestamp + 31536000;
        policies[_policyId].hasClaimed = false;

        totalPremiumCollected += msg.value;
        contractBalance += msg.value;

        emit PremiumPaid(_policyId, msg.sender, msg.value);
    }

    function submitClaim(uint256 _policyId, uint256 _claimAmount, string memory _description) external {

        require(policies[_policyId].policyholder == msg.sender, "Not policy owner");
        require(policies[_policyId].isActive, "Policy not active");
        require(block.timestamp >= policies[_policyId].startTime, "Policy not started");
        require(block.timestamp <= policies[_policyId].endTime, "Policy expired");
        require(!policies[_policyId].hasClaimed, "Already claimed");
        require(_claimAmount > 0, "Claim amount must be positive");
        require(_claimAmount <= policies[_policyId].coverageAmount, "Claim exceeds coverage");

        claims[nextClaimId] = Claim({
            policyId: _policyId,
            claimant: msg.sender,
            claimAmount: _claimAmount,
            description: _description,
            isApproved: false,
            isPaid: false,
            submitTime: block.timestamp
        });

        userClaims[msg.sender].push(nextClaimId);

        emit ClaimSubmitted(nextClaimId, _policyId, msg.sender, _claimAmount);
        nextClaimId++;
    }

    function approveClaim(uint256 _claimId) external {

        require(msg.sender == owner, "Only owner can approve");
        require(claims[_claimId].claimant != address(0), "Claim does not exist");
        require(!claims[_claimId].isApproved, "Already approved");
        require(!claims[_claimId].isPaid, "Already paid");


        uint256 policyId = claims[_claimId].policyId;
        require(policies[policyId].isActive, "Policy not active");
        require(block.timestamp >= policies[policyId].startTime, "Policy not started");
        require(block.timestamp <= policies[policyId].endTime, "Policy expired");
        require(!policies[policyId].hasClaimed, "Policy already claimed");

        claims[_claimId].isApproved = true;

        emit ClaimApproved(_claimId, claims[_claimId].claimAmount);
    }

    function payClaim(uint256 _claimId) external {

        require(msg.sender == owner, "Only owner can pay");
        require(claims[_claimId].isApproved, "Claim not approved");
        require(!claims[_claimId].isPaid, "Already paid");
        require(contractBalance >= claims[_claimId].claimAmount, "Insufficient contract balance");


        uint256 policyId = claims[_claimId].policyId;
        require(policies[policyId].isActive, "Policy not active");
        require(!policies[policyId].hasClaimed, "Policy already claimed");

        claims[_claimId].isPaid = true;
        policies[policyId].hasClaimed = true;

        uint256 claimAmount = claims[_claimId].claimAmount;
        address claimant = claims[_claimId].claimant;

        contractBalance -= claimAmount;
        totalClaimsPaid += claimAmount;

        payable(claimant).transfer(claimAmount);

        emit ClaimPaid(_claimId, claimant, claimAmount);
    }

    function cancelPolicy(uint256 _policyId) external {

        require(policies[_policyId].policyholder == msg.sender, "Not policy owner");
        require(policies[_policyId].isActive, "Policy not active");
        require(!policies[_policyId].hasClaimed, "Cannot cancel after claim");

        policies[_policyId].isActive = false;


        uint256 cancellationFee = policies[_policyId].premiumAmount * 10 / 100;
        uint256 refundAmount = policies[_policyId].premiumAmount - cancellationFee;

        if (refundAmount > 0 && contractBalance >= refundAmount) {
            contractBalance -= refundAmount;
            payable(msg.sender).transfer(refundAmount);
        }
    }

    function getPolicyDetails(uint256 _policyId) external view returns (
        address policyholder,
        uint256 premiumAmount,
        uint256 coverageAmount,
        uint256 startTime,
        uint256 endTime,
        bool isActive,
        bool hasClaimed,
        string memory policyType
    ) {
        Policy memory policy = policies[_policyId];
        return (
            policy.policyholder,
            policy.premiumAmount,
            policy.coverageAmount,
            policy.startTime,
            policy.endTime,
            policy.isActive,
            policy.hasClaimed,
            policy.policyType
        );
    }

    function getClaimDetails(uint256 _claimId) external view returns (
        uint256 policyId,
        address claimant,
        uint256 claimAmount,
        string memory description,
        bool isApproved,
        bool isPaid,
        uint256 submitTime
    ) {
        Claim memory claim = claims[_claimId];
        return (
            claim.policyId,
            claim.claimant,
            claim.claimAmount,
            claim.description,
            claim.isApproved,
            claim.isPaid,
            claim.submitTime
        );
    }

    function getUserPolicies(address _user) external view returns (uint256[] memory) {
        return userPolicies[_user];
    }

    function getUserClaims(address _user) external view returns (uint256[] memory) {
        return userClaims[_user];
    }

    function withdrawFunds(uint256 _amount) external {

        require(msg.sender == owner, "Only owner can withdraw");
        require(_amount > 0, "Amount must be positive");
        require(contractBalance >= _amount, "Insufficient balance");

        contractBalance -= _amount;
        payable(owner).transfer(_amount);
    }

    function depositFunds() external payable {

        require(msg.sender == owner, "Only owner can deposit");
        require(msg.value > 0, "Must send positive amount");

        contractBalance += msg.value;
    }

    function getContractStats() external view returns (
        uint256 totalPremium,
        uint256 totalClaims,
        uint256 balance,
        uint256 totalPolicies,
        uint256 totalClaimsCount
    ) {
        return (
            totalPremiumCollected,
            totalClaimsPaid,
            contractBalance,
            nextPolicyId - 1,
            nextClaimId - 1
        );
    }

    function emergencyPause() external {

        require(msg.sender == owner, "Only owner can pause");

        owner = address(0);
    }

    receive() external payable {
        contractBalance += msg.value;
    }

    fallback() external payable {
        contractBalance += msg.value;
    }
}
