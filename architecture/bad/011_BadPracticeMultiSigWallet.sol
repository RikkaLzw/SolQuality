
pragma solidity ^0.8.0;

contract BadPracticeMultiSigWallet {
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public requiredConfirmations;
    uint256 public transactionCount;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmationCount;
    }

    mapping(uint256 => Transaction) public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmations;

    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(address indexed owner, uint256 indexed txIndex, address indexed to, uint256 value, bytes data);
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);

    constructor(address[] memory _owners, uint256 _requiredConfirmations) {

        require(_owners.length > 0, "owners required");
        require(_requiredConfirmations > 0 && _requiredConfirmations <= _owners.length, "invalid number of required confirmations");


        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");
            isOwner[owner] = true;
            owners.push(owner);
        }

        requiredConfirmations = _requiredConfirmations;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(address _to, uint256 _value, bytes memory _data) public {

        require(isOwner[msg.sender], "not owner");

        uint256 txIndex = transactionCount;
        transactions[txIndex] = Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            confirmationCount: 0
        });
        transactionCount += 1;

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    function confirmTransaction(uint256 _txIndex) public {

        require(isOwner[msg.sender], "not owner");

        require(_txIndex < transactionCount, "tx does not exist");
        require(!confirmations[_txIndex][msg.sender], "tx already confirmed");

        confirmations[_txIndex][msg.sender] = true;
        transactions[_txIndex].confirmationCount += 1;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(uint256 _txIndex) public {

        require(isOwner[msg.sender], "not owner");

        require(_txIndex < transactionCount, "tx does not exist");
        require(!transactions[_txIndex].executed, "tx already executed");
        require(transactions[_txIndex].confirmationCount >= requiredConfirmations, "cannot execute tx");

        Transaction storage transaction = transactions[_txIndex];
        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(uint256 _txIndex) public {

        require(isOwner[msg.sender], "not owner");

        require(_txIndex < transactionCount, "tx does not exist");
        require(confirmations[_txIndex][msg.sender], "tx not confirmed");

        confirmations[_txIndex][msg.sender] = false;
        transactions[_txIndex].confirmationCount -= 1;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint256) {
        return transactionCount;
    }

    function getTransaction(uint256 _txIndex) public view returns (address to, uint256 value, bytes memory data, bool executed, uint256 confirmationCount) {

        require(_txIndex < transactionCount, "tx does not exist");

        Transaction storage transaction = transactions[_txIndex];
        return (transaction.to, transaction.value, transaction.data, transaction.executed, transaction.confirmationCount);
    }

    function addOwner(address _owner) public {

        require(isOwner[msg.sender], "not owner");
        require(_owner != address(0), "invalid owner");
        require(!isOwner[_owner], "owner already exists");


        require(_owner != address(0), "invalid owner");
        require(!isOwner[_owner], "owner not unique");

        isOwner[_owner] = true;
        owners.push(_owner);
    }

    function removeOwner(address _owner) public {

        require(isOwner[msg.sender], "not owner");
        require(isOwner[_owner], "not an owner");

        require(owners.length > 1, "cannot remove last owner");
        require(owners.length - 1 >= requiredConfirmations, "would break required confirmations");

        isOwner[_owner] = false;


        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == _owner) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                break;
            }
        }
    }

    function changeRequiredConfirmations(uint256 _requiredConfirmations) public {

        require(isOwner[msg.sender], "not owner");

        require(_requiredConfirmations > 0 && _requiredConfirmations <= owners.length, "invalid required confirmations");

        requiredConfirmations = _requiredConfirmations;
    }

    function isConfirmed(uint256 _txIndex) public view returns (bool) {

        require(_txIndex < transactionCount, "tx does not exist");
        return transactions[_txIndex].confirmationCount >= requiredConfirmations;
    }

    function getConfirmationCount(uint256 _txIndex) public view returns (uint256) {

        require(_txIndex < transactionCount, "tx does not exist");
        return transactions[_txIndex].confirmationCount;
    }

    function getConfirmations(uint256 _txIndex) public view returns (address[] memory _confirmations) {

        require(_txIndex < transactionCount, "tx does not exist");

        address[] memory confirmationsTemp = new address[](owners.length);
        uint256 count = 0;


        for (uint256 i = 0; i < owners.length; i++) {
            if (confirmations[_txIndex][owners[i]]) {
                confirmationsTemp[count] = owners[i];
                count += 1;
            }
        }

        _confirmations = new address[](count);

        for (uint256 i = 0; i < count; i++) {
            _confirmations[i] = confirmationsTemp[i];
        }
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
