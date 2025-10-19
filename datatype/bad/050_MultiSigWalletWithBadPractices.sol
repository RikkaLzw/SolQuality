
pragma solidity ^0.8.0;

contract MultiSigWalletWithBadPractices {

    uint256 public requiredConfirmations;
    uint256 public ownerCount;
    uint256 public transactionCount;


    string[] public ownerIdentifiers;


    bytes[] public transactionHashes;

    mapping(address => uint256) public isOwner;
    mapping(uint256 => Transaction) public transactions;
    mapping(uint256 => mapping(address => uint256)) public confirmations;

    address[] public owners;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        uint256 executed;
        uint256 numConfirmations;
    }

    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(
        address indexed owner,
        uint256 indexed txIndex,
        address indexed to,
        uint256 value,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);

    modifier onlyOwner() {
        require(isOwner[msg.sender] == 1, "Not owner");
        _;
    }

    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactionCount, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        require(transactions[_txIndex].executed == 0, "Transaction already executed");
        _;
    }

    modifier notConfirmed(uint256 _txIndex) {
        require(confirmations[_txIndex][msg.sender] == 0, "Transaction already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint256 _numConfirmationsRequired) {
        require(_owners.length > 0, "Owners required");
        require(
            _numConfirmationsRequired > 0 && _numConfirmationsRequired <= _owners.length,
            "Invalid number of required confirmations"
        );

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(isOwner[owner] == 0, "Owner not unique");

            isOwner[owner] = 1;
            owners.push(owner);



            ownerIdentifiers.push(string(abi.encodePacked("OWNER_", uint256(i))));
        }

        ownerCount = uint256(_owners.length);
        requiredConfirmations = _numConfirmationsRequired;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) public onlyOwner {
        uint256 txIndex = transactionCount;


        bytes memory txHash = abi.encodePacked(_to, _value, _data, block.timestamp);
        transactionHashes.push(txHash);

        transactions[txIndex] = Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: 0,
            numConfirmations: uint256(0)
        });

        transactionCount += uint256(1);

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    function confirmTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += uint256(1);
        confirmations[_txIndex][msg.sender] = 1;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.numConfirmations >= requiredConfirmations,
            "Cannot execute transaction"
        );

        transaction.executed = 1;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "Transaction failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(confirmations[_txIndex][msg.sender] == 1, "Transaction not confirmed");

        transaction.numConfirmations -= uint256(1);
        confirmations[_txIndex][msg.sender] = 0;

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
            uint256 executed,
            uint256 numConfirmations
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }


    function getTransactionStatus(uint256 _txIndex) public view returns (uint256) {
        if (transactions[_txIndex].executed == 1) {
            return uint256(2);
        } else if (transactions[_txIndex].numConfirmations >= requiredConfirmations) {
            return uint256(1);
        } else {
            return uint256(0);
        }
    }

    function isConfirmed(uint256 _txIndex, address _owner) public view returns (uint256) {
        return confirmations[_txIndex][_owner];
    }
}
