
pragma solidity ^0.8.0;

contract PaymentSplitter {
    address[] public payees;
    mapping(address => uint256) public shares;
    mapping(address => uint256) public released;

    uint256 public totalShares;
    uint256 public totalReleased;

    error InvalidInput();
    error Failed();
    error NotAllowed();

    event PaymentReleased(address to, uint256 amount);
    event PaymentReceived(address from, uint256 amount);

    constructor(address[] memory _payees, uint256[] memory _shares) {
        require(_payees.length == _shares.length);
        require(_payees.length > 0);

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

    function release(address payable account) public {
        require(shares[account] > 0);

        uint256 totalReceived = address(this).balance + totalReleased;
        uint256 payment = (totalReceived * shares[account]) / totalShares - released[account];

        require(payment > 0);

        released[account] += payment;
        totalReleased += payment;

        (bool success, ) = account.call{value: payment}("");
        require(success);

        emit PaymentReleased(account, payment);
    }

    function addPayee(address payee, uint256 share) external {
        require(payee != address(0));
        require(share > 0);
        require(shares[payee] == 0);

        payees.push(payee);
        shares[payee] = share;
        totalShares += share;
    }

    function removePayee(address payee) external {
        require(shares[payee] > 0);

        uint256 payeeShares = shares[payee];
        shares[payee] = 0;
        totalShares -= payeeShares;

        for (uint256 i = 0; i < payees.length; i++) {
            if (payees[i] == payee) {
                payees[i] = payees[payees.length - 1];
                payees.pop();
                break;
            }
        }
    }

    function updateShares(address payee, uint256 newShares) external {
        require(shares[payee] > 0);
        require(newShares > 0);

        uint256 oldShares = shares[payee];
        shares[payee] = newShares;
        totalShares = totalShares - oldShares + newShares;
    }

    function releasableAmount(address account) public view returns (uint256) {
        uint256 totalReceived = address(this).balance + totalReleased;
        return (totalReceived * shares[account]) / totalShares - released[account];
    }

    function getPayees() external view returns (address[] memory) {
        return payees;
    }

    function getShares(address account) external view returns (uint256) {
        return shares[account];
    }

    function getReleased(address account) external view returns (uint256) {
        return released[account];
    }

    function emergencyWithdraw() external {
        require(msg.sender == payees[0]);

        uint256 balance = address(this).balance;
        require(balance > 0);

        (bool success, ) = payable(msg.sender).call{value: balance}("");
        if (!success) {
            revert Failed();
        }
    }
}
