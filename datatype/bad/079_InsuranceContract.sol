
pragma solidity ^0.8.0;

contract InsuranceContract {
    address public owner;
    uint256 public totalPolicies;
    uint256 public contractStatus;

    struct Policy {
        string policyId;
        address policyholder;
        uint256 premiumAmount;
        uint256 coverageAmount;
        uint256 policyType;
        uint256 isActive;
        uint256 startTime;
        uint256 endTime;
        bytes additionalData;
    }

    mapping(address => Policy) public policies;
    mapping(string => address) public policyIdToHolder;

    event PolicyCreated(address indexed policyholder, string policyId);
    event ClaimSubmitted(address indexed policyholder, uint256 amount);
    event ClaimPaid(address indexed policyholder, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyActivePolicyholder() {
        require(policies[msg.sender].isActive == uint256(1), "Policy not active");
        _;
    }

    constructor() {
        owner = msg.sender;
        contractStatus = uint256(1);
        totalPolicies = uint256(0);
    }

    function createPolicy(
        string memory _policyId,
        uint256 _premiumAmount,
        uint256 _coverageAmount,
        uint256 _policyType,
        uint256 _duration,
        bytes memory _additionalData
    ) external payable {
        require(contractStatus == uint256(1), "Contract not active");
        require(msg.value >= _premiumAmount, "Insufficient premium payment");
        require(policies[msg.sender].isActive == uint256(0), "Policy already exists");
        require(_policyType >= uint256(1) && _policyType <= uint256(3), "Invalid policy type");

        policies[msg.sender] = Policy({
            policyId: _policyId,
            policyholder: msg.sender,
            premiumAmount: _premiumAmount,
            coverageAmount: _coverageAmount,
            policyType: _policyType,
            isActive: uint256(1),
            startTime: block.timestamp,
            endTime: block.timestamp + _duration,
            additionalData: _additionalData
        });

        policyIdToHolder[_policyId] = msg.sender;
        totalPolicies = totalPolicies + uint256(1);

        emit PolicyCreated(msg.sender, _policyId);
    }

    function submitClaim(uint256 _claimAmount) external onlyActivePolicyholder {
        require(_claimAmount <= policies[msg.sender].coverageAmount, "Claim exceeds coverage");
        require(block.timestamp <= policies[msg.sender].endTime, "Policy expired");

        emit ClaimSubmitted(msg.sender, _claimAmount);
    }

    function approveClaim(address _policyholder, uint256 _claimAmount) external onlyOwner {
        require(policies[_policyholder].isActive == uint256(1), "Policy not active");
        require(_claimAmount <= policies[_policyholder].coverageAmount, "Claim exceeds coverage");
        require(address(this).balance >= _claimAmount, "Insufficient contract balance");

        payable(_policyholder).transfer(_claimAmount);
        policies[_policyholder].isActive = uint256(0);

        emit ClaimPaid(_policyholder, _claimAmount);
    }

    function renewPolicy(uint256 _newDuration) external payable onlyActivePolicyholder {
        require(msg.value >= policies[msg.sender].premiumAmount, "Insufficient premium payment");

        policies[msg.sender].endTime = block.timestamp + _newDuration;
    }

    function cancelPolicy() external onlyActivePolicyholder {
        policies[msg.sender].isActive = uint256(0);
    }

    function updateContractStatus(uint256 _status) external onlyOwner {
        contractStatus = _status;
    }

    function withdrawFunds(uint256 _amount) external onlyOwner {
        require(address(this).balance >= _amount, "Insufficient balance");
        payable(owner).transfer(_amount);
    }

    function getPolicyDetails(address _policyholder) external view returns (
        string memory policyId,
        uint256 premiumAmount,
        uint256 coverageAmount,
        uint256 policyType,
        uint256 isActive,
        uint256 startTime,
        uint256 endTime,
        bytes memory additionalData
    ) {
        Policy memory policy = policies[_policyholder];
        return (
            policy.policyId,
            policy.premiumAmount,
            policy.coverageAmount,
            policy.policyType,
            policy.isActive,
            policy.startTime,
            policy.endTime,
            policy.additionalData
        );
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {}
}
