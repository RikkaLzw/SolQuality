
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract PaymentSplitter is Ownable, ReentrancyGuard {
    using SafeMath for uint256;


    uint256 private constant MAX_RECIPIENTS = 100;
    uint256 private constant BASIS_POINTS = 10000;


    mapping(address => uint256) private _shares;
    mapping(address => uint256) private _released;
    address[] private _payees;
    uint256 private _totalShares;
    uint256 private _totalReleased;


    event PaymentReleased(address to, uint256 amount);
    event PaymentReceived(address from, uint256 amount);
    event PayeeAdded(address account, uint256 shares);
    event PayeeUpdated(address account, uint256 oldShares, uint256 newShares);


    modifier validPayee(address account) {
        require(account != address(0), "PaymentSplitter: account is the zero address");
        _;
    }

    modifier hasShares(address account) {
        require(_shares[account] > 0, "PaymentSplitter: account has no shares");
        _;
    }

    modifier validShares(uint256 shares) {
        require(shares > 0, "PaymentSplitter: shares are 0");
        _;
    }


    constructor(address[] memory payees, uint256[] memory shares_) {
        require(payees.length == shares_.length, "PaymentSplitter: payees and shares length mismatch");
        require(payees.length > 0, "PaymentSplitter: no payees");
        require(payees.length <= MAX_RECIPIENTS, "PaymentSplitter: too many recipients");

        for (uint256 i = 0; i < payees.length; i++) {
            _addPayee(payees[i], shares_[i]);
        }
    }


    receive() external payable {
        emit PaymentReceived(_msgSender(), msg.value);
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


    function release(address payable account) external nonReentrant hasShares(account) {
        uint256 payment = _releasableAmount(account);
        require(payment > 0, "PaymentSplitter: account is not due payment");

        _released[account] = _released[account].add(payment);
        _totalReleased = _totalReleased.add(payment);

        _safeTransfer(account, payment);
        emit PaymentReleased(account, payment);
    }


    function releaseAll() external nonReentrant {
        uint256 payeesLength = _payees.length;
        for (uint256 i = 0; i < payeesLength; i++) {
            address payable account = payable(_payees[i]);
            uint256 payment = _releasableAmount(account);

            if (payment > 0) {
                _released[account] = _released[account].add(payment);
                _totalReleased = _totalReleased.add(payment);

                _safeTransfer(account, payment);
                emit PaymentReleased(account, payment);
            }
        }
    }


    function addPayee(address account, uint256 shares_)
        external
        onlyOwner
        validPayee(account)
        validShares(shares_)
    {
        require(_shares[account] == 0, "PaymentSplitter: account already has shares");
        require(_payees.length < MAX_RECIPIENTS, "PaymentSplitter: max recipients reached");

        _addPayee(account, shares_);
    }


    function updateShares(address account, uint256 newShares)
        external
        onlyOwner
        validPayee(account)
        validShares(newShares)
        hasShares(account)
    {
        uint256 oldShares = _shares[account];
        _totalShares = _totalShares.sub(oldShares).add(newShares);
        _shares[account] = newShares;

        emit PayeeUpdated(account, oldShares, newShares);
    }


    function releasable(address account) external view returns (uint256) {
        return _releasableAmount(account);
    }


    function _addPayee(address account, uint256 shares_)
        private
        validPayee(account)
        validShares(shares_)
    {
        _payees.push(account);
        _shares[account] = shares_;
        _totalShares = _totalShares.add(shares_);

        emit PayeeAdded(account, shares_);
    }


    function _releasableAmount(address account) private view returns (uint256) {
        uint256 totalReceived = address(this).balance.add(_totalReleased);
        uint256 payment = totalReceived.mul(_shares[account]).div(_totalShares).sub(_released[account]);
        return payment;
    }


    function _safeTransfer(address payable to, uint256 amount) private {
        require(address(this).balance >= amount, "PaymentSplitter: insufficient balance");

        (bool success, ) = to.call{value: amount}("");
        require(success, "PaymentSplitter: transfer failed");
    }


    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "PaymentSplitter: no funds to withdraw");

        _safeTransfer(payable(owner()), balance);
    }


    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
