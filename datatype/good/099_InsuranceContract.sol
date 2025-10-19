
pragma solidity ^0.8.19;

contract InsuranceContract {

    address public immutable insurer;
    uint256 public constant PREMIUM_RATE = 100;
    uint256 public constant CLAIM_PERIOD = 365 days;
    uint256 public constant MAX_COVERAGE = 1000000 ether;

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
        bytes32 evidenceHash;
        ClaimStatus status;
    }

    enum ClaimStatus {
        Pending,
        Approved,
        Rejected,
        Paid
    }


    mapping(bytes32 => Policy) public policies;
    mapping(bytes32 => Claim) public claims;
    mapping(address => bytes32[]) public userPolicies;
    mapping(address => uint256) public balances;


    event PolicyCreated(bytes32 indexed policyId, address indexed policyholder, uint256 coverageAmount);
    event PremiumPaid(bytes32 indexed policyId, uint256 amount);
    event ClaimSubmitted(bytes32 indexed claimId, bytes32 indexed policyId, uint256 amount);
    event ClaimProcessed(bytes32 indexed claimId, ClaimStatus status);
    event PayoutMade(bytes32 indexed claimId, address indexed recipient, uint256 amount);


    modifier onlyInsurer() {
        require(msg.sender == insurer, "Only insurer can call this function");
        _;
    }

    modifier validPolicy(bytes32 _policyId) {
        require(policies[_policyId].isActive, "Policy is not active");
        require(block.timestamp <= policies[_policyId].endTime, "Policy has expired");
        _;
    }

    modifier onlyPolicyholder(bytes32 _policyId) {
        require(msg.sender == policies[_policyId].policyholder, "Only policyholder can call this function");
        _;
    }

    constructor() {
        insurer = msg.sender;
    }


    function createPolicy(
        uint256 _coverageAmount,
        uint256 _durationDays
    ) external payable returns (bytes32 policyId) {
        require(_coverageAmount > 0 && _coverageAmount <= MAX_COVERAGE, "Invalid coverage amount");
        require(_durationDays > 0 && _durationDays <= 365, "Invalid duration");

        uint256 requiredPremium = (_coverageAmount * PREMIUM_RATE) / 10000;
        require(msg.value >= requiredPremium, "Insufficient premium payment");

        policyId = keccak256(abi.encodePacked(msg.sender, block.timestamp, _coverageAmount));

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + (_durationDays * 1 days);

        policies[policyId] = Policy({
            policyId: policyId,
            policyholder: msg.sender,
            coverageAmount: _coverageAmount,
            premiumPaid: msg.value,
            startTime: startTime,
            endTime: endTime,
            isActive: true,
            hasClaimed: false
        });

        userPolicies[msg.sender].push(policyId);
        balances[insurer] += msg.value;

        emit PolicyCreated(policyId, msg.sender, _coverageAmount);
        emit PremiumPaid(policyId, msg.value);


        if (msg.value > requiredPremium) {
            payable(msg.sender).transfer(msg.value - requiredPremium);
        }
    }


    function submitClaim(
        bytes32 _policyId,
        uint256 _claimAmount,
        bytes32 _evidenceHash
    ) external validPolicy(_policyId) onlyPolicyholder(_policyId) returns (bytes32 claimId) {
        require(!policies[_policyId].hasClaimed, "Policy has already been claimed");
        require(_claimAmount > 0 && _claimAmount <= policies[_policyId].coverageAmount, "Invalid claim amount");
        require(_evidenceHash != bytes32(0), "Evidence hash required");

        claimId = keccak256(abi.encodePacked(_policyId, msg.sender, block.timestamp));

        claims[claimId] = Claim({
            claimId: claimId,
            policyId: _policyId,
            claimant: msg.sender,
            claimAmount: _claimAmount,
            claimTime: block.timestamp,
            evidenceHash: _evidenceHash,
            status: ClaimStatus.Pending
        });

        emit ClaimSubmitted(claimId, _policyId, _claimAmount);
    }


    function processClaim(bytes32 _claimId, bool _approve) external onlyInsurer {
        Claim storage claim = claims[_claimId];
        require(claim.status == ClaimStatus.Pending, "Claim already processed");

        if (_approve) {
            claim.status = ClaimStatus.Approved;
            policies[claim.policyId].hasClaimed = true;
        } else {
            claim.status = ClaimStatus.Rejected;
        }

        emit ClaimProcessed(_claimId, claim.status);
    }


    function payClaim(bytes32 _claimId) external onlyInsurer {
        Claim storage claim = claims[_claimId];
        require(claim.status == ClaimStatus.Approved, "Claim not approved");
        require(balances[insurer] >= claim.claimAmount, "Insufficient funds");

        claim.status = ClaimStatus.Paid;
        balances[insurer] -= claim.claimAmount;

        payable(claim.claimant).transfer(claim.claimAmount);

        emit PayoutMade(_claimId, claim.claimant, claim.claimAmount);
    }


    function cancelPolicy(bytes32 _policyId) external onlyPolicyholder(_policyId) {
        Policy storage policy = policies[_policyId];
        require(policy.isActive, "Policy is not active");
        require(!policy.hasClaimed, "Cannot cancel claimed policy");

        policy.isActive = false;


        uint256 refundAmount = policy.premiumPaid / 2;
        if (refundAmount > 0 && balances[insurer] >= refundAmount) {
            balances[insurer] -= refundAmount;
            payable(msg.sender).transfer(refundAmount);
        }
    }


    function withdrawFunds(uint256 _amount) external onlyInsurer {
        require(_amount <= balances[insurer], "Insufficient balance");
        balances[insurer] -= _amount;
        payable(insurer).transfer(_amount);
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
        Policy memory policy = policies[_policyId];
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
        bytes32 evidenceHash,
        ClaimStatus status
    ) {
        Claim memory claim = claims[_claimId];
        return (
            claim.policyId,
            claim.claimant,
            claim.claimAmount,
            claim.claimTime,
            claim.evidenceHash,
            claim.status
        );
    }

    function getUserPolicies(address _user) external view returns (bytes32[] memory) {
        return userPolicies[_user];
    }

    function calculatePremium(uint256 _coverageAmount) external pure returns (uint256) {
        return (_coverageAmount * PREMIUM_RATE) / 10000;
    }


    function emergencyPause() external onlyInsurer {

    }

    receive() external payable {
        balances[insurer] += msg.value;
    }
}
