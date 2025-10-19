
pragma solidity ^0.8.0;

contract VehicleInsuranceContract {
    address public immutable insurer;
    uint256 public constant PREMIUM_RATE = 100;
    uint256 public constant CLAIM_TIMEOUT = 30 days;

    enum PolicyStatus { Active, Expired, Claimed }
    enum ClaimStatus { Pending, Approved, Rejected }

    struct Policy {
        address policyholder;
        uint256 coverageAmount;
        uint256 premiumPaid;
        uint256 startTime;
        uint256 endTime;
        PolicyStatus status;
    }

    struct Claim {
        uint256 policyId;
        uint256 claimAmount;
        uint256 submitTime;
        ClaimStatus status;
        string description;
    }

    mapping(uint256 => Policy) public policies;
    mapping(uint256 => Claim) public claims;
    mapping(address => uint256[]) public userPolicies;

    uint256 public nextPolicyId = 1;
    uint256 public nextClaimId = 1;
    uint256 public totalPremiumCollected;

    event PolicyCreated(uint256 indexed policyId, address indexed policyholder, uint256 coverageAmount);
    event PremiumPaid(uint256 indexed policyId, uint256 amount);
    event ClaimSubmitted(uint256 indexed claimId, uint256 indexed policyId, uint256 amount);
    event ClaimProcessed(uint256 indexed claimId, ClaimStatus status, uint256 payoutAmount);

    modifier onlyInsurer() {
        require(msg.sender == insurer, "Only insurer can call this function");
        _;
    }

    modifier validPolicy(uint256 policyId) {
        require(policyId > 0 && policyId < nextPolicyId, "Invalid policy ID");
        _;
    }

    modifier validClaim(uint256 claimId) {
        require(claimId > 0 && claimId < nextClaimId, "Invalid claim ID");
        _;
    }

    constructor() {
        insurer = msg.sender;
    }

    function createPolicy(uint256 coverageAmount, uint256 duration) external payable returns (uint256) {
        require(coverageAmount > 0, "Coverage amount must be positive");
        require(duration > 0 && duration <= 365 days, "Invalid duration");

        uint256 requiredPremium = calculatePremium(coverageAmount);
        require(msg.value >= requiredPremium, "Insufficient premium payment");

        uint256 policyId = nextPolicyId++;
        policies[policyId] = Policy({
            policyholder: msg.sender,
            coverageAmount: coverageAmount,
            premiumPaid: msg.value,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            status: PolicyStatus.Active
        });

        userPolicies[msg.sender].push(policyId);
        totalPremiumCollected += msg.value;

        emit PolicyCreated(policyId, msg.sender, coverageAmount);
        emit PremiumPaid(policyId, msg.value);

        return policyId;
    }

    function submitClaim(uint256 policyId, uint256 claimAmount, string calldata description)
        external
        validPolicy(policyId)
        returns (uint256)
    {
        Policy storage policy = policies[policyId];
        require(policy.policyholder == msg.sender, "Not policy owner");
        require(policy.status == PolicyStatus.Active, "Policy not active");
        require(block.timestamp <= policy.endTime, "Policy expired");
        require(claimAmount > 0 && claimAmount <= policy.coverageAmount, "Invalid claim amount");

        uint256 claimId = nextClaimId++;
        claims[claimId] = Claim({
            policyId: policyId,
            claimAmount: claimAmount,
            submitTime: block.timestamp,
            status: ClaimStatus.Pending,
            description: description
        });

        emit ClaimSubmitted(claimId, policyId, claimAmount);
        return claimId;
    }

    function processClaim(uint256 claimId, bool approved) external onlyInsurer validClaim(claimId) {
        Claim storage claim = claims[claimId];
        require(claim.status == ClaimStatus.Pending, "Claim already processed");
        require(block.timestamp <= claim.submitTime + CLAIM_TIMEOUT, "Claim processing timeout");

        Policy storage policy = policies[claim.policyId];
        require(policy.status == PolicyStatus.Active, "Policy not active");

        uint256 payoutAmount = 0;

        if (approved) {
            claim.status = ClaimStatus.Approved;
            policy.status = PolicyStatus.Claimed;
            payoutAmount = claim.claimAmount;

            require(address(this).balance >= payoutAmount, "Insufficient contract balance");
            payable(policy.policyholder).transfer(payoutAmount);
        } else {
            claim.status = ClaimStatus.Rejected;
        }

        emit ClaimProcessed(claimId, claim.status, payoutAmount);
    }

    function renewPolicy(uint256 policyId, uint256 duration) external payable validPolicy(policyId) {
        Policy storage policy = policies[policyId];
        require(policy.policyholder == msg.sender, "Not policy owner");
        require(policy.status == PolicyStatus.Active, "Policy not renewable");
        require(duration > 0 && duration <= 365 days, "Invalid duration");

        uint256 requiredPremium = calculatePremium(policy.coverageAmount);
        require(msg.value >= requiredPremium, "Insufficient premium payment");

        policy.premiumPaid += msg.value;
        policy.endTime = block.timestamp + duration;
        totalPremiumCollected += msg.value;

        emit PremiumPaid(policyId, msg.value);
    }

    function calculatePremium(uint256 coverageAmount) public pure returns (uint256) {
        return (coverageAmount * PREMIUM_RATE) / 10000;
    }

    function getPolicyDetails(uint256 policyId) external view validPolicy(policyId) returns (Policy memory) {
        return policies[policyId];
    }

    function getClaimDetails(uint256 claimId) external view validClaim(claimId) returns (Claim memory) {
        return claims[claimId];
    }

    function getUserPolicies(address user) external view returns (uint256[] memory) {
        return userPolicies[user];
    }

    function isPolicyActive(uint256 policyId) external view validPolicy(policyId) returns (bool) {
        Policy memory policy = policies[policyId];
        return policy.status == PolicyStatus.Active && block.timestamp <= policy.endTime;
    }

    function withdrawFunds(uint256 amount) external onlyInsurer {
        require(amount <= address(this).balance, "Insufficient balance");
        require(amount > 0, "Amount must be positive");
        payable(insurer).transfer(amount);
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {
        totalPremiumCollected += msg.value;
    }
}
