
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
    event ContractStateChanged(uint256 newState);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier contractIsActive() {

        require(uint256(contractActive) == uint256(1), "Contract not active");
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
        contractActive = uint256(1);
        emergencyMode = uint256(0);
        totalDeposits = uint256(0);
    }

    function deposit(string memory _depositId) external payable contractIsActive {

        require(uint256(msg.value) >= uint256(minDeposit), "Below minimum deposit");
        require(uint256(msg.value) <= uint256(maxDeposit), "Above maximum deposit");
        require(uint256(emergencyMode) == uint256(0), "Emergency mode active");

        uint256 unlockTime = block.timestamp + lockDuration;

        userDeposits[msg.sender].push(Deposit({
            amount: msg.value,
            unlockTime: unlockTime,
            isActive: uint256(1),
            isWithdrawn: uint256(0),
            depositId: _depositId
        }));


        userDepositCount[msg.sender] = uint256(userDepositCount[msg.sender]) + uint256(1);
        totalDeposits = uint256(totalDeposits) + uint256(msg.value);

        emit DepositMade(msg.sender, msg.value, unlockTime, _depositId);
    }

    function withdraw(uint256 _depositIndex) external contractIsActive {
        require(_depositIndex < userDeposits[msg.sender].length, "Invalid deposit index");
        require(uint256(emergencyMode) == uint256(0), "Emergency mode active");

        Deposit storage userDeposit = userDeposits[msg.sender][_depositIndex];


        require(uint256(userDeposit.isActive) == uint256(1), "Deposit not active");
        require(uint256(userDeposit.isWithdrawn) == uint256(0), "Already withdrawn");
        require(uint256(block.timestamp) >= uint256(userDeposit.unlockTime), "Still locked");

        userDeposit.isWithdrawn = uint256(1);
        userDeposit.isActive = uint256(0);

        uint256 amount = userDeposit.amount;
        totalDeposits = uint256(totalDeposits) - uint256(amount);

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit WithdrawalMade(msg.sender, amount, userDeposit.depositId);
    }

    function getUserDepositCount(address _user) external view returns (uint256) {

        return uint256(userDepositCount[_user]);
    }

    function getUserDeposit(address _user, uint256 _index) external view returns (
        uint256 amount,
        uint256 unlockTime,
        uint256 isActive,
        uint256 isWithdrawn,
        string memory depositId
    ) {
        require(_index < userDeposits[_user].length, "Invalid index");
        Deposit memory deposit = userDeposits[_user][_index];
        return (
            deposit.amount,
            deposit.unlockTime,
            deposit.isActive,
            deposit.isWithdrawn,
            deposit.depositId
        );
    }

    function setContractActive(uint256 _active) external onlyOwner {

        require(uint256(_active) <= uint256(1), "Invalid state");
        contractActive = uint256(_active);
        emit ContractStateChanged(_active);
    }

    function setEmergencyMode(uint256 _emergency) external onlyOwner {

        require(uint256(_emergency) <= uint256(1), "Invalid state");
        emergencyMode = uint256(_emergency);
    }

    function updateContractHash(bytes memory _newHash) external onlyOwner {
        contractHash = _newHash;
    }

    function updateAdminSignature(bytes memory _signature) external onlyOwner {
        adminSignature = _signature;
    }

    function getContractInfo() external view returns (
        string memory id,
        string memory ver,
        bytes memory hash,
        uint256 active,
        uint256 emergency
    ) {
        return (contractId, version, contractHash, contractActive, emergencyMode);
    }

    function emergencyWithdraw(uint256 _depositIndex) external {

        require(uint256(emergencyMode) == uint256(1), "Emergency mode not active");
        require(_depositIndex < userDeposits[msg.sender].length, "Invalid deposit index");

        Deposit storage userDeposit = userDeposits[msg.sender][_depositIndex];

        require(uint256(userDeposit.isActive) == uint256(1), "Deposit not active");
        require(uint256(userDeposit.isWithdrawn) == uint256(0), "Already withdrawn");

        userDeposit.isWithdrawn = uint256(1);
        userDeposit.isActive = uint256(0);

        uint256 amount = userDeposit.amount;
        totalDeposits = uint256(totalDeposits) - uint256(amount);

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit WithdrawalMade(msg.sender, amount, userDeposit.depositId);
    }
}
