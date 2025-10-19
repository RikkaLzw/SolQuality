
pragma solidity ^0.8.0;

contract OptimizedTimeLock {

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
    event NewAdmin(address indexed newAdmin);
    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewDelay(uint256 indexed newDelay);


    uint256 public constant GRACE_PERIOD = 14 days;
    uint256 public constant MINIMUM_DELAY = 2 days;
    uint256 public constant MAXIMUM_DELAY = 30 days;


    address public admin;
    address public pendingAdmin;
    uint256 public delay;


    mapping(bytes32 => bool) public queuedTransactions;

    modifier onlyAdmin() {
        require(msg.sender == admin, "TimeLock: Call must come from admin");
        _;
    }

    constructor(address admin_, uint256 delay_) {
        require(delay_ >= MINIMUM_DELAY, "TimeLock: Delay must exceed minimum delay");
        require(delay_ <= MAXIMUM_DELAY, "TimeLock: Delay must not exceed maximum delay");

        admin = admin_;
        delay = delay_;
    }

    function setDelay(uint256 delay_) external onlyAdmin {
        require(delay_ >= MINIMUM_DELAY, "TimeLock: Delay must exceed minimum delay");
        require(delay_ <= MAXIMUM_DELAY, "TimeLock: Delay must not exceed maximum delay");
        delay = delay_;

        emit NewDelay(delay_);
    }

    function acceptAdmin() external {
        require(msg.sender == pendingAdmin, "TimeLock: Call must come from pendingAdmin");
        admin = msg.sender;
        pendingAdmin = address(0);

        emit NewAdmin(admin);
    }

    function setPendingAdmin(address pendingAdmin_) external onlyAdmin {
        pendingAdmin = pendingAdmin_;

        emit NewPendingAdmin(pendingAdmin_);
    }

    function queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external onlyAdmin returns (bytes32) {
        require(eta >= getBlockTimestamp() + delay, "TimeLock: Estimated execution block must satisfy delay");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
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
    ) external onlyAdmin {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = false;

        emit TransactionCancelled(txHash);
    }

    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external payable onlyAdmin returns (bytes memory) {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        require(queuedTransactions[txHash], "TimeLock: Transaction hasn't been queued");


        uint256 currentTime = getBlockTimestamp();
        require(currentTime >= eta, "TimeLock: Transaction hasn't surpassed time lock");
        require(currentTime <= eta + GRACE_PERIOD, "TimeLock: Transaction is stale");

        queuedTransactions[txHash] = false;

        bytes memory callData;
        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        require(success, "TimeLock: Transaction execution reverted");

        emit TransactionExecuted(txHash, target, value, signature, data, eta);

        return returnData;
    }

    function getBlockTimestamp() internal view returns (uint256) {
        return block.timestamp;
    }

    receive() external payable {}
}
