
pragma solidity ^0.8.0;

contract LendingProtocolContract {

    uint256 public constant INTEREST_RATE = 5;
    uint256 public loanCounter = 0;
    uint256 public maxLoanDuration = 365;


    string public protocolId = "LEND001";
    string public version = "v1.0";


    mapping(address => bytes) public borrowerData;
    mapping(uint256 => bytes) public loanSignatures;

    struct Loan {
        address borrower;
        address lender;
        uint256 amount;
        uint256 interestRate;
        uint256 duration;
        uint256 startTime;

        uint256 isActive;
        uint256 isRepaid;
    }

    mapping(uint256 => Loan) public loans;
    mapping(address => uint256[]) public borrowerLoans;
    mapping(address => uint256[]) public lenderLoans;

    event LoanCreated(uint256 indexed loanId, address indexed borrower, address indexed lender, uint256 amount);
    event LoanRepaid(uint256 indexed loanId, uint256 amount);
    event InterestPaid(uint256 indexed loanId, uint256 interest);

    modifier onlyActiveLoan(uint256 _loanId) {
        require(loans[_loanId].isActive == 1, "Loan is not active");
        _;
    }

    modifier onlyBorrower(uint256 _loanId) {
        require(msg.sender == loans[_loanId].borrower, "Only borrower can call this");
        _;
    }

    function createLoan(
        address _lender,
        uint256 _amount,
        uint256 _duration,
        string memory _borrowerId
    ) external payable {
        require(_lender != address(0), "Invalid lender address");
        require(_amount > 0, "Amount must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");
        require(msg.value == _amount, "Sent value must equal loan amount");

        loanCounter++;


        uint256 convertedAmount = uint256(_amount);
        uint256 convertedDuration = uint256(_duration);

        loans[loanCounter] = Loan({
            borrower: msg.sender,
            lender: _lender,
            amount: convertedAmount,
            interestRate: INTEREST_RATE,
            duration: convertedDuration,
            startTime: block.timestamp,
            isActive: 1,
            isRepaid: 0
        });


        borrowerData[msg.sender] = bytes(_borrowerId);

        borrowerLoans[msg.sender].push(loanCounter);
        lenderLoans[_lender].push(loanCounter);


        payable(msg.sender).transfer(_amount);

        emit LoanCreated(loanCounter, msg.sender, _lender, _amount);
    }

    function repayLoan(uint256 _loanId) external payable onlyActiveLoan(_loanId) onlyBorrower(_loanId) {
        Loan storage loan = loans[_loanId];

        uint256 interest = calculateInterest(_loanId);
        uint256 totalAmount = loan.amount + interest;

        require(msg.value >= totalAmount, "Insufficient repayment amount");


        uint256 convertedRepayment = uint256(msg.value);

        loan.isActive = 0;
        loan.isRepaid = 1;


        payable(loan.lender).transfer(totalAmount);


        if (convertedRepayment > totalAmount) {
            payable(msg.sender).transfer(convertedRepayment - totalAmount);
        }

        emit LoanRepaid(_loanId, totalAmount);
        emit InterestPaid(_loanId, interest);
    }

    function calculateInterest(uint256 _loanId) public view returns (uint256) {
        Loan memory loan = loans[_loanId];


        uint256 convertedTime = uint256(block.timestamp - loan.startTime);
        uint256 convertedRate = uint256(loan.interestRate);


        uint256 daysElapsed = convertedTime / 86400;
        uint256 interest = (loan.amount * convertedRate * daysElapsed) / (100 * 365);

        return interest;
    }

    function getLoanStatus(uint256 _loanId) external view returns (
        address borrower,
        address lender,
        uint256 amount,
        uint256 interestRate,
        uint256 duration,
        uint256 startTime,
        bool isActive,
        bool isRepaid
    ) {
        Loan memory loan = loans[_loanId];
        return (
            loan.borrower,
            loan.lender,
            loan.amount,
            loan.interestRate,
            loan.duration,
            loan.startTime,
            loan.isActive == 1,
            loan.isRepaid == 1
        );
    }

    function getBorrowerLoans(address _borrower) external view returns (uint256[] memory) {
        return borrowerLoans[_borrower];
    }

    function getLenderLoans(address _lender) external view returns (uint256[] memory) {
        return lenderLoans[_lender];
    }

    function updateBorrowerData(bytes memory _data) external {

        borrowerData[msg.sender] = _data;
    }

    function setLoanSignature(uint256 _loanId, bytes memory _signature) external onlyBorrower(_loanId) {

        loanSignatures[_loanId] = _signature;
    }


    function updateMaxDuration(uint256 _newDuration) external {
        require(_newDuration > 0 && _newDuration <= 3650, "Invalid duration");
        maxLoanDuration = _newDuration;
    }


    function isLoanOverdue(uint256 _loanId) external view returns (uint256) {
        Loan memory loan = loans[_loanId];

        if (loan.isActive == 0) {
            return 0;
        }

        uint256 endTime = loan.startTime + (loan.duration * 86400);

        if (block.timestamp > endTime) {
            return 1;
        }

        return 0;
    }
}
