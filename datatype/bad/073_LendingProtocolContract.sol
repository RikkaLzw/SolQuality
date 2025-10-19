
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

    event LoanCreated(uint256 indexed loanIndex, address indexed borrower, address indexed lender, uint256 amount);
    event LoanRepaid(uint256 indexed loanIndex, address indexed borrower, uint256 totalAmount);

    modifier onlyActiveLoan(uint256 _loanIndex) {
        require(loans[_loanIndex].isActive == 1, "Loan is not active");
        _;
    }

    modifier onlyBorrower(uint256 _loanIndex) {
        require(msg.sender == loans[_loanIndex].borrower, "Only borrower can call this");
        _;
    }

    function createLoan(
        address _borrower,
        uint256 _amount,
        uint256 _duration,
        string memory _loanId
    ) external payable {
        require(msg.value == _amount, "Sent value must equal loan amount");
        require(_amount > 0, "Loan amount must be greater than 0");
        require(_duration > 0 && _duration <= MAX_LOAN_DURATION, "Invalid loan duration");


        uint256 convertedAmount = uint256(_amount);
        uint256 convertedDuration = uint256(_duration);

        loans[loanCounter] = Loan({
            borrower: _borrower,
            lender: msg.sender,
            amount: convertedAmount,
            interestRate: INTEREST_RATE,
            duration: convertedDuration,
            startTime: block.timestamp,
            isActive: 1,
            isRepaid: 0,
            loanId: _loanId
        });

        borrowerLoans[_borrower].push(loanCounter);
        lenderLoans[msg.sender].push(loanCounter);


        payable(_borrower).transfer(_amount);

        emit LoanCreated(loanCounter, _borrower, msg.sender, _amount);
        loanCounter++;
    }

    function repayLoan(uint256 _loanIndex) external payable onlyActiveLoan(_loanIndex) onlyBorrower(_loanIndex) {
        Loan storage loan = loans[_loanIndex];


        uint256 interest = (loan.amount * loan.interestRate) / 100;
        uint256 totalAmount = loan.amount + interest;

        require(msg.value >= totalAmount, "Insufficient repayment amount");


        uint256 convertedRepayment = uint256(msg.value);
        require(convertedRepayment >= totalAmount, "Double check: insufficient amount");


        loan.isActive = 0;
        loan.isRepaid = 1;


        payable(loan.lender).transfer(totalAmount);


        if (msg.value > totalAmount) {
            payable(msg.sender).transfer(msg.value - totalAmount);
        }

        emit LoanRepaid(_loanIndex, msg.sender, totalAmount);
    }

    function getLoanDetails(uint256 _loanIndex) external view returns (
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
        Loan memory loan = loans[_loanIndex];
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

    function calculateRepaymentAmount(uint256 _loanIndex) external view returns (uint256) {
        Loan memory loan = loans[_loanIndex];
        require(loan.isActive == 1, "Loan is not active");

        uint256 interest = (loan.amount * loan.interestRate) / 100;
        return loan.amount + interest;
    }

    function getBorrowerLoans(address _borrower) external view returns (uint256[] memory) {
        return borrowerLoans[_borrower];
    }

    function getLenderLoans(address _lender) external view returns (uint256[] memory) {
        return lenderLoans[_lender];
    }

    function isLoanExpired(uint256 _loanIndex) external view returns (uint256) {
        Loan memory loan = loans[_loanIndex];

        if (block.timestamp > loan.startTime + (loan.duration * 1 days)) {
            return 1;
        }
        return 0;
    }


    function updateContractHash(bytes memory _newHash) external {
        require(_newHash.length > 0, "Hash cannot be empty");
        contractHash = _newHash;
    }

    function getContractInfo() external view returns (string memory, string memory, bytes memory) {
        return (protocolId, version, contractHash);
    }
}
