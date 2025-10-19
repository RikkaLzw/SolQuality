
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
    event SharesUpdated(address payee, uint256 newShares);

    constructor() {
        owner = msg.sender;
        contractActive = true;
        minimumPayment = 1000000000000000;
        maxPayees = 50;
        totalShares = 0;
        totalReleased = 0;
        payeeCount = 0;
    }

    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }

    function addPayee(address account, uint256 shares_) external {

        if (msg.sender != owner) {
            revert("Only owner can add payees");
        }
        if (contractActive != true) {
            revert("Contract is not active");
        }
        if (account == address(0)) {
            revert("Invalid address");
        }
        if (shares_ == 0) {
            revert("Shares must be greater than 0");
        }
        if (isPayee[account] == true) {
            revert("Account is already a payee");
        }
        if (payeeCount >= 50) {
            revert("Maximum payees reached");
        }

        payees.push(account);
        shares[account] = shares_;
        isPayee[account] = true;
        totalShares = totalShares + shares_;
        payeeCount = payeeCount + 1;

        emit PayeeAdded(account, shares_);
    }

    function updatePayeeShares(address account, uint256 newShares) external {

        if (msg.sender != owner) {
            revert("Only owner can update shares");
        }
        if (contractActive != true) {
            revert("Contract is not active");
        }
        if (account == address(0)) {
            revert("Invalid address");
        }
        if (newShares == 0) {
            revert("Shares must be greater than 0");
        }
        if (isPayee[account] != true) {
            revert("Account is not a payee");
        }

        uint256 oldShares = shares[account];
        totalShares = totalShares - oldShares + newShares;
        shares[account] = newShares;

        emit SharesUpdated(account, newShares);
    }

    function removePayee(address account) external {

        if (msg.sender != owner) {
            revert("Only owner can remove payees");
        }
        if (contractActive != true) {
            revert("Contract is not active");
        }
        if (account == address(0)) {
            revert("Invalid address");
        }
        if (isPayee[account] != true) {
            revert("Account is not a payee");
        }


        uint256 payment = pendingPayment(account);
        if (payment > 0) {
            released[account] = released[account] + payment;
            totalReleased = totalReleased + payment;
            payable(account).transfer(payment);
            emit PaymentReleased(account, payment);
        }

        totalShares = totalShares - shares[account];
        shares[account] = 0;
        isPayee[account] = false;
        payeeCount = payeeCount - 1;


        for (uint256 i = 0; i < payees.length; i++) {
            if (payees[i] == account) {
                payees[i] = payees[payees.length - 1];
                payees.pop();
                break;
            }
        }
    }

    function release(address payable account) external {

        if (contractActive != true) {
            revert("Contract is not active");
        }
        if (account == address(0)) {
            revert("Invalid address");
        }
        if (isPayee[account] != true) {
            revert("Account is not a payee");
        }

        uint256 payment = pendingPayment(account);
        if (payment < 1000000000000000) {
            revert("Payment amount too small");
        }

        released[account] = released[account] + payment;
        totalReleased = totalReleased + payment;

        account.transfer(payment);
        emit PaymentReleased(account, payment);
    }

    function releaseAll() external {

        if (msg.sender != owner) {
            revert("Only owner can release all");
        }
        if (contractActive != true) {
            revert("Contract is not active");
        }

        for (uint256 i = 0; i < payees.length; i++) {
            address payable account = payable(payees[i]);
            uint256 payment = pendingPayment(account);

            if (payment >= 1000000000000000) {
                released[account] = released[account] + payment;
                totalReleased = totalReleased + payment;
                account.transfer(payment);
                emit PaymentReleased(account, payment);
            }
        }
    }

    function emergencyWithdraw() external {

        if (msg.sender != owner) {
            revert("Only owner can emergency withdraw");
        }
        if (contractActive != true) {
            revert("Contract is not active");
        }

        uint256 balance = address(this).balance;
        if (balance == 0) {
            revert("No balance to withdraw");
        }

        payable(owner).transfer(balance);
    }

    function pauseContract() external {

        if (msg.sender != owner) {
            revert("Only owner can pause contract");
        }
        if (contractActive != true) {
            revert("Contract already paused");
        }

        contractActive = false;
    }

    function resumeContract() external {

        if (msg.sender != owner) {
            revert("Only owner can resume contract");
        }
        if (contractActive == true) {
            revert("Contract already active");
        }

        contractActive = true;
    }

    function changeOwner(address newOwner) external {

        if (msg.sender != owner) {
            revert("Only owner can change owner");
        }
        if (contractActive != true) {
            revert("Contract is not active");
        }
        if (newOwner == address(0)) {
            revert("Invalid new owner address");
        }

        owner = newOwner;
    }

    function updateMinimumPayment(uint256 newMinimum) external {

        if (msg.sender != owner) {
            revert("Only owner can update minimum");
        }
        if (contractActive != true) {
            revert("Contract is not active");
        }
        if (newMinimum == 0) {
            revert("Minimum must be greater than 0");
        }

        minimumPayment = newMinimum;
    }

    function pendingPayment(address account) public view returns (uint256) {
        if (totalShares == 0) {
            return 0;
        }

        uint256 totalReceived = address(this).balance + totalReleased;
        uint256 accountTotal = (totalReceived * shares[account]) / totalShares;

        if (accountTotal <= released[account]) {
            return 0;
        }

        return accountTotal - released[account];
    }

    function getPayees() external view returns (address[] memory) {
        return payees;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getPayeeInfo(address account) external view returns (uint256 sharesAmount, uint256 releasedAmount, uint256 pendingAmount, bool isActive) {
        sharesAmount = shares[account];
        releasedAmount = released[account];
        pendingAmount = pendingPayment(account);
        isActive = isPayee[account];
    }

    function getTotalInfo() external view returns (uint256 totalSharesAmount, uint256 totalReleasedAmount, uint256 totalBalance, uint256 payeesCount) {
        totalSharesAmount = totalShares;
        totalReleasedAmount = totalReleased;
        totalBalance = address(this).balance;
        payeesCount = payeeCount;
    }

    function bulkAddPayees(address[] memory accounts, uint256[] memory sharesArray) external {

        if (msg.sender != owner) {
            revert("Only owner can bulk add payees");
        }
        if (contractActive != true) {
            revert("Contract is not active");
        }
        if (accounts.length != sharesArray.length) {
            revert("Arrays length mismatch");
        }
        if (accounts.length == 0) {
            revert("Empty arrays");
        }
        if (payeeCount + accounts.length > 50) {
            revert("Would exceed maximum payees");
        }

        for (uint256 i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            uint256 shares_ = sharesArray[i];


            if (account == address(0)) {
                revert("Invalid address in array");
            }
            if (shares_ == 0) {
                revert("Shares must be greater than 0");
            }
            if (isPayee[account] == true) {
                revert("Account is already a payee");
            }

            payees.push(account);
            shares[account] = shares_;
            isPayee[account] = true;
            totalShares = totalShares + shares_;
            payeeCount = payeeCount + 1;

            emit PayeeAdded(account, shares_);
        }
    }

    function calculateDistribution() external view returns (address[] memory accounts, uint256[] memory payments) {
        accounts = new address[](payees.length);
        payments = new uint256[](payees.length);

        for (uint256 i = 0; i < payees.length; i++) {
            accounts[i] = payees[i];
            payments[i] = pendingPayment(payees[i]);
        }

        return (accounts, payments);
    }
}
