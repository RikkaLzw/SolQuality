
pragma solidity ^0.8.0;

contract InsuranceContract {
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

    address public owner;
    uint256 public nextPolicyId;
    uint256 public nextClaimId;
    uint256 public totalPremiumCollected;
    uint256 public totalClaimsPaid;

    mapping(uint256 => Policy) public policies;
    mapping(uint256 => Claim) public claims;
    mapping(address => uint256[]) public userPolicies;
    mapping(address => uint256[]) public userClaims;

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
        address indexed policyholder
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Only contract owner can perform this action");
        _;
    }

    modifier validPolicy(uint256 _policyId) {
        require(_policyId < nextPolicyId, "Policy does not exist");
        require(policies[_policyId].isActive, "Policy is not active");
        _;
    }

    modifier onlyPolicyholder(uint256 _policyId) {
        require(
            policies[_policyId].policyholder == msg.sender,
            "Only policyholder can perform this action"
        );
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
        require(msg.value > 0, "Premium amount must be greater than zero");
        require(_coverageAmount > 0, "Coverage amount must be greater than zero");
        require(_durationInDays > 0, "Policy duration must be greater than zero");
        require(
            _coverageAmount <= msg.value * 100,
            "Coverage amount too high relative to premium"
        );

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
        totalPremiumCollected += msg.value;

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
        string calldata _description
    ) external validPolicy(_policyId) onlyPolicyholder(_policyId) {
        Policy storage policy = policies[_policyId];

        require(
            block.timestamp >= policy.startTime && block.timestamp <= policy.endTime,
            "Policy is not within coverage period"
        );
        require(!policy.hasClaimed, "Policy has already been claimed");
        require(_claimAmount > 0, "Claim amount must be greater than zero");
        require(
            _claimAmount <= policy.coverageAmount,
            "Claim amount exceeds coverage limit"
        );
        require(bytes(_description).length > 0, "Claim description cannot be empty");

        claims[nextClaimId] = Claim({
            policyId: _policyId,
            claimant: msg.sender,
            claimAmount: _claimAmount,
            description: _description,
            timestamp: block.timestamp,
            status: ClaimStatus.Pending
        });

        userClaims[msg.sender].push(nextClaimId);

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
        require(_claimId < nextClaimId, "Claim does not exist");

        Claim storage claim = claims[_claimId];
        require(
            claim.status == ClaimStatus.Pending,
            "Claim is not in pending status"
        );

        claim.status = ClaimStatus.Approved;

        emit ClaimStatusUpdated(_claimId, ClaimStatus.Approved, msg.sender);
    }

    function rejectClaim(uint256 _claimId) external onlyOwner {
        require(_claimId < nextClaimId, "Claim does not exist");

        Claim storage claim = claims[_claimId];
        require(
            claim.status == ClaimStatus.Pending,
            "Claim is not in pending status"
        );

        claim.status = ClaimStatus.Rejected;

        emit ClaimStatusUpdated(_claimId, ClaimStatus.Rejected, msg.sender);
    }

    function payClaim(uint256 _claimId) external onlyOwner {
        require(_claimId < nextClaimId, "Claim does not exist");

        Claim storage claim = claims[_claimId];
        require(
            claim.status == ClaimStatus.Approved,
            "Claim must be approved before payment"
        );

        Policy storage policy = policies[claim.policyId];
        require(policy.isActive, "Associated policy is not active");
        require(!policy.hasClaimed, "Policy has already been claimed");

        uint256 claimAmount = claim.claimAmount;
        require(
            address(this).balance >= claimAmount,
            "Insufficient contract balance to pay claim"
        );

        claim.status = ClaimStatus.Paid;
        policy.hasClaimed = true;
        totalClaimsPaid += claimAmount;

        (bool success, ) = payable(claim.claimant).call{value: claimAmount}("");
        if (!success) {
            revert("Failed to transfer claim payment");
        }

        emit ClaimStatusUpdated(_claimId, ClaimStatus.Paid, msg.sender);
        emit ClaimPaid(_claimId, claim.policyId, claim.claimant, claimAmount);
    }

    function cancelPolicy(uint256 _policyId)
        external
        validPolicy(_policyId)
        onlyPolicyholder(_policyId)
    {
        Policy storage policy = policies[_policyId];
        require(!policy.hasClaimed, "Cannot cancel policy that has been claimed");

        policy.isActive = false;

        emit PolicyCancelled(_policyId, msg.sender);
    }

    function withdrawFunds(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Withdrawal amount must be greater than zero");
        require(
            address(this).balance >= _amount,
            "Insufficient contract balance"
        );

        (bool success, ) = payable(owner).call{value: _amount}("");
        if (!success) {
            revert("Failed to withdraw funds");
        }
    }

    function getUserPolicies(address _user) external view returns (uint256[] memory) {
        return userPolicies[_user];
    }

    function getUserClaims(address _user) external view returns (uint256[] memory) {
        return userClaims[_user];
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function isPolicyActive(uint256 _policyId) external view returns (bool) {
        if (_policyId >= nextPolicyId) return false;

        Policy memory policy = policies[_policyId];
        return policy.isActive &&
               block.timestamp >= policy.startTime &&
               block.timestamp <= policy.endTime;
    }

    receive() external payable {
        revert("Direct payments not accepted. Use createPolicy function");
    }

    fallback() external payable {
        revert("Function not found. Check function name and parameters");
    }
}
