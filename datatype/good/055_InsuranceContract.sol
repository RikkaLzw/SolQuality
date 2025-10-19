
pragma solidity ^0.8.0;

contract InsuranceContract {
    address public immutable owner;
    uint256 public constant PREMIUM_RATE = 100;
    uint256 public constant CLAIM_PERIOD = 365 days;
    uint256 public constant MAX_COVERAGE = 1000 ether;

    struct Policy {
        bytes32 policyId;
        address policyholder;
        uint256 coverageAmount;
        uint256 premiumPaid;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        bool hasClaimed;
    }

    struct Claim {
        bytes32 claimId;
        bytes32 policyId;
        address claimant;
        uint256 claimAmount;
        uint256 claimTime;
        bool isApproved;
        bool isPaid;
    }

    mapping(bytes32 => Policy) public policies;
    mapping(bytes32 => Claim) public claims;
    mapping(address => bytes32[]) public userPolicies;

    uint256 public totalPolicies;
    uint256 public totalClaims;
    uint256 public totalPremiumCollected;
    uint256 public totalClaimsPaid;

    event PolicyCreated(bytes32 indexed policyId, address indexed policyholder, uint256 coverageAmount);
    event PremiumPaid(bytes32 indexed policyId, address indexed policyholder, uint256 amount);
    event ClaimSubmitted(bytes32 indexed claimId, bytes32 indexed policyId, address indexed claimant, uint256 amount);
    event ClaimApproved(bytes32 indexed claimId, uint256 amount);
    event ClaimPaid(bytes32 indexed claimId, address indexed claimant, uint256 amount);
    event PolicyExpired(bytes32 indexed policyId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier validPolicy(bytes32 _policyId) {
        require(policies[_policyId].policyholder != address(0), "Policy does not exist");
        _;
    }

    modifier activePolicyOnly(bytes32 _policyId) {
        require(policies[_policyId].isActive, "Policy is not active");
        require(block.timestamp <= policies[_policyId].endTime, "Policy has expired");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createPolicy(uint256 _coverageAmount) external payable returns (bytes32) {
        require(_coverageAmount > 0 && _coverageAmount <= MAX_COVERAGE, "Invalid coverage amount");

        uint256 requiredPremium = (_coverageAmount * PREMIUM_RATE) / 10000;
        require(msg.value >= requiredPremium, "Insufficient premium payment");

        bytes32 policyId = keccak256(abi.encodePacked(msg.sender, block.timestamp, totalPolicies));

        policies[policyId] = Policy({
            policyId: policyId,
            policyholder: msg.sender,
            coverageAmount: _coverageAmount,
            premiumPaid: msg.value,
            startTime: block.timestamp,
            endTime: block.timestamp + CLAIM_PERIOD,
            isActive: true,
            hasClaimed: false
        });

        userPolicies[msg.sender].push(policyId);
        totalPolicies++;
        totalPremiumCollected += msg.value;

        emit PolicyCreated(policyId, msg.sender, _coverageAmount);
        emit PremiumPaid(policyId, msg.sender, msg.value);

        return policyId;
    }

    function submitClaim(bytes32 _policyId, uint256 _claimAmount) external validPolicy(_policyId) activePolicyOnly(_policyId) returns (bytes32) {
        Policy storage policy = policies[_policyId];
        require(msg.sender == policy.policyholder, "Only policyholder can submit claim");
        require(!policy.hasClaimed, "Policy has already been claimed");
        require(_claimAmount > 0 && _claimAmount <= policy.coverageAmount, "Invalid claim amount");

        bytes32 claimId = keccak256(abi.encodePacked(_policyId, msg.sender, block.timestamp, totalClaims));

        claims[claimId] = Claim({
            claimId: claimId,
            policyId: _policyId,
            claimant: msg.sender,
            claimAmount: _claimAmount,
            claimTime: block.timestamp,
            isApproved: false,
            isPaid: false
        });

        totalClaims++;

        emit ClaimSubmitted(claimId, _policyId, msg.sender, _claimAmount);

        return claimId;
    }

    function approveClaim(bytes32 _claimId) external onlyOwner {
        Claim storage claim = claims[_claimId];
        require(claim.claimant != address(0), "Claim does not exist");
        require(!claim.isApproved, "Claim already approved");
        require(!claim.isPaid, "Claim already paid");

        Policy storage policy = policies[claim.policyId];
        require(policy.isActive, "Policy is not active");
        require(!policy.hasClaimed, "Policy has already been claimed");

        claim.isApproved = true;
        policy.hasClaimed = true;

        emit ClaimApproved(_claimId, claim.claimAmount);
    }

    function payClaim(bytes32 _claimId) external onlyOwner {
        Claim storage claim = claims[_claimId];
        require(claim.isApproved, "Claim not approved");
        require(!claim.isPaid, "Claim already paid");
        require(address(this).balance >= claim.claimAmount, "Insufficient contract balance");

        claim.isPaid = true;
        totalClaimsPaid += claim.claimAmount;

        payable(claim.claimant).transfer(claim.claimAmount);

        emit ClaimPaid(_claimId, claim.claimant, claim.claimAmount);
    }

    function expirePolicy(bytes32 _policyId) external validPolicy(_policyId) {
        Policy storage policy = policies[_policyId];
        require(block.timestamp > policy.endTime, "Policy has not expired yet");
        require(policy.isActive, "Policy is already inactive");

        policy.isActive = false;

        emit PolicyExpired(_policyId);
    }

    function getUserPolicies(address _user) external view returns (bytes32[] memory) {
        return userPolicies[_user];
    }

    function getPolicyDetails(bytes32 _policyId) external view returns (
        address policyholder,
        uint256 coverageAmount,
        uint256 premiumPaid,
        uint256 startTime,
        uint256 endTime,
        bool isActive,
        bool hasClaimed
    ) {
        Policy storage policy = policies[_policyId];
        return (
            policy.policyholder,
            policy.coverageAmount,
            policy.premiumPaid,
            policy.startTime,
            policy.endTime,
            policy.isActive,
            policy.hasClaimed
        );
    }

    function getClaimDetails(bytes32 _claimId) external view returns (
        bytes32 policyId,
        address claimant,
        uint256 claimAmount,
        uint256 claimTime,
        bool isApproved,
        bool isPaid
    ) {
        Claim storage claim = claims[_claimId];
        return (
            claim.policyId,
            claim.claimant,
            claim.claimAmount,
            claim.claimTime,
            claim.isApproved,
            claim.isPaid
        );
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function withdrawFunds(uint256 _amount) external onlyOwner {
        require(_amount <= address(this).balance, "Insufficient balance");
        payable(owner).transfer(_amount);
    }

    receive() external payable {}
}
