
pragma solidity ^0.8.0;

contract InsuranceContract {
    struct Policy {
        uint256 policyId;
        address policyholder;
        uint256 premium;
        uint256 coverageAmount;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        string policyType;
    }

    struct Claim {
        uint256 claimId;
        uint256 policyId;
        address claimant;
        uint256 claimAmount;
        string description;
        bool isProcessed;
        bool isApproved;
        uint256 submissionTime;
    }

    mapping(uint256 => Policy) public policies;
    mapping(uint256 => Claim) public claims;
    mapping(address => uint256[]) public userPolicies;

    uint256 public policyCounter;
    uint256 public claimCounter;
    address public owner;
    uint256 public totalPremiums;
    uint256 public totalClaims;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
        policyCounter = 1;
        claimCounter = 1;
    }




    function createPolicyAndProcessPaymentAndUpdateStats(
        address _policyholder,
        uint256 _premium,
        uint256 _coverageAmount,
        uint256 _duration,
        string memory _policyType,
        bool _autoRenewal,
        uint256 _deductible
    ) public payable {
        require(msg.value >= _premium, "Insufficient payment");
        require(_coverageAmount > 0, "Coverage amount must be positive");
        require(_duration > 0, "Duration must be positive");


        uint256 newPolicyId = policyCounter;
        policies[newPolicyId] = Policy({
            policyId: newPolicyId,
            policyholder: _policyholder,
            premium: _premium,
            coverageAmount: _coverageAmount,
            startTime: block.timestamp,
            endTime: block.timestamp + _duration,
            isActive: true,
            policyType: _policyType
        });

        userPolicies[_policyholder].push(newPolicyId);
        policyCounter++;


        totalPremiums += _premium;
        if (msg.value > _premium) {
            payable(msg.sender).transfer(msg.value - _premium);
        }


        if (_autoRenewal) {

        }


        if (_deductible > 0) {

        }
    }


    function calculatePremiumRate(uint256 _age, string memory _riskLevel) public pure returns (uint256) {
        if (keccak256(bytes(_riskLevel)) == keccak256(bytes("low"))) {
            return _age < 30 ? 100 : 150;
        } else if (keccak256(bytes(_riskLevel)) == keccak256(bytes("medium"))) {
            return _age < 30 ? 200 : 250;
        } else {
            return _age < 30 ? 300 : 400;
        }
    }


    function processClaimWithComplexLogic(
        uint256 _policyId,
        uint256 _claimAmount,
        string memory _description
    ) public {
        require(policies[_policyId].isActive, "Policy is not active");
        require(policies[_policyId].policyholder == msg.sender, "Not the policyholder");

        if (block.timestamp <= policies[_policyId].endTime) {
            if (_claimAmount <= policies[_policyId].coverageAmount) {
                if (keccak256(bytes(policies[_policyId].policyType)) == keccak256(bytes("health"))) {
                    if (_claimAmount > 1000) {
                        if (keccak256(bytes(_description)) != keccak256(bytes(""))) {
                            if (address(this).balance >= _claimAmount) {
                                uint256 newClaimId = claimCounter;
                                claims[newClaimId] = Claim({
                                    claimId: newClaimId,
                                    policyId: _policyId,
                                    claimant: msg.sender,
                                    claimAmount: _claimAmount,
                                    description: _description,
                                    isProcessed: false,
                                    isApproved: false,
                                    submissionTime: block.timestamp
                                });
                                claimCounter++;


                                if (_claimAmount < 5000) {
                                    claims[newClaimId].isProcessed = true;
                                    claims[newClaimId].isApproved = true;
                                    totalClaims += _claimAmount;
                                    payable(msg.sender).transfer(_claimAmount);
                                } else {

                                    if (_claimAmount > 10000) {

                                        if (userPolicies[msg.sender].length > 1) {

                                        }
                                    }
                                }
                            }
                        }
                    }
                } else if (keccak256(bytes(policies[_policyId].policyType)) == keccak256(bytes("auto"))) {

                } else {

                }
            }
        }
    }


    function getPolicyInfo(uint256 _policyId) public view returns (uint256, address, uint256, bool, string memory) {
        Policy memory policy = policies[_policyId];
        return (policy.policyId, policy.policyholder, policy.premium, policy.isActive, policy.policyType);
    }

    function approveClaim(uint256 _claimId) public onlyOwner {
        require(!claims[_claimId].isProcessed, "Claim already processed");
        require(address(this).balance >= claims[_claimId].claimAmount, "Insufficient contract balance");

        claims[_claimId].isProcessed = true;
        claims[_claimId].isApproved = true;
        totalClaims += claims[_claimId].claimAmount;

        payable(claims[_claimId].claimant).transfer(claims[_claimId].claimAmount);
    }

    function rejectClaim(uint256 _claimId) public onlyOwner {
        require(!claims[_claimId].isProcessed, "Claim already processed");

        claims[_claimId].isProcessed = true;
        claims[_claimId].isApproved = false;
    }

    function withdrawFunds(uint256 _amount) public onlyOwner {
        require(address(this).balance >= _amount, "Insufficient balance");
        payable(owner).transfer(_amount);
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getUserPolicies(address _user) public view returns (uint256[] memory) {
        return userPolicies[_user];
    }

    receive() external payable {}
}
