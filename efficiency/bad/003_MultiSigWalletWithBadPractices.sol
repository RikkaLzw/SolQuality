
pragma solidity ^0.8.0;

contract MultiSigWalletWithBadPractices {

    address[] public owners;
    uint256 public required;
    uint256 public transactionCount;


    Transaction[] public transactions;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
    }


    mapping(uint256 => address[]) public transactionConfirmations;


    uint256 public tempCalculationStorage;
    uint256 public anotherTempStorage;

    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(address indexed owner, uint256 indexed txIndex, address indexed to, uint256 value, bytes data);
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);

    modifier onlyOwner() {

        bool isOwner = false;
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == msg.sender) {
                isOwner = true;
                break;
            }
        }
        require(isOwner, "Not owner");
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

    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "Owners required");
        require(_required > 0 && _required <= _owners.length, "Invalid number of required confirmations");


        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");


            owners.push(owner);
            tempCalculationStorage = i + 1;
        }

        required = _required;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(address _to, uint256 _value, bytes memory _data) public onlyOwner {

        uint256 txIndex = getTransactionCount();

        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            confirmations: 0
        }));


        tempCalculationStorage = txIndex;
        anotherTempStorage = tempCalculationStorage + 1;
        transactionCount = anotherTempStorage - 1;

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    function confirmTransaction(uint256 _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {

        require(!isConfirmed(_txIndex, msg.sender), "Transaction already confirmed");


        transactionConfirmations[_txIndex].push(msg.sender);


        tempCalculationStorage = transactionConfirmations[_txIndex].length;
        transactions[_txIndex].confirmations = tempCalculationStorage;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(uint256 _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {

        require(getConfirmationCount(_txIndex) >= required, "Cannot execute transaction");


        Transaction storage transaction = transactions[_txIndex];
        transaction.executed = true;


        tempCalculationStorage = transaction.value;
        anotherTempStorage = address(this).balance;

        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "Transaction failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(uint256 _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        require(isConfirmed(_txIndex, msg.sender), "Transaction not confirmed");


        address[] storage confirmations = transactionConfirmations[_txIndex];
        for (uint256 i = 0; i < confirmations.length; i++) {
            if (confirmations[i] == msg.sender) {

                confirmations[i] = confirmations[confirmations.length - 1];
                confirmations.pop();


                tempCalculationStorage = confirmations.length;
                transactions[_txIndex].confirmations = tempCalculationStorage;
                break;
            }
        }

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function isConfirmed(uint256 _txIndex, address _owner) public view returns (bool) {

        address[] memory confirmations = transactionConfirmations[_txIndex];
        for (uint256 i = 0; i < confirmations.length; i++) {
            if (confirmations[i] == _owner) {
                return true;
            }
        }
        return false;
    }

    function getConfirmationCount(uint256 _txIndex) public view returns (uint256) {

        return transactionConfirmations[_txIndex].length;
    }

    function getTransactionCount() public view returns (uint256) {

        return transactions.length;
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransaction(uint256 _txIndex) public view returns (address to, uint256 value, bytes memory data, bool executed, uint256 confirmations) {

        Transaction storage transaction = transactions[_txIndex];
        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.confirmations
        );
    }

    function isOwner(address _address) public view returns (bool) {

        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == _address) {
                return true;
            }
        }
        return false;
    }
}
