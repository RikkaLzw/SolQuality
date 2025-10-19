
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Address.sol";


contract PaymentSplitter is Ownable, ReentrancyGuard, Pausable {
    using Address for address payable;


    uint256 public constant MAX_PAYEES = 50;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MIN_SHARE = 1;


    address[] private _payees;
    mapping(address => uint256) private _shares;
    mapping(address => uint256) private _released;

    uint256 private _totalShares;
    uint256 private _totalReleased;


    event PayeeAdded(address indexed account, uint256 shares);
    event PayeeRemoved(address indexed account);
    event PaymentReleased(address indexed to, uint256 amount);
    event PaymentReceived(address indexed from, uint256 amount);
    event SharesUpdated(address indexed account, uint256 oldShares, uint256 newShares);


    modifier validPayee(address account) {
        require(account != address(0), "PaymentSplitter: account is zero address");
        require(_shares[account] > 0, "PaymentSplitter: account has no shares");
        _;
    }

    modifier validShare(uint256 shares) {
        require(shares >= MIN_SHARE, "PaymentSplitter: shares must be greater than 0");
        _;
    }

    modifier payeesNotEmpty() {
        require(_payees.length > 0, "PaymentSplitter: no payees");
        _;
    }

    modifier maxPayeesNotExceeded() {
        require(_payees.length < MAX_PAYEES, "PaymentSplitter: max payees exceeded");
        _;
    }


    constructor(address[] memory payees, uint256[] memory shares_) {
        require(payees.length == shares_.length, "PaymentSplitter: payees and shares length mismatch");
        require(payees.length > 0, "PaymentSplitter: no payees");
        require(payees.length <= MAX_PAYEES, "PaymentSplitter: too many payees");

        for (uint256 i = 0; i < payees.length; i++) {
            _addPayee(payees[i], shares_[i]);
        }
    }


    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }


    function payeesCount() external view returns (uint256) {
        return _payees.length;
    }


    function payee(uint256 index) external view returns (address) {
        require(index < _payees.length, "PaymentSplitter: index out of bounds");
        return _payees[index];
    }


    function shares(address account) external view returns (uint256) {
        return _shares[account];
    }


    function released(address account) external view returns (uint256) {
        return _released[account];
    }


    function totalShares() external view returns (uint256) {
        return _totalShares;
    }


    function totalReleased() external view returns (uint256) {
        return _totalReleased;
    }


    function getAllPayees() external view returns (address[] memory) {
        return _payees;
    }


    function releasable(address account) public view validPayee(account) returns (uint256) {
        uint256 totalReceived = address(this).balance + _totalReleased;
        return _pendingPayment(account, totalReceived, _released[account]);
    }


    function release(address payable account) external nonReentrant whenNotPaused validPayee(account) {
        uint256 payment = releasable(account);
        require(payment > 0, "PaymentSplitter: account is not due payment");

        _released[account] += payment;
        _totalReleased += payment;

        account.sendValue(payment);
        emit PaymentReleased(account, payment);
    }


    function releaseAll() external nonReentrant whenNotPaused payeesNotEmpty {
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


    function addPayee(address account, uint256 shares_)
        external
        onlyOwner
        maxPayeesNotExceeded
        validShare(shares_)
    {
        require(account != address(0), "PaymentSplitter: account is zero address");
        require(_shares[account] == 0, "PaymentSplitter: account already has shares");

        _addPayee(account, shares_);
    }


    function updatePayeeShares(address account, uint256 newShares)
        external
        onlyOwner
        validPayee(account)
        validShare(newShares)
    {
        uint256 oldShares = _shares[account];
        _totalShares = _totalShares - oldShares + newShares;
        _shares[account] = newShares;

        emit SharesUpdated(account, oldShares, newShares);
    }


    function removePayee(address account) external onlyOwner validPayee(account) {

        uint256 payment = releasable(account);
        if (payment > 0) {
            _released[account] += payment;
            _totalReleased += payment;
            payable(account).sendValue(payment);
            emit PaymentReleased(account, payment);
        }


        _removePayee(account);
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
    }


    function emergencyWithdraw() external onlyOwner whenPaused {
        uint256 balance = address(this).balance;
        require(balance > 0, "PaymentSplitter: no balance to withdraw");

        payable(owner()).transfer(balance);
    }


    function _addPayee(address account, uint256 shares_) private {
        require(account != address(0), "PaymentSplitter: account is zero address");
        require(shares_ > 0, "PaymentSplitter: shares are 0");
        require(_shares[account] == 0, "PaymentSplitter: account already has shares");

        _payees.push(account);
        _shares[account] = shares_;
        _totalShares += shares_;

        emit PayeeAdded(account, shares_);
    }


    function _removePayee(address account) private {
        uint256 shares_ = _shares[account];
        _totalShares -= shares_;
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


    function _pendingPayment(
        address account,
        uint256 totalReceived,
        uint256 alreadyReleased
    ) private view returns (uint256) {
        return (totalReceived * _shares[account]) / _totalShares - alreadyReleased;
    }
}
