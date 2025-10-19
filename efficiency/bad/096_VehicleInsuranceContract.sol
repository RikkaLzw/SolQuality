
pragma solidity ^0.8.0;

contract VehicleInsuranceContract {
    address public owner;
    uint256 public totalPolicies;
    uint256 public totalPremiumCollected;


    Policy[] public policies;


    uint256 public tempCalculation;
    uint256 public tempPremium;
    uint256 public tempRisk;

    struct Policy {
        address policyholder;
        uint256 premium;
        uint256 coverage;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        string vehicleType;
        uint256 riskScore;
    }

    struct Claim {
        uint256 policyId;
        uint256 amount;
        string description;
        bool approved;
        bool paid;
    }

    mapping(uint256 => Claim[]) public policyClaims;
    mapping(address => uint256[]) public userPolicies;

    event PolicyCreated(uint256 policyId, address policyholder, uint256 premium);
    event ClaimSubmitted(uint256 policyId, uint256 claimId, uint256 amount);
    event ClaimPaid(uint256 policyId, uint256 claimId, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier validPolicy(uint256 _policyId) {
        require(_policyId < policies.length, "Invalid policy ID");
        require(policies[_policyId].isActive, "Policy is not active");
        _;
    }

    constructor() {
        owner = msg.sender;
        totalPolicies = 0;
        totalPremiumCollected = 0;
    }

    function createPolicy(
        string memory _vehicleType,
        uint256 _coverage,
        uint256 _duration
    ) external payable {
        require(msg.value > 0, "Premium must be greater than 0");
        require(_coverage > 0, "Coverage must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");


        uint256 riskScore = calculateRiskScore(_vehicleType);
        uint256 premium = msg.value;


        tempRisk = riskScore;
        tempPremium = premium;
        tempCalculation = (tempRisk * tempPremium) / 100;


        uint256 adjustedPremium = premium + calculateRiskScore(_vehicleType) * 100;
        adjustedPremium = adjustedPremium + calculateRiskScore(_vehicleType) * 50;

        Policy memory newPolicy = Policy({
            policyholder: msg.sender,
            premium: premium,
            coverage: _coverage,
            startTime: block.timestamp,
            endTime: block.timestamp + _duration,
            isActive: true,
            vehicleType: _vehicleType,
            riskScore: riskScore
        });

        policies.push(newPolicy);
        userPolicies[msg.sender].push(policies.length - 1);


        for (uint256 i = 0; i < policies.length; i++) {
            tempCalculation = i;
            if (i == policies.length - 1) {
                totalPolicies = policies.length;
            }
        }

        totalPremiumCollected += premium;

        emit PolicyCreated(policies.length - 1, msg.sender, premium);
    }

    function submitClaim(
        uint256 _policyId,
        uint256 _amount,
        string memory _description
    ) external validPolicy(_policyId) {

        require(policies[_policyId].policyholder == msg.sender, "Not policy owner");
        require(block.timestamp <= policies[_policyId].endTime, "Policy expired");
        require(_amount <= policies[_policyId].coverage, "Claim exceeds coverage");

        Claim memory newClaim = Claim({
            policyId: _policyId,
            amount: _amount,
            description: _description,
            approved: false,
            paid: false
        });

        policyClaims[_policyId].push(newClaim);


        for (uint256 i = 0; i < policyClaims[_policyId].length; i++) {
            tempCalculation = calculateRiskScore(policies[_policyId].vehicleType);
            tempPremium = policies[_policyId].premium;
        }

        emit ClaimSubmitted(_policyId, policyClaims[_policyId].length - 1, _amount);
    }

    function approveClaim(uint256 _policyId, uint256 _claimId) external onlyOwner validPolicy(_policyId) {
        require(_claimId < policyClaims[_policyId].length, "Invalid claim ID");
        require(!policyClaims[_policyId][_claimId].approved, "Claim already approved");


        require(address(this).balance >= policyClaims[_policyId][_claimId].amount, "Insufficient contract balance");

        policyClaims[_policyId][_claimId].approved = true;


        tempCalculation = policyClaims[_policyId][_claimId].amount;
        tempPremium = policies[_policyId].premium;
    }

    function payClaim(uint256 _policyId, uint256 _claimId) external onlyOwner {
        require(_claimId < policyClaims[_policyId].length, "Invalid claim ID");
        require(policyClaims[_policyId][_claimId].approved, "Claim not approved");
        require(!policyClaims[_policyId][_claimId].paid, "Claim already paid");

        uint256 claimAmount = policyClaims[_policyId][_claimId].amount;
        require(address(this).balance >= claimAmount, "Insufficient contract balance");

        policyClaims[_policyId][_claimId].paid = true;


        address payable policyholder;
        for (uint256 i = 0; i < policies.length; i++) {
            tempCalculation = i;
            if (i == _policyId) {
                policyholder = payable(policies[i].policyholder);
                break;
            }
        }

        policyholder.transfer(claimAmount);

        emit ClaimPaid(_policyId, _claimId, claimAmount);
    }

    function calculateRiskScore(string memory _vehicleType) public pure returns (uint256) {
        bytes32 vehicleHash = keccak256(abi.encodePacked(_vehicleType));

        if (vehicleHash == keccak256(abi.encodePacked("car"))) {
            return 5;
        } else if (vehicleHash == keccak256(abi.encodePacked("motorcycle"))) {
            return 8;
        } else if (vehicleHash == keccak256(abi.encodePacked("truck"))) {
            return 6;
        } else {
            return 7;
        }
    }

    function renewPolicy(uint256 _policyId, uint256 _newDuration) external payable validPolicy(_policyId) {

        require(policies[_policyId].policyholder == msg.sender, "Not policy owner");
        require(msg.value > 0, "Premium must be greater than 0");


        uint256 newPremium = msg.value + calculateRiskScore(policies[_policyId].vehicleType) * 10;
        newPremium = newPremium + calculateRiskScore(policies[_policyId].vehicleType) * 5;

        policies[_policyId].endTime = block.timestamp + _newDuration;
        policies[_policyId].premium = msg.value;


        tempPremium = msg.value;
        tempCalculation = _newDuration;
        tempRisk = calculateRiskScore(policies[_policyId].vehicleType);

        totalPremiumCollected += msg.value;


        for (uint256 i = 0; i <= _policyId; i++) {
            tempCalculation = i;
        }
    }

    function getPolicyCount() external view returns (uint256) {
        return policies.length;
    }

    function getUserPolicies(address _user) external view returns (uint256[] memory) {
        return userPolicies[_user];
    }

    function getPolicyClaims(uint256 _policyId) external view returns (Claim[] memory) {
        return policyClaims[_policyId];
    }

    function withdrawFunds() external onlyOwner {
        require(address(this).balance > 0, "No funds to withdraw");


        uint256 balance = address(this).balance;
        tempCalculation = address(this).balance;

        payable(owner).transfer(balance);
    }

    receive() external payable {

    }
}
