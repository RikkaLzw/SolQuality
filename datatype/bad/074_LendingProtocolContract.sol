
pragma solidity ^0.8.0;

contract LendingProtocolContract {

    uint256 public constant INTEREST_RATE = 5;
    uint256 public constant MAX_LOAN_DURATION = 30;
    uint256 public loanCounter = 0;


    string public protocolId = "LEND001";
    string public version = "1.0";


    bytes public contractHash;

    struct Loan {
        address borrower;
        address lender;
        uint256 amount;
        uint256 interestRate;
        uint256 duration;
        uint256 startTime;

        uint256 isActive;
        uint256 isRepaid;

        string loanId;
    }

    mapping(uint256 => Loan) public loans;
    mapping(address => uint256[]) public borrowerLoans;
    mapping(address => uint256[]) public lenderLoans;
    mapping(address => uint256) public balances;

    event LoanCreated(uint256 indexed loanIndex, address indexed borrower, address indexed lender, uint256 amount);
    event LoanRepaid(uint256 indexed loanIndex, uint256 totalAmount);
    event FundsDeposited(address indexed user, uint256 amount);
    event FundsWithdrawn(address indexed user, uint256 amount);

    constructor() {

        contractHash = abi.encodePacked(block.timestamp, msg.sender);
    }

    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        balances[msg.sender] += msg.value;
        emit FundsDeposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
        emit FundsWithdrawn(msg.sender, amount);
    }

    function createLoan(
        address borrower,
        uint256 amount,
        uint256 duration,
        string memory loanIdentifier
    ) external {
        require(borrower != address(0), "Invalid borrower address");
        require(amount > 0, "Loan amount must be greater than 0");
        require(duration > 0 && duration <= MAX_LOAN_DURATION, "Invalid loan duration");
        require(balances[msg.sender] >= amount, "Insufficient lender balance");


        uint256 convertedAmount = uint256(amount);
        uint256 convertedDuration = uint256(duration);

        balances[msg.sender] -= convertedAmount;

        loans[loanCounter] = Loan({
            borrower: borrower,
            lender: msg.sender,
            amount: convertedAmount,
            interestRate: INTEREST_RATE,
            duration: convertedDuration,
            startTime: block.timestamp,
            isActive: 1,
            isRepaid: 0,
            loanId: loanIdentifier
        });

        borrowerLoans[borrower].push(loanCounter);
        lenderLoans[msg.sender].push(loanCounter);

        payable(borrower).transfer(convertedAmount);

        emit LoanCreated(loanCounter, borrower, msg.sender, convertedAmount);


        loanCounter = loanCounter + uint256(1);
    }

    function repayLoan(uint256 loanIndex) external payable {
        Loan storage loan = loans[loanIndex];
        require(loan.borrower == msg.sender, "Only borrower can repay");
        require(loan.isActive == 1, "Loan is not active");
        require(loan.isRepaid == 0, "Loan already repaid");

        uint256 interest = (loan.amount * loan.interestRate) / 100;
        uint256 totalAmount = loan.amount + interest;

        require(msg.value >= totalAmount, "Insufficient repayment amount");

        loan.isActive = 0;
        loan.isRepaid = 1;

        balances[loan.lender] += totalAmount;

        if (msg.value > totalAmount) {
            payable(msg.sender).transfer(msg.value - totalAmount);
        }

        emit LoanRepaid(loanIndex, totalAmount);
    }

    function getLoanDetails(uint256 loanIndex) external view returns (
        address borrower,
        address lender,
        uint256 amount,
        uint256 interestRate,
        uint256 duration,
        uint256 startTime,
        uint256 isActive,
        uint256 isRepaid,
        string memory loanId
    ) {
        Loan storage loan = loans[loanIndex];
        return (
            loan.borrower,
            loan.lender,
            loan.amount,
            loan.interestRate,
            loan.duration,
            loan.startTime,
            loan.isActive,
            loan.isRepaid,
            loan.loanId
        );
    }

    function getBorrowerLoans(address borrower) external view returns (uint256[] memory) {
        return borrowerLoans[borrower];
    }

    function getLenderLoans(address lender) external view returns (uint256[] memory) {
        return lenderLoans[lender];
    }

    function calculateTotalRepayment(uint256 loanIndex) external view returns (uint256) {
        Loan storage loan = loans[loanIndex];
        require(loan.isActive == 1, "Loan is not active");


        uint256 convertedAmount = uint256(loan.amount);
        uint256 convertedRate = uint256(loan.interestRate);

        uint256 interest = (convertedAmount * convertedRate) / uint256(100);
        return convertedAmount + interest;
    }

    function isLoanOverdue(uint256 loanIndex) external view returns (uint256) {
        Loan storage loan = loans[loanIndex];
        if (loan.isActive == 0) {
            return 0;
        }

        uint256 endTime = loan.startTime + (loan.duration * 1 days);
        if (block.timestamp > endTime) {
            return 1;
        }
        return 0;
    }

    function updateProtocolInfo(string memory newId, bytes memory newHash) external {

        protocolId = newId;
        contractHash = newHash;
    }
}
