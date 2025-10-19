
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


    constructor(address[] memory payeesArray, uint256[] memory sharesArray) payable {
        require(payeesArray.length == sharesArray.length, "PaymentSplitter: payees and shares length mismatch");
        require(payeesArray.length > 0, "PaymentSplitter: no payees");

        for (uint256 i = 0; i < payeesArray.length; i++) {
            addPayee(payeesArray[i], sharesArray[i]);
        }
    }


    receive() external payable virtual {
        emit PaymentReceived(msg.sender, msg.value);
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


    function getPayee(uint256 index) public view returns (address) {
        return payees[index];
    }


    function getPayeesCount() public view returns (uint256) {
        return payees.length;
    }


    function releasable(address account) public view returns (uint256) {
        uint256 totalReceived = address(this).balance + totalReleased;
        return pendingPayment(account, totalReceived, released[account]);
    }


    function release(address payable account) public virtual {
        require(shares[account] > 0, "PaymentSplitter: account has no shares");

        uint256 payment = releasable(account);
        require(payment != 0, "PaymentSplitter: account is not due payment");

        released[account] += payment;
        totalReleased += payment;

        account.transfer(payment);
        emit PaymentReleased(account, payment);
    }


    function pendingPayment(
        address account,
        uint256 totalReceived,
        uint256 alreadyReleased
    ) private view returns (uint256) {
        return (totalReceived * shares[account]) / totalShares - alreadyReleased;
    }


    function addPayee(address account, uint256 sharesAmount) private {
        require(account != address(0), "PaymentSplitter: account is the zero address");
        require(sharesAmount > 0, "PaymentSplitter: shares are 0");
        require(shares[account] == 0, "PaymentSplitter: account already has shares");

        payees.push(account);
        shares[account] = sharesAmount;
        totalShares = totalShares + sharesAmount;

        emit PayeeAdded(account, sharesAmount);
    }


    function releaseAll() external {
        for (uint256 i = 0; i < payees.length; i++) {
            address payable payee = payable(payees[i]);
            if (releasable(payee) > 0) {
                release(payee);
            }
        }
    }


    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
