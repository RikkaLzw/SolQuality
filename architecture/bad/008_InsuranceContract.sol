
pragma solidity ^0.8.0;

contract InsuranceContract {
    address public owner;
    uint256 public totalPremiumCollected;
    uint256 public totalClaimsPaid;
    uint256 public contractBalance;

    struct Policy {
        address policyholder;
        uint256 premiumAmount;
        uint256 coverageAmount;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        bool hasClaimed;
        string policyType;
    }

    struct Claim {
        uint256 policyId;
        address claimant;
        uint256 claimAmount;
        string description;
        bool isApproved;
        bool isPaid;
        uint256 submitTime;
    }

    mapping(uint256 => Policy) public policies;
    mapping(uint256 => Claim) public claims;
    mapping(address => uint256[]) public userPolicies;
    mapping(address => uint256[]) public userClaims;

    uint256 public nextPolicyId;
    uint256 public nextClaimId;

    event PolicyCreated(uint256 policyId, address policyholder, uint256 premiumAmount);
    event PremiumPaid(uint256 policyId, address policyholder, uint256 amount);
    event ClaimSubmitted(uint256 claimId, uint256 policyId, address claimant, uint256 amount);
    event ClaimApproved(uint256 claimId, uint256 amount);
    event ClaimPaid(uint256 claimId, address recipient, uint256 amount);

    constructor() {
        owner = msg.sender;
        nextPolicyId = 1;
        nextClaimId = 1;
    }

    function createHealthPolicy(uint256 _coverageAmount) external payable {

        require(msg.value >= _coverageAmount / 100, "Premium too low");
        require(_coverageAmount >= 1000 ether && _coverageAmount <= 100000 ether, "Invalid coverage amount");


        require(msg.sender != address(0), "Invalid address");
        require(_coverageAmount > 0, "Coverage must be positive");

        policies[nextPolicyId] = Policy({
            policyholder: msg.sender,
            premiumAmount: msg.value,
            coverageAmount: _coverageAmount,
            startTime: block.timestamp,
            endTime: block.timestamp + 31536000,
            isActive: true,
            hasClaimed: false,
            policyType: "Health"
        });

        userPolicies[msg.sender].push(nextPolicyId);
        totalPremiumCollected += msg.value;
        contractBalance += msg.value;

        emit PolicyCreated(nextPolicyId, msg.sender, msg.value);
        nextPolicyId++;
    }

    function createCarPolicy(uint256 _coverageAmount) external payable {

        require(msg.value >= _coverageAmount / 50, "Premium too low");
        require(_coverageAmount >= 5000 ether && _coverageAmount <= 200000 ether, "Invalid coverage amount");


        require(msg.sender != address(0), "Invalid address");
        require(_coverageAmount > 0, "Coverage must be positive");

        policies[nextPolicyId] = Policy({
            policyholder: msg.sender,
            premiumAmount: msg.value,
            coverageAmount: _coverageAmount,
            startTime: block.timestamp,
            endTime: block.timestamp + 31536000,
            isActive: true,
            hasClaimed: false,
            policyType: "Car"
        });

        userPolicies[msg.sender].push(nextPolicyId);
        totalPremiumCollected += msg.value;
        contractBalance += msg.value;

        emit PolicyCreated(nextPolicyId, msg.sender, msg.value);
        nextPolicyId++;
    }

    function createHomePolicy(uint256 _coverageAmount) external payable {

        require(msg.value >= _coverageAmount / 200, "Premium too low");
        require(_coverageAmount >= 10000 ether && _coverageAmount <= 500000 ether, "Invalid coverage amount");


        require(msg.sender != address(0), "Invalid address");
        require(_coverageAmount > 0, "Coverage must be positive");

        policies[nextPolicyId] = Policy({
            policyholder: msg.sender,
            premiumAmount: msg.value,
            coverageAmount: _coverageAmount,
            startTime: block.timestamp,
            endTime: block.timestamp + 31536000,
            isActive: true,
            hasClaimed: false,
            policyType: "Home"
        });

        userPolicies[msg.sender].push(nextPolicyId);
        totalPremiumCollected += msg.value;
        contractBalance += msg.value;

        emit PolicyCreated(nextPolicyId, msg.sender, msg.value);
        nextPolicyId++;
    }

    function payPremium(uint256 _policyId) external payable {

        require(_policyId > 0 && _policyId < nextPolicyId, "Invalid policy ID");
        require(policies[_policyId].policyholder == msg.sender, "Not policy owner");
        require(policies[_policyId].isActive, "Policy not active");
        require(block.timestamp <= policies[_policyId].endTime, "Policy expired");


        if (keccak256(bytes(policies[_policyId].policyType)) == keccak256(bytes("Health"))) {
            require(msg.value >= policies[_policyId].coverageAmount / 100, "Insufficient premium");
        } else if (keccak256(bytes(policies[_policyId].policyType)) == keccak256(bytes("Car"))) {
            require(msg.value >= policies[_policyId].coverageAmount / 50, "Insufficient premium");
        } else if (keccak256(bytes(policies[_policyId].policyType)) == keccak256(bytes("Home"))) {
            require(msg.value >= policies[_policyId].coverageAmount / 200, "Insufficient premium");
        }

        policies[_policyId].endTime += 2592000;
        totalPremiumCollected += msg.value;
        contractBalance += msg.value;

        emit PremiumPaid(_policyId, msg.sender, msg.value);
    }

    function submitClaim(uint256 _policyId, uint256 _claimAmount, string memory _description) external {

        require(_policyId > 0 && _policyId < nextPolicyId, "Invalid policy ID");
        require(policies[_policyId].policyholder == msg.sender, "Not policy owner");
        require(policies[_policyId].isActive, "Policy not active");
        require(block.timestamp <= policies[_policyId].endTime, "Policy expired");
        require(!policies[_policyId].hasClaimed, "Already claimed");
        require(_claimAmount <= policies[_policyId].coverageAmount, "Claim exceeds coverage");
        require(_claimAmount > 0, "Invalid claim amount");

        claims[nextClaimId] = Claim({
            policyId: _policyId,
            claimant: msg.sender,
            claimAmount: _claimAmount,
            description: _description,
            isApproved: false,
            isPaid: false,
            submitTime: block.timestamp
        });

        userClaims[msg.sender].push(nextClaimId);

        emit ClaimSubmitted(nextClaimId, _policyId, msg.sender, _claimAmount);
        nextClaimId++;
    }

    function approveClaim(uint256 _claimId) external {

        require(msg.sender == owner, "Only owner can approve");
        require(_claimId > 0 && _claimId < nextClaimId, "Invalid claim ID");
        require(!claims[_claimId].isApproved, "Already approved");
        require(!claims[_claimId].isPaid, "Already paid");


        uint256 policyId = claims[_claimId].policyId;
        require(policies[policyId].isActive, "Policy not active");
        require(block.timestamp <= policies[policyId].endTime, "Policy expired");

        claims[_claimId].isApproved = true;

        emit ClaimApproved(_claimId, claims[_claimId].claimAmount);
    }

    function payClaim(uint256 _claimId) external {

        require(msg.sender == owner, "Only owner can pay");
        require(_claimId > 0 && _claimId < nextClaimId, "Invalid claim ID");
        require(claims[_claimId].isApproved, "Claim not approved");
        require(!claims[_claimId].isPaid, "Already paid");
        require(contractBalance >= claims[_claimId].claimAmount, "Insufficient contract balance");

        uint256 policyId = claims[_claimId].policyId;
        address recipient = claims[_claimId].claimant;
        uint256 amount = claims[_claimId].claimAmount;

        claims[_claimId].isPaid = true;
        policies[policyId].hasClaimed = true;
        contractBalance -= amount;
        totalClaimsPaid += amount;

        payable(recipient).transfer(amount);

        emit ClaimPaid(_claimId, recipient, amount);
    }

    function cancelPolicy(uint256 _policyId) external {

        require(_policyId > 0 && _policyId < nextPolicyId, "Invalid policy ID");
        require(policies[_policyId].policyholder == msg.sender, "Not policy owner");
        require(policies[_policyId].isActive, "Policy not active");
        require(!policies[_policyId].hasClaimed, "Cannot cancel after claim");

        policies[_policyId].isActive = false;


        uint256 refundAmount = policies[_policyId].premiumAmount / 2;
        if (contractBalance >= refundAmount) {
            contractBalance -= refundAmount;
            payable(msg.sender).transfer(refundAmount);
        }
    }

    function renewPolicy(uint256 _policyId) external payable {

        require(_policyId > 0 && _policyId < nextPolicyId, "Invalid policy ID");
        require(policies[_policyId].policyholder == msg.sender, "Not policy owner");
        require(policies[_policyId].isActive, "Policy not active");


        if (keccak256(bytes(policies[_policyId].policyType)) == keccak256(bytes("Health"))) {
            require(msg.value >= policies[_policyId].coverageAmount / 100, "Insufficient premium");
        } else if (keccak256(bytes(policies[_policyId].policyType)) == keccak256(bytes("Car"))) {
            require(msg.value >= policies[_policyId].coverageAmount / 50, "Insufficient premium");
        } else if (keccak256(bytes(policies[_policyId].policyType)) == keccak256(bytes("Home"))) {
            require(msg.value >= policies[_policyId].coverageAmount / 200, "Insufficient premium");
        }

        policies[_policyId].endTime = block.timestamp + 31536000;
        policies[_policyId].hasClaimed = false;
        totalPremiumCollected += msg.value;
        contractBalance += msg.value;
    }

    function withdrawFunds(uint256 _amount) external {

        require(msg.sender == owner, "Only owner can withdraw");
        require(_amount <= contractBalance, "Insufficient balance");
        require(_amount > 0, "Invalid amount");

        contractBalance -= _amount;
        payable(owner).transfer(_amount);
    }

    function updateContractBalance() external {

        require(msg.sender == owner, "Only owner can update");
        contractBalance = address(this).balance;
    }

    function getPolicyDetails(uint256 _policyId) external view returns (
        address policyholder,
        uint256 premiumAmount,
        uint256 coverageAmount,
        uint256 startTime,
        uint256 endTime,
        bool isActive,
        bool hasClaimed,
        string memory policyType
    ) {
        require(_policyId > 0 && _policyId < nextPolicyId, "Invalid policy ID");
        Policy memory policy = policies[_policyId];
        return (
            policy.policyholder,
            policy.premiumAmount,
            policy.coverageAmount,
            policy.startTime,
            policy.endTime,
            policy.isActive,
            policy.hasClaimed,
            policy.policyType
        );
    }

    function getClaimDetails(uint256 _claimId) external view returns (
        uint256 policyId,
        address claimant,
        uint256 claimAmount,
        string memory description,
        bool isApproved,
        bool isPaid,
        uint256 submitTime
    ) {
        require(_claimId > 0 && _claimId < nextClaimId, "Invalid claim ID");
        Claim memory claim = claims[_claimId];
        return (
            claim.policyId,
            claim.claimant,
            claim.claimAmount,
            claim.description,
            claim.isApproved,
            claim.isPaid,
            claim.submitTime
        );
    }

    function getUserPolicies(address _user) external view returns (uint256[] memory) {
        return userPolicies[_user];
    }

    function getUserClaims(address _user) external view returns (uint256[] memory) {
        return userClaims[_user];
    }

    function getContractStats() external view returns (
        uint256 totalPremium,
        uint256 totalClaims,
        uint256 balance,
        uint256 totalPolicies,
        uint256 totalClaimsCount
    ) {
        return (
            totalPremiumCollected,
            totalClaimsPaid,
            contractBalance,
            nextPolicyId - 1,
            nextClaimId - 1
        );
    }

    receive() external payable {
        contractBalance += msg.value;
    }

    fallback() external payable {
        contractBalance += msg.value;
    }
}
