
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
        uint256 claimCount;
    }

    struct Claim {
        uint256 claimId;
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

    address public owner;
    uint256 public nextPolicyId;
    uint256 public nextClaimId;
    uint256 public totalFunds;

    event PolicyCreated(uint256 policyId, address policyholder);
    event ClaimSubmitted(uint256 claimId, uint256 policyId);
    event ClaimProcessed(uint256 claimId, bool approved);

    constructor() {
        owner = msg.sender;
        nextPolicyId = 1;
        nextClaimId = 1;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }




    function createPolicyAndUpdateUserDataAndCalculateRisk(
        address _policyholder,
        uint256 _premium,
        uint256 _coverageAmount,
        uint256 _duration,
        string memory _riskCategory,
        uint256 _age,
        bool _hasHistory
    ) public payable {
        require(msg.value >= _premium, "Insufficient premium payment");
        require(_coverageAmount > 0, "Coverage amount must be positive");


        Policy memory newPolicy = Policy({
            policyId: nextPolicyId,
            policyholder: _policyholder,
            premium: _premium,
            coverageAmount: _coverageAmount,
            startTime: block.timestamp,
            endTime: block.timestamp + _duration,
            isActive: true,
            claimCount: 0
        });

        policies[nextPolicyId] = newPolicy;
        userPolicies[_policyholder].push(nextPolicyId);


        totalFunds += msg.value;


        uint256 riskScore = 0;
        if (_age > 65) {
            riskScore += 30;
        } else if (_age > 45) {
            riskScore += 20;
        } else {
            riskScore += 10;
        }

        if (_hasHistory) {
            riskScore += 25;
        }

        if (keccak256(abi.encodePacked(_riskCategory)) == keccak256(abi.encodePacked("high"))) {
            riskScore += 40;
        } else if (keccak256(abi.encodePacked(_riskCategory)) == keccak256(abi.encodePacked("medium"))) {
            riskScore += 20;
        }


        emit PolicyCreated(nextPolicyId, _policyholder);
        nextPolicyId++;
    }


    function calculatePremiumAdjustment(uint256 _baseAmount, uint256 _riskFactor) public pure returns (uint256) {
        return _baseAmount * _riskFactor / 100;
    }



    function processClaimWithComplexLogic(uint256 _policyId, uint256 _claimAmount, string memory _description) public returns (bool) {
        require(policies[_policyId].isActive, "Policy is not active");
        require(policies[_policyId].policyholder == msg.sender, "Not policy holder");

        if (block.timestamp <= policies[_policyId].endTime) {
            if (_claimAmount <= policies[_policyId].coverageAmount) {
                if (policies[_policyId].claimCount < 3) {
                    if (totalFunds >= _claimAmount) {
                        if (bytes(_description).length > 10) {

                            Claim memory newClaim = Claim({
                                claimId: nextClaimId,
                                policyId: _policyId,
                                claimant: msg.sender,
                                amount: _claimAmount,
                                description: _description,
                                isApproved: false,
                                isPaid: false,
                                timestamp: block.timestamp
                            });

                            claims[nextClaimId] = newClaim;


                            bool shouldApprove = false;
                            if (_claimAmount < policies[_policyId].coverageAmount / 2) {
                                if (policies[_policyId].claimCount == 0) {
                                    shouldApprove = true;
                                } else {
                                    if (policies[_policyId].claimCount == 1) {
                                        if (block.timestamp - policies[_policyId].startTime > 30 days) {
                                            shouldApprove = true;
                                        } else {
                                            shouldApprove = false;
                                        }
                                    } else {
                                        if (block.timestamp - policies[_policyId].startTime > 90 days) {
                                            shouldApprove = true;
                                        } else {
                                            shouldApprove = false;
                                        }
                                    }
                                }
                            } else {
                                if (policies[_policyId].claimCount == 0) {
                                    if (block.timestamp - policies[_policyId].startTime > 60 days) {
                                        shouldApprove = true;
                                    } else {
                                        shouldApprove = false;
                                    }
                                } else {
                                    shouldApprove = false;
                                }
                            }

                            if (shouldApprove) {
                                claims[nextClaimId].isApproved = true;
                                claims[nextClaimId].isPaid = true;
                                policies[_policyId].claimCount++;
                                totalFunds -= _claimAmount;
                                payable(msg.sender).transfer(_claimAmount);
                                emit ClaimProcessed(nextClaimId, true);
                            } else {
                                emit ClaimProcessed(nextClaimId, false);
                            }

                            emit ClaimSubmitted(nextClaimId, _policyId);
                            nextClaimId++;
                            return shouldApprove;
                        } else {
                            return false;
                        }
                    } else {
                        return false;
                    }
                } else {
                    return false;
                }
            } else {
                return false;
            }
        } else {
            return false;
        }
    }

    function getPolicyDetails(uint256 _policyId) public view returns (Policy memory) {
        return policies[_policyId];
    }

    function getClaimDetails(uint256 _claimId) public view returns (Claim memory) {
        return claims[_claimId];
    }

    function getUserPolicies(address _user) public view returns (uint256[] memory) {
        return userPolicies[_user];
    }

    function withdrawFunds(uint256 _amount) public onlyOwner {
        require(_amount <= totalFunds, "Insufficient funds");
        totalFunds -= _amount;
        payable(owner).transfer(_amount);
    }

    function depositFunds() public payable onlyOwner {
        totalFunds += msg.value;
    }

    receive() external payable {
        totalFunds += msg.value;
    }
}
