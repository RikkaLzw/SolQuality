
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract OptimizedInsuranceContract is ReentrancyGuard, Ownable, Pausable {

    struct Policy {
        uint128 premium;
        uint64 coverageAmount;
        uint32 startTime;
        uint32 endTime;
        bool isActive;
        uint8 riskLevel;
    }

    struct Claim {
        uint128 amount;
        uint64 timestamp;
        uint32 policyId;
        uint8 status;
        bool processed;
    }


    mapping(address => uint32[]) private userPolicies;
    mapping(uint32 => Policy) private policies;
    mapping(uint32 => Claim) private claims;
    mapping(address => uint256) private balances;

    uint32 private nextPolicyId = 1;
    uint32 private nextClaimId = 1;
    uint256 private totalPremiumPool;
    uint256 private constant MAX_COVERAGE = 1000000 ether;
    uint256 private constant MIN_PREMIUM = 0.01 ether;


    event PolicyCreated(address indexed user, uint32 indexed policyId, uint256 premium, uint256 coverage);
    event ClaimSubmitted(address indexed user, uint32 indexed claimId, uint32 indexed policyId, uint256 amount);
    event ClaimProcessed(uint32 indexed claimId, bool approved, uint256 amount);
    event PremiumPaid(address indexed user, uint32 indexed policyId, uint256 amount);

    modifier validPolicy(uint32 _policyId) {
        require(_policyId > 0 && _policyId < nextPolicyId, "Invalid policy ID");
        _;
    }

    modifier validClaim(uint32 _claimId) {
        require(_claimId > 0 && _claimId < nextClaimId, "Invalid claim ID");
        _;
    }

    constructor() {}

    function createPolicy(
        uint256 _coverageAmount,
        uint32 _duration,
        uint8 _riskLevel
    ) external payable whenNotPaused nonReentrant {
        require(msg.value >= MIN_PREMIUM, "Premium too low");
        require(_coverageAmount <= MAX_COVERAGE, "Coverage too high");
        require(_duration > 0 && _duration <= 365 days, "Invalid duration");
        require(_riskLevel >= 1 && _riskLevel <= 10, "Invalid risk level");

        uint32 currentPolicyId = nextPolicyId++;
        uint32 currentTime = uint32(block.timestamp);


        uint128 premium = uint128(msg.value);
        uint64 coverage = uint64(_coverageAmount);

        policies[currentPolicyId] = Policy({
            premium: premium,
            coverageAmount: coverage,
            startTime: currentTime,
            endTime: currentTime + _duration,
            isActive: true,
            riskLevel: _riskLevel
        });

        userPolicies[msg.sender].push(currentPolicyId);


        totalPremiumPool += msg.value;

        emit PolicyCreated(msg.sender, currentPolicyId, msg.value, _coverageAmount);
    }

    function submitClaim(
        uint32 _policyId,
        uint256 _claimAmount
    ) external whenNotPaused nonReentrant validPolicy(_policyId) {
        Policy memory policy = policies[_policyId];

        require(policy.isActive, "Policy not active");
        require(block.timestamp >= policy.startTime && block.timestamp <= policy.endTime, "Policy expired");
        require(_claimAmount > 0 && _claimAmount <= policy.coverageAmount, "Invalid claim amount");
        require(_isPolicyOwner(msg.sender, _policyId), "Not policy owner");

        uint32 currentClaimId = nextClaimId++;

        claims[currentClaimId] = Claim({
            amount: uint128(_claimAmount),
            timestamp: uint64(block.timestamp),
            policyId: _policyId,
            status: 0,
            processed: false
        });

        emit ClaimSubmitted(msg.sender, currentClaimId, _policyId, _claimAmount);
    }

    function processClaim(
        uint32 _claimId,
        bool _approve
    ) external onlyOwner validClaim(_claimId) {
        Claim storage claim = claims[_claimId];
        require(!claim.processed, "Claim already processed");

        claim.processed = true;

        if (_approve) {
            claim.status = 1;
            uint256 claimAmount = claim.amount;

            require(address(this).balance >= claimAmount, "Insufficient funds");

            address policyOwner = _getPolicyOwner(claim.policyId);
            balances[policyOwner] += claimAmount;

            emit ClaimProcessed(_claimId, true, claimAmount);
        } else {
            claim.status = 2;
            emit ClaimProcessed(_claimId, false, 0);
        }
    }

    function withdrawBalance() external nonReentrant {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance to withdraw");

        balances[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdrawal failed");
    }

    function renewPolicy(uint32 _policyId) external payable whenNotPaused nonReentrant validPolicy(_policyId) {
        require(_isPolicyOwner(msg.sender, _policyId), "Not policy owner");

        Policy storage policy = policies[_policyId];
        require(msg.value >= policy.premium, "Insufficient premium");
        require(block.timestamp <= policy.endTime + 30 days, "Renewal period expired");


        uint32 extensionPeriod = uint32((policy.endTime - policy.startTime));
        policy.endTime += extensionPeriod;
        policy.isActive = true;

        totalPremiumPool += msg.value;

        emit PremiumPaid(msg.sender, _policyId, msg.value);
    }


    function getUserPolicies(address _user) external view returns (uint32[] memory) {
        return userPolicies[_user];
    }

    function getPolicy(uint32 _policyId) external view validPolicy(_policyId) returns (Policy memory) {
        return policies[_policyId];
    }

    function getClaim(uint32 _claimId) external view validClaim(_claimId) returns (Claim memory) {
        return claims[_claimId];
    }

    function getBalance(address _user) external view returns (uint256) {
        return balances[_user];
    }

    function getTotalPremiumPool() external view returns (uint256) {
        return totalPremiumPool;
    }


    function _isPolicyOwner(address _user, uint32 _policyId) internal view returns (bool) {
        uint32[] memory userPolicyIds = userPolicies[_user];
        uint256 length = userPolicyIds.length;

        for (uint256 i = 0; i < length;) {
            if (userPolicyIds[i] == _policyId) {
                return true;
            }
            unchecked { ++i; }
        }
        return false;
    }

    function _getPolicyOwner(uint32 _policyId) internal view returns (address) {


        revert("Function requires optimization for production use");
    }


    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function emergencyWithdraw() external onlyOwner {
        require(paused(), "Contract must be paused");
        uint256 balance = address(this).balance;
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Emergency withdrawal failed");
    }

    receive() external payable {
        totalPremiumPool += msg.value;
    }
}
