
pragma solidity ^0.8.0;

contract MultiSigWallet {
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public required;
    uint256 public transactionCount;

    mapping(uint256 => Transaction) public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmations;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
    }

    error NotOwner();
    error NotExist();
    error AlreadyExecuted();
    error AlreadyConfirmed();
    error NotConfirmed();

    event Deposit(address sender, uint256 amount);
    event SubmitTransaction(uint256 transactionId);
    event ConfirmTransaction(uint256 transactionId);
    event RevokeConfirmation(uint256 transactionId);
    event ExecuteTransaction(uint256 transactionId);

    modifier onlyOwner() {
        require(isOwner[msg.sender]);
        _;
    }

    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactionCount);
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed);
        _;
    }

    modifier notConfirmed(uint256 _txIndex) {
        require(!confirmations[_txIndex][msg.sender]);
        _;
    }

    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0);
        require(_required > 0 && _required <= _owners.length);

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0));
            require(!isOwner[owner]);

            isOwner[owner] = true;
            owners.push(owner);
        }

        required = _required;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) public onlyOwner {
        uint256 txIndex = transactionCount;

        transactions[txIndex] = Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false
        });

        transactionCount++;
        emit SubmitTransaction(txIndex);
    }

    function confirmTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        confirmations[_txIndex][msg.sender] = true;
        emit ConfirmTransaction(_txIndex);
    }

    function executeTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        require(isConfirmed(_txIndex));

        Transaction storage transaction = transactions[_txIndex];
        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success);

        emit ExecuteTransaction(_txIndex);
    }

    function revokeConfirmation(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        require(confirmations[_txIndex][msg.sender]);

        confirmations[_txIndex][msg.sender] = false;
        emit RevokeConfirmation(_txIndex);
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
            uint256 numConfirmations
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            getConfirmationCount(_txIndex)
        );
    }

    function isConfirmed(uint256 _txIndex) public view returns (bool) {
        uint256 count = 0;
        for (uint256 i = 0; i < owners.length; i++) {
            if (confirmations[_txIndex][owners[i]]) {
                count += 1;
            }
        }
        return count >= required;
    }

    function getConfirmationCount(uint256 _txIndex)
        public
        view
        returns (uint256 count)
    {
        for (uint256 i = 0; i < owners.length; i++) {
            if (confirmations[_txIndex][owners[i]]) {
                count += 1;
            }
        }
    }

    function addOwner(address owner) public {
        require(isConfirmed(transactionCount - 1));
        require(owner != address(0));
        require(!isOwner[owner]);

        isOwner[owner] = true;
        owners.push(owner);
    }

    function removeOwner(address owner) public {
        require(isConfirmed(transactionCount - 1));
        require(isOwner[owner]);
        require(owners.length > 1);

        isOwner[owner] = false;
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == owner) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                break;
            }
        }

        if (required > owners.length) {
            required = owners.length;
        }
    }

    function changeRequirement(uint256 _required) public {
        require(isConfirmed(transactionCount - 1));
        require(_required > 0 && _required <= owners.length);

        required = _required;
    }
}
