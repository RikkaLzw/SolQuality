
pragma solidity ^0.8.0;


contract MultiSignatureWallet {

    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(
        address indexed owner,
        uint256 indexed transactionId,
        address indexed to,
        uint256 value,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint256 indexed transactionId);
    event RevokeConfirmation(address indexed owner, uint256 indexed transactionId);
    event ExecuteTransaction(address indexed owner, uint256 indexed transactionId);


    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public numConfirmationsRequired;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
    }


    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    Transaction[] public transactions;


    modifier onlyOwner() {
        require(isOwner[msg.sender], "MultiSignatureWallet: not owner");
        _;
    }

    modifier transactionExists(uint256 _transactionId) {
        require(_transactionId < transactions.length, "MultiSignatureWallet: transaction does not exist");
        _;
    }

    modifier notExecuted(uint256 _transactionId) {
        require(!transactions[_transactionId].executed, "MultiSignatureWallet: transaction already executed");
        _;
    }

    modifier notConfirmed(uint256 _transactionId) {
        require(!isConfirmed[_transactionId][msg.sender], "MultiSignatureWallet: transaction already confirmed");
        _;
    }


    constructor(address[] memory _owners, uint256 _numConfirmationsRequired) {
        require(_owners.length > 0, "MultiSignatureWallet: owners required");
        require(
            _numConfirmationsRequired > 0 && _numConfirmationsRequired <= _owners.length,
            "MultiSignatureWallet: invalid number of required confirmations"
        );

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "MultiSignatureWallet: invalid owner");
            require(!isOwner[owner], "MultiSignatureWallet: owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        numConfirmationsRequired = _numConfirmationsRequired;
    }


    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }


    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) public onlyOwner {
        uint256 transactionId = addTransaction(_to, _value, _data);
        confirmTransaction(transactionId);
    }


    function confirmTransaction(uint256 _transactionId)
        public
        onlyOwner
        transactionExists(_transactionId)
        notExecuted(_transactionId)
        notConfirmed(_transactionId)
    {
        Transaction storage transaction = transactions[_transactionId];
        transaction.numConfirmations += 1;
        isConfirmed[_transactionId][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _transactionId);
    }


    function executeTransaction(uint256 _transactionId)
        public
        onlyOwner
        transactionExists(_transactionId)
        notExecuted(_transactionId)
    {
        Transaction storage transaction = transactions[_transactionId];

        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "MultiSignatureWallet: cannot execute transaction"
        );

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "MultiSignatureWallet: transaction failed");

        emit ExecuteTransaction(msg.sender, _transactionId);
    }


    function revokeConfirmation(uint256 _transactionId)
        public
        onlyOwner
        transactionExists(_transactionId)
        notExecuted(_transactionId)
    {
        Transaction storage transaction = transactions[_transactionId];

        require(isConfirmed[_transactionId][msg.sender], "MultiSignatureWallet: transaction not confirmed");

        transaction.numConfirmations -= 1;
        isConfirmed[_transactionId][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _transactionId);
    }


    function getOwners() public view returns (address[] memory) {
        return owners;
    }


    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }


    function getTransaction(uint256 _transactionId)
        public
        view
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 numConfirmations
        )
    {
        Transaction storage transaction = transactions[_transactionId];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }


    function addTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) internal returns (uint256) {
        uint256 transactionId = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0
            })
        );

        emit SubmitTransaction(msg.sender, transactionId, _to, _value, _data);

        return transactionId;
    }
}
