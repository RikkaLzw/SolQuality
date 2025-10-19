
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

library InsuranceLibrary {
    struct Policy {
        uint256 id;
        address policyholder;
        uint256 premium;
        uint256 coverageAmount;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        bool claimSubmitted;
        uint256 claimAmount;
    }

    struct Claim {
        uint256 policyId;
        address claimant;
        uint256 amount;
        string description;
        uint256 timestamp;
        ClaimStatus status;
    }

    enum ClaimStatus {
        Pending,
        Approved,
        Rejected,
        Paid
    }

    function calculatePremium(uint256 coverageAmount, uint256 riskFactor) internal pure returns (uint256) {
        return (coverageAmount * riskFactor) / 10000;
    }

    function isPolicyValid(Policy memory policy) internal view returns (bool) {
        return policy.isActive &&
               block.timestamp >= policy.startTime &&
               block.timestamp <= policy.endTime;
    }
}

abstract contract InsuranceBase is Ownable, ReentrancyGuard, Pausable {
    using InsuranceLibrary for InsuranceLibrary.Policy;


    uint256 public constant MIN_COVERAGE_AMOUNT = 1000 * 10**18;
    uint256 public constant MAX_COVERAGE_AMOUNT = 1000000 * 10**18;
    uint256 public constant MIN_POLICY_DURATION = 30 days;
    uint256 public constant MAX_POLICY_DURATION = 365 days;
    uint256 public constant CLAIM_PROCESSING_TIME = 7 days;


    uint256 internal _nextPolicyId;
    uint256 internal _nextClaimId;
    uint256 public totalReserves;
    uint256 public riskFactor = 500;

    mapping(uint256 => InsuranceLibrary.Policy) internal _policies;
    mapping(uint256 => InsuranceLibrary.Claim) internal _claims;
    mapping(address => uint256[]) internal _userPolicies;


    event PolicyCreated(uint256 indexed policyId, address indexed policyholder, uint256 premium, uint256 coverageAmount);
    event PremiumPaid(uint256 indexed policyId, address indexed policyholder, uint256 amount);
    event ClaimSubmitted(uint256 indexed claimId, uint256 indexed policyId, address indexed claimant, uint256 amount);
    event ClaimProcessed(uint256 indexed claimId, InsuranceLibrary.ClaimStatus status);
    event ClaimPaid(uint256 indexed claimId, address indexed recipient, uint256 amount);


    modifier onlyValidPolicy(uint256 policyId) {
        require(_policies[policyId].id != 0, "Policy does not exist");
        require(InsuranceLibrary.isPolicyValid(_policies[policyId]), "Policy is not valid");
        _;
    }

    modifier onlyPolicyholder(uint256 policyId) {
        require(_policies[policyId].policyholder == msg.sender, "Not the policyholder");
        _;
    }

    modifier validCoverageAmount(uint256 amount) {
        require(amount >= MIN_COVERAGE_AMOUNT && amount <= MAX_COVERAGE_AMOUNT, "Invalid coverage amount");
        _;
    }

    modifier validDuration(uint256 duration) {
        require(duration >= MIN_POLICY_DURATION && duration <= MAX_POLICY_DURATION, "Invalid policy duration");
        _;
    }

    modifier sufficientReserves(uint256 amount) {
        require(totalReserves >= amount, "Insufficient reserves");
        _;
    }


    function _generatePolicyId() internal returns (uint256) {
        return ++_nextPolicyId;
    }

    function _generateClaimId() internal returns (uint256) {
        return ++_nextClaimId;
    }

    function _updateReserves(uint256 amount, bool increase) internal {
        if (increase) {
            totalReserves += amount;
        } else {
            require(totalReserves >= amount, "Insufficient reserves");
            totalReserves -= amount;
        }
    }
}

contract VehicleInsuranceContract is InsuranceBase {

    uint256 public constant VEHICLE_RISK_MULTIPLIER = 150;

    struct VehicleInfo {
        string make;
        string model;
        uint256 year;
        string licensePlate;
        uint256 estimatedValue;
    }

    mapping(uint256 => VehicleInfo) public vehicleDetails;

    event VehicleRegistered(uint256 indexed policyId, string make, string model, uint256 year);

    modifier validVehicleYear(uint256 year) {
        require(year >= 2000 && year <= block.timestamp / 365 days + 1970, "Invalid vehicle year");
        _;
    }

    constructor() {
        _nextPolicyId = 1;
        _nextClaimId = 1;
    }

    function createPolicy(
        uint256 coverageAmount,
        uint256 duration,
        string memory make,
        string memory model,
        uint256 year,
        string memory licensePlate,
        uint256 estimatedValue
    )
        external
        payable
        whenNotPaused
        nonReentrant
        validCoverageAmount(coverageAmount)
        validDuration(duration)
        validVehicleYear(year)
    {
        uint256 adjustedRiskFactor = (riskFactor * VEHICLE_RISK_MULTIPLIER) / 100;
        uint256 premium = InsuranceLibrary.calculatePremium(coverageAmount, adjustedRiskFactor);

        require(msg.value >= premium, "Insufficient premium payment");

        uint256 policyId = _generatePolicyId();

        _policies[policyId] = InsuranceLibrary.Policy({
            id: policyId,
            policyholder: msg.sender,
            premium: premium,
            coverageAmount: coverageAmount,
            startTime: block.timestamp,
            endTime: block.timestamp + duration,
            isActive: true,
            claimSubmitted: false,
            claimAmount: 0
        });

        vehicleDetails[policyId] = VehicleInfo({
            make: make,
            model: model,
            year: year,
            licensePlate: licensePlate,
            estimatedValue: estimatedValue
        });

        _userPolicies[msg.sender].push(policyId);
        _updateReserves(premium, true);


        if (msg.value > premium) {
            payable(msg.sender).transfer(msg.value - premium);
        }

        emit PolicyCreated(policyId, msg.sender, premium, coverageAmount);
        emit VehicleRegistered(policyId, make, model, year);
    }

    function submitClaim(
        uint256 policyId,
        uint256 claimAmount,
        string memory description
    )
        external
        whenNotPaused
        nonReentrant
        onlyValidPolicy(policyId)
        onlyPolicyholder(policyId)
    {
        require(!_policies[policyId].claimSubmitted, "Claim already submitted for this policy");
        require(claimAmount > 0 && claimAmount <= _policies[policyId].coverageAmount, "Invalid claim amount");

        uint256 claimId = _generateClaimId();

        _claims[claimId] = InsuranceLibrary.Claim({
            policyId: policyId,
            claimant: msg.sender,
            amount: claimAmount,
            description: description,
            timestamp: block.timestamp,
            status: InsuranceLibrary.ClaimStatus.Pending
        });

        _policies[policyId].claimSubmitted = true;
        _policies[policyId].claimAmount = claimAmount;

        emit ClaimSubmitted(claimId, policyId, msg.sender, claimAmount);
    }

    function processClaim(uint256 claimId, bool approve)
        external
        onlyOwner
        whenNotPaused
    {
        require(_claims[claimId].policyId != 0, "Claim does not exist");
        require(_claims[claimId].status == InsuranceLibrary.ClaimStatus.Pending, "Claim already processed");
        require(block.timestamp >= _claims[claimId].timestamp + CLAIM_PROCESSING_TIME, "Claim processing time not met");

        if (approve) {
            _claims[claimId].status = InsuranceLibrary.ClaimStatus.Approved;
        } else {
            _claims[claimId].status = InsuranceLibrary.ClaimStatus.Rejected;

            _policies[_claims[claimId].policyId].claimSubmitted = false;
            _policies[_claims[claimId].policyId].claimAmount = 0;
        }

        emit ClaimProcessed(claimId, _claims[claimId].status);
    }

    function payClaim(uint256 claimId)
        external
        onlyOwner
        whenNotPaused
        nonReentrant
        sufficientReserves(_claims[claimId].amount)
    {
        require(_claims[claimId].status == InsuranceLibrary.ClaimStatus.Approved, "Claim not approved");

        _claims[claimId].status = InsuranceLibrary.ClaimStatus.Paid;
        _updateReserves(_claims[claimId].amount, false);


        _policies[_claims[claimId].policyId].isActive = false;

        payable(_claims[claimId].claimant).transfer(_claims[claimId].amount);

        emit ClaimPaid(claimId, _claims[claimId].claimant, _claims[claimId].amount);
    }

    function renewPolicy(uint256 policyId, uint256 newDuration)
        external
        payable
        whenNotPaused
        nonReentrant
        onlyPolicyholder(policyId)
        validDuration(newDuration)
    {
        require(_policies[policyId].id != 0, "Policy does not exist");
        require(!_policies[policyId].claimSubmitted, "Cannot renew policy with pending claim");

        uint256 adjustedRiskFactor = (riskFactor * VEHICLE_RISK_MULTIPLIER) / 100;
        uint256 renewalPremium = InsuranceLibrary.calculatePremium(_policies[policyId].coverageAmount, adjustedRiskFactor);

        require(msg.value >= renewalPremium, "Insufficient renewal premium");

        _policies[policyId].endTime = block.timestamp + newDuration;
        _policies[policyId].isActive = true;
        _updateReserves(renewalPremium, true);

        if (msg.value > renewalPremium) {
            payable(msg.sender).transfer(msg.value - renewalPremium);
        }

        emit PremiumPaid(policyId, msg.sender, renewalPremium);
    }


    function getPolicy(uint256 policyId) external view returns (InsuranceLibrary.Policy memory) {
        return _policies[policyId];
    }

    function getClaim(uint256 claimId) external view returns (InsuranceLibrary.Claim memory) {
        return _claims[claimId];
    }

    function getUserPolicies(address user) external view returns (uint256[] memory) {
        return _userPolicies[user];
    }

    function getVehicleDetails(uint256 policyId) external view returns (VehicleInfo memory) {
        return vehicleDetails[policyId];
    }


    function updateRiskFactor(uint256 newRiskFactor) external onlyOwner {
        require(newRiskFactor <= 2000, "Risk factor too high");
        riskFactor = newRiskFactor;
    }

    function withdrawReserves(uint256 amount) external onlyOwner nonReentrant {
        require(amount <= totalReserves / 2, "Cannot withdraw more than 50% of reserves");
        _updateReserves(amount, false);
        payable(owner()).transfer(amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }


    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    receive() external payable {
        _updateReserves(msg.value, true);
    }
}
