
pragma solidity ^0.8.0;

contract InsuranceContract {
    address public owner;
    uint256 public premiumRate;
    uint256 public maxCoverage;

    struct Policy {
        address policyholder;
        uint256 premium;
        uint256 coverage;
        uint256 startTime;
        uint256 endTime;
        bool active;
        bool claimed;
    }

    struct Claim {
        uint256 policyId;
        uint256 amount;
        string description;
        bool approved;
        bool processed;
    }

    mapping(uint256 => Policy) public policies;
    mapping(uint256 => Claim) public claims;
    mapping(address => uint256[]) public userPolicies;

    uint256 public nextPolicyId;
    uint256 public nextClaimId;
    uint256 public totalFunds;


    event PolicyCreated(uint256 policyId, address policyholder, uint256 coverage);
    event PremiumPaid(uint256 policyId, uint256 amount);
    event ClaimSubmitted(uint256 claimId, uint256 policyId, uint256 amount);
    event ClaimProcessed(uint256 claimId, bool approved);
    event FundsDeposited(uint256 amount);


    error InvalidInput();
    error NotAuthorized();
    error InsufficientFunds();
    error PolicyExpired();
    error ClaimExists();

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier validPolicy(uint256 _policyId) {
        require(_policyId < nextPolicyId);
        require(policies[_policyId].active);
        _;
    }

    constructor(uint256 _premiumRate, uint256 _maxCoverage) {
        owner = msg.sender;
        premiumRate = _premiumRate;
        maxCoverage = _maxCoverage;
        nextPolicyId = 1;
        nextClaimId = 1;
    }

    function createPolicy(uint256 _coverage, uint256 _duration) external payable {
        require(_coverage > 0);
        require(_coverage <= maxCoverage);
        require(_duration > 0);

        uint256 premium = (_coverage * premiumRate) / 1000;
        require(msg.value >= premium);

        policies[nextPolicyId] = Policy({
            policyholder: msg.sender,
            premium: premium,
            coverage: _coverage,
            startTime: block.timestamp,
            endTime: block.timestamp + _duration,
            active: true,
            claimed: false
        });

        userPolicies[msg.sender].push(nextPolicyId);
        totalFunds += premium;


        nextPolicyId++;

        emit PolicyCreated(nextPolicyId - 1, msg.sender, _coverage);

        if (msg.value > premium) {
            payable(msg.sender).transfer(msg.value - premium);
        }
    }

    function payPremium(uint256 _policyId) external payable validPolicy(_policyId) {
        Policy storage policy = policies[_policyId];
        require(msg.sender == policy.policyholder);
        require(msg.value > 0);

        totalFunds += msg.value;
        emit PremiumPaid(_policyId, msg.value);
    }

    function submitClaim(uint256 _policyId, uint256 _amount, string memory _description) external validPolicy(_policyId) {
        Policy storage policy = policies[_policyId];
        require(msg.sender == policy.policyholder);
        require(block.timestamp <= policy.endTime);
        require(_amount <= policy.coverage);
        require(!policy.claimed);

        claims[nextClaimId] = Claim({
            policyId: _policyId,
            amount: _amount,
            description: _description,
            approved: false,
            processed: false
        });

        emit ClaimSubmitted(nextClaimId, _policyId, _amount);


        nextClaimId++;
    }

    function processClaim(uint256 _claimId, bool _approve) external onlyOwner {
        require(_claimId < nextClaimId);

        Claim storage claim = claims[_claimId];
        require(!claim.processed);

        Policy storage policy = policies[claim.policyId];

        if (_approve) {
            require(totalFunds >= claim.amount);

            totalFunds -= claim.amount;
            policy.claimed = true;

            payable(policy.policyholder).transfer(claim.amount);
        }

        claim.approved = _approve;
        claim.processed = true;

        emit ClaimProcessed(_claimId, _approve);
    }

    function cancelPolicy(uint256 _policyId) external validPolicy(_policyId) {
        Policy storage policy = policies[_policyId];
        require(msg.sender == policy.policyholder);
        require(!policy.claimed);


        policy.active = false;

        uint256 refund = policy.premium / 2;
        if (totalFunds >= refund) {
            totalFunds -= refund;
            payable(msg.sender).transfer(refund);
        }
    }

    function updatePremiumRate(uint256 _newRate) external onlyOwner {
        require(_newRate > 0);


        premiumRate = _newRate;
    }

    function updateMaxCoverage(uint256 _newMaxCoverage) external onlyOwner {
        require(_newMaxCoverage > 0);


        maxCoverage = _newMaxCoverage;
    }

    function depositFunds() external payable onlyOwner {
        require(msg.value > 0);

        totalFunds += msg.value;
        emit FundsDeposited(msg.value);
    }

    function withdrawFunds(uint256 _amount) external onlyOwner {
        require(_amount <= totalFunds);


        totalFunds -= _amount;

        payable(owner).transfer(_amount);
    }

    function getUserPolicies(address _user) external view returns (uint256[] memory) {
        return userPolicies[_user];
    }

    function getPolicyDetails(uint256 _policyId) external view returns (Policy memory) {
        return policies[_policyId];
    }

    function getClaimDetails(uint256 _claimId) external view returns (Claim memory) {
        return claims[_claimId];
    }

    function isPolicyActive(uint256 _policyId) external view returns (bool) {
        if (_policyId >= nextPolicyId) return false;
        Policy memory policy = policies[_policyId];
        return policy.active && block.timestamp <= policy.endTime;
    }
}
