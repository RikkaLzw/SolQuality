
pragma solidity ^0.8.0;

contract PaymentSplitter {
    mapping(address => uint256) private _shares;
    mapping(address => uint256) private _released;

    address[] private _payees;
    uint256 private _totalShares;
    uint256 private _totalReleased;

    event PayeeAdded(address account, uint256 shares);
    event PaymentReleased(address to, uint256 amount);
    event PaymentReceived(address from, uint256 amount);

    modifier onlyPayee(address account) {
        require(_shares[account] > 0, "Account is not a payee");
        _;
    }

    constructor(address[] memory payees, uint256[] memory shares_) {
        require(payees.length == shares_.length, "Payees and shares length mismatch");
        require(payees.length > 0, "No payees provided");

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
        return _payees[index];
    }

    function releasable(address account) public view returns (uint256) {
        uint256 totalReceived = address(this).balance + _totalReleased;
        return _pendingPayment(account, totalReceived);
    }

    function release(address payable account) public onlyPayee(account) {
        uint256 payment = releasable(account);
        require(payment > 0, "Account is not due payment");

        _released[account] += payment;
        _totalReleased += payment;

        account.transfer(payment);
        emit PaymentReleased(account, payment);
    }

    function _addPayee(address account, uint256 shares_) private {
        require(account != address(0), "Account is the zero address");
        require(shares_ > 0, "Shares are 0");
        require(_shares[account] == 0, "Account already has shares");

        _payees.push(account);
        _shares[account] = shares_;
        _totalShares += shares_;
        emit PayeeAdded(account, shares_);
    }

    function _pendingPayment(address account, uint256 totalReceived) private view returns (uint256) {
        return (totalReceived * _shares[account]) / _totalShares - _released[account];
    }
}
