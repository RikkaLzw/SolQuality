
pragma solidity ^0.8.0;

contract InsuranceContract {
    address public owner;
    uint256 public totalPremiums;
    uint256 public totalClaims;
    bool public contractActive;

    struct Policy {
        address policyholder;
        uint256 premium;
        uint256 coverageAmount;
        uint256 startTime;
        uint256 endTime;
        bool active;
        bool claimSubmitted;
        uint256 claimAmount;
    }

    mapping(uint256 => Policy) public policies;
    mapping(address => uint256[]) public userPolicies;
    uint256 public nextPolicyId;

    error Error1();
    error Error2();
    error Error3();

    event PolicyCreated(uint256 policyId, address policyholder, uint256 premium);
    event ClaimSubmitted(uint256 policyId, uint256 amount);
    event ClaimApproved(uint256 policyId, uint256 amount);
    event PremiumPaid(uint256 policyId, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyActivePolicyholder(uint256 _policyId) {
        require(policies[_policyId].policyholder == msg.sender);
        require(policies[_policyId].active);
        _;
    }

    constructor() {
        owner = msg.sender;
        contractActive = true;
        nextPolicyId = 1;
    }

    function createPolicy(uint256 _premium, uint256 _coverageAmount, uint256 _duration) external payable {
        require(msg.value == _premium);
        require(_premium > 0);
        require(_coverageAmount > 0);
        require(_duration > 0);
        require(contractActive);

        uint256 policyId = nextPolicyId;
        nextPolicyId++;

        policies[policyId] = Policy({
            policyholder: msg.sender,
            premium: _premium,
            coverageAmount: _coverageAmount,
            startTime: block.timestamp,
            endTime: block.timestamp + _duration,
            active: true,
            claimSubmitted: false,
            claimAmount: 0
        });

        userPolicies[msg.sender].push(policyId);
        totalPremiums += _premium;

        emit PolicyCreated(policyId, msg.sender, _premium);
    }

    function submitClaim(uint256 _policyId, uint256 _claimAmount) external onlyActivePolicyholder(_policyId) {
        require(!policies[_policyId].claimSubmitted);
        require(_claimAmount <= policies[_policyId].coverageAmount);
        require(block.timestamp <= policies[_policyId].endTime);

        policies[_policyId].claimSubmitted = true;
        policies[_policyId].claimAmount = _claimAmount;

        emit ClaimSubmitted(_policyId, _claimAmount);
    }

    function approveClaim(uint256 _policyId) external onlyOwner {
        require(policies[_policyId].claimSubmitted);
        require(policies[_policyId].active);
        require(address(this).balance >= policies[_policyId].claimAmount);

        uint256 claimAmount = policies[_policyId].claimAmount;
        address policyholder = policies[_policyId].policyholder;

        policies[_policyId].active = false;
        totalClaims += claimAmount;

        payable(policyholder).transfer(claimAmount);

        emit ClaimApproved(_policyId, claimAmount);
    }

    function renewPolicy(uint256 _policyId, uint256 _additionalDuration) external payable onlyActivePolicyholder(_policyId) {
        require(msg.value == policies[_policyId].premium);
        require(_additionalDuration > 0);

        policies[_policyId].endTime += _additionalDuration;
        totalPremiums += msg.value;

        emit PremiumPaid(_policyId, msg.value);
    }

    function cancelPolicy(uint256 _policyId) external onlyActivePolicyholder(_policyId) {
        require(!policies[_policyId].claimSubmitted);

        policies[_policyId].active = false;
    }

    function withdrawFunds(uint256 _amount) external onlyOwner {
        require(_amount <= address(this).balance);
        require(_amount > 0);

        payable(owner).transfer(_amount);
    }

    function updateContractStatus(bool _status) external onlyOwner {
        contractActive = _status;
    }

    function getPolicyDetails(uint256 _policyId) external view returns (
        address policyholder,
        uint256 premium,
        uint256 coverageAmount,
        uint256 startTime,
        uint256 endTime,
        bool active,
        bool claimSubmitted,
        uint256 claimAmount
    ) {
        Policy memory policy = policies[_policyId];
        return (
            policy.policyholder,
            policy.premium,
            policy.coverageAmount,
            policy.startTime,
            policy.endTime,
            policy.active,
            policy.claimSubmitted,
            policy.claimAmount
        );
    }

    function getUserPolicies(address _user) external view returns (uint256[] memory) {
        return userPolicies[_user];
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function emergencyStop() external onlyOwner {
        if (!contractActive) {
            revert Error1();
        }
        contractActive = false;
    }

    function validatePolicyExpiry(uint256 _policyId) external {
        if (block.timestamp > policies[_policyId].endTime && policies[_policyId].active) {
            policies[_policyId].active = false;
        }
    }
}
