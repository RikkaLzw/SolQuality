
pragma solidity ^0.8.0;

contract VehicleInsuranceContract {
    struct Policy {
        uint256 policyId;
        address policyholder;
        uint256 premium;
        uint256 coverageAmount;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        bool claimProcessed;
    }

    struct Claim {
        uint256 claimId;
        uint256 policyId;
        address claimant;
        uint256 claimAmount;
        string description;
        bool isApproved;
        bool isPaid;
        uint256 timestamp;
    }

    address private owner;
    uint256 private nextPolicyId;
    uint256 private nextClaimId;
    uint256 private totalReserves;

    mapping(uint256 => Policy) public policies;
    mapping(address => uint256[]) public userPolicies;
    mapping(uint256 => Claim) public claims;
    mapping(uint256 => uint256[]) public policyClaims;

    event PolicyCreated(uint256 indexed policyId, address indexed policyholder, uint256 premium);
    event PremiumPaid(uint256 indexed policyId, address indexed policyholder, uint256 amount);
    event ClaimSubmitted(uint256 indexed claimId, uint256 indexed policyId, uint256 amount);
    event ClaimApproved(uint256 indexed claimId, uint256 amount);
    event ClaimPaid(uint256 indexed claimId, address indexed claimant, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier validPolicy(uint256 policyId) {
        require(policies[policyId].policyholder != address(0), "Policy does not exist");
        _;
    }

    modifier onlyPolicyholder(uint256 policyId) {
        require(policies[policyId].policyholder == msg.sender, "Only policyholder can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
        nextPolicyId = 1;
        nextClaimId = 1;
    }

    function createPolicy(uint256 coverageAmount, uint256 durationDays) external payable returns (uint256) {
        require(msg.value > 0, "Premium must be greater than 0");
        require(coverageAmount > 0, "Coverage amount must be greater than 0");
        require(durationDays > 0, "Duration must be greater than 0");

        uint256 policyId = nextPolicyId++;

        policies[policyId] = Policy({
            policyId: policyId,
            policyholder: msg.sender,
            premium: msg.value,
            coverageAmount: coverageAmount,
            startTime: block.timestamp,
            endTime: block.timestamp + (durationDays * 1 days),
            isActive: true,
            claimProcessed: false
        });

        userPolicies[msg.sender].push(policyId);
        totalReserves += msg.value;

        emit PolicyCreated(policyId, msg.sender, msg.value);
        return policyId;
    }

    function payPremium(uint256 policyId) external payable validPolicy(policyId) onlyPolicyholder(policyId) {
        require(msg.value > 0, "Premium must be greater than 0");
        require(policies[policyId].isActive, "Policy is not active");

        totalReserves += msg.value;
        emit PremiumPaid(policyId, msg.sender, msg.value);
    }

    function submitClaim(uint256 policyId, uint256 claimAmount, string memory description) external validPolicy(policyId) onlyPolicyholder(policyId) returns (uint256) {
        require(policies[policyId].isActive, "Policy is not active");
        require(block.timestamp <= policies[policyId].endTime, "Policy has expired");
        require(claimAmount > 0, "Claim amount must be greater than 0");
        require(claimAmount <= policies[policyId].coverageAmount, "Claim exceeds coverage amount");

        uint256 claimId = nextClaimId++;

        claims[claimId] = Claim({
            claimId: claimId,
            policyId: policyId,
            claimant: msg.sender,
            claimAmount: claimAmount,
            description: description,
            isApproved: false,
            isPaid: false,
            timestamp: block.timestamp
        });

        policyClaims[policyId].push(claimId);

        emit ClaimSubmitted(claimId, policyId, claimAmount);
        return claimId;
    }

    function approveClaim(uint256 claimId) external onlyOwner {
        require(claims[claimId].claimant != address(0), "Claim does not exist");
        require(!claims[claimId].isApproved, "Claim already approved");
        require(!claims[claimId].isPaid, "Claim already paid");

        claims[claimId].isApproved = true;
        emit ClaimApproved(claimId, claims[claimId].claimAmount);
    }

    function payClaim(uint256 claimId) external onlyOwner {
        require(claims[claimId].isApproved, "Claim not approved");
        require(!claims[claimId].isPaid, "Claim already paid");
        require(totalReserves >= claims[claimId].claimAmount, "Insufficient reserves");

        uint256 claimAmount = claims[claimId].claimAmount;
        address claimant = claims[claimId].claimant;

        claims[claimId].isPaid = true;
        policies[claims[claimId].policyId].claimProcessed = true;
        totalReserves -= claimAmount;

        payable(claimant).transfer(claimAmount);
        emit ClaimPaid(claimId, claimant, claimAmount);
    }

    function cancelPolicy(uint256 policyId) external validPolicy(policyId) onlyPolicyholder(policyId) {
        require(policies[policyId].isActive, "Policy is not active");
        require(!policies[policyId].claimProcessed, "Cannot cancel policy with processed claims");

        policies[policyId].isActive = false;
    }

    function getPolicyDetails(uint256 policyId) external view validPolicy(policyId) returns (Policy memory) {
        return policies[policyId];
    }

    function getClaimDetails(uint256 claimId) external view returns (Claim memory) {
        require(claims[claimId].claimant != address(0), "Claim does not exist");
        return claims[claimId];
    }

    function getUserPolicies(address user) external view returns (uint256[] memory) {
        return userPolicies[user];
    }

    function getPolicyClaims(uint256 policyId) external view returns (uint256[] memory) {
        return policyClaims[policyId];
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getTotalReserves() external view onlyOwner returns (uint256) {
        return totalReserves;
    }

    function withdrawReserves(uint256 amount) external onlyOwner {
        require(amount <= totalReserves, "Amount exceeds available reserves");
        require(amount <= address(this).balance, "Insufficient contract balance");

        totalReserves -= amount;
        payable(owner).transfer(amount);
    }

    function isValidPolicy(uint256 policyId) public view returns (bool) {
        return policies[policyId].isActive &&
               block.timestamp <= policies[policyId].endTime &&
               policies[policyId].policyholder != address(0);
    }
}
