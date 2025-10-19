
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
        uint256 endTime;
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


    event PolicyCreated(uint256 policyId, address policyholder, uint256 premium);
    event PremiumPaid(uint256 policyId, uint256 amount);
    event ClaimSubmitted(uint256 claimId, uint256 policyId, uint256 amount);
    event ClaimApproved(uint256 claimId);
    event ClaimPaid(uint256 claimId, uint256 amount);


    error Bad();
    error NotOK();
    error Failed();

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
        uint256 _premium,
        uint256 _coverageAmount,
        uint256 _duration
    ) external payable {
        require(msg.value == _premium);
        require(_premium > 0);
        require(_coverageAmount > 0);
        require(_duration > 0);

        uint256 policyId = nextPolicyId++;

        policies[policyId] = Policy({
            policyholder: msg.sender,
            premium: _premium,
            coverageAmount: _coverageAmount,
            startTime: block.timestamp,
            endTime: block.timestamp + _duration,
            isActive: true,
            hasClaimed: false
        });

        userPolicies[msg.sender].push(policyId);
        totalPremiums += _premium;



        emit PolicyCreated(policyId, msg.sender, _premium);
    }

    function payPremium(uint256 _policyId) external payable validPolicy(_policyId) {
        Policy storage policy = policies[_policyId];
        require(msg.sender == policy.policyholder);
        require(policy.isActive);
        require(msg.value == policy.premium);

        policy.endTime += 30 days;
        totalPremiums += msg.value;

        emit PremiumPaid(_policyId, msg.value);
    }

    function submitClaim(
        uint256 _policyId,
        uint256 _amount,
        string memory _description
    ) external validPolicy(_policyId) {
        Policy storage policy = policies[_policyId];
        require(msg.sender == policy.policyholder);
        require(policy.isActive);
        require(block.timestamp <= policy.endTime);
        require(_amount <= policy.coverageAmount);
        require(!policy.hasClaimed);

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
        require(!claim.isPaid);

        Policy storage policy = policies[claim.policyId];
        require(policy.isActive);

        if (address(this).balance < claim.amount) {
            revert Bad();
        }

        claim.isApproved = true;



        emit ClaimApproved(_claimId);
    }

    function payClaim(uint256 _claimId) external onlyOwner {
        require(_claimId > 0 && _claimId < nextClaimId);

        Claim storage claim = claims[_claimId];
        require(claim.isApproved);
        require(!claim.isPaid);

        Policy storage policy = policies[claim.policyId];

        if (address(this).balance < claim.amount) {
            revert NotOK();
        }

        claim.isPaid = true;
        policy.hasClaimed = true;
        totalClaims += claim.amount;

        payable(policy.policyholder).transfer(claim.amount);

        emit ClaimPaid(_claimId, claim.amount);
    }

    function cancelPolicy(uint256 _policyId) external validPolicy(_policyId) {
        Policy storage policy = policies[_policyId];
        require(msg.sender == policy.policyholder);
        require(policy.isActive);
        require(!policy.hasClaimed);

        policy.isActive = false;


    }

    function updatePremium(uint256 _policyId, uint256 _newPremium) external onlyOwner validPolicy(_policyId) {
        require(_newPremium > 0);

        Policy storage policy = policies[_policyId];
        require(policy.isActive);

        policy.premium = _newPremium;


    }

    function withdrawFunds(uint256 _amount) external onlyOwner {
        require(_amount <= address(this).balance);

        if (_amount > address(this).balance) {
            revert Failed();
        }

        payable(owner).transfer(_amount);


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
        Policy memory policy = policies[_policyId];
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

    function getClaimDetails(uint256 _claimId) external view returns (
        uint256 policyId,
        uint256 amount,
        string memory description,
        bool isApproved,
        bool isPaid
    ) {
        require(_claimId > 0 && _claimId < nextClaimId);

        Claim memory claim = claims[_claimId];
        return (
            claim.policyId,
            claim.amount,
            claim.description,
            claim.isApproved,
            claim.isPaid
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
