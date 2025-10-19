
pragma solidity ^0.8.0;

contract MultiSigWallet {
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

    error Error1();
    error Error2();
    error Error3();

    event TransactionSubmitted(uint256 transactionId, address to, uint256 value);
    event TransactionConfirmed(uint256 transactionId, address owner);
    event TransactionExecuted(uint256 transactionId);
    event OwnerAdded(address owner);
    event OwnerRemoved(address owner);

    modifier onlyOwner() {
        require(isOwner[msg.sender]);
        _;
    }

    modifier transactionExists(uint256 _transactionId) {
        require(_transactionId < transactionCount);
        _;
    }

    modifier notExecuted(uint256 _transactionId) {
        require(!transactions[_transactionId].executed);
        _;
    }

    modifier notConfirmed(uint256 _transactionId) {
        require(!confirmations[_transactionId][msg.sender]);
        _;
    }

    constructor(address[] memory _owners, uint256 _requiredConfirmations) {
        require(_owners.length > 0);
        require(_requiredConfirmations > 0 && _requiredConfirmations <= _owners.length);

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0));
            require(!isOwner[owner]);

            isOwner[owner] = true;
            owners.push(owner);
        }

        requiredConfirmations = _requiredConfirmations;
    }

    receive() external payable {}

    function submitTransaction(address _to, uint256 _value, bytes memory _data)
        public
        onlyOwner
        returns (uint256)
    {
        uint256 transactionId = transactionCount;

        transactions[transactionId] = Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            confirmationCount: 0
        });

        transactionCount++;

        emit TransactionSubmitted(transactionId, _to, _value);

        return transactionId;
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
    }

    function executeTransaction(uint256 _transactionId)
        public
        onlyOwner
        transactionExists(_transactionId)
        notExecuted(_transactionId)
    {
        Transaction storage txn = transactions[_transactionId];

        if (txn.confirmationCount >= requiredConfirmations) {
            txn.executed = true;

            (bool success, ) = txn.to.call{value: txn.value}(txn.data);
            if (!success) {
                revert Error1();
            }

            emit TransactionExecuted(_transactionId);
        } else {
            revert Error2();
        }
    }

    function revokeConfirmation(uint256 _transactionId)
        public
        onlyOwner
        transactionExists(_transactionId)
        notExecuted(_transactionId)
    {
        require(confirmations[_transactionId][msg.sender]);

        confirmations[_transactionId][msg.sender] = false;
        transactions[_transactionId].confirmationCount--;
    }

    function addOwner(address _owner) public onlyOwner {
        require(_owner != address(0));
        require(!isOwner[_owner]);

        isOwner[_owner] = true;
        owners.push(_owner);

        emit OwnerAdded(_owner);
    }

    function removeOwner(address _owner) public onlyOwner {
        require(isOwner[_owner]);
        require(owners.length > requiredConfirmations);

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

    function changeRequiredConfirmations(uint256 _requiredConfirmations) public onlyOwner {
        require(_requiredConfirmations > 0 && _requiredConfirmations <= owners.length);

        requiredConfirmations = _requiredConfirmations;
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint256) {
        return transactionCount;
    }

    function getTransaction(uint256 _transactionId)
        public
        view
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 confirmationCount
        )
    {
        Transaction storage txn = transactions[_transactionId];
        return (txn.to, txn.value, txn.data, txn.executed, txn.confirmationCount);
    }

    function isConfirmed(uint256 _transactionId, address _owner)
        public
        view
        returns (bool)
    {
        return confirmations[_transactionId][_owner];
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
