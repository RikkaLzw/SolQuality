
pragma solidity ^0.8.0;

contract InsuranceContract {
    address public immutable insurer;

    struct Policy {
        bytes32 policyId;
        address policyholder;
        uint128 premiumAmount;
        uint128 coverageAmount;
        uint32 startTime;
        uint32 endTime;
        bool isActive;
        bool hasClaimed;
    }

    struct Claim {
        bytes32 claimId;
        bytes32 policyId;
        address claimant;
        uint128 claimAmount;
        uint32 claimTime;
        bool isApproved;
        bool isPaid;
    }

    mapping(bytes32 => Policy) public policies;
    mapping(bytes32 => Claim) public claims;
    mapping(address => bytes32[]) public userPolicies;

    uint128 public totalPremiumCollected;
    uint128 public totalClaimsPaid;
    uint32 public policyCount;
    uint32 public claimCount;

    event PolicyCreated(bytes32 indexed policyId, address indexed policyholder, uint128 premiumAmount, uint128 coverageAmount);
    event PremiumPaid(bytes32 indexed policyId, address indexed policyholder, uint128 amount);
    event ClaimSubmitted(bytes32 indexed claimId, bytes32 indexed policyId, address indexed claimant, uint128 amount);
    event ClaimApproved(bytes32 indexed claimId, uint128 amount);
    event ClaimPaid(bytes32 indexed claimId, address indexed claimant, uint128 amount);
    event PolicyCancelled(bytes32 indexed policyId);

    modifier onlyInsurer() {
        require(msg.sender == insurer, "Only insurer can perform this action");
        _;
    }

    modifier validPolicy(bytes32 _policyId) {
        require(policies[_policyId].policyholder != address(0), "Policy does not exist");
        _;
    }

    modifier activePolicyOnly(bytes32 _policyId) {
        require(policies[_policyId].isActive, "Policy is not active");
        require(block.timestamp >= policies[_policyId].startTime, "Policy not yet started");
        require(block.timestamp <= policies[_policyId].endTime, "Policy has expired");
        _;
    }

    constructor() {
        insurer = msg.sender;
    }

    function createPolicy(
        address _policyholder,
        uint128 _premiumAmount,
        uint128 _coverageAmount,
        uint32 _durationInDays
    ) external onlyInsurer returns (bytes32) {
        require(_policyholder != address(0), "Invalid policyholder address");
        require(_premiumAmount > 0, "Premium amount must be greater than 0");
        require(_coverageAmount > 0, "Coverage amount must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");

        policyCount++;
        bytes32 policyId = keccak256(abi.encodePacked(_policyholder, block.timestamp, policyCount));

        uint32 startTime = uint32(block.timestamp);
        uint32 endTime = startTime + (_durationInDays * 1 days);

        policies[policyId] = Policy({
            policyId: policyId,
            policyholder: _policyholder,
            premiumAmount: _premiumAmount,
            coverageAmount: _coverageAmount,
            startTime: startTime,
            endTime: endTime,
            isActive: false,
            hasClaimed: false
        });

        userPolicies[_policyholder].push(policyId);

        emit PolicyCreated(policyId, _policyholder, _premiumAmount, _coverageAmount);
        return policyId;
    }

    function payPremium(bytes32 _policyId) external payable validPolicy(_policyId) {
        Policy storage policy = policies[_policyId];
        require(msg.sender == policy.policyholder, "Only policyholder can pay premium");
        require(!policy.isActive, "Premium already paid");
        require(msg.value == policy.premiumAmount, "Incorrect premium amount");

        policy.isActive = true;
        totalPremiumCollected += policy.premiumAmount;

        emit PremiumPaid(_policyId, msg.sender, policy.premiumAmount);
    }

    function submitClaim(bytes32 _policyId, uint128 _claimAmount) external validPolicy(_policyId) activePolicyOnly(_policyId) returns (bytes32) {
        Policy storage policy = policies[_policyId];
        require(msg.sender == policy.policyholder, "Only policyholder can submit claim");
        require(!policy.hasClaimed, "Claim already submitted for this policy");
        require(_claimAmount > 0, "Claim amount must be greater than 0");
        require(_claimAmount <= policy.coverageAmount, "Claim amount exceeds coverage");

        claimCount++;
        bytes32 claimId = keccak256(abi.encodePacked(_policyId, msg.sender, block.timestamp, claimCount));

        claims[claimId] = Claim({
            claimId: claimId,
            policyId: _policyId,
            claimant: msg.sender,
            claimAmount: _claimAmount,
            claimTime: uint32(block.timestamp),
            isApproved: false,
            isPaid: false
        });

        policy.hasClaimed = true;

        emit ClaimSubmitted(claimId, _policyId, msg.sender, _claimAmount);
        return claimId;
    }

    function approveClaim(bytes32 _claimId) external onlyInsurer {
        Claim storage claim = claims[_claimId];
        require(claim.claimant != address(0), "Claim does not exist");
        require(!claim.isApproved, "Claim already approved");
        require(!claim.isPaid, "Claim already paid");

        claim.isApproved = true;

        emit ClaimApproved(_claimId, claim.claimAmount);
    }

    function payClaim(bytes32 _claimId) external onlyInsurer {
        Claim storage claim = claims[_claimId];
        require(claim.claimant != address(0), "Claim does not exist");
        require(claim.isApproved, "Claim not approved");
        require(!claim.isPaid, "Claim already paid");
        require(address(this).balance >= claim.claimAmount, "Insufficient contract balance");

        claim.isPaid = true;
        totalClaimsPaid += claim.claimAmount;

        payable(claim.claimant).transfer(claim.claimAmount);

        emit ClaimPaid(_claimId, claim.claimant, claim.claimAmount);
    }

    function cancelPolicy(bytes32 _policyId) external onlyInsurer validPolicy(_policyId) {
        Policy storage policy = policies[_policyId];
        require(policy.isActive, "Policy is not active");
        require(!policy.hasClaimed, "Cannot cancel policy with submitted claim");

        policy.isActive = false;

        emit PolicyCancelled(_policyId);
    }

    function getUserPolicies(address _user) external view returns (bytes32[] memory) {
        return userPolicies[_user];
    }

    function getPolicyDetails(bytes32 _policyId) external view returns (
        address policyholder,
        uint128 premiumAmount,
        uint128 coverageAmount,
        uint32 startTime,
        uint32 endTime,
        bool isActive,
        bool hasClaimed
    ) {
        Policy memory policy = policies[_policyId];
        return (
            policy.policyholder,
            policy.premiumAmount,
            policy.coverageAmount,
            policy.startTime,
            policy.endTime,
            policy.isActive,
            policy.hasClaimed
        );
    }

    function getClaimDetails(bytes32 _claimId) external view returns (
        bytes32 policyId,
        address claimant,
        uint128 claimAmount,
        uint32 claimTime,
        bool isApproved,
        bool isPaid
    ) {
        Claim memory claim = claims[_claimId];
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

    function withdrawFunds(uint128 _amount) external onlyInsurer {
        require(_amount <= address(this).balance, "Insufficient balance");
        payable(insurer).transfer(_amount);
    }

    receive() external payable {}
}
