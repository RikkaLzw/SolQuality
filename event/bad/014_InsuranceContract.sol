
pragma solidity ^0.8.0;

contract InsuranceContract {
    address public owner;
    uint256 public totalPremiums;
    uint256 public totalClaims;
    bool public contractActive;

    struct Policy {
        address policyholder;
        uint256 premium;
        uint256 coverageAmount;
        uint256 startTime;
        uint256 endTime;
        bool active;
        bool claimSubmitted;
    }

    struct Claim {
        uint256 policyId;
        address claimant;
        uint256 amount;
        string description;
        bool approved;
        bool processed;
    }

    mapping(uint256 => Policy) public policies;
    mapping(uint256 => Claim) public claims;
    mapping(address => uint256[]) public userPolicies;

    uint256 public nextPolicyId = 1;
    uint256 public nextClaimId = 1;


    event PolicyCreated(uint256 policyId, address policyholder, uint256 premium);
    event ClaimSubmitted(uint256 claimId, uint256 policyId, address claimant);
    event ClaimProcessed(uint256 claimId, bool approved);


    error InvalidInput();
    error NotAuthorized();
    error PolicyExpired();

    modifier onlyOwner() {

        require(msg.sender == owner);
        _;
    }

    modifier onlyActivePolicyholder(uint256 _policyId) {
        require(policies[_policyId].policyholder == msg.sender);
        require(policies[_policyId].active);
        _;
    }

    constructor() {
        owner = msg.sender;
        contractActive = true;
    }

    function createPolicy(uint256 _coverageAmount, uint256 _duration) external payable {
        require(msg.value > 0);
        require(_coverageAmount > 0);
        require(_duration > 0);
        require(contractActive);

        uint256 policyId = nextPolicyId++;

        policies[policyId] = Policy({
            policyholder: msg.sender,
            premium: msg.value,
            coverageAmount: _coverageAmount,
            startTime: block.timestamp,
            endTime: block.timestamp + _duration,
            active: true,
            claimSubmitted: false
        });

        userPolicies[msg.sender].push(policyId);
        totalPremiums += msg.value;



        emit PolicyCreated(policyId, msg.sender, msg.value);
    }

    function submitClaim(uint256 _policyId, uint256 _amount, string memory _description) external onlyActivePolicyholder(_policyId) {
        Policy storage policy = policies[_policyId];

        require(!policy.claimSubmitted);
        require(block.timestamp <= policy.endTime);
        require(_amount <= policy.coverageAmount);
        require(bytes(_description).length > 0);

        uint256 claimId = nextClaimId++;

        claims[claimId] = Claim({
            policyId: _policyId,
            claimant: msg.sender,
            amount: _amount,
            description: _description,
            approved: false,
            processed: false
        });

        policy.claimSubmitted = true;

        emit ClaimSubmitted(claimId, _policyId, msg.sender);
    }

    function processClaim(uint256 _claimId, bool _approve) external onlyOwner {
        Claim storage claim = claims[_claimId];

        require(!claim.processed);
        require(claim.claimant != address(0));

        claim.processed = true;
        claim.approved = _approve;

        if (_approve) {
            require(address(this).balance >= claim.amount);
            totalClaims += claim.amount;


            (bool success, ) = payable(claim.claimant).call{value: claim.amount}("");
            require(success);
        }

        emit ClaimProcessed(_claimId, _approve);
    }

    function withdrawPremiums(uint256 _amount) external onlyOwner {
        require(_amount <= address(this).balance);
        require(contractActive);



        (bool success, ) = payable(owner).call{value: _amount}("");
        if (!success) {

            revert InvalidInput();
        }
    }

    function deactivateContract() external onlyOwner {
        contractActive = false;

    }

    function activateContract() external onlyOwner {
        contractActive = true;
    }

    function getPolicyDetails(uint256 _policyId) external view returns (Policy memory) {
        return policies[_policyId];
    }

    function getClaimDetails(uint256 _claimId) external view returns (Claim memory) {
        return claims[_claimId];
    }

    function getUserPolicies(address _user) external view returns (uint256[] memory) {
        return userPolicies[_user];
    }

    function isPolicyActive(uint256 _policyId) external view returns (bool) {
        Policy memory policy = policies[_policyId];
        return policy.active && block.timestamp <= policy.endTime;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function changeOwner(address _newOwner) external onlyOwner {
        require(_newOwner != address(0));

        if (_newOwner == owner) {

            require(false);
        }

        owner = _newOwner;

    }

    receive() external payable {

    }
}
