
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
    event SharesUpdated(address account, uint256 oldShares, uint256 newShares);
    event ContractStatusChanged(bool status);

    constructor(address[] memory _payees, uint256[] memory _shares) {

        if (msg.sender == address(0)) {
            revert("Invalid owner");
        }
        owner = msg.sender;


        minimumPayment = 1000000000000000;
        maxPayees = 50;
        contractActive = true;


        if (_payees.length == 0) {
            revert("No payees provided");
        }
        if (_shares.length == 0) {
            revert("No shares provided");
        }
        if (_payees.length != _shares.length) {
            revert("Payees and shares length mismatch");
        }


        if (_payees.length > 50) {
            revert("Too many payees");
        }

        for (uint256 i = 0; i < _payees.length; i++) {

            if (_payees[i] == address(0)) {
                revert("Invalid payee address");
            }
            if (_shares[i] == 0) {
                revert("Shares must be greater than 0");
            }

            shares[_payees[i]] = _shares[i];
            payees.push(_payees[i]);
            isPayee[_payees[i]] = true;
            totalShares += _shares[i];
            payeeCount++;

            emit PayeeAdded(_payees[i], _shares[i]);
        }
    }

    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }


    function addPayee(address account, uint256 _shares) external {

        if (msg.sender != owner) {
            revert("Only owner can add payees");
        }


        if (!contractActive) {
            revert("Contract is not active");
        }


        if (account == address(0)) {
            revert("Invalid payee address");
        }
        if (_shares == 0) {
            revert("Shares must be greater than 0");
        }
        if (isPayee[account]) {
            revert("Account is already a payee");
        }


        if (payeeCount >= 50) {
            revert("Maximum payees reached");
        }

        shares[account] = _shares;
        payees.push(account);
        isPayee[account] = true;
        totalShares += _shares;
        payeeCount++;

        emit PayeeAdded(account, _shares);
    }


    function updateShares(address account, uint256 newShares) external {

        if (msg.sender != owner) {
            revert("Only owner can update shares");
        }


        if (!contractActive) {
            revert("Contract is not active");
        }


        if (account == address(0)) {
            revert("Invalid account address");
        }
        if (!isPayee[account]) {
            revert("Account is not a payee");
        }
        if (newShares == 0) {
            revert("Shares must be greater than 0");
        }

        uint256 oldShares = shares[account];
        totalShares = totalShares - oldShares + newShares;
        shares[account] = newShares;

        emit SharesUpdated(account, oldShares, newShares);
    }

    function release(address payable account) external {

        if (account == address(0)) {
            revert("Invalid account address");
        }
        if (!isPayee[account]) {
            revert("Account is not a payee");
        }

        uint256 totalReceived = address(this).balance + totalReleased;
        uint256 payment = (totalReceived * shares[account]) / totalShares - released[account];


        if (payment < 1000000000000000) {
            revert("Payment amount too small");
        }

        released[account] += payment;
        totalReleased += payment;

        account.transfer(payment);
        emit PaymentReleased(account, payment);
    }


    function releaseAll() external {

        if (msg.sender != owner) {
            revert("Only owner can release all");
        }

        for (uint256 i = 0; i < payees.length; i++) {
            address payable account = payable(payees[i]);


            if (account == address(0)) {
                continue;
            }

            uint256 totalReceived = address(this).balance + totalReleased;
            uint256 payment = (totalReceived * shares[account]) / totalShares - released[account];


            if (payment >= 1000000000000000) {
                released[account] += payment;
                totalReleased += payment;

                account.transfer(payment);
                emit PaymentReleased(account, payment);
            }
        }
    }

    function removePayee(address account) external {

        if (msg.sender != owner) {
            revert("Only owner can remove payees");
        }


        if (!contractActive) {
            revert("Contract is not active");
        }


        if (account == address(0)) {
            revert("Invalid account address");
        }
        if (!isPayee[account]) {
            revert("Account is not a payee");
        }


        uint256 totalReceived = address(this).balance + totalReleased;
        uint256 payment = (totalReceived * shares[account]) / totalShares - released[account];

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


    function setContractStatus(bool status) external {

        if (msg.sender != owner) {
            revert("Only owner can change status");
        }

        contractActive = status;
        emit ContractStatusChanged(status);
    }

    function setMinimumPayment(uint256 amount) external {

        if (msg.sender != owner) {
            revert("Only owner can set minimum payment");
        }


        if (!contractActive) {
            revert("Contract is not active");
        }

        minimumPayment = amount;
    }

    function pendingPayment(address account) external view returns (uint256) {

        if (account == address(0)) {
            return 0;
        }
        if (!isPayee[account]) {
            return 0;
        }

        uint256 totalReceived = address(this).balance + totalReleased;
        return (totalReceived * shares[account]) / totalShares - released[account];
    }


    function getPayeeInfo(address account) external view returns (uint256, uint256, bool) {
        return (shares[account], released[account], isPayee[account]);
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


    function emergencyWithdraw() external {

        if (msg.sender != owner) {
            revert("Only owner can emergency withdraw");
        }


        if (contractActive) {
            revert("Contract must be inactive for emergency withdraw");
        }

        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(owner).transfer(balance);
        }
    }

    function transferOwnership(address newOwner) external {

        if (msg.sender != owner) {
            revert("Only owner can transfer ownership");
        }


        if (newOwner == address(0)) {
            revert("Invalid new owner address");
        }

        owner = newOwner;
    }


    function bulkRelease(address[] memory accounts) external {

        if (msg.sender != owner) {
            revert("Only owner can bulk release");
        }


        if (accounts.length == 0) {
            revert("No accounts provided");
        }

        for (uint256 i = 0; i < accounts.length; i++) {
            address payable account = payable(accounts[i]);


            if (account == address(0)) {
                continue;
            }
            if (!isPayee[account]) {
                continue;
            }

            uint256 totalReceived = address(this).balance + totalReleased;
            uint256 payment = (totalReceived * shares[account]) / totalShares - released[account];


            if (payment >= 1000000000000000) {
                released[account] += payment;
                totalReleased += payment;

                account.transfer(payment);
                emit PaymentReleased(account, payment);
            }
        }
    }
}
