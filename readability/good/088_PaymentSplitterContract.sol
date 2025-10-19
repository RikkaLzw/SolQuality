
pragma solidity ^0.8.0;


contract PaymentSplitterContract {

    event PaymentReceived(address from, uint256 amount);
    event PaymentReleased(address to, uint256 amount);
    event PayeeAdded(address account, uint256 shares);


    uint256 private totalShares;
    uint256 private totalReleased;

    mapping(address => uint256) private shares;
    mapping(address => uint256) private released;
    address[] private payees;


    modifier onlyValidPayee(address account) {
        require(shares[account] > 0, "PaymentSplitter: account has no shares");
        _;
    }


    constructor(address[] memory payeesArray, uint256[] memory sharesArray) payable {
        require(
            payeesArray.length == sharesArray.length,
            "PaymentSplitter: payees and shares length mismatch"
        );
        require(payeesArray.length > 0, "PaymentSplitter: no payees");

        for (uint256 i = 0; i < payeesArray.length; i++) {
            addPayee(payeesArray[i], sharesArray[i]);
        }
    }


    receive() external payable virtual {
        emit PaymentReceived(msg.sender, msg.value);
    }


    function getPayeesCount() public view returns (uint256) {
        return payees.length;
    }


    function getPayee(uint256 index) public view returns (address) {
        require(index < payees.length, "PaymentSplitter: index out of bounds");
        return payees[index];
    }


    function getTotalShares() public view returns (uint256) {
        return totalShares;
    }


    function getTotalReleased() public view returns (uint256) {
        return totalReleased;
    }


    function getShares(address account) public view returns (uint256) {
        return shares[account];
    }


    function getReleased(address account) public view returns (uint256) {
        return released[account];
    }


    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }


    function getPendingPayment(address account) public view returns (uint256) {
        uint256 totalReceived = address(this).balance + totalReleased;
        uint256 payment = (totalReceived * shares[account]) / totalShares - released[account];
        return payment;
    }


    function release(address payable account) public virtual onlyValidPayee(account) {
        uint256 payment = getPendingPayment(account);
        require(payment > 0, "PaymentSplitter: account is not due payment");

        released[account] += payment;
        totalReleased += payment;

        (bool success, ) = account.call{value: payment}("");
        require(success, "PaymentSplitter: payment transfer failed");

        emit PaymentReleased(account, payment);
    }


    function releaseAll() public virtual {
        for (uint256 i = 0; i < payees.length; i++) {
            address payable payee = payable(payees[i]);
            uint256 payment = getPendingPayment(payee);

            if (payment > 0) {
                released[payee] += payment;
                totalReleased += payment;

                (bool success, ) = payee.call{value: payment}("");
                require(success, "PaymentSplitter: payment transfer failed");

                emit PaymentReleased(payee, payment);
            }
        }
    }


    function addPayee(address account, uint256 sharesAmount) private {
        require(account != address(0), "PaymentSplitter: account is the zero address");
        require(sharesAmount > 0, "PaymentSplitter: shares are 0");
        require(shares[account] == 0, "PaymentSplitter: account already has shares");

        payees.push(account);
        shares[account] = sharesAmount;
        totalShares += sharesAmount;

        emit PayeeAdded(account, sharesAmount);
    }


    function getAllPayeesInfo() public view returns (address[] memory, uint256[] memory) {
        uint256[] memory payeeShares = new uint256[](payees.length);

        for (uint256 i = 0; i < payees.length; i++) {
            payeeShares[i] = shares[payees[i]];
        }

        return (payees, payeeShares);
    }


    function isValidPayee(address account) public view returns (bool) {
        return shares[account] > 0;
    }
}
