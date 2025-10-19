
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
        require(isOwner[msg.sender], "MultiSigWallet: caller is not an owner");
        _;
    }

    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "MultiSigWallet: transaction does not exist");
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed, "MultiSigWallet: transaction already executed");
        _;
    }

    modifier notConfirmed(uint256 _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "MultiSigWallet: transaction already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint256 _numConfirmationsRequired) {
        require(_owners.length > 0, "MultiSigWallet: owners required");
        require(
            _numConfirmationsRequired > 0 && _numConfirmationsRequired <= _owners.length,
            "MultiSigWallet: invalid number of required confirmations"
        );

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "MultiSigWallet: invalid owner address");
            require(!isOwner[owner], "MultiSigWallet: owner not unique");

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
        require(_to != address(0), "MultiSigWallet: invalid recipient address");

        uint256 txIndex = transactions.length;

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

    function confirmTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

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
            transaction.numConfirmations >= numConfirmationsRequired,
            "MultiSigWallet: cannot execute transaction - insufficient confirmations"
        );

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );

        if (!success) {
            revert("MultiSigWallet: transaction execution failed");
        }

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        require(isConfirmed[_txIndex][msg.sender], "MultiSigWallet: transaction not confirmed");

        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
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
        require(_txIndex < transactions.length, "MultiSigWallet: transaction does not exist");

        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }

    function addOwner(address _owner) public onlyOwner {
        require(_owner != address(0), "MultiSigWallet: invalid owner address");
        require(!isOwner[_owner], "MultiSigWallet: owner already exists");


        uint256 txIndex = transactions.length;
        bytes memory data = abi.encodeWithSignature("_addOwner(address)", _owner);

        transactions.push(
            Transaction({
                to: address(this),
                value: 0,
                data: data,
                executed: false,
                numConfirmations: 0
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, address(this), 0, data);
    }

    function _addOwner(address _owner) external {
        require(msg.sender == address(this), "MultiSigWallet: only contract can call this function");
        require(_owner != address(0), "MultiSigWallet: invalid owner address");
        require(!isOwner[_owner], "MultiSigWallet: owner already exists");

        isOwner[_owner] = true;
        owners.push(_owner);

        emit OwnerAdded(_owner);
    }

    function removeOwner(address _owner) public onlyOwner {
        require(isOwner[_owner], "MultiSigWallet: owner does not exist");
        require(owners.length > numConfirmationsRequired, "MultiSigWallet: cannot remove owner - would break confirmation requirement");


        uint256 txIndex = transactions.length;
        bytes memory data = abi.encodeWithSignature("_removeOwner(address)", _owner);

        transactions.push(
            Transaction({
                to: address(this),
                value: 0,
                data: data,
                executed: false,
                numConfirmations: 0
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, address(this), 0, data);
    }

    function _removeOwner(address _owner) external {
        require(msg.sender == address(this), "MultiSigWallet: only contract can call this function");
        require(isOwner[_owner], "MultiSigWallet: owner does not exist");

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

    function changeRequirement(uint256 _required) public onlyOwner {
        require(_required > 0 && _required <= owners.length, "MultiSigWallet: invalid requirement");


        uint256 txIndex = transactions.length;
        bytes memory data = abi.encodeWithSignature("_changeRequirement(uint256)", _required);

        transactions.push(
            Transaction({
                to: address(this),
                value: 0,
                data: data,
                executed: false,
                numConfirmations: 0
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, address(this), 0, data);
    }

    function _changeRequirement(uint256 _required) external {
        require(msg.sender == address(this), "MultiSigWallet: only contract can call this function");
        require(_required > 0 && _required <= owners.length, "MultiSigWallet: invalid requirement");

        numConfirmationsRequired = _required;

        emit RequirementChanged(_required);
    }
}
