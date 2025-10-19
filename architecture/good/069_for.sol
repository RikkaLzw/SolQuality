
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract PaymentSplitter is Ownable, ReentrancyGuard, Pausable {

    uint256 private constant MAX_PAYEES = 100;
    uint256 private constant PERCENTAGE_BASE = 10000;


    mapping(address => uint256) private _shares;
    mapping(address => uint256) private _released;
    address[] private _payees;
    uint256 private _totalShares;
    uint256 private _totalReleased;


    event PaymentReleased(address to, uint256 amount);
    event PaymentReceived(address from, uint256 amount);
    event PayeeAdded(address account, uint256 shares);
    event PayeeRemoved(address account);
    event SharesUpdated(address account, uint256 newShares);


    modifier validPayee(address account) {
        require(account != address(0), "PaymentSplitter: account is zero address");
        require(_shares[account] > 0, "PaymentSplitter: account has no shares");
        _;
    }

    modifier validShares(uint256 shares) {
        require(shares > 0, "PaymentSplitter: shares must be greater than 0");
        _;
    }

    modifier payeeExists(address account) {
        require(_shares[account] > 0, "PaymentSplitter: payee does not exist");
        _;
    }

    modifier payeeNotExists(address account) {
        require(_shares[account] == 0, "PaymentSplitter: payee already exists");
        _;
    }

    modifier maxPayeesNotExceeded() {
        require(_payees.length < MAX_PAYEES, "PaymentSplitter: max payees exceeded");
        _;
    }


    constructor(address[] memory payees, uint256[] memory shares) {
        require(payees.length == shares.length, "PaymentSplitter: payees and shares length mismatch");
        require(payees.length > 0, "PaymentSplitter: no payees");
        require(payees.length <= MAX_PAYEES, "PaymentSplitter: too many payees");

        for (uint256 i = 0; i < payees.length; i++) {
            _addPayee(payees[i], shares[i]);
        }
    }


    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }


    fallback() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }


    function release(address payable account) external nonReentrant whenNotPaused validPayee(account) {
        uint256 payment = _calculatePayment(account);
        require(payment > 0, "PaymentSplitter: account is not due payment");

        _released[account] += payment;
        _totalReleased += payment;

        (bool success, ) = account.call{value: payment}("");
        require(success, "PaymentSplitter: transfer failed");

        emit PaymentReleased(account, payment);
    }


    function releaseAll() external nonReentrant whenNotPaused {
        for (uint256 i = 0; i < _payees.length; i++) {
            address payable account = payable(_payees[i]);
            uint256 payment = _calculatePayment(account);

            if (payment > 0) {
                _released[account] += payment;
                _totalReleased += payment;

                (bool success, ) = account.call{value: payment}("");
                require(success, "PaymentSplitter: transfer failed");

                emit PaymentReleased(account, payment);
            }
        }
    }


    function addPayee(address account, uint256 shares_)
        external
        onlyOwner
        payeeNotExists(account)
        validShares(shares_)
        maxPayeesNotExceeded
    {
        _addPayee(account, shares_);
    }


    function removePayee(address account) external onlyOwner payeeExists(account) {
        require(_calculatePayment(account) == 0, "PaymentSplitter: payee has pending payments");

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


    function updateShares(address account, uint256 newShares)
        external
        onlyOwner
        payeeExists(account)
        validShares(newShares)
    {

        uint256 payment = _calculatePayment(account);
        if (payment > 0) {
            _released[account] += payment;
            _totalReleased += payment;

            (bool success, ) = payable(account).call{value: payment}("");
            require(success, "PaymentSplitter: transfer failed");

            emit PaymentReleased(account, payment);
        }

        _totalShares = _totalShares - _shares[account] + newShares;
        _shares[account] = newShares;

        emit SharesUpdated(account, newShares);
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
    }


    function totalShares() external view returns (uint256) {
        return _totalShares;
    }


    function totalReleased() external view returns (uint256) {
        return _totalReleased;
    }


    function shares(address account) external view returns (uint256) {
        return _shares[account];
    }


    function released(address account) external view returns (uint256) {
        return _released[account];
    }


    function payee(uint256 index) external view returns (address) {
        require(index < _payees.length, "PaymentSplitter: index out of bounds");
        return _payees[index];
    }


    function payeesCount() external view returns (uint256) {
        return _payees.length;
    }


    function getAllPayees() external view returns (address[] memory) {
        return _payees;
    }


    function pendingPayment(address account) external view returns (uint256) {
        return _calculatePayment(account);
    }


    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }


    function _addPayee(address account, uint256 shares_) private {
        require(account != address(0), "PaymentSplitter: account is zero address");
        require(shares_ > 0, "PaymentSplitter: shares must be greater than 0");
        require(_shares[account] == 0, "PaymentSplitter: payee already exists");

        _payees.push(account);
        _shares[account] = shares_;
        _totalShares += shares_;

        emit PayeeAdded(account, shares_);
    }


    function _calculatePayment(address account) private view returns (uint256) {
        if (_totalShares == 0) {
            return 0;
        }

        uint256 totalReceived = address(this).balance + _totalReleased;
        uint256 accountShare = (totalReceived * _shares[account]) / _totalShares;

        return accountShare - _released[account];
    }
}
