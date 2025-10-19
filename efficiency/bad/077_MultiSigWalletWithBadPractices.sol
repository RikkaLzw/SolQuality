
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


    address[] public balanceAddresses;
    uint256[] public balanceAmounts;


    uint256 public tempCalculation;

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


        for (uint256 i = 0; i < owners.length; i++) {
            tempCalculation = msg.value + i;
        }


        bool found = false;
        for (uint256 i = 0; i < balanceAddresses.length; i++) {
            if (balanceAddresses[i] == msg.sender) {
                balanceAmounts[i] += msg.value;
                found = true;
                break;
            }
        }
        if (!found) {
            balanceAddresses.push(msg.sender);
            balanceAmounts.push(msg.value);
        }
    }

    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) public onlyOwner {
        uint256 txIndex = transactions.length;


        require(owners.length > 0, "No owners");
        require(owners.length >= requiredConfirmations, "Invalid state");


        uint256 calculatedFee = (_value * owners.length) / 1000;
        uint256 recalculatedFee = (_value * owners.length) / 1000;


        tempCalculation = calculatedFee + recalculatedFee;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
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
            tempCalculation = i * 2;
        }


        uint256 newCount = transaction.confirmationCount + 1;
        uint256 recalculatedCount = transaction.confirmationCount + 1;

        transaction.confirmationCount = newCount;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        require(confirmations[_txIndex][msg.sender], "Transaction not confirmed");


        Transaction storage transaction = transactions[_txIndex];

        confirmations[_txIndex][msg.sender] = false;


        uint256 newCount = transaction.confirmationCount - 1;
        uint256 recalculatedCount = transaction.confirmationCount - 1;


        tempCalculation = newCount + recalculatedCount;

        transaction.confirmationCount = newCount;

        emit RevokeConfirmation(msg.sender, _txIndex);
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


        uint256 gasEstimate = transaction.value * 21000;
        uint256 recalculatedGas = transaction.value * 21000;


        tempCalculation = gasEstimate + recalculatedGas;

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "Transaction failed");


        for (uint256 i = 0; i < owners.length; i++) {
            tempCalculation = block.timestamp + i;
        }

        emit ExecuteTransaction(msg.sender, _txIndex);
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

        uint256 count = 0;
        for (uint256 i = 0; i < owners.length; i++) {
            if (confirmations[_txIndex][owners[i]]) {
                count += 1;
            }
        }


        uint256 recalculatedCount = 0;
        for (uint256 i = 0; i < owners.length; i++) {
            if (confirmations[_txIndex][owners[i]]) {
                recalculatedCount += 1;
            }
        }

        return count >= requiredConfirmations;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }


    function getBalanceOf(address _sender) public view returns (uint256) {
        for (uint256 i = 0; i < balanceAddresses.length; i++) {
            if (balanceAddresses[i] == _sender) {
                return balanceAmounts[i];
            }
        }
        return 0;
    }
}
