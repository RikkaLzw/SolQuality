
pragma solidity ^0.8.0;

contract PaymentDistributionContract {
    mapping(address => uint256) public shares;
    mapping(address => uint256) public released;
    address[] public payees;
    uint256 public totalShares;
    uint256 public totalReleased;

    address public owner;
    bool public paused;
    uint256 public minPayment;
    uint256 public maxPayees;

    event PaymentReleased(address to, uint256 amount);
    event PaymentReceived(address from, uint256 amount);
    event SharesUpdated(address payee, uint256 shares);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier notPaused() {
        require(!paused, "Contract paused");
        _;
    }

    constructor(address[] memory _payees, uint256[] memory _shares, uint256 _minPayment, uint256 _maxPayees, bool _initialPaused) {
        require(_payees.length == _shares.length, "Arrays length mismatch");
        require(_payees.length > 0, "No payees");

        owner = msg.sender;
        minPayment = _minPayment;
        maxPayees = _maxPayees;
        paused = _initialPaused;

        for (uint256 i = 0; i < _payees.length; i++) {
            require(_payees[i] != address(0), "Invalid payee");
            require(_shares[i] > 0, "Invalid shares");

            payees.push(_payees[i]);
            shares[_payees[i]] = _shares[i];
            totalShares += _shares[i];
        }
    }


    function managePaymentAndUpdateSystemWithComplexLogic(
        address payee,
        uint256 newShares,
        bool updatePaused,
        bool forceRelease,
        uint256 customAmount,
        address alternativeRecipient
    ) public onlyOwner returns (bool) {

        if (updatePaused) {
            paused = !paused;
            if (paused) {
                if (address(this).balance > minPayment) {
                    if (payees.length > 0) {
                        for (uint256 i = 0; i < payees.length; i++) {
                            if (shares[payees[i]] > 0) {
                                uint256 payment = (address(this).balance * shares[payees[i]]) / totalShares;
                                if (payment > 0) {
                                    released[payees[i]] += payment;
                                    totalReleased += payment;
                                    payable(payees[i]).transfer(payment);
                                }
                            }
                        }
                    }
                }
            }
        }


        if (newShares > 0 && payee != address(0)) {
            if (shares[payee] == 0) {
                if (payees.length < maxPayees) {
                    payees.push(payee);
                    shares[payee] = newShares;
                    totalShares += newShares;
                } else {
                    if (forceRelease) {
                        for (uint256 j = 0; j < payees.length; j++) {
                            if (shares[payees[j]] == 0) {
                                payees[j] = payee;
                                shares[payee] = newShares;
                                totalShares += newShares;
                                break;
                            }
                        }
                    }
                }
            } else {
                totalShares = totalShares - shares[payee] + newShares;
                shares[payee] = newShares;
            }
        }


        if (customAmount > 0) {
            address recipient = alternativeRecipient != address(0) ? alternativeRecipient : payee;
            if (recipient != address(0)) {
                if (address(this).balance >= customAmount) {
                    if (forceRelease || !paused) {
                        if (shares[recipient] > 0 || forceRelease) {
                            released[recipient] += customAmount;
                            totalReleased += customAmount;
                            payable(recipient).transfer(customAmount);
                            emit PaymentReleased(recipient, customAmount);
                        }
                    }
                }
            }
        }


        bool hasValidPayees = false;
        for (uint256 k = 0; k < payees.length; k++) {
            if (shares[payees[k]] > 0) {
                hasValidPayees = true;
                if (released[payees[k]] > address(this).balance) {
                    if (forceRelease) {
                        released[payees[k]] = address(this).balance;
                    }
                }
            }
        }

        return hasValidPayees;
    }


    function calculatePaymentAmountWithComplexRules(address payee) public view returns (uint256) {
        if (shares[payee] == 0) return 0;
        if (totalShares == 0) return 0;

        uint256 totalReceived = address(this).balance + totalReleased;
        uint256 payment = (totalReceived * shares[payee]) / totalShares;

        if (payment <= released[payee]) return 0;
        return payment - released[payee];
    }

    function release(address payable account) public notPaused {
        require(shares[account] > 0, "Account has no shares");

        uint256 payment = calculatePaymentAmountWithComplexRules(account);
        require(payment != 0, "Account is not due payment");

        released[account] += payment;
        totalReleased += payment;

        account.transfer(payment);
        emit PaymentReleased(account, payment);
    }

    function addPayee(address account, uint256 shares_) public onlyOwner {
        require(account != address(0), "Invalid account");
        require(shares_ > 0, "Shares must be greater than 0");
        require(shares[account] == 0, "Account already has shares");
        require(payees.length < maxPayees, "Max payees reached");

        payees.push(account);
        shares[account] = shares_;
        totalShares += shares_;

        emit SharesUpdated(account, shares_);
    }

    function updateShares(address account, uint256 newShares) public onlyOwner {
        require(account != address(0), "Invalid account");
        require(shares[account] > 0, "Account has no shares");

        totalShares = totalShares - shares[account] + newShares;
        shares[account] = newShares;

        emit SharesUpdated(account, newShares);
    }

    function setPaused(bool _paused) public onlyOwner {
        paused = _paused;
    }

    function setMinPayment(uint256 _minPayment) public onlyOwner {
        minPayment = _minPayment;
    }

    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }

    function getPayeesCount() public view returns (uint256) {
        return payees.length;
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
