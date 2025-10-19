
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
        bool isActive;
        bool hasClaimed;
    }

    struct Claim {
        uint128 amount;
        uint64 timestamp;
        uint8 status;
    }

    mapping(address => Policy) public policies;
    mapping(address => Claim[]) public claims;
    mapping(address => uint256) public premiumBalance;

    uint256 public totalPremiumPool;
    uint256 public totalClaims;
    uint256 public maxCoveragePerPolicy;
    uint256 public minPremiumAmount;

    uint256 private constant SECONDS_IN_YEAR = 365 days;
    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant COVERAGE_RATIO = 2000;

    event PolicyPurchased(address indexed policyholder, uint256 premium, uint256 coverage, uint256 duration);
    event ClaimSubmitted(address indexed policyholder, uint256 claimId, uint256 amount);
    event ClaimProcessed(address indexed policyholder, uint256 claimId, bool approved, uint256 payout);
    event PremiumWithdrawn(address indexed owner, uint256 amount);

    error InsufficientPremium();
    error PolicyNotActive();
    error PolicyExpired();
    error ExcessiveCoverage();
    error ClaimAlreadyExists();
    error InvalidClaimAmount();
    error InsufficientPoolFunds();
    error ClaimNotFound();
    error ClaimAlreadyProcessed();

    constructor(uint256 _maxCoverage, uint256 _minPremium) {
        maxCoveragePerPolicy = _maxCoverage;
        minPremiumAmount = _minPremium;
    }

    function purchasePolicy(uint128 _premium, uint64 _durationInDays)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        if (msg.value < minPremiumAmount) revert InsufficientPremium();
        if (msg.value != _premium) revert InsufficientPremium();


        Policy storage policy = policies[msg.sender];
        if (policy.isActive && block.timestamp < policy.endTime) revert PolicyNotActive();

        uint128 coverageAmount = _premium * uint128(COVERAGE_RATIO) / uint128(BASIS_POINTS);
        if (coverageAmount > maxCoveragePerPolicy) revert ExcessiveCoverage();

        uint64 startTime = uint64(block.timestamp);
        uint64 endTime = startTime + (_durationInDays * 1 days);


        policy.premium = _premium;
        policy.coverageAmount = coverageAmount;
        policy.startTime = startTime;
        policy.endTime = endTime;
        policy.isActive = true;
        policy.hasClaimed = false;


        unchecked {
            totalPremiumPool += _premium;
            premiumBalance[msg.sender] += _premium;
        }

        emit PolicyPurchased(msg.sender, _premium, coverageAmount, _durationInDays);
    }

    function submitClaim(uint128 _claimAmount)
        external
        whenNotPaused
        nonReentrant
    {

        Policy memory policy = policies[msg.sender];

        if (!policy.isActive) revert PolicyNotActive();
        if (block.timestamp > policy.endTime) revert PolicyExpired();
        if (policy.hasClaimed) revert ClaimAlreadyExists();
        if (_claimAmount == 0 || _claimAmount > policy.coverageAmount) revert InvalidClaimAmount();

        claims[msg.sender].push(Claim({
            amount: _claimAmount,
            timestamp: uint64(block.timestamp),
            status: 0
        }));

        uint256 claimId = claims[msg.sender].length - 1;
        emit ClaimSubmitted(msg.sender, claimId, _claimAmount);
    }

    function processClaim(address _policyholder, uint256 _claimId, bool _approve)
        external
        onlyOwner
        nonReentrant
    {
        Claim[] storage userClaims = claims[_policyholder];
        if (_claimId >= userClaims.length) revert ClaimNotFound();

        Claim storage claim = userClaims[_claimId];
        if (claim.status != 0) revert ClaimAlreadyProcessed();

        claim.status = _approve ? 1 : 2;
        uint256 payout = 0;

        if (_approve) {
            if (address(this).balance < claim.amount) revert InsufficientPoolFunds();

            policies[_policyholder].hasClaimed = true;
            payout = claim.amount;

            unchecked {
                totalClaims += payout;
            }

            (bool success, ) = _policyholder.call{value: payout}("");
            require(success, "Transfer failed");
        }

        emit ClaimProcessed(_policyholder, _claimId, _approve, payout);
    }

    function getPolicyInfo(address _policyholder)
        external
        view
        returns (
            uint256 premium,
            uint256 coverage,
            uint256 startTime,
            uint256 endTime,
            bool isActive,
            bool hasClaimed
        )
    {
        Policy memory policy = policies[_policyholder];
        return (
            policy.premium,
            policy.coverageAmount,
            policy.startTime,
            policy.endTime,
            policy.isActive,
            policy.hasClaimed
        );
    }

    function getClaimCount(address _policyholder) external view returns (uint256) {
        return claims[_policyholder].length;
    }

    function getClaim(address _policyholder, uint256 _claimId)
        external
        view
        returns (uint256 amount, uint256 timestamp, uint8 status)
    {
        if (_claimId >= claims[_policyholder].length) revert ClaimNotFound();

        Claim memory claim = claims[_policyholder][_claimId];
        return (claim.amount, claim.timestamp, claim.status);
    }

    function withdrawPremiums(uint256 _amount)
        external
        onlyOwner
        nonReentrant
    {
        if (_amount > address(this).balance) revert InsufficientPoolFunds();

        (bool success, ) = owner().call{value: _amount}("");
        require(success, "Transfer failed");

        emit PremiumWithdrawn(owner(), _amount);
    }

    function updateMaxCoverage(uint256 _newMaxCoverage) external onlyOwner {
        maxCoveragePerPolicy = _newMaxCoverage;
    }

    function updateMinPremium(uint256 _newMinPremium) external onlyOwner {
        minPremiumAmount = _newMinPremium;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getPoolStats()
        external
        view
        returns (uint256 totalPool, uint256 totalClaimsAmount, uint256 availableBalance)
    {
        return (totalPremiumPool, totalClaims, address(this).balance);
    }

    receive() external payable {
        unchecked {
            totalPremiumPool += msg.value;
        }
    }
}
