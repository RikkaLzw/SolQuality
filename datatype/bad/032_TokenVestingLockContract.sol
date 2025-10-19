
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
    uint256 public beneficiaryCount = 0;


    string public contractId = "LOCK001";
    string public version = "v1.0";

    struct LockInfo {
        uint256 amount;
        uint256 lockTime;
        uint256 releaseTime;

        uint256 isReleased;
        uint256 isActive;

        bytes lockId;
        bytes beneficiaryData;
    }

    mapping(address => LockInfo[]) public userLocks;
    mapping(address => uint256) public userLockCount;

    event TokensLocked(address indexed beneficiary, uint256 amount, uint256 releaseTime, bytes lockId);
    event TokensReleased(address indexed beneficiary, uint256 amount, bytes lockId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _token) {
        token = IERC20(_token);
        owner = msg.sender;
    }

    function lockTokens(
        address beneficiary,
        uint256 amount,
        uint256 lockDurationDays,
        bytes memory lockId,
        bytes memory beneficiaryData
    ) external onlyOwner {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(amount > 0, "Amount must be greater than 0");
        require(lockDurationDays > 0, "Lock duration must be greater than 0");


        uint256 lockDuration = uint256(lockDurationDays) * uint256(1 days);
        uint256 releaseTime = uint256(block.timestamp) + lockDuration;


        require(token.balanceOf(address(this)) >= amount, "Insufficient contract balance");

        LockInfo memory newLock = LockInfo({
            amount: amount,
            lockTime: uint256(block.timestamp),
            releaseTime: releaseTime,
            isReleased: uint256(0),
            isActive: uint256(1),
            lockId: lockId,
            beneficiaryData: beneficiaryData
        });

        userLocks[beneficiary].push(newLock);
        userLockCount[beneficiary] = uint256(userLockCount[beneficiary]) + uint256(1);


        if (uint256(beneficiaryCount) < uint256(MAX_BENEFICIARIES)) {
            beneficiaryCount = uint256(beneficiaryCount) + uint256(1);
        }

        emit TokensLocked(beneficiary, amount, releaseTime, lockId);
    }

    function releaseTokens(uint256 lockIndex) external {
        require(lockIndex < userLocks[msg.sender].length, "Invalid lock index");

        LockInfo storage lockInfo = userLocks[msg.sender][lockIndex];


        require(lockInfo.isActive == uint256(1), "Lock not active");
        require(lockInfo.isReleased == uint256(0), "Tokens already released");
        require(uint256(block.timestamp) >= lockInfo.releaseTime, "Tokens still locked");


        uint256 amount = uint256(lockInfo.amount);

        lockInfo.isReleased = uint256(1);
        lockInfo.isActive = uint256(0);

        require(token.transfer(msg.sender, amount), "Transfer failed");

        emit TokensReleased(msg.sender, amount, lockInfo.lockId);
    }

    function getUserLockInfo(address user, uint256 lockIndex)
        external
        view
        returns (
            uint256 amount,
            uint256 lockTime,
            uint256 releaseTime,
            uint256 isReleased,
            uint256 isActive,
            bytes memory lockId,
            bytes memory beneficiaryData
        )
    {
        require(lockIndex < userLocks[user].length, "Invalid lock index");

        LockInfo storage lockInfo = userLocks[user][lockIndex];

        return (
            lockInfo.amount,
            lockInfo.lockTime,
            lockInfo.releaseTime,
            lockInfo.isReleased,
            lockInfo.isActive,
            lockInfo.lockId,
            lockInfo.beneficiaryData
        );
    }

    function getReleasableAmount(address user) external view returns (uint256 totalReleasable) {

        uint256 lockCount = uint256(userLocks[user].length);
        totalReleasable = uint256(0);


        for (uint256 i = uint256(0); i < lockCount; i = uint256(i) + uint256(1)) {
            LockInfo storage lockInfo = userLocks[user][i];


            if (lockInfo.isActive == uint256(1) &&
                lockInfo.isReleased == uint256(0) &&
                uint256(block.timestamp) >= lockInfo.releaseTime) {
                totalReleasable = uint256(totalReleasable) + uint256(lockInfo.amount);
            }
        }
    }

    function emergencyWithdraw(address tokenAddress, uint256 amount) external onlyOwner {
        IERC20 emergencyToken = IERC20(tokenAddress);
        require(emergencyToken.transfer(owner, amount), "Emergency withdraw failed");
    }

    function updateContractId(string memory newId) external onlyOwner {
        contractId = newId;
    }

    function getContractInfo() external view returns (string memory, string memory, uint256, uint256) {
        return (contractId, version, beneficiaryCount, MAX_BENEFICIARIES);
    }
}
