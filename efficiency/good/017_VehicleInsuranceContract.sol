
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract VehicleInsuranceContract is ReentrancyGuard, Ownable, Pausable {
    struct Policy {
        address policyholder;
        uint256 premium;
        uint256 coverageAmount;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        uint8 riskLevel;
    }

    struct Claim {
        uint256 policyId;
        address claimant;
        uint256 claimAmount;
        string description;
        uint256 timestamp;
        ClaimStatus status;
        uint256 approvedAmount;
    }

    enum ClaimStatus { Pending, Approved, Rejected, Paid }


    uint256 private constant MAX_COVERAGE = 1000000 ether;
    uint256 private constant MIN_PREMIUM = 0.01 ether;
    uint256 private constant SECONDS_IN_YEAR = 365 days;


    mapping(uint256 => Policy) public policies;
    mapping(uint256 => Claim) public claims;
    mapping(address => uint256[]) private userPolicies;
    mapping(address => uint256[]) private userClaims;


    struct ContractState {
        uint128 totalPremiumCollected;
        uint128 totalClaimsPaid;
        uint64 nextPolicyId;
        uint64 nextClaimId;
    }

    ContractState private contractState;


    event PolicyCreated(uint256 indexed policyId, address indexed policyholder, uint256 premium, uint256 coverage);
    event ClaimSubmitted(uint256 indexed claimId, uint256 indexed policyId, address indexed claimant, uint256 amount);
    event ClaimProcessed(uint256 indexed claimId, ClaimStatus status, uint256 approvedAmount);
    event PremiumPaid(uint256 indexed policyId, address indexed policyholder, uint256 amount);

    constructor() {
        contractState.nextPolicyId = 1;
        contractState.nextClaimId = 1;
    }

    function createPolicy(
        uint256 _coverageAmount,
        uint8 _riskLevel,
        uint256 _durationInDays
    ) external payable whenNotPaused nonReentrant {
        require(_coverageAmount > 0 && _coverageAmount <= MAX_COVERAGE, "Invalid coverage amount");
        require(_riskLevel >= 1 && _riskLevel <= 5, "Risk level must be 1-5");
        require(_durationInDays >= 30 && _durationInDays <= 365, "Duration must be 30-365 days");


        uint256 premium = calculatePremium(_coverageAmount, _riskLevel, _durationInDays);
        require(msg.value >= premium, "Insufficient premium payment");

        uint256 policyId = contractState.nextPolicyId++;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + (_durationInDays * 1 days);


        Policy memory newPolicy = Policy({
            policyholder: msg.sender,
            premium: premium,
            coverageAmount: _coverageAmount,
            startTime: startTime,
            endTime: endTime,
            isActive: true,
            riskLevel: _riskLevel
        });

        policies[policyId] = newPolicy;
        userPolicies[msg.sender].push(policyId);


        contractState.totalPremiumCollected += uint128(premium);


        if (msg.value > premium) {
            payable(msg.sender).transfer(msg.value - premium);
        }

        emit PolicyCreated(policyId, msg.sender, premium, _coverageAmount);
        emit PremiumPaid(policyId, msg.sender, premium);
    }

    function submitClaim(
        uint256 _policyId,
        uint256 _claimAmount,
        string calldata _description
    ) external whenNotPaused nonReentrant {
        Policy storage policy = policies[_policyId];
        require(policy.policyholder == msg.sender, "Not policy owner");
        require(policy.isActive, "Policy not active");
        require(block.timestamp >= policy.startTime && block.timestamp <= policy.endTime, "Policy expired or not started");
        require(_claimAmount > 0 && _claimAmount <= policy.coverageAmount, "Invalid claim amount");

        uint256 claimId = contractState.nextClaimId++;


        Claim memory newClaim = Claim({
            policyId: _policyId,
            claimant: msg.sender,
            claimAmount: _claimAmount,
            description: _description,
            timestamp: block.timestamp,
            status: ClaimStatus.Pending,
            approvedAmount: 0
        });

        claims[claimId] = newClaim;
        userClaims[msg.sender].push(claimId);

        emit ClaimSubmitted(claimId, _policyId, msg.sender, _claimAmount);
    }

    function processClaim(
        uint256 _claimId,
        ClaimStatus _status,
        uint256 _approvedAmount
    ) external onlyOwner whenNotPaused {
        Claim storage claim = claims[_claimId];
        require(claim.status == ClaimStatus.Pending, "Claim already processed");
        require(_status != ClaimStatus.Pending, "Invalid status");

        if (_status == ClaimStatus.Approved) {
            require(_approvedAmount > 0 && _approvedAmount <= claim.claimAmount, "Invalid approved amount");
            claim.approvedAmount = _approvedAmount;
        }

        claim.status = _status;
        emit ClaimProcessed(_claimId, _status, _approvedAmount);
    }

    function payClaim(uint256 _claimId) external onlyOwner whenNotPaused nonReentrant {
        Claim storage claim = claims[_claimId];
        require(claim.status == ClaimStatus.Approved, "Claim not approved");
        require(claim.approvedAmount > 0, "No approved amount");
        require(address(this).balance >= claim.approvedAmount, "Insufficient contract balance");

        claim.status = ClaimStatus.Paid;
        contractState.totalClaimsPaid += uint128(claim.approvedAmount);

        payable(claim.claimant).transfer(claim.approvedAmount);
        emit ClaimProcessed(_claimId, ClaimStatus.Paid, claim.approvedAmount);
    }

    function calculatePremium(
        uint256 _coverageAmount,
        uint8 _riskLevel,
        uint256 _durationInDays
    ) public pure returns (uint256) {

        uint256 baseRate = (_coverageAmount * 2) / 100;


        uint256 riskMultiplier = 100 + ((_riskLevel - 1) * 25);


        uint256 durationFactor = (_durationInDays * 1e18) / 365;

        uint256 premium = (baseRate * riskMultiplier * durationFactor) / (100 * 1e18);

        return premium < MIN_PREMIUM ? MIN_PREMIUM : premium;
    }

    function getUserPolicies(address _user) external view returns (uint256[] memory) {
        return userPolicies[_user];
    }

    function getUserClaims(address _user) external view returns (uint256[] memory) {
        return userClaims[_user];
    }

    function getContractStats() external view returns (
        uint256 totalPremiumCollected,
        uint256 totalClaimsPaid,
        uint256 contractBalance,
        uint256 nextPolicyId,
        uint256 nextClaimId
    ) {
        ContractState memory state = contractState;
        return (
            state.totalPremiumCollected,
            state.totalClaimsPaid,
            address(this).balance,
            state.nextPolicyId,
            state.nextClaimId
        );
    }

    function isPolicyActive(uint256 _policyId) external view returns (bool) {
        Policy storage policy = policies[_policyId];
        return policy.isActive &&
               block.timestamp >= policy.startTime &&
               block.timestamp <= policy.endTime;
    }

    function withdrawFunds(uint256 _amount) external onlyOwner {
        require(_amount <= address(this).balance, "Insufficient balance");
        payable(owner()).transfer(_amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    receive() external payable {}
}
