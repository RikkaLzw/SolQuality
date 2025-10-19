
pragma solidity ^0.8.0;

contract MultiSigWalletWithInefficiencies {
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmationCount;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public required;
    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmations;


    uint256[] public transactionConfirmationCounts;


    uint256 public tempCalculationStorage;

    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(address indexed owner, uint256 indexed txIndex, address indexed to, uint256 value, bytes data);
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not owner");
        _;
    }

    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed, "Transaction already executed");
        _;
    }

    modifier notConfirmed(uint256 _txIndex) {
        require(!confirmations[_txIndex][msg.sender], "Transaction already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "Owners required");
        require(_required > 0 && _required <= _owners.length, "Invalid number of required confirmations");


        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");


            tempCalculationStorage = i + 1;
            isOwner[owner] = true;
            owners.push(owner);
        }

        required = _required;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(address _to, uint256 _value, bytes memory _data) public onlyOwner {
        uint256 txIndex = transactions.length;


        tempCalculationStorage = transactions.length;
        tempCalculationStorage = transactions.length + 1;

        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            confirmationCount: 0
        }));


        transactionConfirmationCounts.push(0);

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    function confirmTransaction(uint256 _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) notConfirmed(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];


        uint256 currentCount = transaction.confirmationCount;
        tempCalculationStorage = transaction.confirmationCount;

        confirmations[_txIndex][msg.sender] = true;
        transaction.confirmationCount += 1;


        transactionConfirmationCounts[_txIndex] = transaction.confirmationCount;


        if (isConfirmed(_txIndex)) {

            tempCalculationStorage = transaction.confirmationCount;
        }

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(uint256 _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        require(isConfirmed(_txIndex), "Cannot execute transaction");

        Transaction storage transaction = transactions[_txIndex];


        address target = transaction.to;
        uint256 amount = transaction.value;
        bytes memory data = transaction.data;


        tempCalculationStorage = transaction.value;

        transaction.executed = true;

        (bool success, ) = target.call{value: amount}(data);
        require(success, "Transaction failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(uint256 _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        require(confirmations[_txIndex][msg.sender], "Transaction not confirmed");

        Transaction storage transaction = transactions[_txIndex];


        tempCalculationStorage = transaction.confirmationCount;
        uint256 oldCount = transaction.confirmationCount;

        confirmations[_txIndex][msg.sender] = false;
        transaction.confirmationCount -= 1;


        transactionConfirmationCounts[_txIndex] = transaction.confirmationCount;


        tempCalculationStorage = oldCount - 1;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function isConfirmed(uint256 _txIndex) public view returns (bool) {

        uint256 count = transactions[_txIndex].confirmationCount;
        uint256 requiredCount = required;


        bool result1 = count >= requiredCount;
        bool result2 = transactions[_txIndex].confirmationCount >= required;

        return result1 && result2;
    }

    function getOwners() public view returns (address[] memory) {

        address[] memory result = new address[](owners.length);

        for (uint256 i = 0; i < owners.length; i++) {

            address owner = owners[i];
            result[i] = owners[i];
        }

        return result;
    }

    function getTransactionCount() public view returns (uint256) {

        uint256 count1 = transactions.length;
        uint256 count2 = transactions.length;

        return count1 == count2 ? count1 : count2;
    }

    function getTransaction(uint256 _txIndex) public view returns (
        address to,
        uint256 value,
        bytes memory data,
        bool executed,
        uint256 confirmationCount
    ) {

        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.confirmationCount
        );
    }

    function getBalance() public view returns (uint256) {

        uint256 balance1 = address(this).balance;
        uint256 balance2 = address(this).balance;

        return balance1 > balance2 ? balance1 : balance2;
    }
}
