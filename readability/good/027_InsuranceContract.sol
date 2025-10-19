
pragma solidity ^0.8.19;


contract InsuranceContract {


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
        string policyType;
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
        string evidenceHash;
    }


    address public insuranceCompany;
    uint256 public totalPolicies;
    uint256 public totalClaims;
    uint256 public companyBalance;
    uint256 public minimumPremium;
    uint256 public maximumCoverage;


    mapping(uint256 => InsurancePolicy) public policies;
    mapping(uint256 => ClaimRequest) public claims;
    mapping(address => uint256[]) public userPolicies;
    mapping(address => uint256[]) public userClaims;
    mapping(address => bool) public authorizedAdjusters;


    event PolicyCreated(
        uint256 indexed policyId,
        address indexed policyholder,
        uint256 premiumAmount,
        uint256 coverageAmount,
        string policyType
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


    modifier onlyInsuranceCompany() {
        require(msg.sender == insuranceCompany, "Only insurance company can call this function");
        _;
    }

    modifier onlyPolicyholder(uint256 _policyId) {
        require(policies[_policyId].policyholder == msg.sender, "Only policyholder can call this function");
        _;
    }

    modifier onlyAuthorizedAdjuster() {
        require(authorizedAdjusters[msg.sender] || msg.sender == insuranceCompany, "Not authorized to process claims");
        _;
    }

    modifier validPolicyId(uint256 _policyId) {
        require(_policyId > 0 && _policyId <= totalPolicies, "Invalid policy ID");
        _;
    }

    modifier validClaimId(uint256 _claimId) {
        require(_claimId > 0 && _claimId <= totalClaims, "Invalid claim ID");
        _;
    }


    constructor(uint256 _minimumPremium, uint256 _maximumCoverage) {
        insuranceCompany = msg.sender;
        minimumPremium = _minimumPremium;
        maximumCoverage = _maximumCoverage;
        totalPolicies = 0;
        totalClaims = 0;
        companyBalance = 0;
    }


    function createPolicy(
        uint256 _coverageAmount,
        uint256 _durationInDays,
        string memory _policyType
    ) external returns (uint256 policyId) {
        require(_coverageAmount > 0, "Coverage amount must be greater than 0");
        require(_coverageAmount <= maximumCoverage, "Coverage amount exceeds maximum");
        require(_durationInDays > 0, "Duration must be greater than 0");
        require(bytes(_policyType).length > 0, "Policy type cannot be empty");


        uint256 premiumAmount = (_coverageAmount * 5 * _durationInDays) / (100 * 365);
        require(premiumAmount >= minimumPremium, "Premium amount below minimum");

        totalPolicies++;
        policyId = totalPolicies;

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
            policyType: _policyType,
            premiumPaid: false
        });

        userPolicies[msg.sender].push(policyId);

        emit PolicyCreated(policyId, msg.sender, premiumAmount, _coverageAmount, _policyType);

        return policyId;
    }


    function payPremium(uint256 _policyId)
        external
        payable
        validPolicyId(_policyId)
        onlyPolicyholder(_policyId)
    {
        InsurancePolicy storage policy = policies[_policyId];

        require(!policy.premiumPaid, "Premium already paid");
        require(policy.status == PolicyStatus.Active, "Policy is not active");
        require(msg.value == policy.premiumAmount, "Incorrect premium amount");

        policy.premiumPaid = true;
        companyBalance += msg.value;

        emit PremiumPaid(_policyId, msg.sender, msg.value);
    }


    function submitClaim(
        uint256 _policyId,
        uint256 _claimAmount,
        string memory _claimReason,
        string memory _evidenceHash
    )
        external
        validPolicyId(_policyId)
        onlyPolicyholder(_policyId)
        returns (uint256 claimId)
    {
        InsurancePolicy storage policy = policies[_policyId];

        require(policy.premiumPaid, "Premium not paid");
        require(policy.status == PolicyStatus.Active, "Policy is not active");
        require(block.timestamp >= policy.startTime, "Policy not yet effective");
        require(block.timestamp <= policy.endTime, "Policy has expired");
        require(_claimAmount > 0, "Claim amount must be greater than 0");
        require(_claimAmount <= policy.coverageAmount, "Claim amount exceeds coverage");
        require(bytes(_claimReason).length > 0, "Claim reason cannot be empty");

        totalClaims++;
        claimId = totalClaims;

        claims[claimId] = ClaimRequest({
            claimId: claimId,
            policyId: _policyId,
            claimant: msg.sender,
            claimAmount: _claimAmount,
            claimReason: _claimReason,
            claimTime: block.timestamp,
            status: ClaimStatus.Pending,
            evidenceHash: _evidenceHash
        });

        userClaims[msg.sender].push(claimId);

        emit ClaimSubmitted(claimId, _policyId, msg.sender, _claimAmount);

        return claimId;
    }


    function processClaim(
        uint256 _claimId,
        bool _approved,
        uint256 _payoutAmount
    )
        external
        validClaimId(_claimId)
        onlyAuthorizedAdjuster
    {
        ClaimRequest storage claim = claims[_claimId];

        require(claim.status == ClaimStatus.Pending, "Claim already processed");

        if (_approved) {
            require(_payoutAmount > 0, "Payout amount must be greater than 0");
            require(_payoutAmount <= claim.claimAmount, "Payout exceeds claim amount");
            require(companyBalance >= _payoutAmount, "Insufficient company balance");

            claim.status = ClaimStatus.Approved;


            companyBalance -= _payoutAmount;
            payable(claim.claimant).transfer(_payoutAmount);

            claim.status = ClaimStatus.Paid;


            policies[claim.policyId].status = PolicyStatus.Claimed;

            emit ClaimProcessed(_claimId, ClaimStatus.Paid, _payoutAmount);
        } else {
            claim.status = ClaimStatus.Rejected;
            emit ClaimProcessed(_claimId, ClaimStatus.Rejected, 0);
        }
    }


    function cancelPolicy(uint256 _policyId)
        external
        validPolicyId(_policyId)
        onlyPolicyholder(_policyId)
    {
        InsurancePolicy storage policy = policies[_policyId];

        require(policy.status == PolicyStatus.Active, "Policy is not active");
        require(block.timestamp < policy.endTime, "Policy has already expired");

        policy.status = PolicyStatus.Cancelled;


        if (policy.premiumPaid && block.timestamp <= policy.startTime + 7 days) {
            uint256 refundAmount = (policy.premiumAmount * 80) / 100;
            if (companyBalance >= refundAmount) {
                companyBalance -= refundAmount;
                payable(msg.sender).transfer(refundAmount);
            }
        }

        emit PolicyStatusChanged(_policyId, PolicyStatus.Cancelled);
    }


    function updateExpiredPolicy(uint256 _policyId)
        external
        validPolicyId(_policyId)
    {
        InsurancePolicy storage policy = policies[_policyId];

        require(policy.status == PolicyStatus.Active, "Policy is not active");
        require(block.timestamp > policy.endTime, "Policy has not expired yet");

        policy.status = PolicyStatus.Expired;

        emit PolicyStatusChanged(_policyId, PolicyStatus.Expired);
    }


    function addAuthorizedAdjuster(address _adjuster)
        external
        onlyInsuranceCompany
    {
        require(_adjuster != address(0), "Invalid adjuster address");
        authorizedAdjusters[_adjuster] = true;
    }


    function removeAuthorizedAdjuster(address _adjuster)
        external
        onlyInsuranceCompany
    {
        authorizedAdjusters[_adjuster] = false;
    }


    function withdrawFunds(uint256 _amount)
        external
        onlyInsuranceCompany
    {
        require(_amount > 0, "Amount must be greater than 0");
        require(companyBalance >= _amount, "Insufficient balance");

        companyBalance -= _amount;
        payable(insuranceCompany).transfer(_amount);
    }


    function depositFunds()
        external
        payable
        onlyInsuranceCompany
    {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        companyBalance += msg.value;
    }


    function getUserPolicies(address _user)
        external
        view
        returns (uint256[] memory)
    {
        return userPolicies[_user];
    }


    function getUserClaims(address _user)
        external
        view
        returns (uint256[] memory)
    {
        return userClaims[_user];
    }


    function getPolicyDetails(uint256 _policyId)
        external
        view
        validPolicyId(_policyId)
        returns (InsurancePolicy memory)
    {
        return policies[_policyId];
    }


    function getClaimDetails(uint256 _claimId)
        external
        view
        validClaimId(_claimId)
        returns (ClaimRequest memory)
    {
        return claims[_claimId];
    }


    function getContractStats()
        external
        view
        returns (uint256 totalPoliciesCount, uint256 totalClaimsCount, uint256 contractBalance)
    {
        return (totalPolicies, totalClaims, companyBalance);
    }


    function emergencyWithdraw()
        external
        onlyInsuranceCompany
    {
        payable(insuranceCompany).transfer(address(this).balance);
        companyBalance = 0;
    }
}
