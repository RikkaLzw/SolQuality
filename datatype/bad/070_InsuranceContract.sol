
pragma solidity ^0.8.0;

contract InsuranceContract {
    address public owner;
    uint256 public totalPolicies;
    uint256 public contractStatus;

    struct Policy {
        string policyId;
        address policyholder;
        uint256 premium;
        uint256 coverageAmount;
        uint256 isActive;
        uint256 policyType;
        bytes additionalData;
        uint256 creationTime;
    }

    mapping(string => Policy) public policies;
    mapping(address => string[]) public userPolicies;

    event PolicyCreated(string policyId, address policyholder, uint256 premium);
    event ClaimSubmitted(string policyId, uint256 claimAmount);
    event ClaimPaid(string policyId, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyActivePolicyholder(string memory _policyId) {
        require(policies[_policyId].policyholder == msg.sender, "Not the policyholder");
        require(policies[_policyId].isActive == uint256(1), "Policy is not active");
        _;
    }

    constructor() {
        owner = msg.sender;
        contractStatus = uint256(1);
        totalPolicies = uint256(0);
    }

    function createPolicy(
        string memory _policyId,
        uint256 _premium,
        uint256 _coverageAmount,
        uint256 _policyType,
        bytes memory _additionalData
    ) external payable {
        require(msg.value >= _premium, "Insufficient premium payment");
        require(bytes(policies[_policyId].policyId).length == 0, "Policy already exists");
        require(_policyType >= uint256(1) && _policyType <= uint256(3), "Invalid policy type");
        require(contractStatus == uint256(1), "Contract is not active");

        policies[_policyId] = Policy({
            policyId: _policyId,
            policyholder: msg.sender,
            premium: _premium,
            coverageAmount: _coverageAmount,
            isActive: uint256(1),
            policyType: _policyType,
            additionalData: _additionalData,
            creationTime: block.timestamp
        });

        userPolicies[msg.sender].push(_policyId);
        totalPolicies = totalPolicies + uint256(1);

        emit PolicyCreated(_policyId, msg.sender, _premium);
    }

    function submitClaim(string memory _policyId, uint256 _claimAmount) external onlyActivePolicyholder(_policyId) {
        require(_claimAmount <= policies[_policyId].coverageAmount, "Claim exceeds coverage");
        require(_claimAmount > uint256(0), "Claim amount must be positive");

        emit ClaimSubmitted(_policyId, _claimAmount);
    }

    function processClaim(string memory _policyId, uint256 _approvedAmount, uint256 _approved) external onlyOwner {
        require(policies[_policyId].isActive == uint256(1), "Policy is not active");
        require(_approvedAmount <= policies[_policyId].coverageAmount, "Amount exceeds coverage");

        if (_approved == uint256(1)) {
            require(address(this).balance >= _approvedAmount, "Insufficient contract balance");
            payable(policies[_policyId].policyholder).transfer(_approvedAmount);
            emit ClaimPaid(_policyId, _approvedAmount);
        }
    }

    function deactivatePolicy(string memory _policyId) external onlyActivePolicyholder(_policyId) {
        policies[_policyId].isActive = uint256(0);
    }

    function updatePolicyData(string memory _policyId, bytes memory _newData) external onlyActivePolicyholder(_policyId) {
        policies[_policyId].additionalData = _newData;
    }

    function getPolicyInfo(string memory _policyId) external view returns (
        address policyholder,
        uint256 premium,
        uint256 coverageAmount,
        uint256 isActive,
        uint256 policyType,
        bytes memory additionalData
    ) {
        Policy memory policy = policies[_policyId];
        return (
            policy.policyholder,
            policy.premium,
            policy.coverageAmount,
            policy.isActive,
            policy.policyType,
            policy.additionalData
        );
    }

    function getUserPolicies(address _user) external view returns (string[] memory) {
        return userPolicies[_user];
    }

    function setContractStatus(uint256 _status) external onlyOwner {
        require(_status == uint256(0) || _status == uint256(1), "Invalid status");
        contractStatus = _status;
    }

    function withdrawFunds(uint256 _amount) external onlyOwner {
        require(address(this).balance >= _amount, "Insufficient balance");
        payable(owner).transfer(_amount);
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {}
}
