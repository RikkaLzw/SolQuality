
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


    address private owner;


    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }


    modifier validAddress(address account) {
        require(account != address(0), "Invalid address: zero address");
        _;
    }


    constructor(address[] memory payeeAddresses, uint256[] memory payeeShares) {
        require(payeeAddresses.length == payeeShares.length, "Payees and shares length mismatch");
        require(payeeAddresses.length > 0, "No payees provided");

        owner = msg.sender;

        for (uint256 i = 0; i < payeeAddresses.length; i++) {
            addPayee(payeeAddresses[i], payeeShares[i]);
        }
    }


    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }


    function addPayee(address account, uint256 shareAmount)
        public
        onlyOwner
        validAddress(account)
    {
        require(shareAmount > 0, "Shares must be greater than 0");
        require(shares[account] == 0, "Account already has shares");

        payees.push(account);
        shares[account] = shareAmount;
        totalShares += shareAmount;

        emit PayeeAdded(account, shareAmount);
    }


    function release(address payable account) public validAddress(account) {
        require(shares[account] > 0, "Account has no shares");

        uint256 totalReceived = address(this).balance + totalReleased;
        uint256 payment = calculatePayment(account, totalReceived);

        require(payment > 0, "Account is not due payment");

        released[account] += payment;
        totalReleased += payment;

        account.transfer(payment);

        emit PaymentReleased(account, payment);
    }


    function releaseAll() public {
        for (uint256 i = 0; i < payees.length; i++) {
            address payeeAddress = payees[i];
            uint256 totalReceived = address(this).balance + totalReleased;
            uint256 payment = calculatePayment(payeeAddress, totalReceived);

            if (payment > 0) {
                released[payeeAddress] += payment;
                totalReleased += payment;

                payable(payeeAddress).transfer(payment);

                emit PaymentReleased(payeeAddress, payment);
            }
        }
    }


    function calculatePayment(address account, uint256 totalReceived)
        private
        view
        returns (uint256)
    {
        uint256 totalDue = (totalReceived * shares[account]) / totalShares;
        return totalDue - released[account];
    }


    function getShares(address account) public view returns (uint256) {
        return shares[account];
    }


    function getReleased(address account) public view returns (uint256) {
        return released[account];
    }


    function getTotalShares() public view returns (uint256) {
        return totalShares;
    }


    function getTotalReleased() public view returns (uint256) {
        return totalReleased;
    }


    function getPayees() public view returns (address[] memory) {
        return payees;
    }


    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }


    function getPendingPayment(address account) public view returns (uint256) {
        uint256 totalReceived = address(this).balance + totalReleased;
        return calculatePayment(account, totalReceived);
    }


    function getOwner() public view returns (address) {
        return owner;
    }
}
