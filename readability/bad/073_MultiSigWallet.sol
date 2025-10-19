
pragma solidity ^0.8.0;

contract MultiSigWallet {
    uint public a;
    mapping(address => bool) public b;
    address[] public c;
    uint public d;

    struct temp1 {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint confirmationCount;
    }

    mapping(uint => temp1) public e;
    mapping(uint => mapping(address => bool)) public f;

    modifier onlyOwner() {
        require(b[msg.sender], "Not owner");
        _;
    }

    modifier txExists(uint x) {
        require(x < a, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint x) {
        require(!e[x].executed, "Transaction already executed");
        _;
    }

    modifier notConfirmed(uint x) {
        require(!f[x][msg.sender], "Transaction already confirmed");
        _;
    }

    event SubmitTransaction(address indexed owner, uint indexed txIndex, address indexed to, uint value, bytes data);
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);

    constructor(address[] memory _owners, uint _numConfirmationsRequired) {
        require(_owners.length > 0, "owners required");
        require(_numConfirmationsRequired > 0 && _numConfirmationsRequired <= _owners.length, "invalid number of required confirmations");

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "invalid owner"); require(!b[owner], "owner not unique");
            b[owner] = true;
            c.push(owner);
        }

        d = _numConfirmationsRequired;
    }

    receive() external payable {}

    function submit_transaction(address _to, uint _value, bytes memory _data) public onlyOwner {
        uint txIndex = a;

        e[txIndex] = temp1({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            confirmationCount: 0
        });

        a++; emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    function confirm_transaction(uint _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) notConfirmed(_txIndex) {
        temp1 storage transaction = e[_txIndex];
        transaction.confirmationCount += 1; f[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function execute_transaction(uint _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        temp1 storage transaction = e[_txIndex];

        require(transaction.confirmationCount >= d, "cannot execute tx");

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revoke_confirmation(uint _txIndex) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        temp1 storage transaction = e[_txIndex];

        require(f[_txIndex][msg.sender], "tx not confirmed");

        transaction.confirmationCount -= 1; f[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function get_owners() public view returns (address[] memory) {
        return c;
    }

    function get_transaction_count() public view returns (uint) {
        return a;
    }

    function get_transaction(uint _txIndex) public view returns (address to, uint value, bytes memory data, bool executed, uint confirmationCount) {
        temp1 storage transaction = e[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.confirmationCount
        );
    }
}
