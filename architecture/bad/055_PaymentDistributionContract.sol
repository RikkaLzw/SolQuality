
pragma solidity ^0.8.0;

contract PaymentDistributionContract {
    address public owner;
    uint256 public totalShares;
    uint256 public totalReleased;

    mapping(address => uint256) public shares;
    mapping(address => uint256) public released;
    address[] public payees;

    mapping(address => bool) public isPayee;
    uint256 public payeeCount;
    bool public contractActive;
    uint256 public minimumPayment;
    uint256 public maxPayees;

    event PayeeAdded(address account, uint256 shares);
    event PaymentReleased(address to, uint256 amount);
    event PaymentReceived(address from, uint256 amount);
    event OwnershipTransferred(address previousOwner, address newOwner);

    constructor(address[] memory _payees, uint256[] memory _shares) {

        if (msg.sender == address(0)) {
            revert("Owner cannot be zero address");
        }
        owner = msg.sender;
        contractActive = true;
        minimumPayment = 1000000000000000;
        maxPayees = 50;


        if (_payees.length != _shares.length) {
            revert("Payees and shares length mismatch");
        }
        if (_payees.length == 0) {
            revert("No payees provided");
        }
        if (_payees.length > 50) {
            revert("Too many payees");
        }

        for (uint256 i = 0; i < _payees.length; i++) {

            if (_payees[i] == address(0)) {
                revert("Payee cannot be zero address");
            }
            if (_shares[i] == 0) {
                revert("Shares cannot be zero");
            }
            if (isPayee[_payees[i]]) {
                revert("Duplicate payee");
            }

            payees.push(_payees[i]);
            shares[_payees[i]] = _shares[i];
            isPayee[_payees[i]] = true;
            totalShares += _shares[i];
            payeeCount++;

            emit PayeeAdded(_payees[i], _shares[i]);
        }
    }

    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }

    function addPayee(address account, uint256 share) external {

        if (msg.sender != owner) {
            revert("Only owner can call this function");
        }
        if (!contractActive) {
            revert("Contract is not active");
        }


        if (account == address(0)) {
            revert("Payee cannot be zero address");
        }
        if (share == 0) {
            revert("Shares cannot be zero");
        }
        if (isPayee[account]) {
            revert("Account is already a payee");
        }
        if (payeeCount >= 50) {
            revert("Maximum payees reached");
        }

        payees.push(account);
        shares[account] = share;
        isPayee[account] = true;
        totalShares += share;
        payeeCount++;

        emit PayeeAdded(account, share);
    }

    function removePayee(address account) external {

        if (msg.sender != owner) {
            revert("Only owner can call this function");
        }
        if (!contractActive) {
            revert("Contract is not active");
        }

        if (!isPayee[account]) {
            revert("Account is not a payee");
        }


        uint256 payment = pendingPayment(account);
        if (payment > 0) {
            released[account] += payment;
            totalReleased += payment;
            payable(account).transfer(payment);
            emit PaymentReleased(account, payment);
        }

        totalShares -= shares[account];
        shares[account] = 0;
        isPayee[account] = false;
        payeeCount--;


        for (uint256 i = 0; i < payees.length; i++) {
            if (payees[i] == account) {
                payees[i] = payees[payees.length - 1];
                payees.pop();
                break;
            }
        }
    }

    function release(address payable account) external {
        if (!isPayee[account]) {
            revert("Account is not a payee");
        }
        if (!contractActive) {
            revert("Contract is not active");
        }

        uint256 payment = pendingPayment(account);
        if (payment == 0) {
            revert("Account is not due payment");
        }
        if (payment < 1000000000000000) {
            revert("Payment below minimum threshold");
        }

        released[account] += payment;
        totalReleased += payment;

        account.transfer(payment);
        emit PaymentReleased(account, payment);
    }

    function releaseAll() external {

        if (msg.sender != owner) {
            revert("Only owner can call this function");
        }
        if (!contractActive) {
            revert("Contract is not active");
        }

        for (uint256 i = 0; i < payees.length; i++) {
            address payable account = payable(payees[i]);
            uint256 payment = pendingPayment(account);

            if (payment > 0 && payment >= 1000000000000000) {
                released[account] += payment;
                totalReleased += payment;
                account.transfer(payment);
                emit PaymentReleased(account, payment);
            }
        }
    }

    function pendingPayment(address account) public view returns (uint256) {
        if (!isPayee[account]) {
            return 0;
        }

        uint256 totalReceived = address(this).balance + totalReleased;
        uint256 payment = (totalReceived * shares[account]) / totalShares - released[account];

        return payment;
    }

    function updateShares(address account, uint256 newShares) external {

        if (msg.sender != owner) {
            revert("Only owner can call this function");
        }
        if (!contractActive) {
            revert("Contract is not active");
        }

        if (!isPayee[account]) {
            revert("Account is not a payee");
        }
        if (newShares == 0) {
            revert("Shares cannot be zero");
        }


        uint256 payment = pendingPayment(account);
        if (payment > 0) {
            released[account] += payment;
            totalReleased += payment;
            payable(account).transfer(payment);
            emit PaymentReleased(account, payment);
        }

        totalShares = totalShares - shares[account] + newShares;
        shares[account] = newShares;
    }

    function transferOwnership(address newOwner) external {

        if (msg.sender != owner) {
            revert("Only owner can call this function");
        }


        if (newOwner == address(0)) {
            revert("New owner cannot be zero address");
        }

        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function setContractActive(bool _active) external {

        if (msg.sender != owner) {
            revert("Only owner can call this function");
        }

        contractActive = _active;
    }

    function setMinimumPayment(uint256 _minimumPayment) external {

        if (msg.sender != owner) {
            revert("Only owner can call this function");
        }

        minimumPayment = _minimumPayment;
    }

    function emergencyWithdraw() external {

        if (msg.sender != owner) {
            revert("Only owner can call this function");
        }

        uint256 balance = address(this).balance;
        if (balance == 0) {
            revert("No funds to withdraw");
        }

        payable(owner).transfer(balance);
    }

    function getPayeeInfo(address account) external view returns (uint256, uint256, uint256, bool) {
        return (shares[account], released[account], pendingPayment(account), isPayee[account]);
    }

    function getAllPayees() external view returns (address[] memory) {
        return payees;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getTotalReceived() external view returns (uint256) {
        return address(this).balance + totalReleased;
    }

    function bulkAddPayees(address[] memory _payees, uint256[] memory _shares) external {

        if (msg.sender != owner) {
            revert("Only owner can call this function");
        }
        if (!contractActive) {
            revert("Contract is not active");
        }


        if (_payees.length != _shares.length) {
            revert("Payees and shares length mismatch");
        }
        if (_payees.length == 0) {
            revert("No payees provided");
        }
        if (payeeCount + _payees.length > 50) {
            revert("Would exceed maximum payees");
        }

        for (uint256 i = 0; i < _payees.length; i++) {

            if (_payees[i] == address(0)) {
                revert("Payee cannot be zero address");
            }
            if (_shares[i] == 0) {
                revert("Shares cannot be zero");
            }
            if (isPayee[_payees[i]]) {
                revert("Duplicate payee");
            }

            payees.push(_payees[i]);
            shares[_payees[i]] = _shares[i];
            isPayee[_payees[i]] = true;
            totalShares += _shares[i];
            payeeCount++;

            emit PayeeAdded(_payees[i], _shares[i]);
        }
    }

    function renounceOwnership() external {

        if (msg.sender != owner) {
            revert("Only owner can call this function");
        }

        address previousOwner = owner;
        owner = address(0);
        emit OwnershipTransferred(previousOwner, address(0));
    }
}
