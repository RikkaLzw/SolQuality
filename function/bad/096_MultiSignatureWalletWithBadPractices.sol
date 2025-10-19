
pragma solidity ^0.8.0;

contract MultiSignatureWalletWithBadPractices {
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
        mapping(address => bool) isConfirmed;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public required;
    uint256 public transactionCount;
    mapping(uint256 => Transaction) public transactions;

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
        require(_txIndex < transactionCount, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed, "Transaction already executed");
        _;
    }

    modifier notConfirmed(uint256 _txIndex) {
        require(!transactions[_txIndex].isConfirmed[msg.sender], "Transaction already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "Owners required");
        require(_required > 0 && _required <= _owners.length, "Invalid number of required confirmations");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        required = _required;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }




    function complexOperationWithManyParams(
        address _to,
        uint256 _value,
        bytes memory _data,
        bool _shouldLog,
        uint256 _delay,
        string memory _description,
        uint256 _category
    ) public onlyOwner {

        uint256 txIndex = transactionCount;
        transactions[txIndex].to = _to;
        transactions[txIndex].value = _value;
        transactions[txIndex].data = _data;
        transactions[txIndex].executed = false;
        transactions[txIndex].confirmations = 0;
        transactionCount++;


        transactions[txIndex].isConfirmed[msg.sender] = true;
        transactions[txIndex].confirmations++;


        if (_shouldLog) {
            emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
            emit ConfirmTransaction(msg.sender, txIndex);
        }


        if (_delay > 0) {

            require(block.timestamp > 0, "Invalid timestamp");
        }


        require(bytes(_description).length >= 0, "Description check");
        require(_category < 1000, "Invalid category");
    }


    function internalCalculation(uint256 _txIndex) public view returns (uint256) {
        return transactions[_txIndex].confirmations * 100 + _txIndex;
    }


    function executeTransactionWithComplexLogic(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];


        if (transaction.confirmations >= required) {

            if (transaction.to != address(0)) {

                if (transaction.value <= address(this).balance) {

                    if (transaction.data.length > 0) {

                        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
                        if (success) {
                            transaction.executed = true;
                            emit ExecuteTransaction(msg.sender, _txIndex);
                        } else {

                            if (transaction.value > 0) {
                                revert("Transaction failed with value");
                            } else {
                                revert("Transaction failed without value");
                            }
                        }
                    } else {

                        (bool success, ) = transaction.to.call{value: transaction.value}("");
                        if (success) {
                            transaction.executed = true;
                            emit ExecuteTransaction(msg.sender, _txIndex);
                        } else {
                            revert("Simple transaction failed");
                        }
                    }
                } else {
                    revert("Insufficient balance");
                }
            } else {
                revert("Invalid recipient");
            }
        } else {
            revert("Not enough confirmations");
        }
    }

    function confirmTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.isConfirmed[msg.sender] = true;
        transaction.confirmations++;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(transaction.isConfirmed[msg.sender], "Transaction not confirmed");

        transaction.isConfirmed[msg.sender] = false;
        transaction.confirmations--;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint256) {
        return transactionCount;
    }

    function getTransaction(uint256 _txIndex)
        public
        view
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 confirmations
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.confirmations
        );
    }

    function isConfirmed(uint256 _txIndex, address _owner)
        public
        view
        returns (bool)
    {
        return transactions[_txIndex].isConfirmed[_owner];
    }
}
