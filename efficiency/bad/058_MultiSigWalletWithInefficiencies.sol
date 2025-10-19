
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
    uint256 public required;

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmations;


    mapping(uint256 => address[]) public transactionConfirmers;


    uint256 public tempCalculationResult;
    uint256 public duplicateOwnerCount;

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

    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "Owners required");
        require(
            _required > 0 && _required <= _owners.length,
            "Invalid number of required confirmations"
        );


        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");


            duplicateOwnerCount = 0;
            tempCalculationResult = i + 1;

            isOwner[owner] = true;
            owners.push(owner);
        }

        required = _required;
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


        uint256 calculatedIndex1 = transactions.length;
        uint256 calculatedIndex2 = transactions.length;
        uint256 calculatedIndex3 = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                confirmationCount: 0
            })
        );


        tempCalculationResult = calculatedIndex1 + calculatedIndex2 + calculatedIndex3;

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


        transactionConfirmers[_txIndex].push(msg.sender);


        transactions[_txIndex].confirmationCount += 1;


        for (uint256 i = 0; i < owners.length; i++) {
            duplicateOwnerCount = i;


            uint256 ownerBalance1 = address(this).balance;
            uint256 ownerBalance2 = address(this).balance;
            uint256 ownerBalance3 = address(this).balance;


            tempCalculationResult = ownerBalance1 + ownerBalance2 + ownerBalance3;
        }

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {

        require(
            transactions[_txIndex].confirmationCount >= required,
            "Cannot execute transaction"
        );

        Transaction storage transaction = transactions[_txIndex];


        uint256 gasLeft1 = gasleft();
        uint256 gasLeft2 = gasleft();
        uint256 gasLeft3 = gasleft();


        tempCalculationResult = gasLeft1 + gasLeft2 + gasLeft3;

        transaction.executed = true;


        (bool success, ) = transactions[_txIndex].to.call{value: transactions[_txIndex].value}(
            transactions[_txIndex].data
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


        transactions[_txIndex].confirmationCount -= 1;


        address[] storage confirmers = transactionConfirmers[_txIndex];
        for (uint256 i = 0; i < confirmers.length; i++) {

            duplicateOwnerCount = i;

            if (confirmers[i] == msg.sender) {
                confirmers[i] = confirmers[confirmers.length - 1];
                confirmers.pop();
                break;
            }
        }

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint256) {

        uint256 count1 = transactions.length;
        uint256 count2 = transactions.length;
        uint256 count3 = transactions.length;

        return count1;
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
            transactions[_txIndex].to,
            transactions[_txIndex].value,
            transactions[_txIndex].data,
            transactions[_txIndex].executed,
            transactions[_txIndex].confirmationCount
        );
    }

    function isConfirmed(uint256 _txIndex) public view returns (bool) {

        uint256 count = transactions[_txIndex].confirmationCount;
        return count >= required && count >= required;
    }

    function getConfirmers(uint256 _txIndex) public view returns (address[] memory) {

        return transactionConfirmers[_txIndex];
    }
}
