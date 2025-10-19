
pragma solidity ^0.8.19;

contract OptimizedInsuranceContract {

    struct Policy {
        address policyholder;
        uint128 premiumAmount;
        uint64 coverageAmount;
        uint32 startTime;
        uint32 endTime;
        uint8 status;
    }

    struct Claim {
        uint128 amount;
        uint64 timestamp;
        uint8 status;
    }


    address private immutable owner;
    uint256 private constant MINIMUM_PREMIUM = 0.01 ether;
    uint256 private constant MAXIMUM_COVERAGE = 100 ether;
    uint256 private constant POLICY_DURATION = 365 days;


    mapping(uint256 => Policy) public policies;
    mapping(uint256 => Claim) public claims;
    mapping(address => uint256[]) private userPolicies;
    mapping(uint256 => uint256[]) private policyClaims;

    uint256 private policyCounter;
    uint256 private claimCounter;
    uint256 private totalPremiumCollected;
    uint256 private totalClaimsPaid;


    event PolicyCreated(uint256 indexed policyId, address indexed policyholder, uint256 premium, uint256 coverage);
    event ClaimSubmitted(uint256 indexed claimId, uint256 indexed policyId, uint256 amount);
    event ClaimProcessed(uint256 indexed claimId, bool approved, uint256 amount);
    event PremiumPaid(uint256 indexed policyId, uint256 amount);


    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier validPolicy(uint256 _policyId) {
        require(_policyId > 0 && _policyId <= policyCounter, "Invalid policy ID");
        _;
    }

    modifier validClaim(uint256 _claimId) {
        require(_claimId > 0 && _claimId <= claimCounter, "Invalid claim ID");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createPolicy(uint256 _coverageAmount) external payable returns (uint256) {
        require(msg.value >= MINIMUM_PREMIUM, "Insufficient premium");
        require(_coverageAmount <= MAXIMUM_COVERAGE, "Coverage exceeds maximum");
        require(_coverageAmount > 0, "Coverage must be positive");


        uint256 currentTime = block.timestamp;
        uint256 newPolicyId = ++policyCounter;


        policies[newPolicyId] = Policy({
            policyholder: msg.sender,
            premiumAmount: uint128(msg.value),
            coverageAmount: uint64(_coverageAmount),
            startTime: uint32(currentTime),
            endTime: uint32(currentTime + POLICY_DURATION),
            status: 1
        });


        userPolicies[msg.sender].push(newPolicyId);


        totalPremiumCollected += msg.value;

        emit PolicyCreated(newPolicyId, msg.sender, msg.value, _coverageAmount);
        return newPolicyId;
    }

    function submitClaim(uint256 _policyId, uint256 _claimAmount)
        external
        validPolicy(_policyId)
        returns (uint256)
    {

        Policy memory policy = policies[_policyId];

        require(policy.policyholder == msg.sender, "Not policy owner");
        require(policy.status == 1, "Policy not active");
        require(block.timestamp <= policy.endTime, "Policy expired");
        require(_claimAmount <= policy.coverageAmount, "Claim exceeds coverage");
        require(_claimAmount > 0, "Invalid claim amount");

        uint256 newClaimId = ++claimCounter;

        claims[newClaimId] = Claim({
            amount: uint128(_claimAmount),
            timestamp: uint64(block.timestamp),
            status: 0
        });

        policyClaims[_policyId].push(newClaimId);

        emit ClaimSubmitted(newClaimId, _policyId, _claimAmount);
        return newClaimId;
    }

    function processClaim(uint256 _claimId, bool _approve)
        external
        onlyOwner
        validClaim(_claimId)
    {

        Claim storage claim = claims[_claimId];
        require(claim.status == 0, "Claim already processed");

        if (_approve) {
            require(address(this).balance >= claim.amount, "Insufficient contract balance");

            claim.status = 1;
            totalClaimsPaid += claim.amount;


            address policyholder = _findPolicyholderForClaim(_claimId);
            require(policyholder != address(0), "Policyholder not found");

            (bool success, ) = payable(policyholder).call{value: claim.amount}("");
            require(success, "Transfer failed");
        } else {
            claim.status = 2;
        }

        emit ClaimProcessed(_claimId, _approve, claim.amount);
    }

    function renewPolicy(uint256 _policyId) external payable validPolicy(_policyId) {
        Policy storage policy = policies[_policyId];
        require(policy.policyholder == msg.sender, "Not policy owner");
        require(policy.status != 2, "Policy has active claim");
        require(msg.value >= MINIMUM_PREMIUM, "Insufficient premium");


        uint256 currentTime = block.timestamp;
        policy.premiumAmount = uint128(msg.value);
        policy.startTime = uint32(currentTime);
        policy.endTime = uint32(currentTime + POLICY_DURATION);
        policy.status = 1;

        totalPremiumCollected += msg.value;

        emit PremiumPaid(_policyId, msg.value);
    }

    function getUserPolicies(address _user) external view returns (uint256[] memory) {
        return userPolicies[_user];
    }

    function getPolicyClaims(uint256 _policyId) external view returns (uint256[] memory) {
        return policyClaims[_policyId];
    }

    function getContractStats() external view returns (
        uint256 totalPolicies,
        uint256 totalClaims,
        uint256 premiumCollected,
        uint256 claimsPaid,
        uint256 contractBalance
    ) {
        return (
            policyCounter,
            claimCounter,
            totalPremiumCollected,
            totalClaimsPaid,
            address(this).balance
        );
    }

    function isPolicyActive(uint256 _policyId) external view validPolicy(_policyId) returns (bool) {
        Policy memory policy = policies[_policyId];
        return policy.status == 1 && block.timestamp <= policy.endTime;
    }

    function withdrawFunds(uint256 _amount) external onlyOwner {
        require(_amount <= address(this).balance, "Insufficient balance");
        require(_amount > 0, "Invalid amount");

        (bool success, ) = payable(owner).call{value: _amount}("");
        require(success, "Withdrawal failed");
    }


    function _findPolicyholderForClaim(uint256 _claimId) private view returns (address) {

        for (uint256 i = 1; i <= policyCounter; i++) {
            uint256[] memory claimIds = policyClaims[i];
            for (uint256 j = 0; j < claimIds.length; j++) {
                if (claimIds[j] == _claimId) {
                    return policies[i].policyholder;
                }
            }
        }
        return address(0);
    }


    function emergencyPause(uint256 _policyId) external onlyOwner validPolicy(_policyId) {
        policies[_policyId].status = 0;
    }

    receive() external payable {

    }
}
