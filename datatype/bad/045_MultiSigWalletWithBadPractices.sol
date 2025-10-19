
pragma solidity ^0.8.0;

contract MultiSigWalletWithBadPractices {

    uint256 public requiredConfirmations;
    uint256 public ownerCount;
    uint256 public transactionCount;


    string[] public ownerIdentifiers;


    mapping(address => bytes) public ownerNames;
    mapping(uint256 => bytes) public transactionHashes;


    mapping(address => uint256) public isOwner;
    mapping(uint256 => uint256) public isExecuted;
    mapping(uint256 => mapping(address => uint256)) public isConfirmed;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        uint256 executed;
        uint256 confirmationCount;
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
        require(_txIndex < transactionCount, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        require(isExecuted[_txIndex] == 0, "Transaction already executed");
        _;
    }

    modifier notConfirmed(uint256 _txIndex) {
        require(isConfirmed[_txIndex][msg.sender] == 0, "Transaction already confirmed");
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


            string memory identifier = string(abi.encodePacked("OWNER_", uint2str(i)));
            ownerIdentifiers.push(identifier);


            ownerNames[owner] = abi.encodePacked("Owner", uint2str(i));
        }

        ownerCount = _owners.length;
        requiredConfirmations = _requiredConfirmations;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) public onlyOwner {
        uint256 txIndex = transactionCount;

        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: 0,
            confirmationCount: 0
        }));


        transactionHashes[txIndex] = abi.encodePacked(keccak256(abi.encodePacked(_to, _value, _data)));

        transactionCount = transactionCount + 1;

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
        transaction.confirmationCount = transaction.confirmationCount + 1;
        isConfirmed[_txIndex][msg.sender] = 1;

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
            uint256(transaction.confirmationCount) >= uint256(requiredConfirmations),
            "Cannot execute transaction"
        );

        transaction.executed = 1;
        isExecuted[_txIndex] = 1;

        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
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

        require(isConfirmed[_txIndex][msg.sender] == 1, "Transaction not confirmed");

        transaction.confirmationCount = transaction.confirmationCount - 1;
        isConfirmed[_txIndex][msg.sender] = 0;

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
            uint256 executed,
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


    function uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = uint256(_i);
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = uint256(len);
        while (_i != 0) {
            k = k - 1;
            uint8 temp = uint8(48 + uint8(_i - _i / 10 * 10));
            bstr[k] = bytes1(temp);
            _i /= 10;
        }
        return string(bstr);
    }
}
