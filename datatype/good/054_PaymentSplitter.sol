
pragma solidity ^0.8.0;

contract PaymentSplitter {

    event PayeeAdded(address account, uint256 shares);
    event PaymentReleased(address to, uint256 amount);
    event PaymentReceived(address from, uint256 amount);


    uint256 private _totalShares;
    uint256 private _totalReleased;

    mapping(address => uint256) private _shares;
    mapping(address => uint256) private _released;
    address[] private _payees;


    modifier validPayee(address account) {
        require(account != address(0), "PaymentSplitter: account is the zero address");
        require(_shares[account] > 0, "PaymentSplitter: account has no shares");
        _;
    }


    constructor(address[] memory payees, uint256[] memory shares_) payable {
        require(payees.length == shares_.length, "PaymentSplitter: payees and shares length mismatch");
        require(payees.length > 0, "PaymentSplitter: no payees");

        for (uint256 i = 0; i < payees.length; i++) {
            _addPayee(payees[i], shares_[i]);
        }
    }


    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
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
        return _payees[index];
    }

    function payeesCount() external view returns (uint256) {
        return _payees.length;
    }


    function releasable(address account) public view returns (uint256) {
        uint256 totalReceived = address(this).balance + _totalReleased;
        return _pendingPayment(account, totalReceived, _released[account]);
    }


    function release(address payable account) external validPayee(account) {
        uint256 payment = releasable(account);
        require(payment != 0, "PaymentSplitter: account is not due payment");

        _released[account] += payment;
        _totalReleased += payment;

        (bool success, ) = account.call{value: payment}("");
        require(success, "PaymentSplitter: unable to send value");

        emit PaymentReleased(account, payment);
    }


    function releaseAll() external {
        for (uint256 i = 0; i < _payees.length; i++) {
            address payable account = payable(_payees[i]);
            uint256 payment = releasable(account);

            if (payment > 0) {
                _released[account] += payment;
                _totalReleased += payment;

                (bool success, ) = account.call{value: payment}("");
                require(success, "PaymentSplitter: unable to send value");

                emit PaymentReleased(account, payment);
            }
        }
    }


    function _pendingPayment(
        address account,
        uint256 totalReceived,
        uint256 alreadyReleased
    ) private view returns (uint256) {
        return (totalReceived * _shares[account]) / _totalShares - alreadyReleased;
    }

    function _addPayee(address account, uint256 shares_) private {
        require(account != address(0), "PaymentSplitter: account is the zero address");
        require(shares_ > 0, "PaymentSplitter: shares are 0");
        require(_shares[account] == 0, "PaymentSplitter: account already has shares");

        _payees.push(account);
        _shares[account] = shares_;
        _totalShares += shares_;
        emit PayeeAdded(account, shares_);
    }
}
