
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


library InsuranceLibrary {
    struct Policy {
        uint256 policyId;
        address policyholder;
        uint256 premium;
        uint256 coverageAmount;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        bool hasClaimed;
    }

    struct Claim {
        uint256 claimId;
        uint256 policyId;
        address claimant;
        uint256 claimAmount;
        string description;
        uint256 timestamp;
        ClaimStatus status;
    }

    enum ClaimStatus { Pending, Approved, Rejected, Paid }

    function calculatePremium(uint256 coverageAmount, uint256 riskFactor) internal pure returns (uint256) {
        require(coverageAmount > 0, "Coverage amount must be positive");
        require(riskFactor > 0 && riskFactor <= 100, "Risk factor must be between 1-100");
        return (coverageAmount * riskFactor) / 1000;
    }

    function isPolicyValid(Policy memory policy) internal view returns (bool) {
        return policy.isActive &&
               block.timestamp >= policy.startTime &&
               block.timestamp <= policy.endTime &&
               !policy.hasClaimed;
    }
}


abstract contract BaseInsurance is Ownable, ReentrancyGuard, Pausable {
    using InsuranceLibrary for InsuranceLibrary.Policy;


    uint256 public constant MIN_COVERAGE_AMOUNT = 0.1 ether;
    uint256 public constant MAX_COVERAGE_AMOUNT = 100 ether;
    uint256 public constant MIN_POLICY_DURATION = 30 days;
    uint256 public constant MAX_POLICY_DURATION = 365 days;
    uint256 public constant CLAIM_REVIEW_PERIOD = 7 days;


    uint256 internal _nextPolicyId = 1;
    uint256 internal _nextClaimId = 1;
    uint256 public totalPremiumCollected;
    uint256 public totalClaimsPaid;

    mapping(uint256 => InsuranceLibrary.Policy) public policies;
    mapping(uint256 => InsuranceLibrary.Claim) public claims;
    mapping(address => uint256[]) public userPolicies;
    mapping(address => uint256[]) public userClaims;


    event PolicyPurchased(uint256 indexed policyId, address indexed policyholder, uint256 premium, uint256 coverageAmount);
    event ClaimSubmitted(uint256 indexed claimId, uint256 indexed policyId, address indexed claimant, uint256 amount);
    event ClaimProcessed(uint256 indexed claimId, InsuranceLibrary.ClaimStatus status, uint256 payoutAmount);
    event PremiumCollected(address indexed policyholder, uint256 amount);
    event FundsWithdrawn(address indexed owner, uint256 amount);


    modifier validPolicyId(uint256 policyId) {
        require(policyId > 0 && policyId < _nextPolicyId, "Invalid policy ID");
        _;
    }

    modifier validClaimId(uint256 claimId) {
        require(claimId > 0 && claimId < _nextClaimId, "Invalid claim ID");
        _;
    }

    modifier onlyPolicyholder(uint256 policyId) {
        require(policies[policyId].policyholder == msg.sender, "Not the policyholder");
        _;
    }

    modifier policyActive(uint256 policyId) {
        require(InsuranceLibrary.isPolicyValid(policies[policyId]), "Policy is not valid or active");
        _;
    }

    modifier sufficientBalance(uint256 amount) {
        require(address(this).balance >= amount, "Insufficient contract balance");
        _;
    }


    function _validateCoverageAmount(uint256 amount) internal pure {
        require(amount >= MIN_COVERAGE_AMOUNT && amount <= MAX_COVERAGE_AMOUNT,
                "Coverage amount out of valid range");
    }

    function _validatePolicyDuration(uint256 duration) internal pure {
        require(duration >= MIN_POLICY_DURATION && duration <= MAX_POLICY_DURATION,
                "Policy duration out of valid range");
    }

    function _createPolicy(address policyholder, uint256 premium, uint256 coverageAmount, uint256 duration)
        internal returns (uint256) {
        uint256 policyId = _nextPolicyId++;

        policies[policyId] = InsuranceLibrary.Policy({
            policyId: policyId,
            policyholder: policyholder,
            premium: premium,
            coverageAmount: coverageAmount,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            isActive: true,
            hasClaimed: false
        });

        userPolicies[policyholder].push(policyId);
        totalPremiumCollected += premium;

        emit PolicyPurchased(policyId, policyholder, premium, coverageAmount);
        emit PremiumCollected(policyholder, premium);

        return policyId;
    }

    function _processClaim(uint256 claimId, InsuranceLibrary.ClaimStatus status, uint256 payoutAmount)
        internal sufficientBalance(payoutAmount) {
        InsuranceLibrary.Claim storage claim = claims[claimId];
        claim.status = status;

        if (status == InsuranceLibrary.ClaimStatus.Approved && payoutAmount > 0) {
            policies[claim.policyId].hasClaimed = true;
            totalClaimsPaid += payoutAmount;

            payable(claim.claimant).transfer(payoutAmount);
        }

        emit ClaimProcessed(claimId, status, payoutAmount);
    }
}


contract ComprehensiveInsurance is BaseInsurance {

    uint256 public defaultRiskFactor = 50;
    mapping(address => uint256) public userRiskFactors;

    constructor() {
        _transferOwnership(msg.sender);
    }


    function purchasePolicy(uint256 coverageAmount, uint256 duration)
        external payable whenNotPaused nonReentrant returns (uint256) {
        _validateCoverageAmount(coverageAmount);
        _validatePolicyDuration(duration);

        uint256 riskFactor = userRiskFactors[msg.sender] > 0 ? userRiskFactors[msg.sender] : defaultRiskFactor;
        uint256 requiredPremium = InsuranceLibrary.calculatePremium(coverageAmount, riskFactor);

        require(msg.value >= requiredPremium, "Insufficient premium payment");

        uint256 policyId = _createPolicy(msg.sender, requiredPremium, coverageAmount, duration);


        if (msg.value > requiredPremium) {
            payable(msg.sender).transfer(msg.value - requiredPremium);
        }

        return policyId;
    }


    function submitClaim(uint256 policyId, uint256 claimAmount, string calldata description)
        external whenNotPaused validPolicyId(policyId) onlyPolicyholder(policyId) policyActive(policyId)
        returns (uint256) {
        require(claimAmount > 0 && claimAmount <= policies[policyId].coverageAmount, "Invalid claim amount");
        require(bytes(description).length > 0, "Claim description required");

        uint256 claimId = _nextClaimId++;

        claims[claimId] = InsuranceLibrary.Claim({
            claimId: claimId,
            policyId: policyId,
            claimant: msg.sender,
            claimAmount: claimAmount,
            description: description,
            timestamp: block.timestamp,
            status: InsuranceLibrary.ClaimStatus.Pending
        });

        userClaims[msg.sender].push(claimId);

        emit ClaimSubmitted(claimId, policyId, msg.sender, claimAmount);
        return claimId;
    }


    function processClaim(uint256 claimId, bool approve, uint256 payoutAmount)
        external onlyOwner validClaimId(claimId) {
        InsuranceLibrary.Claim storage claim = claims[claimId];
        require(claim.status == InsuranceLibrary.ClaimStatus.Pending, "Claim already processed");
        require(block.timestamp >= claim.timestamp + CLAIM_REVIEW_PERIOD, "Claim review period not elapsed");

        if (approve) {
            require(payoutAmount > 0 && payoutAmount <= claim.claimAmount, "Invalid payout amount");
            _processClaim(claimId, InsuranceLibrary.ClaimStatus.Approved, payoutAmount);
        } else {
            _processClaim(claimId, InsuranceLibrary.ClaimStatus.Rejected, 0);
        }
    }


    function setUserRiskFactor(address user, uint256 riskFactor) external onlyOwner {
        require(riskFactor > 0 && riskFactor <= 100, "Risk factor must be between 1-100");
        userRiskFactors[user] = riskFactor;
    }


    function setDefaultRiskFactor(uint256 riskFactor) external onlyOwner {
        require(riskFactor > 0 && riskFactor <= 100, "Risk factor must be between 1-100");
        defaultRiskFactor = riskFactor;
    }


    function withdrawFunds(uint256 amount) external onlyOwner sufficientBalance(amount) {
        payable(owner()).transfer(amount);
        emit FundsWithdrawn(owner(), amount);
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
    }


    function getPolicyDetails(uint256 policyId)
        external view validPolicyId(policyId)
        returns (InsuranceLibrary.Policy memory) {
        return policies[policyId];
    }


    function getClaimDetails(uint256 claimId)
        external view validClaimId(claimId)
        returns (InsuranceLibrary.Claim memory) {
        return claims[claimId];
    }


    function getUserPolicies(address user) external view returns (uint256[] memory) {
        return userPolicies[user];
    }


    function getUserClaims(address user) external view returns (uint256[] memory) {
        return userClaims[user];
    }


    function calculatePremiumForUser(uint256 coverageAmount, address user)
        external view returns (uint256) {
        uint256 riskFactor = userRiskFactors[user] > 0 ? userRiskFactors[user] : defaultRiskFactor;
        return InsuranceLibrary.calculatePremium(coverageAmount, riskFactor);
    }


    function getContractStats() external view returns (
        uint256 totalPolicies,
        uint256 totalClaims,
        uint256 contractBalance,
        uint256 premiumCollected,
        uint256 claimsPaid
    ) {
        return (
            _nextPolicyId - 1,
            _nextClaimId - 1,
            address(this).balance,
            totalPremiumCollected,
            totalClaimsPaid
        );
    }


    receive() external payable {}
}
