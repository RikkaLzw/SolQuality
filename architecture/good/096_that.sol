
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";


contract TimelockTreasury is Ownable, ReentrancyGuard {
    using Address for address;


    uint256 public constant MINIMUM_DELAY = 1 hours;
    uint256 public constant MAXIMUM_DELAY = 30 days;
    uint256 public constant GRACE_PERIOD = 14 days;


    uint256 private _delay;
    mapping(bytes32 => bool) private _queuedTransactions;
    mapping(bytes32 => uint256) private _timestamps;


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
        bytes data
    );

    event TransactionCancelled(bytes32 indexed txHash);
    event DelayChanged(uint256 oldDelay, uint256 newDelay);


    modifier validDelay(uint256 delay) {
        require(
            delay >= MINIMUM_DELAY && delay <= MAXIMUM_DELAY,
            "TimelockTreasury: Invalid delay"
        );
        _;
    }

    modifier onlyTimelock() {
        require(
            msg.sender == address(this),
            "TimelockTreasury: Call must come from timelock"
        );
        _;
    }

    modifier transactionExists(bytes32 txHash) {
        require(
            _queuedTransactions[txHash],
            "TimelockTreasury: Transaction not queued"
        );
        _;
    }


    constructor(uint256 delay_) validDelay(delay_) {
        _delay = delay_;
    }


    function getDelay() external view returns (uint256) {
        return _delay;
    }


    function setDelay(uint256 newDelay)
        external
        onlyTimelock
        validDelay(newDelay)
    {
        uint256 oldDelay = _delay;
        _delay = newDelay;
        emit DelayChanged(oldDelay, newDelay);
    }


    function queueTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external onlyOwner returns (bytes32) {
        require(
            eta >= block.timestamp + _delay,
            "TimelockTreasury: ETA must satisfy delay"
        );

        bytes32 txHash = _getTxHash(target, value, signature, data, eta);
        require(
            !_queuedTransactions[txHash],
            "TimelockTreasury: Transaction already queued"
        );

        _queuedTransactions[txHash] = true;
        _timestamps[txHash] = eta;

        emit TransactionQueued(txHash, target, value, signature, data, eta);
        return txHash;
    }


    function executeTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external payable onlyOwner nonReentrant returns (bytes memory) {
        bytes32 txHash = _getTxHash(target, value, signature, data, eta);

        require(
            _queuedTransactions[txHash],
            "TimelockTreasury: Transaction not queued"
        );
        require(
            block.timestamp >= eta,
            "TimelockTreasury: Transaction not ready"
        );
        require(
            block.timestamp <= eta + GRACE_PERIOD,
            "TimelockTreasury: Transaction expired"
        );

        _queuedTransactions[txHash] = false;
        delete _timestamps[txHash];

        bytes memory callData = _getCallData(signature, data);
        bytes memory returnData = _executeCall(target, value, callData);

        emit TransactionExecuted(txHash, target, value, signature, data);
        return returnData;
    }


    function cancelTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external onlyOwner {
        bytes32 txHash = _getTxHash(target, value, signature, data, eta);

        require(
            _queuedTransactions[txHash],
            "TimelockTreasury: Transaction not queued"
        );

        _queuedTransactions[txHash] = false;
        delete _timestamps[txHash];

        emit TransactionCancelled(txHash);
    }


    function isTransactionQueued(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external view returns (bool) {
        bytes32 txHash = _getTxHash(target, value, signature, data, eta);
        return _queuedTransactions[txHash];
    }


    function getTransactionTimestamp(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external view returns (uint256) {
        bytes32 txHash = _getTxHash(target, value, signature, data, eta);
        return _timestamps[txHash];
    }


    function _getTxHash(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(target, value, signature, data, eta)
        );
    }


    function _getCallData(
        string calldata signature,
        bytes calldata data
    ) private pure returns (bytes memory) {
        if (bytes(signature).length == 0) {
            return data;
        } else {
            return abi.encodePacked(
                bytes4(keccak256(bytes(signature))),
                data
            );
        }
    }


    function _executeCall(
        address target,
        uint256 value,
        bytes memory callData
    ) private returns (bytes memory) {
        require(
            address(this).balance >= value,
            "TimelockTreasury: Insufficient balance"
        );

        (bool success, bytes memory returnData) = target.call{value: value}(callData);

        if (!success) {
            if (returnData.length > 0) {
                assembly {
                    let returnData_size := mload(returnData)
                    revert(add(32, returnData), returnData_size)
                }
            } else {
                revert("TimelockTreasury: Transaction execution failed");
            }
        }

        return returnData;
    }


    receive() external payable {}


    function emergencyWithdraw(address payable recipient, uint256 amount)
        external
        onlyTimelock
    {
        require(recipient != address(0), "TimelockTreasury: Invalid recipient");
        require(amount <= address(this).balance, "TimelockTreasury: Insufficient balance");

        recipient.transfer(amount);
    }
}
