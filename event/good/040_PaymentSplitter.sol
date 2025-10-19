
pragma solidity ^0.8.0;

contract PaymentSplitter {

    event PayeeAdded(address indexed payee, uint256 shares);
    event PaymentReleased(address indexed to, uint256 amount);
    event PaymentReceived(address indexed from, uint256 amount);
    event SharesUpdated(address indexed payee, uint256 oldShares, uint256 newShares);


    uint256 private _totalShares;
    uint256 private _totalReleased;

    mapping(address => uint256) private _shares;
    mapping(address => uint256) private _released;
    address[] private _payees;

    address public owner;


    modifier onlyOwner() {
        require(msg.sender == owner, "PaymentSplitter: caller is not the owner");
        _;
    }

    modifier validPayee(address account) {
        require(account != address(0), "PaymentSplitter: account is the zero address");
        require(_shares[account] > 0, "PaymentSplitter: account has no shares");
        _;
    }

    constructor(address[] memory payees, uint256[] memory shares_) {
        require(payees.length == shares_.length, "PaymentSplitter: payees and shares length mismatch");
        require(payees.length > 0, "PaymentSplitter: no payees provided");

        owner = msg.sender;

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
        uint256 totalReceived = address(this).balance + totalReleased();
        return _pendingPayment(account, totalReceived, released(account));
    }

    function release(address payable account) public validPayee(account) {
        uint256 payment = releasable(account);

        require(payment > 0, "PaymentSplitter: account is not due payment");

        _released[account] += payment;
        _totalReleased += payment;

        (bool success, ) = account.call{value: payment}("");
        require(success, "PaymentSplitter: unable to send value, recipient may have reverted");

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
                require(success, "PaymentSplitter: unable to send value, recipient may have reverted");

                emit PaymentReleased(account, payment);
            }
        }
    }

    function addPayee(address account, uint256 shares_) external onlyOwner {
        _addPayee(account, shares_);
    }

    function updateShares(address account, uint256 newShares) external onlyOwner {
        require(account != address(0), "PaymentSplitter: account is the zero address");
        require(_shares[account] > 0, "PaymentSplitter: account is not a payee");
        require(newShares > 0, "PaymentSplitter: shares are 0");

        uint256 oldShares = _shares[account];
        _totalShares = _totalShares - oldShares + newShares;
        _shares[account] = newShares;

        emit SharesUpdated(account, oldShares, newShares);
    }

    function removePayee(address account) external onlyOwner validPayee(account) {

        uint256 payment = releasable(account);
        if (payment > 0) {
            release(payable(account));
        }


        for (uint256 i = 0; i < _payees.length; i++) {
            if (_payees[i] == account) {
                _payees[i] = _payees[_payees.length - 1];
                _payees.pop();
                break;
            }
        }


        _totalShares -= _shares[account];
        _shares[account] = 0;
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

    function _pendingPayment(
        address account,
        uint256 totalReceived,
        uint256 alreadyReleased
    ) private view returns (uint256) {
        return (totalReceived * _shares[account]) / _totalShares - alreadyReleased;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getAllPayees() external view returns (address[] memory) {
        return _payees;
    }

    function emergencyWithdraw() external onlyOwner {
        require(address(this).balance > 0, "PaymentSplitter: no balance to withdraw");

        uint256 balance = address(this).balance;
        (bool success, ) = payable(owner).call{value: balance}("");
        require(success, "PaymentSplitter: emergency withdrawal failed");
    }
}
