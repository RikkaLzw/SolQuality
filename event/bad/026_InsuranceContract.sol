
pragma solidity ^0.8.0;

contract InsuranceContract {
    address public owner;
    uint256 public totalPremiumCollected;
    uint256 public totalClaimsPaid;

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
        uint256 submitTime;
    }

    mapping(uint256 => Policy) public policies;
    mapping(uint256 => Claim) public claims;
    mapping(address => uint256[]) public userPolicies;

    uint256 public nextPolicyId = 1;
    uint256 public nextClaimId = 1;

    error E1();
    error E2();
    error E3();

    event PolicyCreated(uint256 policyId, address policyholder, uint256 premium);
    event ClaimSubmitted(uint256 claimId, uint256 policyId, uint256 amount);
    event ClaimApproved(uint256 claimId);
    event ClaimPaid(uint256 claimId, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createPolicy(uint256 _coverageAmount, uint256 _duration) external payable {
        require(msg.value > 0);
        require(_coverageAmount > 0);
        require(_duration > 0);

        uint256 policyId = nextPolicyId++;

        policies[policyId] = Policy({
            policyholder: msg.sender,
            premium: msg.value,
            coverageAmount: _coverageAmount,
            startTime: block.timestamp,
            endTime: block.timestamp + _duration,
            isActive: true,
            hasClaimed: false
        });

        userPolicies[msg.sender].push(policyId);
        totalPremiumCollected += msg.value;

        emit PolicyCreated(policyId, msg.sender, msg.value);
    }

    function submitClaim(uint256 _policyId, uint256 _amount, string memory _description) external {
        Policy storage policy = policies[_policyId];

        require(policy.policyholder == msg.sender);
        require(policy.isActive);
        require(block.timestamp <= policy.endTime);
        require(!policy.hasClaimed);
        require(_amount <= policy.coverageAmount);

        uint256 claimId = nextClaimId++;

        claims[claimId] = Claim({
            policyId: _policyId,
            amount: _amount,
            description: _description,
            isApproved: false,
            isPaid: false,
            submitTime: block.timestamp
        });

        emit ClaimSubmitted(claimId, _policyId, _amount);
    }

    function approveClaim(uint256 _claimId) external onlyOwner {
        Claim storage claim = claims[_claimId];

        require(!claim.isApproved);
        require(!claim.isPaid);

        claim.isApproved = true;

        emit ClaimApproved(_claimId);
    }

    function payClaim(uint256 _claimId) external onlyOwner {
        Claim storage claim = claims[_claimId];
        Policy storage policy = policies[claim.policyId];

        require(claim.isApproved);
        require(!claim.isPaid);
        require(address(this).balance >= claim.amount);

        claim.isPaid = true;
        policy.hasClaimed = true;
        totalClaimsPaid += claim.amount;

        payable(policy.policyholder).transfer(claim.amount);

        emit ClaimPaid(_claimId, claim.amount);
    }

    function cancelPolicy(uint256 _policyId) external {
        Policy storage policy = policies[_policyId];

        require(policy.policyholder == msg.sender);
        require(policy.isActive);

        if (policy.hasClaimed) {
            revert E1();
        }

        policy.isActive = false;
    }

    function updatePremium(uint256 _policyId, uint256 _newPremium) external onlyOwner {
        Policy storage policy = policies[_policyId];

        require(policy.isActive);

        if (_newPremium == 0) {
            revert E2();
        }

        policy.premium = _newPremium;
    }

    function withdrawFunds(uint256 _amount) external onlyOwner {
        require(address(this).balance >= _amount);

        if (_amount > address(this).balance - totalClaimsPaid) {
            revert E3();
        }

        payable(owner).transfer(_amount);
    }

    function extendPolicy(uint256 _policyId, uint256 _additionalTime) external payable {
        Policy storage policy = policies[_policyId];

        require(policy.policyholder == msg.sender);
        require(policy.isActive);
        require(msg.value > 0);

        policy.endTime += _additionalTime;
        policy.premium += msg.value;
        totalPremiumCollected += msg.value;
    }

    function deactivateExpiredPolicies(uint256[] memory _policyIds) external onlyOwner {
        for (uint256 i = 0; i < _policyIds.length; i++) {
            Policy storage policy = policies[_policyIds[i]];

            require(block.timestamp > policy.endTime);

            policy.isActive = false;
        }
    }

    function getPolicyDetails(uint256 _policyId) external view returns (Policy memory) {
        return policies[_policyId];
    }

    function getClaimDetails(uint256 _claimId) external view returns (Claim memory) {
        return claims[_claimId];
    }

    function getUserPolicies(address _user) external view returns (uint256[] memory) {
        return userPolicies[_user];
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
