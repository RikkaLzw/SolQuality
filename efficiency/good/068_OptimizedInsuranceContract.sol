
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract OptimizedInsuranceContract is ReentrancyGuard, Ownable, Pausable {

    struct Policy {
        uint128 premiumAmount;
        uint128 coverageAmount;
        uint64 startTime;
        uint64 endTime;
        bool isActive;
        bool hasClaimed;
    }

    struct Claim {
        uint128 amount;
        uint64 timestamp;
        bool isApproved;
        bool isPaid;
    }


    mapping(address => Policy) public policies;
    mapping(address => Claim[]) public claims;
    mapping(address => uint256) public premiumBalances;


    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MIN_PREMIUM = 0.01 ether;
    uint256 public constant MAX_COVERAGE_RATIO = 50;


    event PolicyCreated(address indexed policyholder, uint256 premium, uint256 coverage);
    event PremiumPaid(address indexed policyholder, uint256 amount);
    event ClaimSubmitted(address indexed policyholder, uint256 amount, uint256 claimIndex);
    event ClaimApproved(address indexed policyholder, uint256 amount, uint256 claimIndex);
    event ClaimPaid(address indexed policyholder, uint256 amount, uint256 claimIndex);
    event PolicyExpired(address indexed policyholder);


    error InsufficientPremium();
    error PolicyNotActive();
    error PolicyExpired();
    error ExcessiveCoverage();
    error ClaimAlreadyExists();
    error InvalidClaim();
    error InsufficientFunds();

    constructor() {}

    function createPolicy(uint128 _coverageAmount, uint64 _durationInDays)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        if (msg.value < MIN_PREMIUM) revert InsufficientPremium();

        uint128 premium = uint128(msg.value);
        if (_coverageAmount > premium * MAX_COVERAGE_RATIO) revert ExcessiveCoverage();


        uint64 currentTime = uint64(block.timestamp);

        Policy storage policy = policies[msg.sender];
        policy.premiumAmount = premium;
        policy.coverageAmount = _coverageAmount;
        policy.startTime = currentTime;
        policy.endTime = currentTime + (_durationInDays * 1 days);
        policy.isActive = true;
        policy.hasClaimed = false;


        premiumBalances[msg.sender] += premium;

        emit PolicyCreated(msg.sender, premium, _coverageAmount);
    }

    function payAdditionalPremium()
        external
        payable
        whenNotPaused
        nonReentrant
    {
        Policy storage policy = policies[msg.sender];
        if (!policy.isActive) revert PolicyNotActive();
        if (block.timestamp > policy.endTime) revert PolicyExpired();

        premiumBalances[msg.sender] += msg.value;
        emit PremiumPaid(msg.sender, msg.value);
    }

    function submitClaim(uint128 _amount)
        external
        whenNotPaused
        nonReentrant
    {
        Policy storage policy = policies[msg.sender];
        if (!policy.isActive) revert PolicyNotActive();
        if (block.timestamp > policy.endTime) revert PolicyExpired();
        if (policy.hasClaimed) revert ClaimAlreadyExists();
        if (_amount > policy.coverageAmount) revert InvalidClaim();


        policy.hasClaimed = true;


        Claim memory newClaim = Claim({
            amount: _amount,
            timestamp: uint64(block.timestamp),
            isApproved: false,
            isPaid: false
        });

        claims[msg.sender].push(newClaim);
        uint256 claimIndex = claims[msg.sender].length - 1;

        emit ClaimSubmitted(msg.sender, _amount, claimIndex);
    }

    function approveClaim(address _policyholder, uint256 _claimIndex)
        external
        onlyOwner
        whenNotPaused
    {
        Claim[] storage userClaims = claims[_policyholder];
        if (_claimIndex >= userClaims.length) revert InvalidClaim();

        Claim storage claim = userClaims[_claimIndex];
        if (claim.isApproved) revert InvalidClaim();

        claim.isApproved = true;
        emit ClaimApproved(_policyholder, claim.amount, _claimIndex);
    }

    function payClaim(address _policyholder, uint256 _claimIndex)
        external
        onlyOwner
        whenNotPaused
        nonReentrant
    {
        Claim[] storage userClaims = claims[_policyholder];
        if (_claimIndex >= userClaims.length) revert InvalidClaim();

        Claim storage claim = userClaims[_claimIndex];
        if (!claim.isApproved || claim.isPaid) revert InvalidClaim();
        if (address(this).balance < claim.amount) revert InsufficientFunds();

        claim.isPaid = true;


        (bool success, ) = payable(_policyholder).call{value: claim.amount}("");
        require(success, "Transfer failed");

        emit ClaimPaid(_policyholder, claim.amount, _claimIndex);
    }

    function expirePolicy(address _policyholder)
        external
        onlyOwner
    {
        Policy storage policy = policies[_policyholder];
        if (block.timestamp <= policy.endTime) revert PolicyNotActive();

        policy.isActive = false;
        emit PolicyExpired(_policyholder);
    }


    function getPolicyInfo(address _policyholder)
        external
        view
        returns (
            uint128 premium,
            uint128 coverage,
            uint64 startTime,
            uint64 endTime,
            bool isActive,
            bool hasClaimed
        )
    {
        Policy storage policy = policies[_policyholder];
        return (
            policy.premiumAmount,
            policy.coverageAmount,
            policy.startTime,
            policy.endTime,
            policy.isActive,
            policy.hasClaimed
        );
    }

    function getClaimCount(address _policyholder)
        external
        view
        returns (uint256)
    {
        return claims[_policyholder].length;
    }

    function getClaim(address _policyholder, uint256 _index)
        external
        view
        returns (
            uint128 amount,
            uint64 timestamp,
            bool isApproved,
            bool isPaid
        )
    {
        if (_index >= claims[_policyholder].length) revert InvalidClaim();

        Claim storage claim = claims[_policyholder][_index];
        return (
            claim.amount,
            claim.timestamp,
            claim.isApproved,
            claim.isPaid
        );
    }

    function isPolicyActive(address _policyholder)
        external
        view
        returns (bool)
    {
        Policy storage policy = policies[_policyholder];
        return policy.isActive && block.timestamp <= policy.endTime;
    }


    function withdrawFunds(uint256 _amount)
        external
        onlyOwner
        nonReentrant
    {
        if (_amount > address(this).balance) revert InsufficientFunds();

        (bool success, ) = payable(owner()).call{value: _amount}("");
        require(success, "Withdrawal failed");
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


    function emergencyWithdraw()
        external
        onlyOwner
        whenPaused
        nonReentrant
    {
        (bool success, ) = payable(owner()).call{value: address(this).balance}("");
        require(success, "Emergency withdrawal failed");
    }
}
