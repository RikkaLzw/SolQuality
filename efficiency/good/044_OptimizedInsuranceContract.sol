
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract OptimizedInsuranceContract is ReentrancyGuard, Ownable, Pausable {
    struct Policy {
        uint128 premium;
        uint128 coverage;
        uint64 startTime;
        uint64 endTime;
        uint32 policyType;
        bool isActive;
    }

    struct Claim {
        uint128 amount;
        uint64 timestamp;
        uint32 status;
        uint32 policyId;
    }


    struct UserStats {
        uint64 totalPolicies;
        uint64 activePolicies;
        uint128 totalPremiumPaid;
    }


    uint256 private constant MAX_COVERAGE = 1000000 ether;
    uint256 private constant MIN_PREMIUM = 0.01 ether;
    uint256 private constant CLAIM_PERIOD = 30 days;

    uint32 public nextPolicyId = 1;
    uint32 public nextClaimId = 1;
    uint128 public totalReserves;
    uint128 public totalClaims;


    mapping(uint32 => Policy) public policies;
    mapping(uint32 => Claim) public claims;
    mapping(address => uint32[]) public userPolicies;
    mapping(address => uint32[]) public userClaims;
    mapping(address => UserStats) public userStats;
    mapping(uint32 => address) public policyOwners;
    mapping(uint32 => address) public claimants;


    event PolicyCreated(uint32 indexed policyId, address indexed user, uint128 premium, uint128 coverage);
    event ClaimSubmitted(uint32 indexed claimId, uint32 indexed policyId, address indexed claimant, uint128 amount);
    event ClaimProcessed(uint32 indexed claimId, uint32 status, uint128 payout);
    event PremiumCollected(address indexed user, uint128 amount);

    constructor() {}

    function createPolicy(
        uint128 _coverage,
        uint32 _policyType,
        uint64 _duration
    ) external payable whenNotPaused nonReentrant {
        require(_coverage >= MIN_PREMIUM && _coverage <= MAX_COVERAGE, "Invalid coverage");
        require(_duration >= 30 days && _duration <= 365 days, "Invalid duration");
        require(msg.value >= MIN_PREMIUM, "Insufficient premium");

        uint32 policyId = nextPolicyId++;
        uint64 startTime = uint64(block.timestamp);
        uint64 endTime = startTime + _duration;


        uint128 premium = uint128(msg.value);

        policies[policyId] = Policy({
            premium: premium,
            coverage: _coverage,
            startTime: startTime,
            endTime: endTime,
            policyType: _policyType,
            isActive: true
        });

        policyOwners[policyId] = msg.sender;
        userPolicies[msg.sender].push(policyId);


        UserStats storage stats = userStats[msg.sender];
        stats.totalPolicies++;
        stats.activePolicies++;
        stats.totalPremiumPaid += premium;

        totalReserves += premium;

        emit PolicyCreated(policyId, msg.sender, premium, _coverage);
        emit PremiumCollected(msg.sender, premium);
    }

    function submitClaim(uint32 _policyId, uint128 _amount) external whenNotPaused nonReentrant {
        require(policyOwners[_policyId] == msg.sender, "Not policy owner");

        Policy storage policy = policies[_policyId];
        require(policy.isActive, "Policy not active");
        require(block.timestamp <= policy.endTime, "Policy expired");
        require(block.timestamp >= policy.startTime, "Policy not started");
        require(_amount <= policy.coverage, "Amount exceeds coverage");

        uint32 claimId = nextClaimId++;

        claims[claimId] = Claim({
            amount: _amount,
            timestamp: uint64(block.timestamp),
            status: 0,
            policyId: _policyId
        });

        claimants[claimId] = msg.sender;
        userClaims[msg.sender].push(claimId);

        emit ClaimSubmitted(claimId, _policyId, msg.sender, _amount);
    }

    function processClaim(uint32 _claimId, uint32 _status) external onlyOwner nonReentrant {
        Claim storage claim = claims[_claimId];
        require(claim.status == 0, "Claim already processed");
        require(_status == 1 || _status == 2, "Invalid status");

        claim.status = _status;
        uint128 payout = 0;

        if (_status == 1) {
            address claimant = claimants[_claimId];
            uint128 claimAmount = claim.amount;

            require(address(this).balance >= claimAmount, "Insufficient reserves");

            payout = claimAmount;
            totalClaims += claimAmount;
            totalReserves -= claimAmount;

            (bool success, ) = payable(claimant).call{value: claimAmount}("");
            require(success, "Transfer failed");
        }

        emit ClaimProcessed(_claimId, _status, payout);
    }

    function getUserPolicies(address _user) external view returns (uint32[] memory) {
        return userPolicies[_user];
    }

    function getUserClaims(address _user) external view returns (uint32[] memory) {
        return userClaims[_user];
    }

    function getActivePoliciesCount(address _user) external view returns (uint64) {
        uint32[] memory policyIds = userPolicies[_user];
        uint64 activeCount = 0;


        uint256 length = policyIds.length;

        for (uint256 i = 0; i < length;) {
            Policy storage policy = policies[policyIds[i]];
            if (policy.isActive && block.timestamp <= policy.endTime) {
                activeCount++;
            }
            unchecked { ++i; }
        }

        return activeCount;
    }

    function isPolicyValid(uint32 _policyId) external view returns (bool) {
        Policy storage policy = policies[_policyId];
        return policy.isActive &&
               block.timestamp >= policy.startTime &&
               block.timestamp <= policy.endTime;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Transfer failed");
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    receive() external payable {
        totalReserves += uint128(msg.value);
    }
}
