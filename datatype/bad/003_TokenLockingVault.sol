
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract TokenLockingVault {
    IERC20 public immutable token;
    address public owner;


    uint256 public lockDuration;
    uint256 public totalLocks;
    uint256 public isInitialized;

    struct LockInfo {
        address beneficiary;
        uint256 amount;
        uint256 lockTime;
        uint256 unlockTime;
        uint256 isActive;
        string lockId;
        bytes metadata;
    }

    mapping(address => LockInfo[]) public userLocks;
    mapping(string => uint256) public lockIdToIndex;

    event TokensLocked(address indexed beneficiary, uint256 amount, uint256 unlockTime, string lockId);
    event TokensUnlocked(address indexed beneficiary, uint256 amount, string lockId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyInitialized() {
        require(uint8(isInitialized) == 1, "Not initialized");
        _;
    }

    constructor(address _token, uint256 _lockDuration) {
        token = IERC20(_token);
        owner = msg.sender;
        lockDuration = _lockDuration;
        isInitialized = uint256(1);
        totalLocks = uint256(0);
    }

    function lockTokens(
        uint256 _amount,
        address _beneficiary,
        string memory _lockId,
        bytes memory _metadata
    ) external onlyInitialized {
        require(_amount > 0, "Amount must be greater than 0");
        require(_beneficiary != address(0), "Invalid beneficiary");
        require(bytes(_lockId).length > 0, "Lock ID required");
        require(lockIdToIndex[_lockId] == 0, "Lock ID already exists");


        require(token.transferFrom(msg.sender, address(this), _amount), "Transfer failed");

        uint256 unlockTime = block.timestamp + lockDuration;

        LockInfo memory newLock = LockInfo({
            beneficiary: _beneficiary,
            amount: _amount,
            lockTime: block.timestamp,
            unlockTime: unlockTime,
            isActive: uint256(1),
            lockId: _lockId,
            metadata: _metadata
        });

        userLocks[_beneficiary].push(newLock);
        totalLocks = totalLocks + uint256(1);
        lockIdToIndex[_lockId] = userLocks[_beneficiary].length;

        emit TokensLocked(_beneficiary, _amount, unlockTime, _lockId);
    }

    function unlockTokens(string memory _lockId) external onlyInitialized {
        uint256 lockIndex = lockIdToIndex[_lockId];
        require(lockIndex > 0, "Lock not found");

        address beneficiary = msg.sender;
        require(lockIndex <= userLocks[beneficiary].length, "Invalid lock index");

        LockInfo storage lockInfo = userLocks[beneficiary][lockIndex - 1];
        require(uint8(lockInfo.isActive) == 1, "Lock not active");
        require(block.timestamp >= lockInfo.unlockTime, "Tokens still locked");
        require(keccak256(bytes(lockInfo.lockId)) == keccak256(bytes(_lockId)), "Lock ID mismatch");

        uint256 amount = lockInfo.amount;
        lockInfo.isActive = uint256(0);

        require(token.transfer(beneficiary, amount), "Transfer failed");

        emit TokensUnlocked(beneficiary, amount, _lockId);
    }

    function getUserLocks(address _user) external view returns (LockInfo[] memory) {
        return userLocks[_user];
    }

    function getLockInfo(address _user, string memory _lockId) external view returns (LockInfo memory) {
        uint256 lockIndex = lockIdToIndex[_lockId];
        require(lockIndex > 0, "Lock not found");
        require(lockIndex <= userLocks[_user].length, "Invalid lock index");

        return userLocks[_user][lockIndex - 1];
    }

    function updateLockDuration(uint256 _newDuration) external onlyOwner {
        lockDuration = _newDuration;
    }

    function emergencyWithdraw(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).transfer(owner, _amount);
    }

    function getContractBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function setInitialized(uint256 _status) external onlyOwner {
        isInitialized = _status;
    }
}
