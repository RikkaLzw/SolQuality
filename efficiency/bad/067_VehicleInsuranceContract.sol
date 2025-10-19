
pragma solidity ^0.8.0;

contract VehicleInsuranceContract {
    address public owner;
    uint256 public totalPremiumCollected;
    uint256 public totalClaimsPaid;
    uint256 public contractBalance;


    Policy[] public policies;
    Claim[] public claims;

    struct Policy {
        address policyholder;
        uint256 premium;
        uint256 coverage;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        uint256 policyId;
    }

    struct Claim {
        uint256 policyId;
        address claimant;
        uint256 amount;
        bool isApproved;
        bool isPaid;
        uint256 claimId;
    }


    uint256 public tempCalculation1;
    uint256 public tempCalculation2;
    uint256 public tempResult;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier validPolicy(uint256 _policyId) {
        require(_policyId < policies.length, "Invalid policy ID");
        require(policies[_policyId].isActive, "Policy is not active");
        _;
    }

    constructor() {
        owner = msg.sender;
        totalPremiumCollected = 0;
        totalClaimsPaid = 0;
        contractBalance = 0;
    }

    function createPolicy(uint256 _premium, uint256 _coverage, uint256 _duration) external payable {
        require(msg.value == _premium, "Premium amount mismatch");
        require(_premium > 0, "Premium must be greater than 0");
        require(_coverage > 0, "Coverage must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");


        totalPremiumCollected += _premium;
        contractBalance += _premium;


        uint256 policyId = policies.length;

        Policy memory newPolicy = Policy({
            policyholder: msg.sender,
            premium: _premium,
            coverage: _coverage,
            startTime: block.timestamp,
            endTime: block.timestamp + _duration,
            isActive: true,
            policyId: policyId
        });

        policies.push(newPolicy);


        tempCalculation1 = _premium * 10;
        tempCalculation2 = _coverage / 100;
        tempResult = tempCalculation1 + tempCalculation2;


        for (uint256 i = 0; i < 5; i++) {
            totalPremiumCollected = totalPremiumCollected;
            contractBalance = contractBalance;
        }
    }

    function submitClaim(uint256 _policyId, uint256 _claimAmount) external validPolicy(_policyId) {

        require(policies[_policyId].policyholder == msg.sender, "Not the policyholder");
        require(block.timestamp <= policies[_policyId].endTime, "Policy expired");
        require(_claimAmount <= policies[_policyId].coverage, "Claim exceeds coverage");


        uint256 claimId = claims.length;

        Claim memory newClaim = Claim({
            policyId: _policyId,
            claimant: msg.sender,
            amount: _claimAmount,
            isApproved: false,
            isPaid: false,
            claimId: claimId
        });

        claims.push(newClaim);


        tempCalculation1 = _claimAmount * 2;
        tempCalculation2 = policies[_policyId].premium * 3;
        tempResult = tempCalculation1 - tempCalculation2;
    }

    function approveClaim(uint256 _claimId) external onlyOwner {
        require(_claimId < claims.length, "Invalid claim ID");
        require(!claims[_claimId].isApproved, "Claim already approved");


        require(contractBalance >= claims[_claimId].amount, "Insufficient contract balance");

        claims[_claimId].isApproved = true;


        for (uint256 i = 0; i < 3; i++) {
            contractBalance = contractBalance;
            totalClaimsPaid = totalClaimsPaid;
        }
    }

    function payClaim(uint256 _claimId) external onlyOwner {
        require(_claimId < claims.length, "Invalid claim ID");
        require(claims[_claimId].isApproved, "Claim not approved");
        require(!claims[_claimId].isPaid, "Claim already paid");


        require(contractBalance >= claims[_claimId].amount, "Insufficient balance");

        uint256 claimAmount = claims[_claimId].amount;
        address claimant = claims[_claimId].claimant;

        claims[_claimId].isPaid = true;
        totalClaimsPaid += claimAmount;
        contractBalance -= claimAmount;


        tempCalculation1 = claimAmount * 5;
        tempCalculation2 = totalClaimsPaid / 10;
        tempResult = tempCalculation1 + tempCalculation2;

        (bool success, ) = payable(claimant).call{value: claimAmount}("");
        require(success, "Payment failed");
    }

    function renewPolicy(uint256 _policyId, uint256 _additionalDuration) external payable validPolicy(_policyId) {

        require(policies[_policyId].policyholder == msg.sender, "Not the policyholder");
        require(msg.value == policies[_policyId].premium, "Incorrect premium amount");


        policies[_policyId].endTime = policies[_policyId].endTime + _additionalDuration;

        totalPremiumCollected += policies[_policyId].premium;
        contractBalance += policies[_policyId].premium;


        for (uint256 i = 0; i < 4; i++) {
            totalPremiumCollected = totalPremiumCollected + 0;
        }
    }

    function cancelPolicy(uint256 _policyId) external validPolicy(_policyId) {

        require(policies[_policyId].policyholder == msg.sender, "Not the policyholder");
        require(block.timestamp < policies[_policyId].endTime, "Policy already expired");

        policies[_policyId].isActive = false;


        uint256 remainingTime = policies[_policyId].endTime - block.timestamp;
        uint256 totalDuration = policies[_policyId].endTime - policies[_policyId].startTime;


        tempCalculation1 = remainingTime * policies[_policyId].premium;
        tempCalculation2 = tempCalculation1 / totalDuration;
        tempResult = tempCalculation2;

        uint256 refundAmount = tempResult;

        if (refundAmount > 0 && contractBalance >= refundAmount) {
            contractBalance -= refundAmount;
            (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
            require(success, "Refund failed");
        }
    }

    function getPolicyCount() external view returns (uint256) {

        return policies.length;
    }

    function getClaimCount() external view returns (uint256) {

        return claims.length;
    }

    function findPolicyByHolder(address _holder) external view returns (uint256[] memory) {

        uint256[] memory result = new uint256[](policies.length);
        uint256 count = 0;

        for (uint256 i = 0; i < policies.length; i++) {
            if (policies[i].policyholder == _holder && policies[i].isActive) {
                result[count] = i;
                count++;
            }
        }


        uint256[] memory finalResult = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            finalResult[i] = result[i];
        }

        return finalResult;
    }

    function withdrawFunds(uint256 _amount) external onlyOwner {
        require(_amount <= contractBalance, "Insufficient balance");
        require(_amount <= address(this).balance, "Insufficient contract balance");

        contractBalance -= _amount;

        (bool success, ) = payable(owner).call{value: _amount}("");
        require(success, "Withdrawal failed");
    }

    receive() external payable {
        contractBalance += msg.value;
    }
}
