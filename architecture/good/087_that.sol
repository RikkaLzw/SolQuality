
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract MultiSigWallet is ReentrancyGuard {


    uint256 public constant MAX_OWNER_COUNT = 50;
    uint256 public constant MIN_OWNER_COUNT = 2;


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
    event OwnerAddition(address indexed owner);
    event OwnerRemoval(address indexed owner);
    event RequirementChange(uint256 required);


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
            _required > 0 &&
            _required <= _ownerCount &&
            _ownerCount <= MAX_OWNER_COUNT &&
            _ownerCount >= MIN_OWNER_COUNT,
            "Invalid requirement"
        );
        _;
    }

    modifier ownerDoesNotExist(address _owner) {
        require(!isOwner[_owner], "Owner already exists");
        _;
    }

    modifier ownerExists(address _owner) {
        require(isOwner[_owner], "Owner does not exist");
        _;
    }

    modifier notNull(address _address) {
        require(_address != address(0), "Invalid address");
        _;
    }


    constructor(
        address[] memory _owners,
        uint256 _numConfirmationsRequired
    ) validRequirement(_owners.length, _numConfirmationsRequired) {
        require(_owners.length > 0, "Owners required");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        numConfirmationsRequired = _numConfirmationsRequired;
    }


    receive() external payable {
        if (msg.value > 0) {
            emit Deposit(msg.sender, msg.value, address(this).balance);
        }
    }


    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) public onlyOwner {
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
        nonReentrant
    {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.numConfirmations >= numConfirmationsRequired,
            "Cannot execute transaction"
        );

        transaction.executed = true;

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

        require(isConfirmed[_txIndex][msg.sender], "Transaction not confirmed");

        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }


    function addOwner(address _owner)
        public
        onlyOwner
        ownerDoesNotExist(_owner)
        notNull(_owner)
        validRequirement(owners.length + 1, numConfirmationsRequired)
    {
        isOwner[_owner] = true;
        owners.push(_owner);
        emit OwnerAddition(_owner);
    }


    function removeOwner(address _owner)
        public
        onlyOwner
        ownerExists(_owner)
    {
        require(owners.length > MIN_OWNER_COUNT, "Cannot remove owner");

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

        emit OwnerRemoval(_owner);
    }


    function replaceOwner(address _owner, address _newOwner)
        public
        onlyOwner
        ownerExists(_owner)
        ownerDoesNotExist(_newOwner)
        notNull(_newOwner)
    {
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == _owner) {
                owners[i] = _newOwner;
                break;
            }
        }

        isOwner[_owner] = false;
        isOwner[_newOwner] = true;

        emit OwnerRemoval(_owner);
        emit OwnerAddition(_newOwner);
    }


    function changeRequirement(uint256 _required)
        public
        onlyOwner
        validRequirement(owners.length, _required)
    {
        numConfirmationsRequired = _required;
        emit RequirementChange(_required);
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
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }


    function isTransactionConfirmed(uint256 _txIndex, address _owner)
        public
        view
        returns (bool)
    {
        return isConfirmed[_txIndex][_owner];
    }


    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
