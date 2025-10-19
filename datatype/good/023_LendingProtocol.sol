
pragma solidity ^0.8.0;

contract LendingProtocol {

    uint256 public constant INTEREST_RATE_PRECISION = 10000;
    uint256 public constant MAX_LOAN_DURATION = 365 days;
    uint256 public constant MIN_LOAN_AMOUNT = 1 ether;


    bytes32 public constant DOMAIN_SEPARATOR = keccak256("LendingProtocol");

    struct Loan {
        address borrower;
        address lender;
        uint256 amount;
        uint256 interestRate;
        uint256 duration;
        uint256 startTime;
        uint256 repaymentAmount;
        bool isActive;
        bool isRepaid;
    }

    struct LenderProfile {
        uint256 totalLent;
        uint256 availableBalance;
        uint256 activeLoans;
        bool isRegistered;
    }

    struct BorrowerProfile {
        uint256 totalBorrowed;
        uint256 activeLoans;
        uint256 creditScore;
        bool isRegistered;
    }

    mapping(bytes32 => Loan) public loans;
    mapping(address => LenderProfile) public lenders;
    mapping(address => BorrowerProfile) public borrowers;
    mapping(address => bytes32[]) public userLoans;

    uint256 private loanCounter;
    address public owner;

    event LoanCreated(bytes32 indexed loanId, address indexed borrower, address indexed lender, uint256 amount);
    event LoanRepaid(bytes32 indexed loanId, uint256 repaymentAmount);
    event LenderRegistered(address indexed lender);
    event BorrowerRegistered(address indexed borrower);
    event FundsDeposited(address indexed lender, uint256 amount);
    event FundsWithdrawn(address indexed lender, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyRegisteredLender() {
        require(lenders[msg.sender].isRegistered, "Lender not registered");
        _;
    }

    modifier onlyRegisteredBorrower() {
        require(borrowers[msg.sender].isRegistered, "Borrower not registered");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function registerAsLender() external {
        require(!lenders[msg.sender].isRegistered, "Already registered as lender");

        lenders[msg.sender] = LenderProfile({
            totalLent: 0,
            availableBalance: 0,
            activeLoans: 0,
            isRegistered: true
        });

        emit LenderRegistered(msg.sender);
    }

    function registerAsBorrower() external {
        require(!borrowers[msg.sender].isRegistered, "Already registered as borrower");

        borrowers[msg.sender] = BorrowerProfile({
            totalBorrowed: 0,
            activeLoans: 0,
            creditScore: 500,
            isRegistered: true
        });

        emit BorrowerRegistered(msg.sender);
    }

    function depositFunds() external payable onlyRegisteredLender {
        require(msg.value > 0, "Deposit amount must be greater than 0");

        lenders[msg.sender].availableBalance += msg.value;

        emit FundsDeposited(msg.sender, msg.value);
    }

    function withdrawFunds(uint256 amount) external onlyRegisteredLender {
        require(amount > 0, "Withdrawal amount must be greater than 0");
        require(lenders[msg.sender].availableBalance >= amount, "Insufficient balance");

        lenders[msg.sender].availableBalance -= amount;
        payable(msg.sender).transfer(amount);

        emit FundsWithdrawn(msg.sender, amount);
    }

    function createLoan(
        address borrower,
        uint256 amount,
        uint256 interestRate,
        uint256 duration
    ) external onlyRegisteredLender returns (bytes32) {
        require(borrowers[borrower].isRegistered, "Borrower not registered");
        require(amount >= MIN_LOAN_AMOUNT, "Loan amount too small");
        require(duration <= MAX_LOAN_DURATION, "Loan duration too long");
        require(interestRate <= 5000, "Interest rate too high");
        require(lenders[msg.sender].availableBalance >= amount, "Insufficient lender balance");


        bytes32 loanId = keccak256(abi.encodePacked(
            msg.sender,
            borrower,
            amount,
            block.timestamp,
            loanCounter++
        ));


        uint256 repaymentAmount = amount + (amount * interestRate / INTEREST_RATE_PRECISION);

        loans[loanId] = Loan({
            borrower: borrower,
            lender: msg.sender,
            amount: amount,
            interestRate: interestRate,
            duration: duration,
            startTime: block.timestamp,
            repaymentAmount: repaymentAmount,
            isActive: true,
            isRepaid: false
        });


        lenders[msg.sender].availableBalance -= amount;
        lenders[msg.sender].totalLent += amount;
        lenders[msg.sender].activeLoans++;

        borrowers[borrower].totalBorrowed += amount;
        borrowers[borrower].activeLoans++;

        userLoans[msg.sender].push(loanId);
        userLoans[borrower].push(loanId);


        payable(borrower).transfer(amount);

        emit LoanCreated(loanId, borrower, msg.sender, amount);

        return loanId;
    }

    function repayLoan(bytes32 loanId) external payable {
        Loan storage loan = loans[loanId];

        require(loan.isActive, "Loan is not active");
        require(!loan.isRepaid, "Loan already repaid");
        require(msg.sender == loan.borrower, "Only borrower can repay");
        require(msg.value >= loan.repaymentAmount, "Insufficient repayment amount");


        loan.isActive = false;
        loan.isRepaid = true;


        lenders[loan.lender].activeLoans--;
        borrowers[loan.borrower].activeLoans--;


        if (block.timestamp <= loan.startTime + loan.duration) {
            borrowers[loan.borrower].creditScore = _min(1000, borrowers[loan.borrower].creditScore + 10);
        }


        payable(loan.lender).transfer(loan.repaymentAmount);


        if (msg.value > loan.repaymentAmount) {
            payable(msg.sender).transfer(msg.value - loan.repaymentAmount);
        }

        emit LoanRepaid(loanId, loan.repaymentAmount);
    }

    function liquidateLoan(bytes32 loanId) external {
        Loan storage loan = loans[loanId];

        require(loan.isActive, "Loan is not active");
        require(!loan.isRepaid, "Loan already repaid");
        require(block.timestamp > loan.startTime + loan.duration, "Loan not yet due");
        require(msg.sender == loan.lender || msg.sender == owner, "Not authorized to liquidate");


        loan.isActive = false;


        lenders[loan.lender].activeLoans--;
        borrowers[loan.borrower].activeLoans--;


        borrowers[loan.borrower].creditScore = borrowers[loan.borrower].creditScore > 50 ?
            borrowers[loan.borrower].creditScore - 50 : 0;
    }

    function getLoanDetails(bytes32 loanId) external view returns (
        address borrower,
        address lender,
        uint256 amount,
        uint256 interestRate,
        uint256 duration,
        uint256 startTime,
        uint256 repaymentAmount,
        bool isActive,
        bool isRepaid
    ) {
        Loan memory loan = loans[loanId];
        return (
            loan.borrower,
            loan.lender,
            loan.amount,
            loan.interestRate,
            loan.duration,
            loan.startTime,
            loan.repaymentAmount,
            loan.isActive,
            loan.isRepaid
        );
    }

    function getUserLoans(address user) external view returns (bytes32[] memory) {
        return userLoans[user];
    }

    function isLoanOverdue(bytes32 loanId) external view returns (bool) {
        Loan memory loan = loans[loanId];
        return loan.isActive && !loan.isRepaid && block.timestamp > loan.startTime + loan.duration;
    }

    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }


    bool public paused = false;

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    function pause() external onlyOwner {
        paused = true;
    }

    function unpause() external onlyOwner {
        paused = false;
    }
}
