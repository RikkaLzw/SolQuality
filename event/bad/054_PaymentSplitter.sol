
pragma solidity ^0.8.0;

contract PaymentSplitter {
    address private owner;
    mapping(address => uint256) private shares;
    mapping(address => uint256) private released;
    address[] private payees;
    uint256 private totalShares;
    uint256 private totalReleased;

    error Error();
    error Failed();
    error Invalid();

    event PaymentReleased(address to, uint256 amount);
    event PaymentReceived(address from, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor(address[] memory _payees, uint256[] memory _shares) {
        require(_payees.length == _shares.length);
        require(_payees.length > 0);

        owner = msg.sender;

        for (uint256 i = 0; i < _payees.length; i++) {
            require(_payees[i] != address(0));
            require(_shares[i] > 0);
            require(shares[_payees[i]] == 0);

            payees.push(_payees[i]);
            shares[_payees[i]] = _shares[i];
            totalShares += _shares[i];
        }
    }

    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }

    function addPayee(address payee, uint256 share) external onlyOwner {
        require(payee != address(0));
        require(share > 0);
        require(shares[payee] == 0);

        payees.push(payee);
        shares[payee] = share;
        totalShares += share;

    }

    function updateShare(address payee, uint256 newShare) external onlyOwner {
        require(shares[payee] > 0);
        require(newShare > 0);

        totalShares = totalShares - shares[payee] + newShare;
        shares[payee] = newShare;

    }

    function removePayee(address payee) external onlyOwner {
        require(shares[payee] > 0);

        uint256 payment = pendingPayment(payee);
        if (payment > 0) {
            released[payee] += payment;
            totalReleased += payment;
            payable(payee).transfer(payment);
            emit PaymentReleased(payee, payment);
        }

        totalShares -= shares[payee];
        shares[payee] = 0;

        for (uint256 i = 0; i < payees.length; i++) {
            if (payees[i] == payee) {
                payees[i] = payees[payees.length - 1];
                payees.pop();
                break;
            }
        }

    }

    function release(address payable account) external {
        require(shares[account] > 0);

        uint256 payment = pendingPayment(account);
        if (payment == 0) {
            revert Invalid();
        }

        released[account] += payment;
        totalReleased += payment;

        account.transfer(payment);
        emit PaymentReleased(account, payment);
    }

    function releaseAll() external {
        for (uint256 i = 0; i < payees.length; i++) {
            address payable account = payable(payees[i]);
            uint256 payment = pendingPayment(account);

            if (payment > 0) {
                released[account] += payment;
                totalReleased += payment;
                account.transfer(payment);
                emit PaymentReleased(account, payment);
            }
        }
    }

    function emergencyWithdraw() external onlyOwner {
        require(address(this).balance > 0);
        payable(owner).transfer(address(this).balance);

    }

    function pendingPayment(address account) public view returns (uint256) {
        if (shares[account] == 0) {
            return 0;
        }

        uint256 totalReceived = address(this).balance + totalReleased;
        uint256 payment = (totalReceived * shares[account]) / totalShares - released[account];

        return payment;
    }

    function getShares(address account) external view returns (uint256) {
        return shares[account];
    }

    function getReleased(address account) external view returns (uint256) {
        return released[account];
    }

    function getTotalShares() external view returns (uint256) {
        return totalShares;
    }

    function getTotalReleased() external view returns (uint256) {
        return totalReleased;
    }

    function getPayees() external view returns (address[] memory) {
        return payees;
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
