
pragma solidity ^0.8.0;


contract OptimizedTimelock {

    event TransactionQueued(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );

    event TransactionExecuted(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );

    event TransactionCancelled(bytes32 indexed txHash);
    event DelayUpdated(uint256 oldDelay, uint256 newDelay);
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);


    address public admin;
    uint256 public delay;
    uint256 public constant GRACE_PERIOD = 14 days;
    uint256 public constant MINIMUM_DELAY = 2 days;
    uint256 public constant MAXIMUM_DELAY = 30 days;


    mapping(bytes32 => bool) public queuedTransactions;


    modifier onlyAdmin() {
        require(msg.sender == admin, "Timelock: caller is not admin");
        _;
    }

    modifier validDelay(uint256 _delay) {
        require(
            _delay >= MINIMUM_DELAY && _delay <= MAXIMUM_DELAY,
            "Timelock: invalid delay"
        );
        _;
    }

    constructor(address _admin, uint256 _delay) validDelay(_delay) {
        require(_admin != address(0), "Timelock: invalid admin address");
        admin = _admin;
        delay = _delay;
    }


    function queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public onlyAdmin returns (bytes32) {
        require(
            eta >= getBlockTimestamp() + delay,
            "Timelock: estimated execution block must satisfy delay"
        );

        bytes32 txHash = getTxHash(target, value, signature, data, eta);


        queuedTransactions[txHash] = true;

        emit TransactionQueued(txHash, target, value, signature, data, eta);
        return txHash;
    }


    function cancelTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public onlyAdmin {
        bytes32 txHash = getTxHash(target, value, signature, data, eta);

        require(queuedTransactions[txHash], "Timelock: transaction not queued");


        queuedTransactions[txHash] = false;

        emit TransactionCancelled(txHash);
    }


    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public payable onlyAdmin returns (bytes memory) {
        bytes32 txHash = getTxHash(target, value, signature, data, eta);

        require(queuedTransactions[txHash], "Timelock: transaction not queued");


        uint256 currentTime = getBlockTimestamp();
        require(currentTime >= eta, "Timelock: transaction hasn't surpassed time lock");
        require(currentTime <= eta + GRACE_PERIOD, "Timelock: transaction is stale");


        queuedTransactions[txHash] = false;

        bytes memory callData;
        if (bytes(signature).length == 0) {
            callData = data;
        } else {

            bytes4 selector = bytes4(keccak256(bytes(signature)));
            callData = abi.encodePacked(selector, data);
        }


        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        require(success, "Timelock: transaction execution reverted");

        emit TransactionExecuted(txHash, target, value, signature, data, eta);
        return returnData;
    }


    function setDelay(uint256 _delay) public onlyAdmin validDelay(_delay) {
        uint256 oldDelay = delay;
        delay = _delay;
        emit DelayUpdated(oldDelay, _delay);
    }


    function setAdmin(address _admin) public onlyAdmin {
        require(_admin != address(0), "Timelock: invalid admin address");
        address oldAdmin = admin;
        admin = _admin;
        emit AdminChanged(oldAdmin, _admin);
    }


    function getTxHash(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public pure returns (bytes32) {
        return keccak256(abi.encode(target, value, signature, data, eta));
    }


    function getBlockTimestamp() internal view returns (uint256) {
        return block.timestamp;
    }


    function isTransactionQueued(bytes32 txHash) external view returns (bool) {
        return queuedTransactions[txHash];
    }


    receive() external payable {}


    fallback() external payable {}
}
