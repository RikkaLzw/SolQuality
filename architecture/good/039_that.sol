
pragma solidity ^0.8.0;


contract MultiSigWallet {

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
    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);
    event RequirementChanged(uint256 required);


    uint256 public constant MAX_OWNER_COUNT = 50;
    uint256 public constant MIN_REQUIRED_CONFIRMATIONS = 1;


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

    Transaction[] public transactions;


    mapping(uint256 => mapping(address => bool)) public isConfirmed;


    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not owner");
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

    modifier notConfirmed(uint256 _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "Transaction already confirmed");
        _;
    }

    modifier validRequirement(uint256 _ownerCount, uint256 _required) {
        require(
            _ownerCount <= MAX_OWNER_COUNT &&
            _required >= MIN_REQUIRED_CONFIRMATIONS &&
            _required <= _ownerCount &&
            _ownerCount != 0,
            "Invalid requirement"
        );
        _;
    }


    constructor(address[] memory _owners, uint256 _numConfirmationsRequired)
        validRequirement(_owners.length, _numConfirmationsRequired)
    {
        require(_owners.length > 0, "Owners required");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            _validateOwnerAddress(owner);
            require(!isOwner[owner], "Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
            emit OwnerAdded(owner);
        }

        numConfirmationsRequired = _numConfirmationsRequired;
        emit RequirementChanged(_numConfirmationsRequired);
    }


    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) public onlyOwner returns (uint256 txIndex) {
        txIndex = _addTransaction(_to, _value, _data);
        confirmTransaction(txIndex);
    }


    function confirmTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);

        if (_isConfirmed(_txIndex)) {
            executeTransaction(_txIndex);
        }
    }


    function revokeConfirmation(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        require(isConfirmed[_txIndex][msg.sender], "Transaction not confirmed");

        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }


    function executeTransaction(uint256 _txIndex)
        public
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        require(_isConfirmed(_txIndex), "Cannot execute transaction");

        Transaction storage transaction = transactions[_txIndex];
        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "Transaction failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }


    function addOwner(address _owner)
        public
        onlyWallet
        validRequirement(owners.length + 1, numConfirmationsRequired)
    {
        _validateOwnerAddress(_owner);
        require(!isOwner[_owner], "Owner already exists");

        isOwner[_owner] = true;
        owners.push(_owner);
        emit OwnerAdded(_owner);
    }


    function removeOwner(address _owner) public onlyWallet {
        require(isOwner[_owner], "Owner does not exist");

        isOwner[_owner] = false;
        for (uint256 i = 0; i < owners.length - 1; i++) {
            if (owners[i] == _owner) {
                owners[i] = owners[owners.length - 1];
                break;
            }
        }
        owners.pop();

        if (numConfirmationsRequired > owners.length) {
            changeRequirement(owners.length);
        }

        emit OwnerRemoved(_owner);
    }


    function changeRequirement(uint256 _required)
        public
        onlyWallet
        validRequirement(owners.length, _required)
    {
        numConfirmationsRequired = _required;
        emit RequirementChanged(_required);
    }


    function isConfirmed(uint256 _txIndex) public view returns (bool) {
        return _isConfirmed(_txIndex);
    }


    function getConfirmationCount(uint256 _txIndex)
        public
        view
        returns (uint256 count)
    {
        for (uint256 i = 0; i < owners.length; i++) {
            if (isConfirmed[_txIndex][owners[i]]) {
                count += 1;
            }
        }
    }


    function getTransactionCount(bool _pending, bool _executed)
        public
        view
        returns (uint256 count)
    {
        for (uint256 i = 0; i < transactions.length; i++) {
            if (
                (_pending && !transactions[i].executed) ||
                (_executed && transactions[i].executed)
            ) {
                count += 1;
            }
        }
    }


    function getOwners() public view returns (address[] memory) {
        return owners;
    }


    function getConfirmations(uint256 _txIndex)
        public
        view
        returns (address[] memory _confirmations)
    {
        address[] memory confirmationsTemp = new address[](owners.length);
        uint256 count = 0;
        uint256 i;
        for (i = 0; i < owners.length; i++) {
            if (isConfirmed[_txIndex][owners[i]]) {
                confirmationsTemp[count] = owners[i];
                count += 1;
            }
        }
        _confirmations = new address[](count);
        for (i = 0; i < count; i++) {
            _confirmations[i] = confirmationsTemp[i];
        }
    }


    function getTransactionIds(
        uint256 _from,
        uint256 _to,
        bool _pending,
        bool _executed
    ) public view returns (uint256[] memory _transactionIds) {
        uint256[] memory transactionIdsTemp = new uint256[](transactions.length);
        uint256 count = 0;
        uint256 i;
        for (i = 0; i < transactions.length; i++) {
            if (
                (_pending && !transactions[i].executed) ||
                (_executed && transactions[i].executed)
            ) {
                transactionIdsTemp[count] = i;
                count += 1;
            }
        }
        _transactionIds = new uint256[](count);
        for (i = _from; i < _to && i < count; i++) {
            _transactionIds[i - _from] = transactionIdsTemp[i];
        }
    }


    receive() external payable {
        if (msg.value > 0) {
            emit Deposit(msg.sender, msg.value, address(this).balance);
        }
    }


    function _addTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) internal returns (uint256 txIndex) {
        txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    function _isConfirmed(uint256 _txIndex) internal view returns (bool) {
        uint256 count = 0;
        for (uint256 i = 0; i < owners.length; i++) {
            if (isConfirmed[_txIndex][owners[i]]) {
                count += 1;
            }
            if (count == numConfirmationsRequired) {
                return true;
            }
        }
        return false;
    }

    function _validateOwnerAddress(address _owner) internal pure {
        require(_owner != address(0), "Invalid owner address");
    }

    modifier onlyWallet() {
        require(msg.sender == address(this), "Only wallet");
        _;
    }
}
