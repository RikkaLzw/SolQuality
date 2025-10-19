
pragma solidity ^0.8.0;

contract InsuranceContract {
    address public owner;
    uint256 public totalPremiums;
    uint256 public totalClaims;

    struct Policy {
        address policyholder;
        uint256 premium;
        uint256 coverageAmount;
        uint256 startTime;
        uint256 duration;
        bool isActive;
        bool hasClaimed;
    }

    struct Claim {
        uint256 policyId;
        uint256 amount;
        string description;
        bool isApproved;
        bool isPaid;
    }

    mapping(uint256 => Policy) public policies;
    mapping(uint256 => Claim) public claims;
    mapping(address => uint256[]) public userPolicies;

    uint256 public nextPolicyId = 1;
    uint256 public nextClaimId = 1;

    error Error();
    error Fail();
    error Invalid();


    event PolicyCreated(uint256 policyId, address policyholder, uint256 premium);
    event PremiumPaid(uint256 policyId, uint256 amount);
    event ClaimSubmitted(uint256 claimId, uint256 policyId, uint256 amount);
    event ClaimApproved(uint256 claimId);
    event ClaimPaid(uint256 claimId, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier validPolicy(uint256 _policyId) {
        require(_policyId > 0 && _policyId < nextPolicyId);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createPolicy(
        address _policyholder,
        uint256 _premium,
        uint256 _coverageAmount,
        uint256 _duration
    ) external onlyOwner {
        require(_policyholder != address(0));
        require(_premium > 0);
        require(_coverageAmount > 0);
        require(_duration > 0);

        uint256 policyId = nextPolicyId++;

        policies[policyId] = Policy({
            policyholder: _policyholder,
            premium: _premium,
            coverageAmount: _coverageAmount,
            startTime: block.timestamp,
            duration: _duration,
            isActive: false,
            hasClaimed: false
        });

        userPolicies[_policyholder].push(policyId);

        emit PolicyCreated(policyId, _policyholder, _premium);
    }

    function payPremium(uint256 _policyId) external payable validPolicy(_policyId) {
        Policy storage policy = policies[_policyId];
        require(msg.sender == policy.policyholder);
        require(msg.value == policy.premium);
        require(!policy.isActive);


        policy.isActive = true;
        totalPremiums += msg.value;

        emit PremiumPaid(_policyId, msg.value);
    }

    function submitClaim(
        uint256 _policyId,
        uint256 _amount,
        string calldata _description
    ) external validPolicy(_policyId) {
        Policy storage policy = policies[_policyId];
        require(msg.sender == policy.policyholder);
        require(policy.isActive);
        require(!policy.hasClaimed);
        require(_amount <= policy.coverageAmount);
        require(block.timestamp <= policy.startTime + policy.duration);

        uint256 claimId = nextClaimId++;

        claims[claimId] = Claim({
            policyId: _policyId,
            amount: _amount,
            description: _description,
            isApproved: false,
            isPaid: false
        });

        emit ClaimSubmitted(claimId, _policyId, _amount);
    }

    function approveClaim(uint256 _claimId) external onlyOwner {
        require(_claimId > 0 && _claimId < nextClaimId);

        Claim storage claim = claims[_claimId];
        require(!claim.isApproved);


        claim.isApproved = true;

        emit ClaimApproved(_claimId);
    }

    function payClaim(uint256 _claimId) external onlyOwner {
        require(_claimId > 0 && _claimId < nextClaimId);

        Claim storage claim = claims[_claimId];
        Policy storage policy = policies[claim.policyId];

        require(claim.isApproved);
        require(!claim.isPaid);
        require(address(this).balance >= claim.amount);


        claim.isPaid = true;
        policy.hasClaimed = true;
        totalClaims += claim.amount;

        payable(policy.policyholder).transfer(claim.amount);

        emit ClaimPaid(_claimId, claim.amount);
    }

    function cancelPolicy(uint256 _policyId) external validPolicy(_policyId) {
        Policy storage policy = policies[_policyId];
        require(msg.sender == policy.policyholder || msg.sender == owner);
        require(policy.isActive);
        require(!policy.hasClaimed);


        policy.isActive = false;
    }

    function extendPolicy(uint256 _policyId, uint256 _additionalDuration) external onlyOwner validPolicy(_policyId) {
        Policy storage policy = policies[_policyId];
        require(policy.isActive);
        require(_additionalDuration > 0);


        policy.duration += _additionalDuration;
    }

    function updateCoverageAmount(uint256 _policyId, uint256 _newAmount) external onlyOwner validPolicy(_policyId) {
        require(_newAmount > 0);

        Policy storage policy = policies[_policyId];
        require(policy.isActive);


        policy.coverageAmount = _newAmount;
    }

    function withdrawFunds(uint256 _amount) external onlyOwner {
        require(_amount <= address(this).balance);

        payable(owner).transfer(_amount);
    }

    function emergencyStop(uint256 _policyId) external onlyOwner validPolicy(_policyId) {
        Policy storage policy = policies[_policyId];

        if (!policy.isActive) {

            revert Invalid();
        }


        policy.isActive = false;
    }

    function validateClaim(uint256 _claimId) external view returns (bool) {
        if (_claimId == 0 || _claimId >= nextClaimId) {

            revert Fail();
        }

        return claims[_claimId].isApproved;
    }

    function getPolicyDetails(uint256 _policyId) external view validPolicy(_policyId) returns (
        address policyholder,
        uint256 premium,
        uint256 coverageAmount,
        uint256 startTime,
        uint256 duration,
        bool isActive,
        bool hasClaimed
    ) {
        Policy storage policy = policies[_policyId];
        return (
            policy.policyholder,
            policy.premium,
            policy.coverageAmount,
            policy.startTime,
            policy.duration,
            policy.isActive,
            policy.hasClaimed
        );
    }

    function getUserPolicies(address _user) external view returns (uint256[] memory) {
        return userPolicies[_user];
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {}
}
