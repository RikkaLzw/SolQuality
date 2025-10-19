
pragma solidity ^0.8.0;

contract TimeLockVault {

    uint256 public lockDuration;
    uint256 public minDelay;
    uint256 public maxDelay;


    string public contractId;
    string public vaultType;


    bytes public adminKey;
    bytes public secretHash;


    uint256 public isLocked;
    uint256 public isActive;
    uint256 public emergencyMode;

    address public owner;
    address public beneficiary;
    uint256 public lockTime;
    uint256 public unlockTime;
    uint256 public depositAmount;

    mapping(address => uint256) public deposits;
    mapping(string => uint256) public transactionStatus;

    event Deposit(address indexed user, uint256 amount, uint256 unlockTime);
    event Withdrawal(address indexed user, uint256 amount);
    event LockExtended(uint256 newUnlockTime);
    event EmergencyActivated(address indexed activator);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier onlyWhenActive() {

        require(isActive == 1, "Contract is not active");
        _;
    }

    modifier onlyWhenLocked() {

        require(isLocked == 1, "Vault is not locked");
        _;
    }

    constructor(
        address _beneficiary,
        uint256 _lockDuration,
        string memory _contractId,
        string memory _vaultType,
        bytes memory _adminKey
    ) {
        owner = msg.sender;
        beneficiary = _beneficiary;


        lockDuration = uint256(_lockDuration);
        minDelay = uint256(1 days);
        maxDelay = uint256(365 days);


        contractId = _contractId;
        vaultType = _vaultType;


        adminKey = _adminKey;


        isActive = 1;
        isLocked = 0;
        emergencyMode = 0;

        lockTime = block.timestamp;
        unlockTime = block.timestamp + lockDuration;
    }

    function deposit() external payable onlyWhenActive {
        require(msg.value > 0, "Deposit amount must be greater than 0");


        uint256 amount = uint256(msg.value);
        deposits[msg.sender] += amount;
        depositAmount += amount;


        isLocked = 1;


        string memory txId = string(abi.encodePacked("deposit_", uint2str(block.timestamp)));
        transactionStatus[txId] = 1;

        emit Deposit(msg.sender, amount, unlockTime);
    }

    function withdraw() external onlyWhenLocked {
        require(block.timestamp >= unlockTime, "Funds are still locked");
        require(deposits[msg.sender] > 0, "No funds to withdraw");


        uint256 amount = uint256(deposits[msg.sender]);
        deposits[msg.sender] = 0;
        depositAmount -= amount;


        if (depositAmount == 0) {
            isLocked = 0;
        }


        string memory txId = string(abi.encodePacked("withdraw_", uint2str(block.timestamp)));
        transactionStatus[txId] = 1;

        payable(msg.sender).transfer(amount);
        emit Withdrawal(msg.sender, amount);
    }

    function extendLock(uint256 additionalTime) external onlyOwner onlyWhenLocked {

        require(additionalTime <= maxDelay, "Additional time exceeds maximum delay");
        require(additionalTime >= minDelay, "Additional time below minimum delay");

        unlockTime += additionalTime;
        emit LockExtended(unlockTime);
    }

    function activateEmergencyMode(bytes memory emergencyKey) external onlyOwner {

        require(keccak256(emergencyKey) == keccak256(adminKey), "Invalid emergency key");


        emergencyMode = 1;

        emit EmergencyActivated(msg.sender);
    }

    function emergencyWithdraw() external onlyOwner {

        require(emergencyMode == 1, "Emergency mode not activated");

        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "No funds to withdraw");

        payable(owner).transfer(contractBalance);
    }

    function updateVaultInfo(string memory newVaultType, bytes memory newSecretHash) external onlyOwner {

        vaultType = newVaultType;


        secretHash = newSecretHash;
    }

    function setActive(uint256 _isActive) external onlyOwner {

        require(_isActive == 0 || _isActive == 1, "Invalid active status");
        isActive = _isActive;
    }

    function getVaultStatus() external view returns (
        uint256 _isLocked,
        uint256 _isActive,
        uint256 _emergencyMode,
        string memory _contractId,
        string memory _vaultType
    ) {


        return (isLocked, isActive, emergencyMode, contractId, vaultType);
    }

    function verifyAdminAccess(bytes memory providedKey) external view returns (uint256) {


        if (keccak256(providedKey) == keccak256(adminKey)) {
            return 1;
        }
        return 0;
    }


    function uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }


    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }


    function getUserDeposit(address user) external view returns (uint256) {
        return deposits[user];
    }


    function getRemainingLockTime() external view returns (uint256) {
        if (block.timestamp >= unlockTime) {
            return 0;
        }
        return unlockTime - block.timestamp;
    }
}
