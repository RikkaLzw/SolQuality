
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

        uint256 payment = releasable(payee);
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

    function updateShare(address payee, uint256 newShare) external onlyOwner {
        require(shares[payee] > 0);
        require(newShare > 0);

        uint256 payment = releasable(payee);
        if (payment > 0) {
            released[payee] += payment;
            totalReleased += payment;
            payable(payee).transfer(payment);
            emit PaymentReleased(payee, payment);
        }

        totalShares = totalShares - shares[payee] + newShare;
        shares[payee] = newShare;
    }

    function release(address payee) external {
        require(shares[payee] > 0);

        uint256 payment = releasable(payee);
        require(payment > 0);

        released[payee] += payment;
        totalReleased += payment;

        payable(payee).transfer(payment);
        emit PaymentReleased(payee, payment);
    }

    function releaseAll() external {
        for (uint256 i = 0; i < payees.length; i++) {
            address payee = payees[i];
            uint256 payment = releasable(payee);

            if (payment > 0) {
                released[payee] += payment;
                totalReleased += payment;
                payable(payee).transfer(payment);
                emit PaymentReleased(payee, payment);
            }
        }
    }

    function emergencyWithdraw() external onlyOwner {
        require(address(this).balance > 0);
        payable(owner).transfer(address(this).balance);
    }

    function releasable(address payee) public view returns (uint256) {
        uint256 totalReceived = address(this).balance + totalReleased;
        return (totalReceived * shares[payee] / totalShares) - released[payee];
    }

    function getPayeesCount() external view returns (uint256) {
        return payees.length;
    }

    function getPayee(uint256 index) external view returns (address) {
        require(index < payees.length);
        return payees[index];
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0));
        owner = newOwner;
    }
}
