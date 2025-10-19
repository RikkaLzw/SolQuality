
pragma solidity ^0.8.0;

contract OptimizedInsuranceContract {

    struct Policy {
        address policyholder;
        uint128 premium;
        uint128 coverageAmount;
        uint32 startTime;
        uint32 duration;
        uint8 status;
    }

    struct Claim {
        uint128 amount;
        uint32 timestamp;
        uint8 status;
    }


    address public immutable owner;
    bool private _paused;


    mapping(uint256 => Policy) public policies;
    mapping(address => uint256[]) private _holderPolicies;
    mapping(uint256 => Claim[]) public policyClaims;

    uint256 private _policyCounter;
    uint256 public totalPremiumCollected;
    uint256 public totalPayouts;


    uint256 private constant SECONDS_PER_DAY = 86400;
    uint256 private constant MAX_COVERAGE = 1000000 ether;
    uint256 private constant MIN_PREMIUM = 0.01 ether;


    event PolicyCreated(uint256 indexed policyId, address indexed holder, uint128 premium, uint128 coverage);
    event PremiumPaid(uint256 indexed policyId, uint128 amount);
    event ClaimSubmitted(uint256 indexed policyId, uint256 claimIndex, uint128 amount);
    event ClaimProcessed(uint256 indexed policyId, uint256 claimIndex, bool approved, uint128 payout);
    event PolicyExpired(uint256 indexed policyId);


    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier whenNotPaused() {
        require(!_paused, "Contract paused");
        _;
    }

    modifier validPolicy(uint256 _policyId) {
        require(_policyId > 0 && _policyId <= _policyCounter, "Invalid policy");
        _;
    }

    modifier onlyPolicyholder(uint256 _policyId) {
        require(policies[_policyId].policyholder == msg.sender, "Not policyholder");
        _;
    }

    constructor() {
        owner = msg.sender;
    }


    function createPolicy(
        uint128 _coverageAmount,
        uint32 _durationDays
    ) external payable whenNotPaused {
        require(_coverageAmount <= MAX_COVERAGE, "Coverage too high");
        require(_durationDays >= 30 && _durationDays <= 365, "Invalid duration");
        require(msg.value >= MIN_PREMIUM, "Premium too low");


        uint128 premium = uint128(msg.value);
        uint32 startTime = uint32(block.timestamp);
        uint32 duration = _durationDays * uint32(SECONDS_PER_DAY);


        uint256 policyId = ++_policyCounter;


        Policy memory newPolicy = Policy({
            policyholder: msg.sender,
            premium: premium,
            coverageAmount: _coverageAmount,
            startTime: startTime,
            duration: duration,
            status: 1
        });

        policies[policyId] = newPolicy;
        _holderPolicies[msg.sender].push(policyId);


        totalPremiumCollected += premium;

        emit PolicyCreated(policyId, msg.sender, premium, _coverageAmount);
    }


    function payPremium(uint256 _policyId)
        external
        payable
        whenNotPaused
        validPolicy(_policyId)
        onlyPolicyholder(_policyId)
    {
        Policy storage policy = policies[_policyId];
        require(policy.status == 1, "Policy not active");
        require(msg.value >= MIN_PREMIUM, "Premium too low");


        uint32 currentTime = uint32(block.timestamp);
        uint32 policyEnd = policy.startTime + policy.duration;

        require(currentTime < policyEnd, "Policy expired");

        uint128 additionalPremium = uint128(msg.value);
        policy.premium += additionalPremium;
        totalPremiumCollected += additionalPremium;

        emit PremiumPaid(_policyId, additionalPremium);
    }


    function submitClaim(uint256 _policyId, uint128 _claimAmount)
        external
        whenNotPaused
        validPolicy(_policyId)
        onlyPolicyholder(_policyId)
    {
        Policy storage policy = policies[_policyId];
        require(policy.status == 1, "Policy not active");
        require(_claimAmount > 0 && _claimAmount <= policy.coverageAmount, "Invalid claim amount");


        uint32 currentTime = uint32(block.timestamp);
        uint32 policyEnd = policy.startTime + policy.duration;

        require(currentTime >= policy.startTime && currentTime < policyEnd, "Policy not valid");


        Claim memory newClaim = Claim({
            amount: _claimAmount,
            timestamp: currentTime,
            status: 0
        });

        policyClaims[_policyId].push(newClaim);
        uint256 claimIndex = policyClaims[_policyId].length - 1;

        emit ClaimSubmitted(_policyId, claimIndex, _claimAmount);
    }


    function processClaim(uint256 _policyId, uint256 _claimIndex, bool _approve)
        external
        onlyOwner
        validPolicy(_policyId)
    {
        require(_claimIndex < policyClaims[_policyId].length, "Invalid claim");

        Claim storage claim = policyClaims[_policyId][_claimIndex];
        Policy storage policy = policies[_policyId];

        require(claim.status == 0, "Claim already processed");

        uint128 payout = 0;

        if (_approve) {
            require(address(this).balance >= claim.amount, "Insufficient contract balance");

            claim.status = 1;
            policy.status = 2;
            payout = claim.amount;
            totalPayouts += payout;


            payable(policy.policyholder).transfer(payout);
        } else {
            claim.status = 2;
        }

        emit ClaimProcessed(_policyId, _claimIndex, _approve, payout);
    }


    function updatePolicyStatus(uint256 _policyId) external validPolicy(_policyId) {
        Policy storage policy = policies[_policyId];

        if (policy.status == 1) {
            uint32 currentTime = uint32(block.timestamp);
            uint32 policyEnd = policy.startTime + policy.duration;

            if (currentTime >= policyEnd) {
                policy.status = 3;
                emit PolicyExpired(_policyId);
            }
        }
    }


    function getHolderPolicies(address _holder) external view returns (uint256[] memory) {
        return _holderPolicies[_holder];
    }


    function getPolicyDetails(uint256 _policyId)
        external
        view
        validPolicy(_policyId)
        returns (
            address holder,
            uint128 premium,
            uint128 coverage,
            uint32 startTime,
            uint32 endTime,
            uint8 status,
            bool isActive
        )
    {
        Policy storage policy = policies[_policyId];


        holder = policy.policyholder;
        premium = policy.premium;
        coverage = policy.coverageAmount;
        startTime = policy.startTime;
        endTime = policy.startTime + policy.duration;
        status = policy.status;


        uint32 currentTime = uint32(block.timestamp);
        isActive = (status == 1) && (currentTime >= startTime) && (currentTime < endTime);
    }


    function getClaimCount(uint256 _policyId) external view validPolicy(_policyId) returns (uint256) {
        return policyClaims[_policyId].length;
    }


    function pause() external onlyOwner {
        _paused = true;
    }

    function unpause() external onlyOwner {
        _paused = false;
    }


    function withdrawExcess(uint256 _amount) external onlyOwner {
        require(_amount <= address(this).balance, "Insufficient balance");
        payable(owner).transfer(_amount);
    }


    function getContractStats()
        external
        view
        returns (
            uint256 totalPolicies,
            uint256 premiumCollected,
            uint256 payouts,
            uint256 contractBalance,
            bool paused
        )
    {
        return (
            _policyCounter,
            totalPremiumCollected,
            totalPayouts,
            address(this).balance,
            _paused
        );
    }


    receive() external payable {
        totalPremiumCollected += msg.value;
    }
}
