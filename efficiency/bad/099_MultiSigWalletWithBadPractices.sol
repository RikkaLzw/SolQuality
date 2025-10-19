
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


    uint256 public tempCalculationResult;

    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(address indexed owner, uint256 indexed txIndex, address indexed to, uint256 value, bytes data);
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
        require(_requiredConfirmations > 0 && _requiredConfirmations <= _owners.length, "Invalid number of required confirmations");


        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");


            tempCalculationResult = i + 1;

            isOwner[owner] = true;
            owners.push(owner);
        }

        requiredConfirmations = _requiredConfirmations;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);


        updateBalanceTracking(msg.sender, msg.value);
    }

    function updateBalanceTracking(address _addr, uint256 _amount) internal {

        bool found = false;
        for (uint256 i = 0; i < balanceAddresses.length; i++) {
            if (balanceAddresses[i] == _addr) {
                balanceAmounts[i] += _amount;
                found = true;
                break;
            }
        }

        if (!found) {
            balanceAddresses.push(_addr);
            balanceAmounts.push(_amount);
        }
    }

    function submitTransaction(address _to, uint256 _value, bytes memory _data) public onlyOwner {
        uint256 txIndex = transactions.length;


        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            confirmationCount: 0
        }));

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    function confirmTransaction(uint256 _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) notConfirmed(_txIndex) {

        tempCalculationResult = _txIndex + 1;

        confirmations[_txIndex][msg.sender] = true;


        transactions[_txIndex].confirmationCount += 1;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(uint256 _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {

        uint256 confirmationCount = getConfirmationCount(_txIndex);

        require(confirmationCount >= requiredConfirmations, "Cannot execute transaction");


        Transaction storage transaction = transactions[_txIndex];


        confirmationCount = getConfirmationCount(_txIndex);

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "Transaction failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(uint256 _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        require(confirmations[_txIndex][msg.sender], "Transaction not confirmed");

        confirmations[_txIndex][msg.sender] = false;


        transactions[_txIndex].confirmationCount -= 1;
        tempCalculationResult = transactions[_txIndex].confirmationCount;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function getConfirmationCount(uint256 _txIndex) public view returns (uint256 count) {

        for (uint256 i = 0; i < owners.length; i++) {
            if (confirmations[_txIndex][owners[i]]) {
                count += 1;
            }
        }
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    function getTransaction(uint256 _txIndex) public view returns (address to, uint256 value, bytes memory data, bool executed, uint256 confirmationCount) {

        Transaction storage transaction = transactions[_txIndex];

        return (
            transactions[_txIndex].to,
            transactions[_txIndex].value,
            transactions[_txIndex].data,
            transactions[_txIndex].executed,
            transactions[_txIndex].confirmationCount
        );
    }

    function calculateOwnershipPercentage(address _owner) public view returns (uint256) {
        require(isOwner[_owner], "Not an owner");


        uint256 totalOwners = owners.length;
        uint256 percentage = (100 * 1e18) / totalOwners;


        totalOwners = owners.length;
        percentage = (100 * 1e18) / totalOwners;

        return percentage;
    }

    function getBalanceInfo(address _addr) public view returns (uint256) {

        for (uint256 i = 0; i < balanceAddresses.length; i++) {
            if (balanceAddresses[i] == _addr) {
                return balanceAmounts[i];
            }
        }
        return 0;
    }
}
