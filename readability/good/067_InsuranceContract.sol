
pragma solidity ^0.8.0;


contract InsuranceContract {

    address public contractOwner;


    enum PolicyStatus {
        Active,
        Expired,
        Claimed,
        Cancelled
    }


    enum ClaimStatus {
        Pending,
        Approved,
        Rejected,
        Paid
    }


    struct InsurancePolicy {
        uint256 policyId;
        address policyholder;
        uint256 premiumAmount;
        uint256 coverageAmount;
        uint256 startTime;
        uint256 endTime;
        PolicyStatus status;
        bool premiumPaid;
    }


    struct ClaimRequest {
        uint256 claimId;
        uint256 policyId;
        address claimant;
        uint256 claimAmount;
        string claimReason;
        uint256 claimTime;
        ClaimStatus status;
    }


    uint256 private nextPolicyId = 1;
    uint256 private nextClaimId = 1;
    uint256 public totalPremiumCollected;
    uint256 public totalClaimsPaid;


    mapping(uint256 => InsurancePolicy) public policies;
    mapping(uint256 => ClaimRequest) public claims;
    mapping(address => uint256[]) public userPolicies;
    mapping(address => uint256[]) public userClaims;


    event PolicyCreated(
        uint256 indexed policyId,
        address indexed policyholder,
        uint256 premiumAmount,
        uint256 coverageAmount
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
        uint256 claimAmount
    );

    event ClaimProcessed(
        uint256 indexed claimId,
        ClaimStatus status,
        uint256 payoutAmount
    );

    event PolicyStatusChanged(
        uint256 indexed policyId,
        PolicyStatus newStatus
    );


    modifier onlyOwner() {
        require(msg.sender == contractOwner, "Only contract owner can call this function");
        _;
    }

    modifier onlyPolicyholder(uint256 _policyId) {
        require(
            policies[_policyId].policyholder == msg.sender,
            "Only policyholder can call this function"
        );
        _;
    }

    modifier policyExists(uint256 _policyId) {
        require(
            _policyId > 0 && _policyId < nextPolicyId,
            "Policy does not exist"
        );
        _;
    }

    modifier claimExists(uint256 _claimId) {
        require(
            _claimId > 0 && _claimId < nextClaimId,
            "Claim does not exist"
        );
        _;
    }


    constructor() {
        contractOwner = msg.sender;
    }


    function createPolicy(
        uint256 _coverageAmount,
        uint256 _durationInDays
    ) external returns (uint256) {
        require(_coverageAmount > 0, "Coverage amount must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");


        uint256 premiumAmount = (_coverageAmount * 5) / 100;

        uint256 policyId = nextPolicyId++;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + (_durationInDays * 1 days);

        policies[policyId] = InsurancePolicy({
            policyId: policyId,
            policyholder: msg.sender,
            premiumAmount: premiumAmount,
            coverageAmount: _coverageAmount,
            startTime: startTime,
            endTime: endTime,
            status: PolicyStatus.Active,
            premiumPaid: false
        });

        userPolicies[msg.sender].push(policyId);

        emit PolicyCreated(policyId, msg.sender, premiumAmount, _coverageAmount);

        return policyId;
    }


    function payPremium(uint256 _policyId)
        external
        payable
        policyExists(_policyId)
        onlyPolicyholder(_policyId)
    {
        InsurancePolicy storage policy = policies[_policyId];

        require(!policy.premiumPaid, "Premium already paid");
        require(policy.status == PolicyStatus.Active, "Policy is not active");
        require(msg.value == policy.premiumAmount, "Incorrect premium amount");

        policy.premiumPaid = true;
        totalPremiumCollected += msg.value;

        emit PremiumPaid(_policyId, msg.sender, msg.value);
    }


    function submitClaim(
        uint256 _policyId,
        uint256 _claimAmount,
        string memory _claimReason
    )
        external
        policyExists(_policyId)
        onlyPolicyholder(_policyId)
        returns (uint256)
    {
        InsurancePolicy storage policy = policies[_policyId];

        require(policy.premiumPaid, "Premium not paid");
        require(policy.status == PolicyStatus.Active, "Policy is not active");
        require(block.timestamp <= policy.endTime, "Policy has expired");
        require(_claimAmount > 0, "Claim amount must be greater than 0");
        require(_claimAmount <= policy.coverageAmount, "Claim amount exceeds coverage");
        require(bytes(_claimReason).length > 0, "Claim reason cannot be empty");

        uint256 claimId = nextClaimId++;

        claims[claimId] = ClaimRequest({
            claimId: claimId,
            policyId: _policyId,
            claimant: msg.sender,
            claimAmount: _claimAmount,
            claimReason: _claimReason,
            claimTime: block.timestamp,
            status: ClaimStatus.Pending
        });

        userClaims[msg.sender].push(claimId);

        emit ClaimSubmitted(claimId, _policyId, msg.sender, _claimAmount);

        return claimId;
    }


    function processClaim(uint256 _claimId, bool _approved)
        external
        onlyOwner
        claimExists(_claimId)
    {
        ClaimRequest storage claim = claims[_claimId];

        require(claim.status == ClaimStatus.Pending, "Claim already processed");

        if (_approved) {
            claim.status = ClaimStatus.Approved;
            _payClaim(_claimId);
        } else {
            claim.status = ClaimStatus.Rejected;
        }

        emit ClaimProcessed(_claimId, claim.status, _approved ? claim.claimAmount : 0);
    }


    function _payClaim(uint256 _claimId) internal {
        ClaimRequest storage claim = claims[_claimId];
        InsurancePolicy storage policy = policies[claim.policyId];

        require(address(this).balance >= claim.claimAmount, "Insufficient contract balance");

        claim.status = ClaimStatus.Paid;
        policy.status = PolicyStatus.Claimed;
        totalClaimsPaid += claim.claimAmount;

        payable(claim.claimant).transfer(claim.claimAmount);

        emit PolicyStatusChanged(claim.policyId, PolicyStatus.Claimed);
    }


    function cancelPolicy(uint256 _policyId)
        external
        policyExists(_policyId)
        onlyPolicyholder(_policyId)
    {
        InsurancePolicy storage policy = policies[_policyId];

        require(!policy.premiumPaid, "Cannot cancel policy after premium payment");
        require(policy.status == PolicyStatus.Active, "Policy is not active");

        policy.status = PolicyStatus.Cancelled;

        emit PolicyStatusChanged(_policyId, PolicyStatus.Cancelled);
    }


    function updateExpiredPolicy(uint256 _policyId)
        external
        policyExists(_policyId)
    {
        InsurancePolicy storage policy = policies[_policyId];

        require(policy.status == PolicyStatus.Active, "Policy is not active");
        require(block.timestamp > policy.endTime, "Policy has not expired yet");

        policy.status = PolicyStatus.Expired;

        emit PolicyStatusChanged(_policyId, PolicyStatus.Expired);
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


    function withdrawFunds(uint256 _amount) external onlyOwner {
        require(_amount <= address(this).balance, "Insufficient balance");
        require(_amount > 0, "Amount must be greater than 0");

        payable(contractOwner).transfer(_amount);
    }


    function emergencyStop() external onlyOwner {
        selfdestruct(payable(contractOwner));
    }


    receive() external payable {

    }
}
