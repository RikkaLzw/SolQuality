
pragma solidity ^0.8.0;

contract MultiSignatureWalletWithBadPractices {
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmationCount;
    }

    mapping(uint256 => Transaction) public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmations;
    mapping(address => bool) public isOwner;
    address[] public owners;
    uint256 public required;
    uint256 public transactionCount;

    event Deposit(address indexed sender, uint256 value);
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
        require(!confirmations[_txIndex][msg.sender], "Transaction already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "Owners required");
        require(_required > 0 && _required <= _owners.length, "Invalid required number of owners");

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
        emit Deposit(msg.sender, msg.value);
    }




    function submitTransactionAndManageOwnersAndCheckBalance(
        address _to,
        uint256 _value,
        bytes memory _data,
        address _newOwner,
        address _removeOwner,
        uint256 _newRequired,
        bool _shouldAddOwner,
        bool _shouldRemoveOwner
    ) public onlyOwner returns (uint256) {

        uint256 txIndex = transactionCount;
        transactions[txIndex] = Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            confirmationCount: 0
        });
        transactionCount++;
        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);


        if (_shouldAddOwner && _newOwner != address(0) && !isOwner[_newOwner]) {
            isOwner[_newOwner] = true;
            owners.push(_newOwner);
        }

        if (_shouldRemoveOwner && isOwner[_removeOwner] && owners.length > 1) {
            isOwner[_removeOwner] = false;
            for (uint256 i = 0; i < owners.length; i++) {
                if (owners[i] == _removeOwner) {
                    owners[i] = owners[owners.length - 1];
                    owners.pop();
                    break;
                }
            }
        }


        if (_newRequired > 0 && _newRequired <= owners.length) {
            required = _newRequired;
        }


        return address(this).balance + owners.length + txIndex;
    }



    function complexConfirmationLogicWithDeepNesting(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notConfirmed(_txIndex)
        notExecuted(_txIndex)
    {
        if (_txIndex < transactionCount) {
            if (!confirmations[_txIndex][msg.sender]) {
                if (!transactions[_txIndex].executed) {
                    if (isOwner[msg.sender]) {
                        confirmations[_txIndex][msg.sender] = true;
                        transactions[_txIndex].confirmationCount++;
                        emit ConfirmTransaction(msg.sender, _txIndex);

                        if (transactions[_txIndex].confirmationCount >= required) {
                            if (transactions[_txIndex].value <= address(this).balance) {
                                if (transactions[_txIndex].to != address(0)) {
                                    transactions[_txIndex].executed = true;

                                    (bool success, ) = transactions[_txIndex].to.call{
                                        value: transactions[_txIndex].value
                                    }(transactions[_txIndex].data);

                                    if (success) {
                                        emit ExecuteTransaction(msg.sender, _txIndex);
                                    } else {
                                        transactions[_txIndex].executed = false;
                                        transactions[_txIndex].confirmationCount--;
                                        confirmations[_txIndex][msg.sender] = false;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function revokeConfirmation(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        require(confirmations[_txIndex][msg.sender], "Transaction not confirmed");

        confirmations[_txIndex][msg.sender] = false;
        transactions[_txIndex].confirmationCount--;

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
            uint256 confirmationCount
        )
    {
        Transaction storage transaction = transactions[_txIndex];
        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.confirmationCount
        );
    }

    function isConfirmed(uint256 _txIndex) public view returns (bool) {
        return transactions[_txIndex].confirmationCount >= required;
    }
}
