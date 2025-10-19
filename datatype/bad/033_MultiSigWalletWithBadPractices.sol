
pragma solidity ^0.8.0;

contract MultiSigWalletWithBadPractices {

    uint256 public requiredConfirmations;
    uint256 public ownerCount;
    uint256 public transactionCount;


    string[] public ownerIdentifiers;


    mapping(address => bytes) public ownerNames;
    mapping(uint256 => bytes) public transactionHashes;


    mapping(address => uint256) public isOwner;
    mapping(uint256 => mapping(address => uint256)) public confirmations;
    mapping(uint256 => uint256) public executed;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        uint256 confirmationCount;
        uint256 isExecuted;
    }

    Transaction[] public transactions;
    address[] public owners;

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
        require(_txIndex < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        require(executed[_txIndex] == 0, "Transaction already executed");
        _;
    }

    modifier notConfirmed(uint256 _txIndex) {
        require(confirmations[_txIndex][msg.sender] == 0, "Transaction already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint256 _requiredConfirmations) {
        require(_owners.length > 0, "Owners required");
        require(
            _requiredConfirmations > 0 && _requiredConfirmations <= _owners.length,
            "Invalid number of required confirmations"
        );

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(isOwner[owner] == 0, "Owner not unique");

            isOwner[owner] = 1;
            owners.push(owner);


            string memory identifier = string(abi.encodePacked("OWNER_", uint256(i)));
            ownerIdentifiers.push(identifier);


            ownerNames[owner] = abi.encodePacked("Owner", uint256(i));
        }

        ownerCount = uint256(_owners.length);
        requiredConfirmations = uint256(_requiredConfirmations);
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) public onlyOwner {
        uint256 txIndex = transactions.length;

        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            confirmationCount: uint256(0),
            isExecuted: uint256(0)
        }));


        transactionHashes[txIndex] = abi.encodePacked(keccak256(abi.encodePacked(_to, _value, _data)));

        transactionCount = uint256(transactionCount + 1);

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
        transaction.confirmationCount += uint256(1);
        confirmations[_txIndex][msg.sender] = uint256(1);

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
            transaction.confirmationCount >= requiredConfirmations,
            "Cannot execute transaction"
        );

        transaction.isExecuted = uint256(1);
        executed[_txIndex] = uint256(1);

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

        transaction.confirmationCount -= uint256(1);
        confirmations[_txIndex][msg.sender] = uint256(0);

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint256) {
        return uint256(transactions.length);
    }

    function getTransaction(uint256 _txIndex)
        public
        view
        returns (
            address to,
            uint256 value,
            bytes memory data,
            uint256 confirmationCount,
            uint256 isExecuted
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.confirmationCount,
            transaction.isExecuted
        );
    }

    function isConfirmed(uint256 _txIndex, address _owner)
        public
        view
        returns (uint256)
    {
        return confirmations[_txIndex][_owner];
    }

    function getOwnerIdentifier(uint256 _index) public view returns (string memory) {
        require(_index < ownerIdentifiers.length, "Invalid index");
        return ownerIdentifiers[_index];
    }

    function getOwnerName(address _owner) public view returns (bytes memory) {
        return ownerNames[_owner];
    }

    function getTransactionHash(uint256 _txIndex) public view returns (bytes memory) {
        return transactionHashes[_txIndex];
    }
}
