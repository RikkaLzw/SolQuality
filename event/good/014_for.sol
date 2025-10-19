
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";


contract PaymentSplitter is Ownable, ReentrancyGuard {
    using Address for address payable;


    event PayeeAdded(address indexed account, uint256 shares);
    event PayeeRemoved(address indexed account);
    event PaymentReleased(address indexed to, uint256 amount);
    event PaymentReceived(address indexed from, uint256 amount);
    event SharesUpdated(address indexed account, uint256 oldShares, uint256 newShares);


    uint256 private _totalShares;
    uint256 private _totalReleased;

    mapping(address => uint256) private _shares;
    mapping(address => uint256) private _released;
    address[] private _payees;


    constructor(address[] memory payees, uint256[] memory shares_) {
        require(payees.length == shares_.length, "PaymentSplitter: payees and shares length mismatch");
        require(payees.length > 0, "PaymentSplitter: no payees provided");

        for (uint256 i = 0; i < payees.length; i++) {
            _addPayee(payees[i], shares_[i]);
        }
    }


    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }


    function totalShares() public view returns (uint256) {
        return _totalShares;
    }


    function totalReleased() public view returns (uint256) {
        return _totalReleased;
    }


    function shares(address account) public view returns (uint256) {
        return _shares[account];
    }


    function released(address account) public view returns (uint256) {
        return _released[account];
    }


    function payee(uint256 index) public view returns (address) {
        require(index < _payees.length, "PaymentSplitter: index out of bounds");
        return _payees[index];
    }


    function payeesCount() public view returns (uint256) {
        return _payees.length;
    }


    function release(address payable account) public nonReentrant {
        require(_shares[account] > 0, "PaymentSplitter: account has no shares");

        uint256 payment = releasable(account);
        require(payment > 0, "PaymentSplitter: account is not due payment");

        _released[account] += payment;
        _totalReleased += payment;

        account.sendValue(payment);
        emit PaymentReleased(account, payment);
    }


    function releasable(address account) public view returns (uint256) {
        uint256 totalReceived = address(this).balance + totalReleased();
        return _pendingPayment(account, totalReceived, released(account));
    }


    function _pendingPayment(
        address account,
        uint256 totalReceived,
        uint256 alreadyReleased
    ) private view returns (uint256) {
        return (totalReceived * _shares[account]) / _totalShares - alreadyReleased;
    }


    function addPayee(address account, uint256 shares_) external onlyOwner {
        _addPayee(account, shares_);
    }


    function removePayee(address account) external onlyOwner {
        require(_shares[account] > 0, "PaymentSplitter: account is not a payee");
        require(releasable(account) == 0, "PaymentSplitter: account has pending payments");

        _totalShares -= _shares[account];
        _shares[account] = 0;


        for (uint256 i = 0; i < _payees.length; i++) {
            if (_payees[i] == account) {
                _payees[i] = _payees[_payees.length - 1];
                _payees.pop();
                break;
            }
        }

        emit PayeeRemoved(account);
    }


    function updateShares(address account, uint256 newShares) external onlyOwner {
        require(_shares[account] > 0, "PaymentSplitter: account is not a payee");
        require(newShares > 0, "PaymentSplitter: shares must be greater than 0");
        require(releasable(account) == 0, "PaymentSplitter: account has pending payments");

        uint256 oldShares = _shares[account];
        _totalShares = _totalShares - oldShares + newShares;
        _shares[account] = newShares;

        emit SharesUpdated(account, oldShares, newShares);
    }


    function releaseAll() external nonReentrant {
        for (uint256 i = 0; i < _payees.length; i++) {
            address payable account = payable(_payees[i]);
            uint256 payment = releasable(account);

            if (payment > 0) {
                _released[account] += payment;
                _totalReleased += payment;
                account.sendValue(payment);
                emit PaymentReleased(account, payment);
            }
        }
    }


    function _addPayee(address account, uint256 shares_) private {
        require(account != address(0), "PaymentSplitter: account is the zero address");
        require(shares_ > 0, "PaymentSplitter: shares must be greater than 0");
        require(_shares[account] == 0, "PaymentSplitter: account already has shares");

        _payees.push(account);
        _shares[account] = shares_;
        _totalShares += shares_;

        emit PayeeAdded(account, shares_);
    }


    function emergencyWithdraw() external onlyOwner {
        require(_payees.length == 0, "PaymentSplitter: cannot withdraw with active payees");

        uint256 balance = address(this).balance;
        require(balance > 0, "PaymentSplitter: no funds to withdraw");

        payable(owner()).sendValue(balance);
    }
}
