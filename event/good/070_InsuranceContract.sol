
pragma solidity ^0.8.0;

contract InsuranceContract {
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
        address claimant;
        uint256 claimAmount;
        string description;
        uint256 timestamp;
        ClaimStatus status;
    }

    enum ClaimStatus { Pending, Approved, Rejected, Paid }

    address public owner;
    uint256 public totalPolicies;
    uint256 public totalClaims;
    uint256 public contractBalance;

    mapping(uint256 => Policy) public policies;
    mapping(uint256 => Claim) public claims;
    mapping(address => uint256[]) public userPolicies;
    mapping(address => uint256[]) public userClaims;

    event PolicyCreated(
        uint256 indexed policyId,
        address indexed policyholder,
        uint256 premium,
        uint256 indexed coverageAmount,
        uint256 startTime,
        uint256 endTime
    );

    event PremiumPaid(
        uint256 indexed policyId,
        address indexed policyholder,
        uint256 amount
    );

    event ClaimSubmitted(
        uint256 indexed claimId,
        uint256 indexed policyId,
        address indexed claimant,
        uint256 claimAmount,
        string description
    );

    event ClaimStatusUpdated(
        uint256 indexed claimId,
        ClaimStatus indexed newStatus,
        address indexed updatedBy
    );

    event ClaimPaid(
        uint256 indexed claimId,
        uint256 indexed policyId,
        address indexed recipient,
        uint256 amount
    );

    event PolicyCancelled(
        uint256 indexed policyId,
        address indexed policyholder
    );

    event FundsDeposited(
        address indexed depositor,
        uint256 amount
    );

    event FundsWithdrawn(
        address indexed recipient,
        uint256 amount
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "InsuranceContract: Only owner can perform this action");
        _;
    }

    modifier validPolicy(uint256 _policyId) {
        require(_policyId > 0 && _policyId <= totalPolicies, "InsuranceContract: Invalid policy ID");
        _;
    }

    modifier validClaim(uint256 _claimId) {
        require(_claimId > 0 && _claimId <= totalClaims, "InsuranceContract: Invalid claim ID");
        _;
    }

    modifier onlyPolicyholder(uint256 _policyId) {
        require(policies[_policyId].policyholder == msg.sender, "InsuranceContract: Only policyholder can perform this action");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createPolicy(
        uint256 _premium,
        uint256 _coverageAmount,
        uint256 _durationInDays
    ) external payable returns (uint256) {
        require(_premium > 0, "InsuranceContract: Premium must be greater than zero");
        require(_coverageAmount > 0, "InsuranceContract: Coverage amount must be greater than zero");
        require(_durationInDays > 0, "InsuranceContract: Duration must be greater than zero");
        require(msg.value == _premium, "InsuranceContract: Sent value must equal premium amount");

        totalPolicies++;
        uint256 policyId = totalPolicies;

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + (_durationInDays * 1 days);

        policies[policyId] = Policy({
            policyholder: msg.sender,
            premium: _premium,
            coverageAmount: _coverageAmount,
            startTime: startTime,
            endTime: endTime,
            isActive: true,
            hasClaimed: false
        });

        userPolicies[msg.sender].push(policyId);
        contractBalance += _premium;

        emit PolicyCreated(policyId, msg.sender, _premium, _coverageAmount, startTime, endTime);
        emit PremiumPaid(policyId, msg.sender, _premium);

        return policyId;
    }

    function submitClaim(
        uint256 _policyId,
        uint256 _claimAmount,
        string calldata _description
    ) external validPolicy(_policyId) onlyPolicyholder(_policyId) returns (uint256) {
        Policy storage policy = policies[_policyId];

        require(policy.isActive, "InsuranceContract: Policy is not active");
        require(block.timestamp >= policy.startTime, "InsuranceContract: Policy coverage has not started yet");
        require(block.timestamp <= policy.endTime, "InsuranceContract: Policy has expired");
        require(!policy.hasClaimed, "InsuranceContract: Policy has already been claimed");
        require(_claimAmount > 0, "InsuranceContract: Claim amount must be greater than zero");
        require(_claimAmount <= policy.coverageAmount, "InsuranceContract: Claim amount exceeds coverage limit");
        require(bytes(_description).length > 0, "InsuranceContract: Claim description cannot be empty");

        totalClaims++;
        uint256 claimId = totalClaims;

        claims[claimId] = Claim({
            policyId: _policyId,
            claimant: msg.sender,
            claimAmount: _claimAmount,
            description: _description,
            timestamp: block.timestamp,
            status: ClaimStatus.Pending
        });

        userClaims[msg.sender].push(claimId);

        emit ClaimSubmitted(claimId, _policyId, msg.sender, _claimAmount, _description);

        return claimId;
    }

    function approveClaim(uint256 _claimId) external onlyOwner validClaim(_claimId) {
        Claim storage claim = claims[_claimId];

        require(claim.status == ClaimStatus.Pending, "InsuranceContract: Claim is not in pending status");
        require(contractBalance >= claim.claimAmount, "InsuranceContract: Insufficient contract balance to pay claim");

        claim.status = ClaimStatus.Approved;

        emit ClaimStatusUpdated(_claimId, ClaimStatus.Approved, msg.sender);
    }

    function rejectClaim(uint256 _claimId) external onlyOwner validClaim(_claimId) {
        Claim storage claim = claims[_claimId];

        require(claim.status == ClaimStatus.Pending, "InsuranceContract: Claim is not in pending status");

        claim.status = ClaimStatus.Rejected;

        emit ClaimStatusUpdated(_claimId, ClaimStatus.Rejected, msg.sender);
    }

    function payClaim(uint256 _claimId) external onlyOwner validClaim(_claimId) {
        Claim storage claim = claims[_claimId];

        require(claim.status == ClaimStatus.Approved, "InsuranceContract: Claim must be approved before payment");
        require(contractBalance >= claim.claimAmount, "InsuranceContract: Insufficient contract balance");

        Policy storage policy = policies[claim.policyId];
        require(policy.isActive, "InsuranceContract: Associated policy is not active");

        claim.status = ClaimStatus.Paid;
        policy.hasClaimed = true;
        contractBalance -= claim.claimAmount;

        (bool success, ) = payable(claim.claimant).call{value: claim.claimAmount}("");
        if (!success) {
            revert("InsuranceContract: Failed to transfer claim payment");
        }

        emit ClaimStatusUpdated(_claimId, ClaimStatus.Paid, msg.sender);
        emit ClaimPaid(_claimId, claim.policyId, claim.claimant, claim.claimAmount);
    }

    function cancelPolicy(uint256 _policyId) external validPolicy(_policyId) onlyPolicyholder(_policyId) {
        Policy storage policy = policies[_policyId];

        require(policy.isActive, "InsuranceContract: Policy is already inactive");
        require(!policy.hasClaimed, "InsuranceContract: Cannot cancel policy that has been claimed");

        policy.isActive = false;

        emit PolicyCancelled(_policyId, msg.sender);
    }

    function depositFunds() external payable onlyOwner {
        require(msg.value > 0, "InsuranceContract: Deposit amount must be greater than zero");

        contractBalance += msg.value;

        emit FundsDeposited(msg.sender, msg.value);
    }

    function withdrawFunds(uint256 _amount) external onlyOwner {
        require(_amount > 0, "InsuranceContract: Withdrawal amount must be greater than zero");
        require(_amount <= contractBalance, "InsuranceContract: Insufficient contract balance");

        contractBalance -= _amount;

        (bool success, ) = payable(owner).call{value: _amount}("");
        if (!success) {
            revert("InsuranceContract: Failed to transfer funds");
        }

        emit FundsWithdrawn(owner, _amount);
    }

    function getUserPolicies(address _user) external view returns (uint256[] memory) {
        return userPolicies[_user];
    }

    function getUserClaims(address _user) external view returns (uint256[] memory) {
        return userClaims[_user];
    }

    function getPolicyDetails(uint256 _policyId) external view validPolicy(_policyId) returns (
        address policyholder,
        uint256 premium,
        uint256 coverageAmount,
        uint256 startTime,
        uint256 endTime,
        bool isActive,
        bool hasClaimed
    ) {
        Policy storage policy = policies[_policyId];
        return (
            policy.policyholder,
            policy.premium,
            policy.coverageAmount,
            policy.startTime,
            policy.endTime,
            policy.isActive,
            policy.hasClaimed
        );
    }

    function getClaimDetails(uint256 _claimId) external view validClaim(_claimId) returns (
        uint256 policyId,
        address claimant,
        uint256 claimAmount,
        string memory description,
        uint256 timestamp,
        ClaimStatus status
    ) {
        Claim storage claim = claims[_claimId];
        return (
            claim.policyId,
            claim.claimant,
            claim.claimAmount,
            claim.description,
            claim.timestamp,
            claim.status
        );
    }

    receive() external payable {
        contractBalance += msg.value;
        emit FundsDeposited(msg.sender, msg.value);
    }
}
