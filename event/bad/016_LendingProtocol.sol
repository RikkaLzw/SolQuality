
pragma solidity ^0.8.0;

contract LendingProtocol {
    struct Loan {
        address borrower;
        uint256 amount;
        uint256 interestRate;
        uint256 duration;
        uint256 startTime;
        bool isActive;
        bool isRepaid;
    }

    mapping(address => uint256) public balances;
    mapping(uint256 => Loan) public loans;
    mapping(address => uint256[]) public userLoans;

    uint256 public totalDeposits;
    uint256 public totalLoans;
    uint256 public nextLoanId;
    address public owner;


    event Deposit(address user, uint256 amount);
    event Withdrawal(address user, uint256 amount);
    event LoanCreated(uint256 loanId, address borrower, uint256 amount);
    event LoanRepaid(uint256 loanId, address borrower, uint256 amount);


    error InvalidInput();
    error NotAllowed();
    error Failed();

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {

        require(msg.sender == owner);
        _;
    }

    function deposit() external payable {

        require(msg.value > 0);

        balances[msg.sender] += msg.value;
        totalDeposits += msg.value;




        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {

        require(balances[msg.sender] >= amount);
        require(amount > 0);

        balances[msg.sender] -= amount;
        totalDeposits -= amount;




        payable(msg.sender).transfer(amount);
        emit Withdrawal(msg.sender, amount);
    }

    function requestLoan(uint256 amount, uint256 duration) external {

        require(amount > 0);
        require(duration > 0);
        require(address(this).balance >= amount);

        uint256 interestRate = calculateInterestRate(amount);

        loans[nextLoanId] = Loan({
            borrower: msg.sender,
            amount: amount,
            interestRate: interestRate,
            duration: duration,
            startTime: block.timestamp,
            isActive: true,
            isRepaid: false
        });

        userLoans[msg.sender].push(nextLoanId);
        totalLoans += amount;




        payable(msg.sender).transfer(amount);
        emit LoanCreated(nextLoanId, msg.sender, amount);

        nextLoanId++;
    }

    function repayLoan(uint256 loanId) external payable {
        Loan storage loan = loans[loanId];


        require(loan.borrower == msg.sender);
        require(loan.isActive);
        require(!loan.isRepaid);

        uint256 totalAmount = calculateRepaymentAmount(loanId);


        require(msg.value >= totalAmount);

        loan.isActive = false;
        loan.isRepaid = true;
        totalLoans -= loan.amount;




        if (msg.value > totalAmount) {
            payable(msg.sender).transfer(msg.value - totalAmount);
        }

        emit LoanRepaid(loanId, msg.sender, totalAmount);
    }

    function calculateInterestRate(uint256 amount) internal pure returns (uint256) {
        if (amount < 1 ether) {
            return 5;
        } else if (amount < 10 ether) {
            return 7;
        } else {
            return 10;
        }
    }

    function calculateRepaymentAmount(uint256 loanId) public view returns (uint256) {
        Loan memory loan = loans[loanId];


        require(loan.borrower != address(0));

        uint256 interest = (loan.amount * loan.interestRate) / 100;
        return loan.amount + interest;
    }

    function liquidateLoan(uint256 loanId) external onlyOwner {
        Loan storage loan = loans[loanId];


        require(loan.isActive);
        require(block.timestamp > loan.startTime + loan.duration);

        loan.isActive = false;
        totalLoans -= loan.amount;



    }

    function updateInterestRate(uint256 loanId, uint256 newRate) external onlyOwner {

        if (loans[loanId].borrower == address(0)) revert InvalidInput();
        if (!loans[loanId].isActive) revert NotAllowed();

        loans[loanId].interestRate = newRate;



    }

    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;


        require(balance > 0);

        payable(owner).transfer(balance);



    }

    function getUserLoanCount(address user) external view returns (uint256) {
        return userLoans[user].length;
    }

    function getLoanDetails(uint256 loanId) external view returns (
        address borrower,
        uint256 amount,
        uint256 interestRate,
        uint256 duration,
        uint256 startTime,
        bool isActive,
        bool isRepaid
    ) {
        Loan memory loan = loans[loanId];
        return (
            loan.borrower,
            loan.amount,
            loan.interestRate,
            loan.duration,
            loan.startTime,
            loan.isActive,
            loan.isRepaid
        );
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {
        balances[msg.sender] += msg.value;
        totalDeposits += msg.value;



    }
}
