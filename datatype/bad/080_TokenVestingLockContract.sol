
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenVestingLockContract {
    IERC20 public token;
    address public owner;


    uint256 public constant LOCK_PERIOD_DAYS = 30;
    uint256 public constant MAX_BENEFICIARIES = 100;
    uint256 public totalBeneficiaries = 0;


    string public contractId = "LOCK001";
    string public version = "1.0";


    bytes public contractHash;

    struct LockInfo {
        uint256 amount;
        uint256 lockTime;
        uint256 releaseTime;

        uint256 isReleased;
        uint256 isActive;
        bytes beneficiaryId;
    }

    mapping(address => LockInfo) public locks;
    mapping(address => uint256) public lockCount;
    address[] public beneficiaries;

    event TokensLocked(address indexed beneficiary, uint256 amount, uint256 releaseTime);
    event TokensReleased(address indexed beneficiary, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier validBeneficiary(address _beneficiary) {
        require(_beneficiary != address(0), "Invalid beneficiary address");
        _;
    }

    constructor(address _token, bytes memory _contractHash) {
        require(_token != address(0), "Invalid token address");
        token = IERC20(_token);
        owner = msg.sender;
        contractHash = _contractHash;
    }

    function lockTokens(
        address _beneficiary,
        uint256 _amount,
        uint256 _lockDurationDays,
        bytes memory _beneficiaryId
    ) external onlyOwner validBeneficiary(_beneficiary) {
        require(_amount > 0, "Amount must be greater than 0");
        require(_lockDurationDays > 0, "Lock duration must be greater than 0");


        require(locks[_beneficiary].isActive == 0, "Beneficiary already has active lock");


        uint256 lockDuration = uint256(_lockDurationDays) * uint256(1 days);
        uint256 releaseTime = block.timestamp + lockDuration;

        require(token.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");

        locks[_beneficiary] = LockInfo({
            amount: _amount,
            lockTime: block.timestamp,
            releaseTime: releaseTime,
            isReleased: 0,
            isActive: 1,
            beneficiaryId: _beneficiaryId
        });


        if (lockCount[_beneficiary] == 0) {
            beneficiaries.push(_beneficiary);
            totalBeneficiaries = totalBeneficiaries + uint256(1);
        }
        lockCount[_beneficiary] = lockCount[_beneficiary] + uint256(1);

        emit TokensLocked(_beneficiary, _amount, releaseTime);
    }

    function releaseTokens() external {
        LockInfo storage lockInfo = locks[msg.sender];


        require(lockInfo.isActive == 1, "No active lock found");
        require(lockInfo.isReleased == 0, "Tokens already released");
        require(block.timestamp >= lockInfo.releaseTime, "Lock period not expired");

        uint256 amount = lockInfo.amount;


        lockInfo.isReleased = 1;
        lockInfo.isActive = 0;

        require(token.transfer(msg.sender, amount), "Token transfer failed");

        emit TokensReleased(msg.sender, amount);
    }

    function emergencyWithdraw(address _beneficiary) external onlyOwner validBeneficiary(_beneficiary) {
        LockInfo storage lockInfo = locks[_beneficiary];


        require(lockInfo.isActive == 1, "No active lock found");
        require(lockInfo.isReleased == 0, "Tokens already released");

        uint256 amount = lockInfo.amount;

        lockInfo.isReleased = 1;
        lockInfo.isActive = 0;

        require(token.transfer(_beneficiary, amount), "Token transfer failed");

        emit TokensReleased(_beneficiary, amount);
    }

    function getLockInfo(address _beneficiary) external view returns (
        uint256 amount,
        uint256 lockTime,
        uint256 releaseTime,
        uint256 isReleased,
        uint256 isActive,
        bytes memory beneficiaryId
    ) {
        LockInfo memory lockInfo = locks[_beneficiary];
        return (
            lockInfo.amount,
            lockInfo.lockTime,
            lockInfo.releaseTime,
            lockInfo.isReleased,
            lockInfo.isActive,
            lockInfo.beneficiaryId
        );
    }

    function isTokensReleasable(address _beneficiary) external view returns (uint256) {
        LockInfo memory lockInfo = locks[_beneficiary];


        if (lockInfo.isActive == 1 && lockInfo.isReleased == 0 && block.timestamp >= lockInfo.releaseTime) {
            return 1;
        }
        return 0;
    }

    function updateContractId(string memory _newId) external onlyOwner {
        contractId = _newId;
    }

    function updateContractHash(bytes memory _newHash) external onlyOwner {
        contractHash = _newHash;
    }

    function getBeneficiariesCount() external view returns (uint256) {

        return uint256(totalBeneficiaries);
    }

    function getAllBeneficiaries() external view returns (address[] memory) {
        return beneficiaries;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        address previousOwner = owner;
        owner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    function getContractInfo() external view returns (
        string memory id,
        string memory ver,
        bytes memory hash,
        uint256 beneficiaryCount
    ) {
        return (contractId, version, contractHash, totalBeneficiaries);
    }
}
