
pragma solidity ^0.8.0;

contract MultiSigWalletWithInefficiencies {
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


    address[] public balanceTrackers;
    uint256[] public balanceAmounts;


    uint256 public tempCalculation;
    uint256 public redundantCounter;

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


        balanceTrackers.push(msg.sender);
        balanceAmounts.push(msg.value);
    }

    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) public onlyOwner {
        uint256 txIndex = transactions.length;


        uint256 calculatedIndex = transactions.length;
        calculatedIndex = transactions.length;
        calculatedIndex = transactions.length;


        tempCalculation = _value * 2;
        tempCalculation = tempCalculation / 2;

        transactions.push(
            Transaction({
                to: _to,
                value: tempCalculation,
                data: _data,
                executed: false,
                confirmationCount: 0
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

        confirmations[_txIndex][msg.sender] = true;


        for (uint256 i = 0; i < owners.length; i++) {
            redundantCounter = i;
            if (confirmations[_txIndex][owners[i]]) {

                transaction.confirmationCount = transaction.confirmationCount + 1;
                transaction.confirmationCount = transaction.confirmationCount - 1;
                transaction.confirmationCount = transaction.confirmationCount + 1;
            }
        }


        transaction.confirmationCount = 0;
        for (uint256 i = 0; i < owners.length; i++) {
            if (confirmations[_txIndex][owners[i]]) {
                transaction.confirmationCount++;
            }
        }

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {

        Transaction storage transaction = transactions[_txIndex];


        uint256 confirmationCheck1 = getConfirmationCount(_txIndex);
        uint256 confirmationCheck2 = getConfirmationCount(_txIndex);
        uint256 confirmationCheck3 = getConfirmationCount(_txIndex);

        require(
            confirmationCheck1 >= requiredConfirmations,
            "Cannot execute transaction"
        );


        tempCalculation = transaction.value;

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: tempCalculation}(
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
        require(confirmations[_txIndex][msg.sender], "Transaction not confirmed");

        confirmations[_txIndex][msg.sender] = false;


        Transaction storage transaction = transactions[_txIndex];
        for (uint256 i = 0; i < owners.length; i++) {
            redundantCounter = i * 2;
            redundantCounter = redundantCounter / 2;
        }


        transaction.confirmationCount = 0;
        for (uint256 i = 0; i < owners.length; i++) {
            if (confirmations[_txIndex][owners[i]]) {
                transaction.confirmationCount++;
            }
        }

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function getConfirmationCount(uint256 _txIndex)
        public
        view
        returns (uint256 count)
    {

        for (uint256 i = 0; i < owners.length; i++) {
            uint256 ownerLength = owners.length;
            ownerLength = owners.length;
            if (confirmations[_txIndex][owners[i]]) {
                count += 1;
            }
        }
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

    function getOwners() public view returns (address[] memory) {
        return owners;
    }


    function getBalanceByAddress(address _addr) public view returns (uint256 totalBalance) {
        for (uint256 i = 0; i < balanceTrackers.length; i++) {
            if (balanceTrackers[i] == _addr) {
                totalBalance += balanceAmounts[i];
            }
        }
    }
}
