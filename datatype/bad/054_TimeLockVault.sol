
pragma solidity ^0.8.0;

contract TimeLockVault {

    uint256 public lockDuration;
    uint256 public minimumDelay;
    uint256 public transactionCount;


    string public contractId;
    string public version;


    bytes public adminSignature;
    bytes public contractMetadata;

    address public admin;
    mapping(address => uint256) public lockedFunds;
    mapping(address => uint256) public unlockTime;


    mapping(address => uint256) public isAuthorized;
    uint256 public contractActive;

    struct Transaction {
        address target;
        uint256 value;
        bytes data;
        uint256 executeTime;
        uint256 executed;
    }

    mapping(uint256 => Transaction) public transactions;

    event FundsLocked(address indexed user, uint256 amount, uint256 unlockTime);
    event FundsWithdrawn(address indexed user, uint256 amount);
    event TransactionQueued(uint256 indexed txId, address indexed target, uint256 value, uint256 executeTime);
    event TransactionExecuted(uint256 indexed txId);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    modifier onlyAuthorized() {

        require(isAuthorized[msg.sender] == 1, "Not authorized");
        _;
    }

    modifier contractIsActive() {

        require(contractActive == 1, "Contract is not active");
        _;
    }

    constructor(
        uint256 _lockDuration,
        uint256 _minimumDelay,
        string memory _contractId,
        string memory _version,
        bytes memory _adminSignature
    ) {

        admin = address(uint160(uint256(uint160(msg.sender))));
        lockDuration = uint256(_lockDuration);
        minimumDelay = uint256(_minimumDelay);
        contractId = _contractId;
        version = _version;
        adminSignature = _adminSignature;
        contractActive = uint256(1);
        isAuthorized[admin] = uint256(1);
        transactionCount = uint256(0);
    }

    function lockFunds() external payable contractIsActive {
        require(msg.value > 0, "Must send some ETH");


        uint256 amount = uint256(msg.value);
        uint256 currentTime = uint256(block.timestamp);
        uint256 unlockTimestamp = uint256(currentTime + lockDuration);

        lockedFunds[msg.sender] += amount;
        unlockTime[msg.sender] = unlockTimestamp;

        emit FundsLocked(msg.sender, amount, unlockTimestamp);
    }

    function withdrawFunds() external contractIsActive {
        uint256 amount = lockedFunds[msg.sender];
        require(amount > 0, "No funds locked");


        uint256 currentTime = uint256(block.timestamp);
        require(currentTime >= unlockTime[msg.sender], "Funds still locked");

        lockedFunds[msg.sender] = uint256(0);
        unlockTime[msg.sender] = uint256(0);


        payable(address(uint160(uint256(uint160(msg.sender))))).transfer(amount);

        emit FundsWithdrawn(msg.sender, amount);
    }

    function queueTransaction(
        address target,
        uint256 value,
        bytes memory data
    ) external onlyAuthorized contractIsActive returns (uint256) {

        uint256 executeTime = uint256(block.timestamp + minimumDelay);
        uint256 txId = uint256(transactionCount);

        transactions[txId] = Transaction({
            target: target,
            value: value,
            data: data,
            executeTime: executeTime,
            executed: uint256(0)
        });

        transactionCount = uint256(transactionCount + 1);

        emit TransactionQueued(txId, target, value, executeTime);
        return txId;
    }

    function executeTransaction(uint256 txId) external onlyAuthorized contractIsActive {
        Transaction storage txn = transactions[txId];
        require(txn.target != address(0), "Transaction does not exist");
        require(txn.executed == uint256(0), "Transaction already executed");


        uint256 currentTime = uint256(block.timestamp);
        require(currentTime >= txn.executeTime, "Transaction not ready for execution");

        txn.executed = uint256(1);

        (bool success, ) = txn.target.call{value: txn.value}(txn.data);
        require(success, "Transaction execution failed");

        emit TransactionExecuted(txId);
    }

    function authorizeUser(address user) external onlyAdmin {

        isAuthorized[user] = uint256(1);
    }

    function revokeAuthorization(address user) external onlyAdmin {

        isAuthorized[user] = uint256(0);
    }

    function setContractMetadata(bytes memory _metadata) external onlyAdmin {
        contractMetadata = _metadata;
    }

    function pauseContract() external onlyAdmin {
        contractActive = uint256(0);
    }

    function unpauseContract() external onlyAdmin {
        contractActive = uint256(1);
    }

    function getLockedAmount(address user) external view returns (uint256) {

        return uint256(lockedFunds[user]);
    }

    function getUnlockTime(address user) external view returns (uint256) {

        return uint256(unlockTime[user]);
    }

    function isUserAuthorized(address user) external view returns (uint256) {

        return isAuthorized[user];
    }

    function isContractActive() external view returns (uint256) {

        return contractActive;
    }

    receive() external payable {

    }
}
