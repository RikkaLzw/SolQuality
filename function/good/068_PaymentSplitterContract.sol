
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract PaymentSplitterContract is Ownable, ReentrancyGuard, Pausable {
    struct Payee {
        address payable wallet;
        uint256 shares;
        uint256 released;
    }

    mapping(address => uint256) private _payeeIndex;
    Payee[] private _payees;
    uint256 private _totalShares;
    uint256 private _totalReleased;

    event PayeeAdded(address indexed payee, uint256 shares);
    event PayeeRemoved(address indexed payee);
    event PaymentReleased(address indexed payee, uint256 amount);
    event PaymentReceived(address indexed from, uint256 amount);

    modifier validPayee(address payee) {
        require(payee != address(0), "Invalid payee address");
        _;
    }

    modifier payeeExists(address payee) {
        require(_isPayee(payee), "Payee does not exist");
        _;
    }

    modifier payeeNotExists(address payee) {
        require(!_isPayee(payee), "Payee already exists");
        _;
    }

    constructor(address[] memory payees, uint256[] memory shares_) {
        require(payees.length == shares_.length, "Arrays length mismatch");
        require(payees.length > 0, "No payees provided");

        _initializePayees(payees, shares_);
    }

    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }

    function addPayee(address payee, uint256 shares)
        external
        onlyOwner
        validPayee(payee)
        payeeNotExists(payee)
    {
        require(shares > 0, "Shares must be greater than 0");

        _payees.push(Payee({
            wallet: payable(payee),
            shares: shares,
            released: 0
        }));

        _payeeIndex[payee] = _payees.length - 1;
        _totalShares += shares;

        emit PayeeAdded(payee, shares);
    }

    function removePayee(address payee)
        external
        onlyOwner
        payeeExists(payee)
    {
        _releasePayment(payee);
        _removePayeeFromArray(payee);

        emit PayeeRemoved(payee);
    }

    function releasePayment(address payee)
        external
        nonReentrant
        whenNotPaused
        payeeExists(payee)
    {
        _releasePayment(payee);
    }

    function releaseAllPayments() external nonReentrant whenNotPaused {
        for (uint256 i = 0; i < _payees.length; i++) {
            address payee = _payees[i].wallet;
            if (_calculatePendingPayment(payee) > 0) {
                _releasePayment(payee);
            }
        }
    }

    function getPayeeInfo(address payee)
        external
        view
        payeeExists(payee)
        returns (uint256 shares, uint256 released, uint256 pending)
    {
        uint256 index = _payeeIndex[payee];
        Payee memory payeeInfo = _payees[index];

        return (
            payeeInfo.shares,
            payeeInfo.released,
            _calculatePendingPayment(payee)
        );
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getTotalShares() external view returns (uint256) {
        return _totalShares;
    }

    function getPayeesCount() external view returns (uint256) {
        return _payees.length;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _initializePayees(address[] memory payees, uint256[] memory shares) private {
        for (uint256 i = 0; i < payees.length; i++) {
            require(payees[i] != address(0), "Invalid payee address");
            require(shares[i] > 0, "Shares must be greater than 0");
            require(!_isPayee(payees[i]), "Duplicate payee address");

            _payees.push(Payee({
                wallet: payable(payees[i]),
                shares: shares[i],
                released: 0
            }));

            _payeeIndex[payees[i]] = i;
            _totalShares += shares[i];

            emit PayeeAdded(payees[i], shares[i]);
        }
    }

    function _releasePayment(address payee) private {
        uint256 payment = _calculatePendingPayment(payee);
        require(payment > 0, "No payment due");

        uint256 index = _payeeIndex[payee];
        _payees[index].released += payment;
        _totalReleased += payment;

        (bool success, ) = payee.call{value: payment}("");
        require(success, "Payment transfer failed");

        emit PaymentReleased(payee, payment);
    }

    function _calculatePendingPayment(address payee) private view returns (uint256) {
        uint256 index = _payeeIndex[payee];
        Payee memory payeeInfo = _payees[index];

        uint256 totalReceived = address(this).balance + _totalReleased;
        uint256 entitled = (totalReceived * payeeInfo.shares) / _totalShares;

        return entitled - payeeInfo.released;
    }

    function _removePayeeFromArray(address payee) private {
        uint256 index = _payeeIndex[payee];
        uint256 lastIndex = _payees.length - 1;

        _totalShares -= _payees[index].shares;

        if (index != lastIndex) {
            _payees[index] = _payees[lastIndex];
            _payeeIndex[_payees[index].wallet] = index;
        }

        _payees.pop();
        delete _payeeIndex[payee];
    }

    function _isPayee(address account) private view returns (bool) {
        if (_payees.length == 0) return false;

        uint256 index = _payeeIndex[account];
        return index < _payees.length && _payees[index].wallet == account;
    }
}
