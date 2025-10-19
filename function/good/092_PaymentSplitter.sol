
pragma solidity ^0.8.0;

contract PaymentSplitter {
    address[] private _payees;
    mapping(address => uint256) private _shares;
    mapping(address => uint256) private _released;
    uint256 private _totalShares;
    uint256 private _totalReleased;

    event PayeeAdded(address account, uint256 shares);
    event PaymentReleased(address to, uint256 amount);
    event PaymentReceived(address from, uint256 amount);

    modifier validPayee(address account) {
        require(account != address(0), "PaymentSplitter: account is zero address");
        require(_shares[account] > 0, "PaymentSplitter: account has no shares");
        _;
    }

    constructor(address[] memory payees, uint256[] memory shares_) {
        require(payees.length == shares_.length, "PaymentSplitter: payees and shares length mismatch");
        require(payees.length > 0, "PaymentSplitter: no payees");

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

    function releasable(address account) public view returns (uint256) {
        uint256 totalReceived = address(this).balance + _totalReleased;
        return _pendingPayment(account, totalReceived);
    }

    function release(address payable account) public validPayee(account) {
        uint256 payment = releasable(account);
        require(payment > 0, "PaymentSplitter: account is not due payment");

        _released[account] += payment;
        _totalReleased += payment;

        account.transfer(payment);
        emit PaymentReleased(account, payment);
    }

    function releaseAll() public {
        for (uint256 i = 0; i < _payees.length; i++) {
            address payable account = payable(_payees[i]);
            uint256 payment = releasable(account);

            if (payment > 0) {
                _released[account] += payment;
                _totalReleased += payment;
                account.transfer(payment);
                emit PaymentReleased(account, payment);
            }
        }
    }

    function _pendingPayment(address account, uint256 totalReceived) private view returns (uint256) {
        return (totalReceived * _shares[account]) / _totalShares - _released[account];
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
}
