
pragma solidity ^0.8.0;

contract VehicleInsuranceContract {
    struct Policy {
        address policyholder;
        uint256 premium;
        uint256 coverageAmount;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        bool hasClaimed;
    }

    struct Claim {
        uint256 policyId;
        uint256 amount;
        string description;
        uint256 timestamp;
        ClaimStatus status;
    }

    enum ClaimStatus {
        Pending,
        Approved,
        Rejected,
        Paid
    }

    address public owner;
    uint256 public nextPolicyId;
    uint256 public nextClaimId;
    uint256 public totalReserves;

    mapping(uint256 => Policy) public policies;
    mapping(uint256 => Claim) public claims;
    mapping(address => uint256[]) public userPolicies;

    event PolicyCreated(uint256 indexed policyId, address indexed policyholder);
    event PremiumPaid(uint256 indexed policyId, uint256 amount);
    event ClaimSubmitted(uint256 indexed claimId, uint256 indexed policyId);
    event ClaimProcessed(uint256 indexed claimId, ClaimStatus status);
    event ClaimPaid(uint256 indexed claimId, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    modifier validPolicy(uint256 policyId) {
        require(policyId < nextPolicyId, "Policy does not exist");
        require(policies[policyId].isActive, "Policy is not active");
        _;
    }

    modifier onlyPolicyholder(uint256 policyId) {
        require(policies[policyId].policyholder == msg.sender, "Only policyholder can perform this action");
        _;
    }

    constructor() {
        owner = msg.sender;
        nextPolicyId = 1;
        nextClaimId = 1;
    }

    function createPolicy(uint256 coverageAmount, uint256 duration) external payable returns (uint256) {
        require(msg.value > 0, "Premium must be greater than 0");
        require(coverageAmount > 0, "Coverage amount must be greater than 0");
        require(duration > 0, "Duration must be greater than 0");

        uint256 policyId = nextPolicyId++;

        policies[policyId] = Policy({
            policyholder: msg.sender,
            premium: msg.value,
            coverageAmount: coverageAmount,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            isActive: true,
            hasClaimed: false
        });

        userPolicies[msg.sender].push(policyId);
        totalReserves += msg.value;

        emit PolicyCreated(policyId, msg.sender);
        emit PremiumPaid(policyId, msg.value);

        return policyId;
    }

    function renewPolicy(uint256 policyId, uint256 duration) external payable validPolicy(policyId) onlyPolicyholder(policyId) {
        require(msg.value > 0, "Premium must be greater than 0");
        require(duration > 0, "Duration must be greater than 0");

        Policy storage policy = policies[policyId];
        policy.endTime = block.timestamp + duration;
        policy.premium += msg.value;

        totalReserves += msg.value;

        emit PremiumPaid(policyId, msg.value);
    }

    function submitClaim(uint256 policyId, uint256 amount, string memory description) external validPolicy(policyId) onlyPolicyholder(policyId) returns (uint256) {
        require(amount > 0, "Claim amount must be greater than 0");
        require(bytes(description).length > 0, "Description cannot be empty");

        Policy storage policy = policies[policyId];
        require(block.timestamp <= policy.endTime, "Policy has expired");
        require(!policy.hasClaimed, "Policy has already been claimed");
        require(amount <= policy.coverageAmount, "Claim exceeds coverage amount");

        uint256 claimId = nextClaimId++;

        claims[claimId] = Claim({
            policyId: policyId,
            amount: amount,
            description: description,
            timestamp: block.timestamp,
            status: ClaimStatus.Pending
        });

        emit ClaimSubmitted(claimId, policyId);

        return claimId;
    }

    function approveClaim(uint256 claimId) external onlyOwner {
        require(claimId < nextClaimId, "Claim does not exist");

        Claim storage claim = claims[claimId];
        require(claim.status == ClaimStatus.Pending, "Claim is not pending");

        claim.status = ClaimStatus.Approved;

        emit ClaimProcessed(claimId, ClaimStatus.Approved);
    }

    function rejectClaim(uint256 claimId) external onlyOwner {
        require(claimId < nextClaimId, "Claim does not exist");

        Claim storage claim = claims[claimId];
        require(claim.status == ClaimStatus.Pending, "Claim is not pending");

        claim.status = ClaimStatus.Rejected;

        emit ClaimProcessed(claimId, ClaimStatus.Rejected);
    }

    function payClaim(uint256 claimId) external onlyOwner {
        require(claimId < nextClaimId, "Claim does not exist");

        Claim storage claim = claims[claimId];
        require(claim.status == ClaimStatus.Approved, "Claim is not approved");
        require(totalReserves >= claim.amount, "Insufficient reserves");

        Policy storage policy = policies[claim.policyId];
        address payable policyholder = payable(policy.policyholder);

        policy.hasClaimed = true;
        policy.isActive = false;
        claim.status = ClaimStatus.Paid;
        totalReserves -= claim.amount;

        policyholder.transfer(claim.amount);

        emit ClaimPaid(claimId, claim.amount);
    }

    function cancelPolicy(uint256 policyId) external validPolicy(policyId) onlyPolicyholder(policyId) {
        Policy storage policy = policies[policyId];
        require(!policy.hasClaimed, "Cannot cancel policy with existing claim");

        policy.isActive = false;

        uint256 refundAmount = _calculateRefund(policyId);
        if (refundAmount > 0) {
            totalReserves -= refundAmount;
            payable(msg.sender).transfer(refundAmount);
        }
    }

    function getPolicyDetails(uint256 policyId) external view returns (Policy memory) {
        require(policyId < nextPolicyId, "Policy does not exist");
        return policies[policyId];
    }

    function getClaimDetails(uint256 claimId) external view returns (Claim memory) {
        require(claimId < nextClaimId, "Claim does not exist");
        return claims[claimId];
    }

    function getUserPolicies(address user) external view returns (uint256[] memory) {
        return userPolicies[user];
    }

    function withdrawReserves(uint256 amount) external onlyOwner {
        require(amount <= totalReserves, "Insufficient reserves");

        totalReserves -= amount;
        payable(owner).transfer(amount);
    }

    function _calculateRefund(uint256 policyId) internal view returns (uint256) {
        Policy memory policy = policies[policyId];

        if (block.timestamp >= policy.endTime) {
            return 0;
        }

        uint256 remainingTime = policy.endTime - block.timestamp;
        uint256 totalDuration = policy.endTime - policy.startTime;

        return (policy.premium * remainingTime) / totalDuration / 2;
    }

    receive() external payable {
        totalReserves += msg.value;
    }
}
