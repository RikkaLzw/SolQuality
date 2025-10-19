
pragma solidity ^0.8.0;

contract InsuranceContract {
    address public owner;
    uint256 public totalPremiumPool;
    uint256 public nextPolicyId;

    struct Policy {
        address policyholder;
        uint256 premiumAmount;
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

    enum ClaimStatus {
        Pending,
        Approved,
        Rejected,
        Paid
    }

    mapping(uint256 => Policy) public policies;
    mapping(uint256 => Claim) public claims;
    mapping(address => uint256[]) public userPolicies;
    uint256 public nextClaimId;

    event PolicyCreated(
        uint256 indexed policyId,
        address indexed policyholder,
        uint256 premiumAmount,
        uint256 coverageAmount,
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
        address indexed policyholder,
        uint256 refundAmount
    );

    event FundsWithdrawn(
        address indexed owner,
        uint256 amount
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "InsuranceContract: Only owner can perform this action");
        _;
    }

    modifier validPolicy(uint256 _policyId) {
        require(_policyId < nextPolicyId, "InsuranceContract: Policy does not exist");
        require(policies[_policyId].isActive, "InsuranceContract: Policy is not active");
        _;
    }

    modifier onlyPolicyholder(uint256 _policyId) {
        require(policies[_policyId].policyholder == msg.sender, "InsuranceContract: Only policyholder can perform this action");
        _;
    }

    constructor() {
        owner = msg.sender;
        nextPolicyId = 1;
        nextClaimId = 1;
    }

    function createPolicy(
        uint256 _coverageAmount,
        uint256 _durationInDays
    ) external payable {
        require(msg.value > 0, "InsuranceContract: Premium amount must be greater than zero");
        require(_coverageAmount > 0, "InsuranceContract: Coverage amount must be greater than zero");
        require(_durationInDays > 0, "InsuranceContract: Duration must be greater than zero");
        require(_coverageAmount <= msg.value * 10, "InsuranceContract: Coverage amount too high relative to premium");

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + (_durationInDays * 1 days);

        policies[nextPolicyId] = Policy({
            policyholder: msg.sender,
            premiumAmount: msg.value,
            coverageAmount: _coverageAmount,
            startTime: startTime,
            endTime: endTime,
            isActive: true,
            hasClaimed: false
        });

        userPolicies[msg.sender].push(nextPolicyId);
        totalPremiumPool += msg.value;

        emit PolicyCreated(
            nextPolicyId,
            msg.sender,
            msg.value,
            _coverageAmount,
            startTime,
            endTime
        );

        emit PremiumPaid(nextPolicyId, msg.sender, msg.value);

        nextPolicyId++;
    }

    function submitClaim(
        uint256 _policyId,
        uint256 _claimAmount,
        string memory _description
    ) external validPolicy(_policyId) onlyPolicyholder(_policyId) {
        Policy storage policy = policies[_policyId];

        require(block.timestamp >= policy.startTime, "InsuranceContract: Policy coverage has not started yet");
        require(block.timestamp <= policy.endTime, "InsuranceContract: Policy has expired");
        require(!policy.hasClaimed, "InsuranceContract: Policy has already been claimed");
        require(_claimAmount > 0, "InsuranceContract: Claim amount must be greater than zero");
        require(_claimAmount <= policy.coverageAmount, "InsuranceContract: Claim amount exceeds coverage limit");
        require(bytes(_description).length > 0, "InsuranceContract: Claim description cannot be empty");

        claims[nextClaimId] = Claim({
            policyId: _policyId,
            claimant: msg.sender,
            claimAmount: _claimAmount,
            description: _description,
            timestamp: block.timestamp,
            status: ClaimStatus.Pending
        });

        emit ClaimSubmitted(
            nextClaimId,
            _policyId,
            msg.sender,
            _claimAmount,
            _description
        );

        nextClaimId++;
    }

    function approveClaim(uint256 _claimId) external onlyOwner {
        require(_claimId < nextClaimId, "InsuranceContract: Claim does not exist");

        Claim storage claim = claims[_claimId];
        require(claim.status == ClaimStatus.Pending, "InsuranceContract: Claim is not in pending status");

        Policy storage policy = policies[claim.policyId];
        require(policy.isActive, "InsuranceContract: Associated policy is not active");
        require(address(this).balance >= claim.claimAmount, "InsuranceContract: Insufficient funds to pay claim");

        claim.status = ClaimStatus.Approved;

        emit ClaimStatusUpdated(_claimId, ClaimStatus.Approved, msg.sender);
    }

    function rejectClaim(uint256 _claimId) external onlyOwner {
        require(_claimId < nextClaimId, "InsuranceContract: Claim does not exist");

        Claim storage claim = claims[_claimId];
        require(claim.status == ClaimStatus.Pending, "InsuranceContract: Claim is not in pending status");

        claim.status = ClaimStatus.Rejected;

        emit ClaimStatusUpdated(_claimId, ClaimStatus.Rejected, msg.sender);
    }

    function payClaim(uint256 _claimId) external onlyOwner {
        require(_claimId < nextClaimId, "InsuranceContract: Claim does not exist");

        Claim storage claim = claims[_claimId];
        require(claim.status == ClaimStatus.Approved, "InsuranceContract: Claim must be approved before payment");

        Policy storage policy = policies[claim.policyId];
        require(policy.isActive, "InsuranceContract: Associated policy is not active");
        require(address(this).balance >= claim.claimAmount, "InsuranceContract: Insufficient contract balance");

        claim.status = ClaimStatus.Paid;
        policy.hasClaimed = true;

        (bool success, ) = payable(claim.claimant).call{value: claim.claimAmount}("");
        if (!success) {
            revert("InsuranceContract: Failed to transfer claim payment");
        }

        emit ClaimPaid(_claimId, claim.policyId, claim.claimant, claim.claimAmount);
        emit ClaimStatusUpdated(_claimId, ClaimStatus.Paid, msg.sender);
    }

    function cancelPolicy(uint256 _policyId) external validPolicy(_policyId) onlyPolicyholder(_policyId) {
        Policy storage policy = policies[_policyId];
        require(!policy.hasClaimed, "InsuranceContract: Cannot cancel policy that has been claimed");
        require(block.timestamp < policy.endTime, "InsuranceContract: Cannot cancel expired policy");

        uint256 refundAmount = 0;
        uint256 timeRemaining = policy.endTime - block.timestamp;
        uint256 totalDuration = policy.endTime - policy.startTime;

        if (timeRemaining > 0) {
            refundAmount = (policy.premiumAmount * timeRemaining) / totalDuration;
        }

        policy.isActive = false;
        totalPremiumPool -= refundAmount;

        if (refundAmount > 0) {
            (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
            if (!success) {
                revert("InsuranceContract: Failed to transfer refund");
            }
        }

        emit PolicyCancelled(_policyId, msg.sender, refundAmount);
    }

    function withdrawFunds(uint256 _amount) external onlyOwner {
        require(_amount > 0, "InsuranceContract: Withdrawal amount must be greater than zero");
        require(address(this).balance >= _amount, "InsuranceContract: Insufficient contract balance");

        (bool success, ) = payable(owner).call{value: _amount}("");
        if (!success) {
            revert("InsuranceContract: Failed to withdraw funds");
        }

        emit FundsWithdrawn(owner, _amount);
    }

    function getUserPolicies(address _user) external view returns (uint256[] memory) {
        return userPolicies[_user];
    }

    function getPolicyDetails(uint256 _policyId) external view returns (
        address policyholder,
        uint256 premiumAmount,
        uint256 coverageAmount,
        uint256 startTime,
        uint256 endTime,
        bool isActive,
        bool hasClaimed
    ) {
        require(_policyId < nextPolicyId, "InsuranceContract: Policy does not exist");

        Policy storage policy = policies[_policyId];
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

    function getClaimDetails(uint256 _claimId) external view returns (
        uint256 policyId,
        address claimant,
        uint256 claimAmount,
        string memory description,
        uint256 timestamp,
        ClaimStatus status
    ) {
        require(_claimId < nextClaimId, "InsuranceContract: Claim does not exist");

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

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {
        totalPremiumPool += msg.value;
    }
}
