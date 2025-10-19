
pragma solidity ^0.8.0;

contract LendingProtocolContract {

    uint256 public constant INTEREST_RATE = 5;
    uint256 public constant MAX_LOAN_DURATION = 365;
    uint256 public loanCounter = 0;


    mapping(uint256 => string) public loanIds;
    mapping(address => string) public userIds;


    mapping(uint256 => bytes) public loanSignatures;
    mapping(address => bytes) public userProfiles;

    struct Loan {
        address borrower;
        address lender;
        uint256 amount;
        uint256 interestRate;
        uint256 duration;
        uint256 startTime;

        uint256 isActive;
        uint256 isRepaid;
        uint256 collateralRequired;
    }

    mapping(uint256 => Loan) public loans;
    mapping(address => uint256[]) public borrowerLoans;
    mapping(address => uint256[]) public lenderLoans;
    mapping(address => uint256) public userBalances;

    event LoanCreated(uint256 indexed loanId, address indexed borrower, address indexed lender, uint256 amount);
    event LoanRepaid(uint256 indexed loanId, uint256 totalAmount);
    event CollateralDeposited(uint256 indexed loanId, uint256 amount);

    modifier onlyActiveLoan(uint256 _loanId) {
        require(loans[_loanId].isActive == 1, "Loan is not active");
        _;
    }

    modifier onlyBorrower(uint256 _loanId) {
        require(msg.sender == loans[_loanId].borrower, "Only borrower can call this");
        _;
    }

    modifier onlyLender(uint256 _loanId) {
        require(msg.sender == loans[_loanId].lender, "Only lender can call this");
        _;
    }

    function registerUser(string memory _userId, bytes memory _profile) external {
        userIds[msg.sender] = _userId;
        userProfiles[msg.sender] = _profile;
    }

    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        userBalances[msg.sender] += msg.value;
    }

    function withdraw(uint256 _amount) external {
        require(userBalances[msg.sender] >= _amount, "Insufficient balance");
        userBalances[msg.sender] -= _amount;
        payable(msg.sender).transfer(_amount);
    }

    function createLoan(
        address _borrower,
        uint256 _amount,
        uint256 _duration,
        string memory _loanId,
        bytes memory _signature,

        uint256 _collateralRequired
    ) external {
        require(_borrower != address(0), "Invalid borrower address");
        require(_amount > 0, "Loan amount must be greater than 0");
        require(_duration > 0 && _duration <= MAX_LOAN_DURATION, "Invalid loan duration");
        require(userBalances[msg.sender] >= _amount, "Insufficient lender balance");
        require(_collateralRequired <= 1, "Invalid collateral flag");


        uint256 loanId = uint256(loanCounter);
        loanCounter = uint256(loanCounter + 1);

        loans[loanId] = Loan({
            borrower: _borrower,
            lender: msg.sender,
            amount: _amount,
            interestRate: uint256(INTEREST_RATE),
            duration: _duration,
            startTime: block.timestamp,
            isActive: uint256(1),
            isRepaid: uint256(0),
            collateralRequired: _collateralRequired
        });

        loanIds[loanId] = _loanId;
        loanSignatures[loanId] = _signature;

        borrowerLoans[_borrower].push(loanId);
        lenderLoans[msg.sender].push(loanId);

        userBalances[msg.sender] -= _amount;
        userBalances[_borrower] += _amount;

        emit LoanCreated(loanId, _borrower, msg.sender, _amount);
    }

    function depositCollateral(uint256 _loanId) external payable onlyActiveLoan(_loanId) onlyBorrower(_loanId) {
        require(loans[_loanId].collateralRequired == 1, "Collateral not required for this loan");
        require(msg.value > 0, "Collateral amount must be greater than 0");

        emit CollateralDeposited(_loanId, msg.value);
    }

    function repayLoan(uint256 _loanId) external onlyActiveLoan(_loanId) onlyBorrower(_loanId) {
        Loan storage loan = loans[_loanId];


        uint256 daysPassed = uint256((block.timestamp - loan.startTime) / 86400);
        uint256 interest = uint256((loan.amount * loan.interestRate * daysPassed) / (100 * 365));
        uint256 totalAmount = uint256(loan.amount + interest);

        require(userBalances[msg.sender] >= totalAmount, "Insufficient balance to repay loan");

        userBalances[msg.sender] -= totalAmount;
        userBalances[loan.lender] += totalAmount;


        loan.isActive = uint256(0);
        loan.isRepaid = uint256(1);

        emit LoanRepaid(_loanId, totalAmount);
    }

    function getLoanDetails(uint256 _loanId) external view returns (
        address borrower,
        address lender,
        uint256 amount,
        uint256 interestRate,
        uint256 duration,
        uint256 startTime,
        uint256 isActive,
        uint256 isRepaid,
        uint256 collateralRequired
    ) {
        Loan memory loan = loans[_loanId];
        return (
            loan.borrower,
            loan.lender,
            loan.amount,
            loan.interestRate,
            loan.duration,
            loan.startTime,
            loan.isActive,
            loan.isRepaid,
            loan.collateralRequired
        );
    }

    function calculateInterest(uint256 _loanId) external view returns (uint256) {
        Loan memory loan = loans[_loanId];
        require(loan.isActive == 1, "Loan is not active");


        uint256 daysPassed = uint256((block.timestamp - loan.startTime) / 86400);
        uint256 interest = uint256((loan.amount * loan.interestRate * daysPassed) / (100 * 365));

        return interest;
    }

    function getBorrowerLoans(address _borrower) external view returns (uint256[] memory) {
        return borrowerLoans[_borrower];
    }

    function getLenderLoans(address _lender) external view returns (uint256[] memory) {
        return lenderLoans[_lender];
    }

    function isLoanOverdue(uint256 _loanId) external view returns (uint256) {
        Loan memory loan = loans[_loanId];
        if (loan.isActive == 0) {
            return uint256(0);
        }

        uint256 daysPassed = (block.timestamp - loan.startTime) / 86400;
        if (daysPassed > loan.duration) {
            return uint256(1);
        }
        return uint256(0);
    }
}
