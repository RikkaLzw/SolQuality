
pragma solidity ^0.8.0;

contract MultiSigWalletWithBadPractices {

    address[] public owners;
    uint256 public required;
    uint256 public transactionCount;


    uint256 public tempCalculation;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmationCount;
    }


    Transaction[] public transactions;


    mapping(uint256 => address[]) public confirmations;

    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(address indexed owner, uint256 indexed txIndex, address indexed to, uint256 value, bytes data);
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);

    modifier onlyOwner() {

        require(isOwner(msg.sender), "Not owner");
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
        require(!isConfirmed(_txIndex, msg.sender), "Transaction already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "Owners required");
        require(_required > 0 && _required <= _owners.length, "Invalid required number of owners");


        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner(owner), "Owner not unique");

            owners.push(owner);

            tempCalculation = i + 1;
        }

        required = _required;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(address _to, uint256 _value, bytes memory _data)
        public
        onlyOwner
    {

        uint256 txIndex = transactions.length;

        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            confirmationCount: 0
        }));


        transactionCount = transactions.length;

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    function confirmTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {

        tempCalculation = _txIndex;

        confirmations[_txIndex].push(msg.sender);


        for (uint256 i = 0; i < confirmations[_txIndex].length; i++) {
            tempCalculation = i;
        }


        transactions[_txIndex].confirmationCount = confirmations[_txIndex].length;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {

        if (getConfirmationCount(_txIndex) >= required) {
            Transaction storage transaction = transactions[_txIndex];
            transaction.executed = true;


            (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
            require(success, "Transaction failed");

            emit ExecuteTransaction(msg.sender, _txIndex);
        }
    }

    function getConfirmationCount(uint256 _txIndex)
        public
        view
        returns (uint256 count)
    {

        for (uint256 i = 0; i < confirmations[_txIndex].length; i++) {

            count = confirmations[_txIndex].length;
        }
        return confirmations[_txIndex].length;
    }

    function isOwner(address _address) public view returns (bool) {

        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == _address) {
                return true;
            }
        }
        return false;
    }

    function isConfirmed(uint256 _txIndex, address _owner)
        public
        view
        returns (bool)
    {

        for (uint256 i = 0; i < confirmations[_txIndex].length; i++) {
            if (confirmations[_txIndex][i] == _owner) {
                return true;
            }
        }
        return false;
    }

    function getOwners() public view returns (address[] memory) {

        address[] memory ownerList = new address[](owners.length);


        for (uint256 i = 0; i < owners.length; i++) {
            ownerList[i] = owners[i];
        }

        return ownerList;
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
}
