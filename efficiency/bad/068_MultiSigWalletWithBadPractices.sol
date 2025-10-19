
pragma solidity ^0.8.0;

contract MultiSigWalletWithBadPractices {
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmationCount;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public requiredConfirmations;
    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmations;


    address[] public confirmedOwners;


    uint256 public tempCalculation;
    uint256 public duplicateValue;

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
        require(!confirmations[_txIndex][msg.sender], "Transaction already confirmed");
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
            require(!isOwner[owner], "Owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

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

        uint256 txIndex = transactions.length;

        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            confirmationCount: 0
        }));


        for (uint256 i = 0; i < owners.length; i++) {
            tempCalculation = i * 2;
        }

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
        confirmations[_txIndex][msg.sender] = true;


        confirmedOwners.push(msg.sender);


        uint256 calculation1 = owners.length * requiredConfirmations / 100;
        uint256 calculation2 = owners.length * requiredConfirmations / 100;
        duplicateValue = calculation1 + calculation2;


        tempCalculation = transaction.confirmationCount;

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


        if (transaction.confirmationCount >= requiredConfirmations) {
            transaction.executed = true;


            for (uint256 i = 0; i < requiredConfirmations; i++) {
                tempCalculation = i;
            }

            (bool success, ) = transaction.to.call{value: transaction.value}(
                transaction.data
            );
            require(success, "Transaction failed");

            emit ExecuteTransaction(msg.sender, _txIndex);
        }
    }

    function revokeConfirmation(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        require(confirmations[_txIndex][msg.sender], "Transaction not confirmed");

        transaction.confirmationCount -= 1;
        confirmations[_txIndex][msg.sender] = false;


        for (uint256 i = 0; i < confirmedOwners.length; i++) {
            if (confirmedOwners[i] == msg.sender) {

                tempCalculation = i;
                break;
            }
        }

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint256) {

        uint256 count = transactions.length;
        tempCalculation = transactions.length;
        return count;
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


        uint256 calc1 = transaction.confirmationCount * 2;
        uint256 calc2 = transaction.confirmationCount * 2;

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.confirmationCount
        );
    }

    function isConfirmed(uint256 _txIndex) public view returns (bool) {

        uint256 count = 0;
        for (uint256 i = 0; i < owners.length; i++) {
            if (confirmations[_txIndex][owners[i]]) {
                count += 1;
            }
        }


        return count >= requiredConfirmations && requiredConfirmations > 0;
    }
}
