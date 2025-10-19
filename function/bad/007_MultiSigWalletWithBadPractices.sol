
pragma solidity ^0.8.0;

contract MultiSigWalletWithBadPractices {
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
    }

    mapping(address => bool) public isOwner;
    mapping(uint256 => mapping(address => bool)) public confirmations;
    mapping(address => uint256) public ownerIndex;

    address[] public owners;
    uint256 public required;
    Transaction[] public transactions;

    event Deposit(address indexed sender, uint256 amount);
    event Submission(uint256 indexed transactionId);
    event Confirmation(address indexed sender, uint256 indexed transactionId);
    event Execution(uint256 indexed transactionId);
    event OwnerAddition(address indexed owner);
    event OwnerRemoval(address indexed owner);
    event RequirementChange(uint256 required);

    modifier onlyWallet() {
        require(msg.sender == address(this), "Only wallet can call this function");
        _;
    }

    modifier ownerExists(address owner) {
        require(isOwner[owner], "Owner does not exist");
        _;
    }

    modifier transactionExists(uint256 transactionId) {
        require(transactionId < transactions.length, "Transaction does not exist");
        _;
    }

    modifier confirmed(uint256 transactionId, address owner) {
        require(confirmations[transactionId][owner], "Transaction not confirmed by owner");
        _;
    }

    modifier notConfirmed(uint256 transactionId, address owner) {
        require(!confirmations[transactionId][owner], "Transaction already confirmed by owner");
        _;
    }

    modifier notExecuted(uint256 transactionId) {
        require(!transactions[transactionId].executed, "Transaction already executed");
        _;
    }

    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "Owners required");
        require(_required > 0 && _required <= _owners.length, "Invalid required number of owners");

        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "Invalid owner");
            require(!isOwner[_owners[i]], "Owner not unique");

            isOwner[_owners[i]] = true;
            ownerIndex[_owners[i]] = i;
            owners.push(_owners[i]);
        }

        required = _required;
    }

    receive() external payable {
        if (msg.value > 0) {
            emit Deposit(msg.sender, msg.value);
        }
    }




    function submitAndConfirmTransactionWithValidation(
        address to,
        uint256 value,
        bytes memory data,
        bool autoExecute,
        uint256 gasLimit,
        address validator,
        uint256 deadline
    ) public returns (uint256) {
        require(isOwner[msg.sender], "Not an owner");
        require(to != address(0), "Invalid destination");
        require(deadline > block.timestamp, "Deadline passed");


        if (validator != address(0)) {
            require(isOwner[validator], "Invalid validator");
        }


        uint256 transactionId = transactions.length;
        transactions.push(Transaction({
            to: to,
            value: value,
            data: data,
            executed: false,
            confirmations: 0
        }));

        emit Submission(transactionId);


        confirmations[transactionId][msg.sender] = true;
        transactions[transactionId].confirmations++;
        emit Confirmation(msg.sender, transactionId);


        if (autoExecute && transactions[transactionId].confirmations >= required) {
            if (gasLimit > 0) {
                executeTransactionWithGasLimit(transactionId, gasLimit);
            } else {
                executeTransaction(transactionId);
            }
        }


        if (value > 1 ether) {
            emit Deposit(address(this), value);
        }

        return transactionId;
    }


    function executeTransactionWithGasLimit(uint256 transactionId, uint256 gasLimit)
        public
        ownerExists(msg.sender)
        transactionExists(transactionId)
        notExecuted(transactionId)
    {
        require(transactions[transactionId].confirmations >= required, "Not enough confirmations");

        Transaction storage txn = transactions[transactionId];
        txn.executed = true;

        (bool success,) = txn.to.call{value: txn.value, gas: gasLimit}(txn.data);
        if (success) {
            emit Execution(transactionId);
        } else {
            txn.executed = false;
        }
    }


    function manageOwnersAndRequirements(
        address[] memory newOwners,
        address[] memory removeOwners,
        uint256 newRequired,
        bool validateAll
    ) public onlyWallet {

        if (removeOwners.length > 0) {

            for (uint256 i = 0; i < removeOwners.length; i++) {

                if (isOwner[removeOwners[i]]) {

                    if (validateAll) {

                        for (uint256 j = 0; j < owners.length; j++) {

                            if (owners[j] == removeOwners[i]) {

                                if (j < owners.length - 1) {
                                    owners[j] = owners[owners.length - 1];
                                    ownerIndex[owners[j]] = j;
                                }
                                owners.pop();
                                isOwner[removeOwners[i]] = false;
                                delete ownerIndex[removeOwners[i]];
                                emit OwnerRemoval(removeOwners[i]);
                                break;
                            }
                        }
                    } else {

                        uint256 index = ownerIndex[removeOwners[i]];
                        if (index < owners.length - 1) {
                            owners[index] = owners[owners.length - 1];
                            ownerIndex[owners[index]] = index;
                        }
                        owners.pop();
                        isOwner[removeOwners[i]] = false;
                        delete ownerIndex[removeOwners[i]];
                        emit OwnerRemoval(removeOwners[i]);
                    }
                }
            }
        }


        if (newOwners.length > 0) {
            for (uint256 i = 0; i < newOwners.length; i++) {
                if (newOwners[i] != address(0) && !isOwner[newOwners[i]]) {
                    if (validateAll) {
                        bool isDuplicate = false;
                        for (uint256 j = 0; j < newOwners.length; j++) {
                            if (i != j && newOwners[i] == newOwners[j]) {
                                isDuplicate = true;
                                break;
                            }
                        }
                        if (!isDuplicate) {
                            isOwner[newOwners[i]] = true;
                            ownerIndex[newOwners[i]] = owners.length;
                            owners.push(newOwners[i]);
                            emit OwnerAddition(newOwners[i]);
                        }
                    } else {
                        isOwner[newOwners[i]] = true;
                        ownerIndex[newOwners[i]] = owners.length;
                        owners.push(newOwners[i]);
                        emit OwnerAddition(newOwners[i]);
                    }
                }
            }
        }

        if (newRequired > 0 && newRequired <= owners.length) {
            required = newRequired;
            emit RequirementChange(newRequired);
        }
    }

    function submitTransaction(address to, uint256 value, bytes memory data)
        public
        returns (uint256 transactionId)
    {
        require(isOwner[msg.sender], "Not an owner");

        transactionId = transactions.length;
        transactions.push(Transaction({
            to: to,
            value: value,
            data: data,
            executed: false,
            confirmations: 0
        }));

        emit Submission(transactionId);
    }

    function confirmTransaction(uint256 transactionId)
        public
        ownerExists(msg.sender)
        transactionExists(transactionId)
        notConfirmed(transactionId, msg.sender)
    {
        confirmations[transactionId][msg.sender] = true;
        transactions[transactionId].confirmations++;
        emit Confirmation(msg.sender, transactionId);

        if (transactions[transactionId].confirmations >= required) {
            executeTransaction(transactionId);
        }
    }

    function executeTransaction(uint256 transactionId)
        public
        ownerExists(msg.sender)
        transactionExists(transactionId)
        notExecuted(transactionId)
    {
        require(transactions[transactionId].confirmations >= required, "Not enough confirmations");

        Transaction storage txn = transactions[transactionId];
        txn.executed = true;

        (bool success,) = txn.to.call{value: txn.value}(txn.data);
        require(success, "Transaction execution failed");

        emit Execution(transactionId);
    }

    function revokeConfirmation(uint256 transactionId)
        public
        ownerExists(msg.sender)
        transactionExists(transactionId)
        confirmed(transactionId, msg.sender)
        notExecuted(transactionId)
    {
        confirmations[transactionId][msg.sender] = false;
        transactions[transactionId].confirmations--;
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    function getTransaction(uint256 transactionId)
        public
        view
        returns (address to, uint256 value, bytes memory data, bool executed, uint256 confirmationCount)
    {
        Transaction storage txn = transactions[transactionId];
        return (txn.to, txn.value, txn.data, txn.executed, txn.confirmations);
    }

    function getConfirmationCount(uint256 transactionId) public view returns (uint256) {
        return transactions[transactionId].confirmations;
    }

    function isConfirmed(uint256 transactionId) public view returns (bool) {
        return transactions[transactionId].confirmations >= required;
    }
}
