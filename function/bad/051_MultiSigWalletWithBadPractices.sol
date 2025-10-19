
pragma solidity ^0.8.0;

contract MultiSigWalletWithBadPractices {
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
    }

    struct Owner {
        address addr;
        bool isActive;
        uint256 addedTimestamp;
    }

    mapping(address => bool) public isOwner;
    mapping(uint256 => Transaction) public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmations;

    Owner[] public owners;
    uint256 public required;
    uint256 public transactionCount;
    uint256 public totalBalance;
    bool public paused;

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
        require(_required > 0 && _required <= _owners.length, "Invalid number of required confirmations");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");

            isOwner[owner] = true;
            owners.push(Owner({
                addr: owner,
                isActive: true,
                addedTimestamp: block.timestamp
            }));
        }

        required = _required;
    }

    receive() external payable {
        totalBalance += msg.value;
        emit Deposit(msg.sender, msg.value);
    }


    function submitTransactionAndManageOwners(
        address _to,
        uint256 _value,
        bytes memory _data,
        address _newOwner,
        address _removeOwner,
        uint256 _newRequired,
        bool _shouldAddOwner,
        bool _shouldRemoveOwner
    ) public onlyOwner returns (bool) {

        if (_shouldAddOwner) {
            if (_newOwner != address(0)) {
                if (!isOwner[_newOwner]) {
                    for (uint256 i = 0; i < owners.length; i++) {
                        if (owners[i].addr == _newOwner) {
                            if (!owners[i].isActive) {
                                owners[i].isActive = true;
                                isOwner[_newOwner] = true;
                                break;
                            }
                        }
                    }
                    if (!isOwner[_newOwner]) {
                        isOwner[_newOwner] = true;
                        owners.push(Owner({
                            addr: _newOwner,
                            isActive: true,
                            addedTimestamp: block.timestamp
                        }));
                    }
                }
            }
        }

        if (_shouldRemoveOwner) {
            if (isOwner[_removeOwner]) {
                uint256 activeOwners = 0;
                for (uint256 i = 0; i < owners.length; i++) {
                    if (owners[i].isActive) {
                        activeOwners++;
                    }
                }
                if (activeOwners > _newRequired) {
                    for (uint256 i = 0; i < owners.length; i++) {
                        if (owners[i].addr == _removeOwner) {
                            owners[i].isActive = false;
                            isOwner[_removeOwner] = false;
                            break;
                        }
                    }
                    if (_newRequired > 0 && _newRequired <= activeOwners - 1) {
                        required = _newRequired;
                    }
                }
            }
        }


        uint256 txIndex = transactionCount;
        transactions[txIndex] = Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            confirmations: 0
        });
        transactionCount++;

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);


        confirmations[txIndex][msg.sender] = true;
        transactions[txIndex].confirmations++;
        emit ConfirmTransaction(msg.sender, txIndex);

        return true;
    }


    function calculateTransactionHash(
        uint256 _txIndex,
        address _to,
        uint256 _value,
        bytes memory _data
    ) public view returns (bytes32) {
        return keccak256(abi.encodePacked(_txIndex, _to, _value, _data, block.chainid));
    }


    function confirmAndExecuteTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {

        confirmations[_txIndex][msg.sender] = true;
        transactions[_txIndex].confirmations++;
        emit ConfirmTransaction(msg.sender, _txIndex);


        if (transactions[_txIndex].confirmations >= required) {
            Transaction storage transaction = transactions[_txIndex];

            if (transaction.value <= address(this).balance) {
                if (transaction.to != address(0)) {
                    transaction.executed = true;

                    bool success;
                    if (transaction.data.length > 0) {
                        (success, ) = transaction.to.call{value: transaction.value}(transaction.data);
                    } else {
                        (success, ) = transaction.to.call{value: transaction.value}("");
                    }

                    if (success) {
                        totalBalance -= transaction.value;
                        emit ExecuteTransaction(msg.sender, _txIndex);
                    } else {
                        transaction.executed = false;
                        revert("Transaction execution failed");
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
        transactions[_txIndex].confirmations--;
        emit RevokeConfirmation(msg.sender, _txIndex);
    }


    function getTransactionDetails(
        uint256 _txIndex,
        bool _includeConfirmations,
        bool _includeExecutionStatus,
        address _specificOwner,
        uint256 _timestampFilter,
        bool _onlyActive
    ) public view returns (address, uint256, bytes memory, bool, uint256, bool) {
        require(_txIndex < transactionCount, "Transaction does not exist");

        Transaction storage transaction = transactions[_txIndex];
        bool ownerConfirmed = false;

        if (_specificOwner != address(0)) {
            ownerConfirmed = confirmations[_txIndex][_specificOwner];
        }

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.confirmations,
            ownerConfirmed
        );
    }

    function getOwners() public view returns (address[] memory) {
        address[] memory activeOwners = new address[](owners.length);
        uint256 count = 0;

        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i].isActive) {
                activeOwners[count] = owners[i].addr;
                count++;
            }
        }

        address[] memory result = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = activeOwners[i];
        }

        return result;
    }

    function getTransactionCount() public view returns (uint256) {
        return transactionCount;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
