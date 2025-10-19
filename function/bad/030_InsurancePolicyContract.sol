
pragma solidity ^0.8.0;

contract InsurancePolicyContract {
    struct Policy {
        uint256 id;
        address policyholder;
        uint256 premium;
        uint256 coverage;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        string policyType;
        uint256 claimCount;
    }

    struct Claim {
        uint256 id;
        uint256 policyId;
        address claimant;
        uint256 amount;
        string description;
        bool isApproved;
        bool isPaid;
        uint256 timestamp;
    }

    mapping(uint256 => Policy) public policies;
    mapping(uint256 => Claim) public claims;
    mapping(address => uint256[]) public userPolicies;

    uint256 public policyCounter;
    uint256 public claimCounter;
    address public owner;
    uint256 public totalPremiumCollected;
    uint256 public totalClaimsPaid;

    event PolicyCreated(uint256 indexed policyId, address indexed policyholder);
    event ClaimSubmitted(uint256 indexed claimId, uint256 indexed policyId);
    event ClaimPaid(uint256 indexed claimId, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
    }




    function createPolicyAndUpdateStats(
        address _policyholder,
        uint256 _premium,
        uint256 _coverage,
        uint256 _duration,
        string memory _policyType,
        bool _autoRenewal,
        uint256 _discountRate,
        string memory _notes
    ) public payable {
        require(msg.value >= _premium, "Insufficient premium payment");
        require(_coverage > 0, "Coverage must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");

        policyCounter++;
        uint256 newPolicyId = policyCounter;


        policies[newPolicyId] = Policy({
            id: newPolicyId,
            policyholder: _policyholder,
            premium: _premium,
            coverage: _coverage,
            startTime: block.timestamp,
            endTime: block.timestamp + _duration,
            isActive: true,
            policyType: _policyType,
            claimCount: 0
        });

        userPolicies[_policyholder].push(newPolicyId);


        totalPremiumCollected += _premium;


        if (_discountRate > 0) {
            uint256 discount = (_premium * _discountRate) / 100;
            if (discount > 0) {
                payable(_policyholder).transfer(discount);
            }
        }


        if (_autoRenewal) {

        }

        emit PolicyCreated(newPolicyId, _policyholder);
    }


    function calculatePremiumWithComplexLogic(
        uint256 _basePremium,
        uint256 _age,
        string memory _riskCategory,
        bool _hasHistory
    ) public pure returns (uint256) {
        uint256 premium = _basePremium;

        if (_age < 25) {
            premium = (premium * 120) / 100;
        } else if (_age > 60) {
            premium = (premium * 150) / 100;
        }

        if (keccak256(bytes(_riskCategory)) == keccak256(bytes("high"))) {
            premium = (premium * 200) / 100;
        }

        if (_hasHistory) {
            premium = (premium * 130) / 100;
        }

        return premium;
    }


    function processClaimWithComplexValidation(
        uint256 _policyId,
        uint256 _claimAmount,
        string memory _description
    ) public {
        require(_policyId > 0 && _policyId <= policyCounter, "Invalid policy ID");
        Policy storage policy = policies[_policyId];
        require(policy.isActive, "Policy is not active");
        require(msg.sender == policy.policyholder, "Only policyholder can submit claim");

        if (policy.endTime > block.timestamp) {
            if (_claimAmount <= policy.coverage) {
                if (policy.claimCount < 3) {
                    if (bytes(_description).length > 10) {
                        if (_claimAmount > 0) {
                            claimCounter++;
                            uint256 newClaimId = claimCounter;

                            claims[newClaimId] = Claim({
                                id: newClaimId,
                                policyId: _policyId,
                                claimant: msg.sender,
                                amount: _claimAmount,
                                description: _description,
                                isApproved: false,
                                isPaid: false,
                                timestamp: block.timestamp
                            });

                            policy.claimCount++;


                            if (_claimAmount < policy.coverage / 10) {
                                if (keccak256(bytes(policy.policyType)) == keccak256(bytes("basic"))) {
                                    claims[newClaimId].isApproved = true;
                                    if (address(this).balance >= _claimAmount) {
                                        claims[newClaimId].isPaid = true;
                                        payable(msg.sender).transfer(_claimAmount);
                                        totalClaimsPaid += _claimAmount;
                                        emit ClaimPaid(newClaimId, _claimAmount);
                                    }
                                } else {

                                }
                            }

                            emit ClaimSubmitted(newClaimId, _policyId);
                        } else {
                            revert("Claim amount must be greater than 0");
                        }
                    } else {
                        revert("Description too short");
                    }
                } else {
                    revert("Maximum claims reached for this policy");
                }
            } else {
                revert("Claim amount exceeds coverage");
            }
        } else {
            revert("Policy has expired");
        }
    }

    function approveClaim(uint256 _claimId) public onlyOwner {
        require(_claimId > 0 && _claimId <= claimCounter, "Invalid claim ID");
        Claim storage claim = claims[_claimId];
        require(!claim.isApproved, "Claim already approved");
        require(!claim.isPaid, "Claim already paid");

        claim.isApproved = true;
    }

    function payClaim(uint256 _claimId) public onlyOwner {
        require(_claimId > 0 && _claimId <= claimCounter, "Invalid claim ID");
        Claim storage claim = claims[_claimId];
        require(claim.isApproved, "Claim not approved");
        require(!claim.isPaid, "Claim already paid");
        require(address(this).balance >= claim.amount, "Insufficient contract balance");

        claim.isPaid = true;
        payable(claim.claimant).transfer(claim.amount);
        totalClaimsPaid += claim.amount;

        emit ClaimPaid(_claimId, claim.amount);
    }

    function renewPolicy(uint256 _policyId, uint256 _newDuration) public payable {
        require(_policyId > 0 && _policyId <= policyCounter, "Invalid policy ID");
        Policy storage policy = policies[_policyId];
        require(msg.sender == policy.policyholder, "Only policyholder can renew");
        require(msg.value >= policy.premium, "Insufficient premium for renewal");

        policy.endTime = block.timestamp + _newDuration;
        policy.isActive = true;
        totalPremiumCollected += policy.premium;
    }

    function getPolicyDetails(uint256 _policyId) public view returns (Policy memory) {
        require(_policyId > 0 && _policyId <= policyCounter, "Invalid policy ID");
        return policies[_policyId];
    }

    function getClaimDetails(uint256 _claimId) public view returns (Claim memory) {
        require(_claimId > 0 && _claimId <= claimCounter, "Invalid claim ID");
        return claims[_claimId];
    }

    function getUserPolicies(address _user) public view returns (uint256[] memory) {
        return userPolicies[_user];
    }

    function withdrawFunds(uint256 _amount) public onlyOwner {
        require(address(this).balance >= _amount, "Insufficient balance");
        payable(owner).transfer(_amount);
    }

    receive() external payable {}
}
