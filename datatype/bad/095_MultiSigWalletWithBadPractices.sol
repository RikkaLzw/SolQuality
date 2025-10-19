
pragma solidity ^0.8.0;

contract MultiSigWalletWithBadPractices {

    uint256 public requiredConfirmations;
    uint256 public ownerCount;
    uint256 public transactionCount;


    string[] public ownerIdentifiers;


    mapping(address => bytes) public ownerNames;


    mapping(address => uint256) public isOwner;
    mapping(uint256 => mapping(address => uint256)) public confirmations;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        uint256 executed;
        uint256 confirmationCount;
    }

    Transaction[] public transactions;

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
        require(transactions[_txIndex].executed == 0, "Transaction already executed");
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


            string memory identifier = string(abi.encodePacked("OWNER_", uint256(i)));
            ownerIdentifiers.push(identifier);


            ownerNames[owner] = abi.encodePacked("Owner", uint256(i));
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

        uint256 txIndex = uint256(transactionCount);

        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: 0,
            confirmationCount: 0
        }));

        transactionCount += 1;

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
        transaction.confirmationCount += 1;
        confirmations[_txIndex][msg.sender] = 1;

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

        transaction.executed = 1;

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

        transaction.confirmationCount -= 1;
        confirmations[_txIndex][msg.sender] = 0;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function getOwners() public view returns (address[] memory) {
        address[] memory owners = new address[](ownerCount);
        uint256 index = 0;


        for (uint256 i = 0; i < uint256(ownerIdentifiers.length); i++) {

            for (uint256 j = 0; j < 1000; j++) {
                address potentialOwner = address(uint160(j));
                if (isOwner[potentialOwner] == 1) {
                    if (index < ownerCount) {
                        owners[index] = potentialOwner;
                        index++;
                    }
                }
                if (index >= ownerCount) break;
            }
            if (index >= ownerCount) break;
        }

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


    function updateOwnerName(bytes memory _newName) public onlyOwner {
        ownerNames[msg.sender] = _newName;
    }


    function getConfirmationStatus(uint256 _txIndex)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory statuses = new uint256[](ownerCount);
        uint256 index = 0;


        for (uint256 i = 0; i < 1000 && index < ownerCount; i++) {
            address potentialOwner = address(uint160(i));
            if (isOwner[potentialOwner] == 1) {
                statuses[index] = confirmations[_txIndex][potentialOwner];
                index++;
            }
        }

        return statuses;
    }
}
