
pragma solidity ^0.8.0;

contract PaymentSplitter {
    address public owner;
    mapping(address => uint256) public shares;
    mapping(address => uint256) public released;
    address[] public payees;
    uint256 public totalShares;
    uint256 public totalReleased;

    error InvalidInput();
    error Failed();
    error NotAllowed();

    event PaymentReceived(address from, uint256 amount);
    event PaymentReleased(address to, uint256 amount);

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

    function removePayee(address payee) external onlyOwner {
        require(shares[payee] > 0);

        uint256 payeeShares = shares[payee];
        totalShares -= payeeShares;
        shares[payee] = 0;

        for (uint256 i = 0; i < payees.length; i++) {
            if (payees[i] == payee) {
                payees[i] = payees[payees.length - 1];
                payees.pop();
                break;
            }
        }
    }

    function updateShares(address payee, uint256 newShare) external onlyOwner {
        require(shares[payee] > 0);
        require(newShare > 0);

        uint256 oldShare = shares[payee];
        totalShares = totalShares - oldShare + newShare;
        shares[payee] = newShare;
    }

    function release(address payable account) external {
        require(shares[account] > 0);

        uint256 totalReceived = address(this).balance + totalReleased;
        uint256 payment = (totalReceived * shares[account]) / totalShares - released[account];

        require(payment > 0);

        released[account] += payment;
        totalReleased += payment;

        (bool success, ) = account.call{value: payment}("");
        if (!success) {
            revert Failed();
        }

        emit PaymentReleased(account, payment);
    }

    function releasable(address account) external view returns (uint256) {
        uint256 totalReceived = address(this).balance + totalReleased;
        return (totalReceived * shares[account]) / totalShares - released[account];
    }

    function getPayeesCount() external view returns (uint256) {
        return payees.length;
    }

    function getPayee(uint256 index) external view returns (address) {
        require(index < payees.length);
        return payees[index];
    }

    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0);

        (bool success, ) = payable(owner).call{value: balance}("");
        if (!success) {
            revert Failed();
        }
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0));
        owner = newOwner;
    }
}
