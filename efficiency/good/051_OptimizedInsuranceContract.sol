
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract OptimizedInsuranceContract is ReentrancyGuard, Ownable, Pausable {

    struct Policy {
        uint128 premium;
        uint128 coverageAmount;
        uint64 startTime;
        uint64 endTime;
        uint64 lastPremiumPayment;
        uint32 policyType;
        bool isActive;
    }

    struct Claim {
        uint128 amount;
        uint64 timestamp;
        uint32 claimType;
        uint8 status;
    }


    mapping(address => Policy) public policies;
    mapping(address => Claim[]) public claims;
    mapping(address => uint256) public totalPaidClaims;
    mapping(uint32 => uint256) public policyTypeRates;


    uint128 public totalPremiumCollected;
    uint128 public totalClaimsPaid;
    uint32 public nextPolicyId;
    uint32 public claimProcessingFee;


    uint256 private constant SECONDS_PER_YEAR = 365 days;
    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant MAX_COVERAGE = 1000000 ether;


    event PolicyCreated(address indexed policyholder, uint32 policyType, uint256 premium, uint256 coverage);
    event PremiumPaid(address indexed policyholder, uint256 amount);
    event ClaimSubmitted(address indexed policyholder, uint256 claimId, uint256 amount);
    event ClaimProcessed(address indexed policyholder, uint256 claimId, uint256 amount, bool approved);


    modifier onlyPolicyholder() {
        require(policies[msg.sender].isActive, "No active policy");
        _;
    }

    modifier validPolicyType(uint32 _policyType) {
        require(policyTypeRates[_policyType] > 0, "Invalid policy type");
        _;
    }

    constructor() {

        policyTypeRates[1] = 500;
        policyTypeRates[2] = 300;
        policyTypeRates[3] = 200;
        policyTypeRates[4] = 800;

        claimProcessingFee = 100;
    }

    function createPolicy(
        uint32 _policyType,
        uint128 _coverageAmount,
        uint64 _duration
    ) external payable nonReentrant whenNotPaused validPolicyType(_policyType) {
        require(_coverageAmount > 0 && _coverageAmount <= MAX_COVERAGE, "Invalid coverage amount");
        require(_duration >= 30 days && _duration <= 5 * SECONDS_PER_YEAR, "Invalid duration");
        require(!policies[msg.sender].isActive, "Policy already exists");


        uint256 rate = policyTypeRates[_policyType];
        uint128 annualPremium = uint128((_coverageAmount * rate) / BASIS_POINTS);
        uint128 totalPremium = uint128((annualPremium * _duration) / SECONDS_PER_YEAR);

        require(msg.value >= totalPremium, "Insufficient premium payment");


        Policy memory newPolicy = Policy({
            premium: totalPremium,
            coverageAmount: _coverageAmount,
            startTime: uint64(block.timestamp),
            endTime: uint64(block.timestamp + _duration),
            lastPremiumPayment: uint64(block.timestamp),
            policyType: _policyType,
            isActive: true
        });

        policies[msg.sender] = newPolicy;


        totalPremiumCollected += totalPremium;


        if (msg.value > totalPremium) {
            payable(msg.sender).transfer(msg.value - totalPremium);
        }

        emit PolicyCreated(msg.sender, _policyType, totalPremium, _coverageAmount);
    }

    function payPremium() external payable onlyPolicyholder nonReentrant {
        Policy storage policy = policies[msg.sender];


        uint64 currentTime = uint64(block.timestamp);
        uint64 endTime = policy.endTime;
        uint128 premium = policy.premium;

        require(currentTime < endTime, "Policy expired");

        uint256 timeRemaining = endTime - currentTime;
        uint256 totalDuration = endTime - policy.startTime;
        uint128 requiredPremium = uint128((premium * timeRemaining) / totalDuration);

        require(msg.value >= requiredPremium, "Insufficient premium payment");


        policy.lastPremiumPayment = currentTime;
        totalPremiumCollected += requiredPremium;


        if (msg.value > requiredPremium) {
            payable(msg.sender).transfer(msg.value - requiredPremium);
        }

        emit PremiumPaid(msg.sender, requiredPremium);
    }

    function submitClaim(
        uint128 _amount,
        uint32 _claimType
    ) external onlyPolicyholder nonReentrant returns (uint256 claimId) {
        Policy storage policy = policies[msg.sender];


        uint64 currentTime = uint64(block.timestamp);
        uint128 coverageAmount = policy.coverageAmount;

        require(currentTime >= policy.startTime && currentTime <= policy.endTime, "Policy not active");
        require(_amount > 0 && _amount <= coverageAmount, "Invalid claim amount");
        require(currentTime - policy.lastPremiumPayment <= 90 days, "Premium payment overdue");


        Claim memory newClaim = Claim({
            amount: _amount,
            timestamp: currentTime,
            claimType: _claimType,
            status: 0
        });

        claims[msg.sender].push(newClaim);
        claimId = claims[msg.sender].length - 1;

        emit ClaimSubmitted(msg.sender, claimId, _amount);
    }

    function processClaim(
        address _policyholder,
        uint256 _claimId,
        bool _approve
    ) external onlyOwner nonReentrant {
        require(_claimId < claims[_policyholder].length, "Invalid claim ID");

        Claim storage claim = claims[_policyholder][_claimId];
        require(claim.status == 0, "Claim already processed");

        if (_approve) {

            uint128 claimAmount = claim.amount;
            uint256 processingFee = (claimAmount * claimProcessingFee) / BASIS_POINTS;
            uint256 payoutAmount = claimAmount - processingFee;

            require(address(this).balance >= payoutAmount, "Insufficient contract balance");

            claim.status = 1;
            totalClaimsPaid += claimAmount;
            totalPaidClaims[_policyholder] += claimAmount;

            payable(_policyholder).transfer(payoutAmount);
        } else {
            claim.status = 2;
        }

        emit ClaimProcessed(_policyholder, _claimId, claim.amount, _approve);
    }

    function renewPolicy(uint64 _additionalDuration) external payable onlyPolicyholder nonReentrant {
        require(_additionalDuration >= 30 days && _additionalDuration <= SECONDS_PER_YEAR, "Invalid duration");

        Policy storage policy = policies[msg.sender];


        uint128 coverageAmount = policy.coverageAmount;
        uint32 policyType = policy.policyType;

        uint256 rate = policyTypeRates[policyType];
        uint128 annualPremium = uint128((coverageAmount * rate) / BASIS_POINTS);
        uint128 renewalPremium = uint128((annualPremium * _additionalDuration) / SECONDS_PER_YEAR);

        require(msg.value >= renewalPremium, "Insufficient renewal payment");


        policy.endTime += _additionalDuration;
        policy.lastPremiumPayment = uint64(block.timestamp);
        totalPremiumCollected += renewalPremium;


        if (msg.value > renewalPremium) {
            payable(msg.sender).transfer(msg.value - renewalPremium);
        }
    }

    function getPolicyDetails(address _policyholder) external view returns (Policy memory) {
        return policies[_policyholder];
    }

    function getClaimsCount(address _policyholder) external view returns (uint256) {
        return claims[_policyholder].length;
    }

    function getClaim(address _policyholder, uint256 _claimId) external view returns (Claim memory) {
        require(_claimId < claims[_policyholder].length, "Invalid claim ID");
        return claims[_policyholder][_claimId];
    }

    function isPolicyActive(address _policyholder) external view returns (bool) {
        Policy storage policy = policies[_policyholder];
        return policy.isActive && block.timestamp <= policy.endTime;
    }

    function calculatePremium(uint32 _policyType, uint128 _coverageAmount, uint64 _duration) external view returns (uint256) {
        require(policyTypeRates[_policyType] > 0, "Invalid policy type");
        uint256 rate = policyTypeRates[_policyType];
        uint256 annualPremium = (_coverageAmount * rate) / BASIS_POINTS;
        return (annualPremium * _duration) / SECONDS_PER_YEAR;
    }


    function updatePolicyTypeRate(uint32 _policyType, uint256 _rate) external onlyOwner {
        require(_rate > 0 && _rate <= 2000, "Invalid rate");
        policyTypeRates[_policyType] = _rate;
    }

    function updateClaimProcessingFee(uint32 _fee) external onlyOwner {
        require(_fee <= 1000, "Fee too high");
        claimProcessingFee = _fee;
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
