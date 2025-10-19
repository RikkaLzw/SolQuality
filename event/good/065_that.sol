
pragma solidity ^0.8.0;


contract MultiSigWallet {

    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);
    event RequiredConfirmationsChanged(uint256 indexed newRequired);
    event TransactionSubmitted(uint256 indexed transactionId, address indexed submitter, address indexed to, uint256 value, bytes data);
    event TransactionConfirmed(uint256 indexed transactionId, address indexed owner);
    event TransactionRevoked(uint256 indexed transactionId, address indexed owner);
    event TransactionExecuted(uint256 indexed transactionId, address indexed executor);
    event Deposit(address indexed sender, uint256 value);


    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmationCount;
    }


    mapping(address => bool) public isOwner;
    address[] public owners;
    uint256 public required;

    mapping(uint256 => Transaction) public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmations;
    uint256 public transactionCount;


    modifier onlyOwner() {
        require(isOwner[msg.sender], "MultiSigWallet: caller is not an owner");
        _;
    }

    modifier transactionExists(uint256 _transactionId) {
        require(_transactionId < transactionCount, "MultiSigWallet: transaction does not exist");
        _;
    }

    modifier notExecuted(uint256 _transactionId) {
        require(!transactions[_transactionId].executed, "MultiSigWallet: transaction already executed");
        _;
    }

    modifier notConfirmed(uint256 _transactionId) {
        require(!confirmations[_transactionId][msg.sender], "MultiSigWallet: transaction already confirmed by this owner");
        _;
    }

    modifier confirmed(uint256 _transactionId) {
        require(confirmations[_transactionId][msg.sender], "MultiSigWallet: transaction not confirmed by this owner");
        _;
    }


    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "MultiSigWallet: owners list cannot be empty");
        require(_required > 0 && _required <= _owners.length, "MultiSigWallet: invalid required confirmations count");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "MultiSigWallet: invalid owner address");
            require(!isOwner[owner], "MultiSigWallet: duplicate owner");

            isOwner[owner] = true;
            owners.push(owner);
            emit OwnerAdded(owner);
        }

        required = _required;
        emit RequiredConfirmationsChanged(_required);
    }


    receive() external payable {
        if (msg.value > 0) {
            emit Deposit(msg.sender, msg.value);
        }
    }


    function submitTransaction(address _to, uint256 _value, bytes memory _data)
        public
        onlyOwner
        returns (uint256 transactionId)
    {
        require(_to != address(0), "MultiSigWallet: invalid destination address");

        transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            confirmationCount: 0
        });
        transactionCount++;

        emit TransactionSubmitted(transactionId, msg.sender, _to, _value, _data);


        confirmTransaction(transactionId);
    }


    function confirmTransaction(uint256 _transactionId)
        public
        onlyOwner
        transactionExists(_transactionId)
        notExecuted(_transactionId)
        notConfirmed(_transactionId)
    {
        confirmations[_transactionId][msg.sender] = true;
        transactions[_transactionId].confirmationCount++;

        emit TransactionConfirmed(_transactionId, msg.sender);


        if (isConfirmed(_transactionId)) {
            executeTransaction(_transactionId);
        }
    }


    function revokeConfirmation(uint256 _transactionId)
        public
        onlyOwner
        transactionExists(_transactionId)
        notExecuted(_transactionId)
        confirmed(_transactionId)
    {
        confirmations[_transactionId][msg.sender] = false;
        transactions[_transactionId].confirmationCount--;

        emit TransactionRevoked(_transactionId, msg.sender);
    }


    function executeTransaction(uint256 _transactionId)
        public
        onlyOwner
        transactionExists(_transactionId)
        notExecuted(_transactionId)
    {
        require(isConfirmed(_transactionId), "MultiSigWallet: transaction not sufficiently confirmed");

        Transaction storage txn = transactions[_transactionId];
        txn.executed = true;

        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        require(success, "MultiSigWallet: transaction execution failed");

        emit TransactionExecuted(_transactionId, msg.sender);
    }


    function isConfirmed(uint256 _transactionId) public view returns (bool) {
        return transactions[_transactionId].confirmationCount >= required;
    }


    function addOwner(address _owner) external {
        require(msg.sender == address(this), "MultiSigWallet: can only be called by wallet itself");
        require(_owner != address(0), "MultiSigWallet: invalid owner address");
        require(!isOwner[_owner], "MultiSigWallet: owner already exists");

        isOwner[_owner] = true;
        owners.push(_owner);

        emit OwnerAdded(_owner);
    }


    function removeOwner(address _owner) external {
        require(msg.sender == address(this), "MultiSigWallet: can only be called by wallet itself");
        require(isOwner[_owner], "MultiSigWallet: address is not an owner");
        require(owners.length > required, "MultiSigWallet: cannot remove owner, would break required confirmations");

        isOwner[_owner] = false;


        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == _owner) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                break;
            }
        }

        emit OwnerRemoved(_owner);
    }


    function changeRequiredConfirmations(uint256 _required) external {
        require(msg.sender == address(this), "MultiSigWallet: can only be called by wallet itself");
        require(_required > 0 && _required <= owners.length, "MultiSigWallet: invalid required confirmations count");

        required = _required;
        emit RequiredConfirmationsChanged(_required);
    }


    function getOwners() external view returns (address[] memory) {
        return owners;
    }


    function getTransaction(uint256 _transactionId)
        external
        view
        returns (address to, uint256 value, bytes memory data, bool executed, uint256 confirmationCount)
    {
        Transaction storage txn = transactions[_transactionId];
        return (txn.to, txn.value, txn.data, txn.executed, txn.confirmationCount);
    }


    function getConfirmation(uint256 _transactionId, address _owner) external view returns (bool) {
        return confirmations[_transactionId][_owner];
    }


    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
