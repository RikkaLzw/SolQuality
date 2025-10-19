
pragma solidity ^0.8.0;

contract TimeLockVault {

    uint256 public lockDuration;
    uint256 public minDeposit;
    uint256 public maxDeposit;
    uint256 public totalDeposits;


    string public contractId;
    string public version;


    bytes public contractHash;
    bytes public adminSignature;

    address public owner;

    struct Deposit {
        uint256 amount;
        uint256 unlockTime;

        uint256 isActive;
        uint256 isWithdrawn;

        string depositId;
    }

    mapping(address => Deposit[]) public userDeposits;
    mapping(address => uint256) public userDepositCount;


    uint256 public contractActive;
    uint256 public emergencyMode;

    event DepositMade(address indexed user, uint256 amount, uint256 unlockTime, string depositId);
    event WithdrawalMade(address indexed user, uint256 amount, string depositId);
    event ContractStatusChanged(uint256 newStatus);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier contractIsActive() {
        require(contractActive == 1, "Contract is not active");
        _;
    }

    modifier notInEmergencyMode() {
        require(emergencyMode == 0, "Contract is in emergency mode");
        _;
    }

    constructor(
        uint256 _lockDuration,
        uint256 _minDeposit,
        uint256 _maxDeposit,
        string memory _contractId,
        string memory _version,
        bytes memory _contractHash
    ) {
        owner = msg.sender;
        lockDuration = _lockDuration;
        minDeposit = _minDeposit;
        maxDeposit = _maxDeposit;
        contractId = _contractId;
        version = _version;
        contractHash = _contractHash;
        contractActive = 1;
        emergencyMode = 0;
        totalDeposits = 0;
    }

    function deposit(string memory _depositId, bytes memory _signature) external payable contractIsActive notInEmergencyMode {
        require(msg.value >= minDeposit, "Deposit amount too small");
        require(msg.value <= maxDeposit, "Deposit amount too large");
        require(bytes(_depositId).length > 0, "Deposit ID cannot be empty");


        uint256 depositAmount = uint256(msg.value);
        uint256 currentTime = uint256(block.timestamp);
        uint256 unlockTime = uint256(currentTime + lockDuration);

        Deposit memory newDeposit = Deposit({
            amount: depositAmount,
            unlockTime: unlockTime,
            isActive: uint256(1),
            isWithdrawn: uint256(0),
            depositId: _depositId
        });

        userDeposits[msg.sender].push(newDeposit);
        userDepositCount[msg.sender] = uint256(userDepositCount[msg.sender] + 1);
        totalDeposits = uint256(totalDeposits + depositAmount);


        adminSignature = _signature;

        emit DepositMade(msg.sender, depositAmount, unlockTime, _depositId);
    }

    function withdraw(uint256 _depositIndex) external contractIsActive notInEmergencyMode {
        require(_depositIndex < userDeposits[msg.sender].length, "Invalid deposit index");

        Deposit storage userDeposit = userDeposits[msg.sender][_depositIndex];
        require(userDeposit.isActive == 1, "Deposit is not active");
        require(userDeposit.isWithdrawn == 0, "Already withdrawn");


        uint256 currentTime = uint256(block.timestamp);
        require(currentTime >= userDeposit.unlockTime, "Tokens are still locked");

        uint256 withdrawAmount = uint256(userDeposit.amount);
        userDeposit.isWithdrawn = uint256(1);
        userDeposit.isActive = uint256(0);

        totalDeposits = uint256(totalDeposits - withdrawAmount);

        payable(msg.sender).transfer(withdrawAmount);

        emit WithdrawalMade(msg.sender, withdrawAmount, userDeposit.depositId);
    }

    function getUserDeposits(address _user) external view returns (Deposit[] memory) {
        return userDeposits[_user];
    }

    function getDepositInfo(address _user, uint256 _index) external view returns (
        uint256 amount,
        uint256 unlockTime,
        uint256 isActive,
        uint256 isWithdrawn,
        string memory depositId
    ) {
        require(_index < userDeposits[_user].length, "Invalid deposit index");
        Deposit memory deposit = userDeposits[_user][_index];
        return (deposit.amount, deposit.unlockTime, deposit.isActive, deposit.isWithdrawn, deposit.depositId);
    }

    function setContractStatus(uint256 _status) external onlyOwner {
        require(_status == 0 || _status == 1, "Status must be 0 or 1");
        contractActive = _status;
        emit ContractStatusChanged(_status);
    }

    function setEmergencyMode(uint256 _mode) external onlyOwner {
        require(_mode == 0 || _mode == 1, "Mode must be 0 or 1");
        emergencyMode = _mode;
    }

    function updateContractHash(bytes memory _newHash) external onlyOwner {
        contractHash = _newHash;
    }

    function updateLockDuration(uint256 _newDuration) external onlyOwner {
        require(_newDuration > 0, "Duration must be greater than 0");
        lockDuration = _newDuration;
    }

    function emergencyWithdraw() external onlyOwner {
        require(emergencyMode == 1, "Not in emergency mode");
        payable(owner).transfer(address(this).balance);
    }

    function getContractBalance() external view returns (uint256) {
        return uint256(address(this).balance);
    }

    function isDepositUnlocked(address _user, uint256 _index) external view returns (uint256) {
        require(_index < userDeposits[_user].length, "Invalid deposit index");
        Deposit memory deposit = userDeposits[_user][_index];


        uint256 currentTime = uint256(block.timestamp);

        if (currentTime >= deposit.unlockTime && deposit.isActive == 1 && deposit.isWithdrawn == 0) {
            return uint256(1);
        }
        return uint256(0);
    }
}
