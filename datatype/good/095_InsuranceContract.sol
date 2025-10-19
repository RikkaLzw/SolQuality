
pragma solidity ^0.8.0;

contract InsuranceContract {
    address private owner;
    uint256 private contractCounter;

    struct Policy {
        bytes32 policyId;
        address policyholder;
        uint256 premiumAmount;
        uint256 coverageAmount;
        uint32 startTime;
        uint32 endTime;
        bool isActive;
        bool claimSubmitted;
        bool claimApproved;
    }

    struct Claim {
        bytes32 claimId;
        bytes32 policyId;
        address claimant;
        uint256 claimAmount;
        bytes32 description;
        uint32 submissionTime;
        bool isProcessed;
        bool isApproved;
    }

    mapping(bytes32 => Policy) public policies;
    mapping(bytes32 => Claim) public claims;
    mapping(address => bytes32[]) public userPolicies;
    mapping(address => uint256) public balances;

    uint256 public constant MIN_PREMIUM = 0.01 ether;
    uint256 public constant MAX_COVERAGE_RATIO = 100;
    uint32 public constant MIN_POLICY_DURATION = 30 days;
    uint32 public constant MAX_POLICY_DURATION = 365 days;

    event PolicyCreated(bytes32 indexed policyId, address indexed policyholder, uint256 premiumAmount, uint256 coverageAmount);
    event PremiumPaid(bytes32 indexed policyId, address indexed policyholder, uint256 amount);
    event ClaimSubmitted(bytes32 indexed claimId, bytes32 indexed policyId, address indexed claimant, uint256 amount);
    event ClaimProcessed(bytes32 indexed claimId, bool approved, uint256 payoutAmount);
    event PolicyExpired(bytes32 indexed policyId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier validPolicy(bytes32 _policyId) {
        require(policies[_policyId].policyholder != address(0), "Policy does not exist");
        _;
    }

    modifier onlyPolicyholder(bytes32 _policyId) {
        require(policies[_policyId].policyholder == msg.sender, "Only policyholder can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
        contractCounter = 0;
    }

    function createPolicy(
        uint256 _coverageAmount,
        uint32 _duration
    ) external payable returns (bytes32) {
        require(msg.value >= MIN_PREMIUM, "Premium amount too low");
        require(_duration >= MIN_POLICY_DURATION && _duration <= MAX_POLICY_DURATION, "Invalid policy duration");
        require(_coverageAmount <= msg.value * MAX_COVERAGE_RATIO, "Coverage amount exceeds maximum ratio");

        contractCounter++;
        bytes32 policyId = keccak256(abi.encodePacked(msg.sender, block.timestamp, contractCounter));

        uint32 startTime = uint32(block.timestamp);
        uint32 endTime = startTime + _duration;

        policies[policyId] = Policy({
            policyId: policyId,
            policyholder: msg.sender,
            premiumAmount: msg.value,
            coverageAmount: _coverageAmount,
            startTime: startTime,
            endTime: endTime,
            isActive: true,
            claimSubmitted: false,
            claimApproved: false
        });

        userPolicies[msg.sender].push(policyId);

        emit PolicyCreated(policyId, msg.sender, msg.value, _coverageAmount);
        emit PremiumPaid(policyId, msg.sender, msg.value);

        return policyId;
    }

    function submitClaim(
        bytes32 _policyId,
        uint256 _claimAmount,
        bytes32 _description
    ) external validPolicy(_policyId) onlyPolicyholder(_policyId) returns (bytes32) {
        Policy storage policy = policies[_policyId];

        require(policy.isActive, "Policy is not active");
        require(block.timestamp >= policy.startTime && block.timestamp <= policy.endTime, "Policy is not in valid period");
        require(!policy.claimSubmitted, "Claim already submitted for this policy");
        require(_claimAmount <= policy.coverageAmount, "Claim amount exceeds coverage");
        require(_claimAmount > 0, "Claim amount must be greater than zero");

        bytes32 claimId = keccak256(abi.encodePacked(_policyId, msg.sender, block.timestamp, _claimAmount));

        claims[claimId] = Claim({
            claimId: claimId,
            policyId: _policyId,
            claimant: msg.sender,
            claimAmount: _claimAmount,
            description: _description,
            submissionTime: uint32(block.timestamp),
            isProcessed: false,
            isApproved: false
        });

        policy.claimSubmitted = true;

        emit ClaimSubmitted(claimId, _policyId, msg.sender, _claimAmount);

        return claimId;
    }

    function processClaim(bytes32 _claimId, bool _approve) external onlyOwner {
        Claim storage claim = claims[_claimId];
        require(claim.claimant != address(0), "Claim does not exist");
        require(!claim.isProcessed, "Claim already processed");

        Policy storage policy = policies[claim.policyId];

        claim.isProcessed = true;
        claim.isApproved = _approve;
        policy.claimApproved = _approve;

        uint256 payoutAmount = 0;

        if (_approve) {
            payoutAmount = claim.claimAmount;
            require(address(this).balance >= payoutAmount, "Insufficient contract balance");

            balances[claim.claimant] += payoutAmount;
            policy.isActive = false;
        }

        emit ClaimProcessed(_claimId, _approve, payoutAmount);
    }

    function withdrawPayout() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No payout available");

        balances[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
    }

    function expirePolicy(bytes32 _policyId) external validPolicy(_policyId) {
        Policy storage policy = policies[_policyId];
        require(block.timestamp > policy.endTime, "Policy has not expired yet");
        require(policy.isActive, "Policy is already inactive");

        policy.isActive = false;

        emit PolicyExpired(_policyId);
    }

    function getPolicyDetails(bytes32 _policyId) external view validPolicy(_policyId) returns (
        address policyholder,
        uint256 premiumAmount,
        uint256 coverageAmount,
        uint32 startTime,
        uint32 endTime,
        bool isActive,
        bool claimSubmitted,
        bool claimApproved
    ) {
        Policy memory policy = policies[_policyId];
        return (
            policy.policyholder,
            policy.premiumAmount,
            policy.coverageAmount,
            policy.startTime,
            policy.endTime,
            policy.isActive,
            policy.claimSubmitted,
            policy.claimApproved
        );
    }

    function getClaimDetails(bytes32 _claimId) external view returns (
        bytes32 policyId,
        address claimant,
        uint256 claimAmount,
        bytes32 description,
        uint32 submissionTime,
        bool isProcessed,
        bool isApproved
    ) {
        require(claims[_claimId].claimant != address(0), "Claim does not exist");

        Claim memory claim = claims[_claimId];
        return (
            claim.policyId,
            claim.claimant,
            claim.claimAmount,
            claim.description,
            claim.submissionTime,
            claim.isProcessed,
            claim.isApproved
        );
    }

    function getUserPolicies(address _user) external view returns (bytes32[] memory) {
        return userPolicies[_user];
    }

    function getContractBalance() external view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    function withdrawOwnerFunds(uint256 _amount) external onlyOwner {
        require(_amount <= address(this).balance, "Insufficient balance");

        (bool success, ) = payable(owner).call{value: _amount}("");
        require(success, "Transfer failed");
    }

    receive() external payable {}

    fallback() external payable {}
}
