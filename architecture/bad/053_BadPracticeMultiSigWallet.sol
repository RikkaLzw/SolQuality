
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
        mapping(address => bool) isConfirmed;
    }

    mapping(uint256 => Transaction) public transactions;

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
        transactions[txIndex].to = _to;
        transactions[txIndex].value = _value;
        transactions[txIndex].data = _data;
        transactions[txIndex].executed = false;
        transactions[txIndex].confirmationCount = 0;

        transactionCount++;

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    function confirmTransaction(uint256 _txIndex) public {

        require(isOwner[msg.sender], "not owner");

        require(_txIndex < transactionCount, "tx does not exist");
        require(!transactions[_txIndex].isConfirmed[msg.sender], "tx already confirmed");

        transactions[_txIndex].isConfirmed[msg.sender] = true;
        transactions[_txIndex].confirmationCount++;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(uint256 _txIndex) public {

        require(isOwner[msg.sender], "not owner");

        require(_txIndex < transactionCount, "tx does not exist");
        require(!transactions[_txIndex].executed, "tx already executed");

        require(transactions[_txIndex].confirmationCount >= requiredConfirmations, "cannot execute tx");

        transactions[_txIndex].executed = true;

        (bool success, ) = transactions[_txIndex].to.call{value: transactions[_txIndex].value}(transactions[_txIndex].data);
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(uint256 _txIndex) public {

        require(isOwner[msg.sender], "not owner");

        require(_txIndex < transactionCount, "tx does not exist");
        require(transactions[_txIndex].isConfirmed[msg.sender], "tx not confirmed");

        transactions[_txIndex].isConfirmed[msg.sender] = false;
        transactions[_txIndex].confirmationCount--;

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

    function isConfirmed(uint256 _txIndex, address _owner) public view returns (bool) {

        require(_txIndex < transactionCount, "tx does not exist");
        return transactions[_txIndex].isConfirmed[_owner];
    }

    function addOwner(address _owner) public {

        require(isOwner[msg.sender], "not owner");
        require(_owner != address(0), "invalid owner");
        require(!isOwner[_owner], "owner already exists");

        require(owners.length < 10, "too many owners");


        uint256 txIndex = transactionCount;
        bytes memory data = abi.encodeWithSignature("addOwnerInternal(address)", _owner);
        transactions[txIndex].to = address(this);
        transactions[txIndex].value = 0;
        transactions[txIndex].data = data;
        transactions[txIndex].executed = false;
        transactions[txIndex].confirmationCount = 1;
        transactions[txIndex].isConfirmed[msg.sender] = true;

        transactionCount++;

        emit SubmitTransaction(msg.sender, txIndex, address(this), 0, data);
        emit ConfirmTransaction(msg.sender, txIndex);
    }

    function addOwnerInternal(address _owner) public {
        require(msg.sender == address(this), "only contract can call");
        isOwner[_owner] = true;
        owners.push(_owner);
    }

    function removeOwner(address _owner) public {

        require(isOwner[msg.sender], "not owner");
        require(isOwner[_owner], "not an owner");

        require(owners.length > 1, "cannot remove last owner");
        require(owners.length - 1 >= requiredConfirmations, "would break required confirmations");


        uint256 txIndex = transactionCount;
        bytes memory data = abi.encodeWithSignature("removeOwnerInternal(address)", _owner);
        transactions[txIndex].to = address(this);
        transactions[txIndex].value = 0;
        transactions[txIndex].data = data;
        transactions[txIndex].executed = false;
        transactions[txIndex].confirmationCount = 1;
        transactions[txIndex].isConfirmed[msg.sender] = true;

        transactionCount++;

        emit SubmitTransaction(msg.sender, txIndex, address(this), 0, data);
        emit ConfirmTransaction(msg.sender, txIndex);
    }

    function removeOwnerInternal(address _owner) public {
        require(msg.sender == address(this), "only contract can call");
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


        uint256 txIndex = transactionCount;
        bytes memory data = abi.encodeWithSignature("changeRequiredConfirmationsInternal(uint256)", _requiredConfirmations);
        transactions[txIndex].to = address(this);
        transactions[txIndex].value = 0;
        transactions[txIndex].data = data;
        transactions[txIndex].executed = false;
        transactions[txIndex].confirmationCount = 1;
        transactions[txIndex].isConfirmed[msg.sender] = true;

        transactionCount++;

        emit SubmitTransaction(msg.sender, txIndex, address(this), 0, data);
        emit ConfirmTransaction(msg.sender, txIndex);
    }

    function changeRequiredConfirmationsInternal(uint256 _requiredConfirmations) public {
        require(msg.sender == address(this), "only contract can call");
        requiredConfirmations = _requiredConfirmations;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function emergencyWithdraw() public {

        require(isOwner[msg.sender], "not owner");

        require(address(this).balance > 0, "no balance");


        uint256 confirmCount = 0;
        for (uint256 i = 0; i < owners.length; i++) {

            confirmCount++;
        }

        require(confirmCount == owners.length, "need all owners confirmation");

        payable(msg.sender).transfer(address(this).balance);
    }
}
