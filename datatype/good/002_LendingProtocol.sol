
pragma solidity ^0.8.0;

contract LendingProtocol {
    struct Loan {
        address borrower;
        address lender;
        uint256 principal;
        uint256 interestRate;
        uint256 duration;
        uint256 startTime;
        uint256 collateralAmount;
        address collateralToken;
        bool isActive;
        bool isRepaid;
        bytes32 loanId;
    }

    struct LenderInfo {
        uint256 totalLent;
        uint256 availableBalance;
        bool isRegistered;
    }

    struct BorrowerInfo {
        uint256 totalBorrowed;
        uint256 activeLoans;
        bool isRegistered;
        uint8 creditScore;
    }

    mapping(bytes32 => Loan) public loans;
    mapping(address => LenderInfo) public lenders;
    mapping(address => BorrowerInfo) public borrowers;
    mapping(address => mapping(address => uint256)) public tokenBalances;

    bytes32[] public activeLoanIds;

    address public owner;
    uint256 public platformFeeRate;
    uint256 public minLoanAmount;
    uint256 public maxLoanDuration;
    bool public protocolActive;

    event LoanCreated(bytes32 indexed loanId, address indexed borrower, address indexed lender, uint256 amount);
    event LoanRepaid(bytes32 indexed loanId, uint256 totalAmount);
    event CollateralDeposited(bytes32 indexed loanId, address token, uint256 amount);
    event CollateralWithdrawn(bytes32 indexed loanId, address token, uint256 amount);
    event LenderRegistered(address indexed lender);
    event BorrowerRegistered(address indexed borrower);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier protocolIsActive() {
        require(protocolActive, "Protocol is paused");
        _;
    }

    modifier validLoan(bytes32 _loanId) {
        require(loans[_loanId].borrower != address(0), "Loan does not exist");
        _;
    }

    constructor(uint256 _platformFeeRate, uint256 _minLoanAmount, uint256 _maxLoanDuration) {
        owner = msg.sender;
        platformFeeRate = _platformFeeRate;
        minLoanAmount = _minLoanAmount;
        maxLoanDuration = _maxLoanDuration;
        protocolActive = true;
    }

    function registerAsLender() external {
        require(!lenders[msg.sender].isRegistered, "Already registered");

        lenders[msg.sender] = LenderInfo({
            totalLent: 0,
            availableBalance: 0,
            isRegistered: true
        });

        emit LenderRegistered(msg.sender);
    }

    function registerAsBorrower() external {
        require(!borrowers[msg.sender].isRegistered, "Already registered");

        borrowers[msg.sender] = BorrowerInfo({
            totalBorrowed: 0,
            activeLoans: 0,
            isRegistered: true,
            creditScore: 50
        });

        emit BorrowerRegistered(msg.sender);
    }

    function depositFunds() external payable protocolIsActive {
        require(lenders[msg.sender].isRegistered, "Not registered as lender");
        require(msg.value > 0, "Amount must be greater than 0");

        lenders[msg.sender].availableBalance += msg.value;
    }

    function createLoan(
        address _borrower,
        uint256 _principal,
        uint256 _interestRate,
        uint256 _duration,
        uint256 _collateralAmount,
        address _collateralToken
    ) external protocolIsActive returns (bytes32) {
        require(lenders[msg.sender].isRegistered, "Not registered as lender");
        require(borrowers[_borrower].isRegistered, "Borrower not registered");
        require(_principal >= minLoanAmount, "Amount below minimum");
        require(_duration <= maxLoanDuration, "Duration exceeds maximum");
        require(_principal <= lenders[msg.sender].availableBalance, "Insufficient lender balance");
        require(_collateralAmount > 0, "Collateral required");

        bytes32 loanId = keccak256(abi.encodePacked(
            msg.sender,
            _borrower,
            _principal,
            block.timestamp,
            block.number
        ));

        loans[loanId] = Loan({
            borrower: _borrower,
            lender: msg.sender,
            principal: _principal,
            interestRate: _interestRate,
            duration: _duration,
            startTime: block.timestamp,
            collateralAmount: _collateralAmount,
            collateralToken: _collateralToken,
            isActive: true,
            isRepaid: false,
            loanId: loanId
        });

        activeLoanIds.push(loanId);

        lenders[msg.sender].availableBalance -= _principal;
        lenders[msg.sender].totalLent += _principal;
        borrowers[_borrower].totalBorrowed += _principal;
        borrowers[_borrower].activeLoans++;

        payable(_borrower).transfer(_principal);

        emit LoanCreated(loanId, _borrower, msg.sender, _principal);
        return loanId;
    }

    function depositCollateral(bytes32 _loanId) external payable validLoan(_loanId) {
        Loan storage loan = loans[_loanId];
        require(msg.sender == loan.borrower, "Not the borrower");
        require(loan.isActive, "Loan not active");
        require(msg.value >= loan.collateralAmount, "Insufficient collateral");

        tokenBalances[loan.collateralToken][address(this)] += msg.value;

        emit CollateralDeposited(_loanId, loan.collateralToken, msg.value);
    }

    function repayLoan(bytes32 _loanId) external payable validLoan(_loanId) protocolIsActive {
        Loan storage loan = loans[_loanId];
        require(msg.sender == loan.borrower, "Not the borrower");
        require(loan.isActive, "Loan not active");
        require(!loan.isRepaid, "Loan already repaid");

        uint256 interest = calculateInterest(_loanId);
        uint256 platformFee = (interest * platformFeeRate) / 10000;
        uint256 totalRepayment = loan.principal + interest;
        uint256 lenderAmount = loan.principal + interest - platformFee;

        require(msg.value >= totalRepayment, "Insufficient repayment amount");

        loan.isActive = false;
        loan.isRepaid = true;

        borrowers[loan.borrower].activeLoans--;
        lenders[loan.lender].availableBalance += lenderAmount;

        payable(loan.lender).transfer(lenderAmount);
        if (platformFee > 0) {
            payable(owner).transfer(platformFee);
        }


        if (msg.value > totalRepayment) {
            payable(msg.sender).transfer(msg.value - totalRepayment);
        }


        if (loan.collateralAmount > 0) {
            payable(loan.borrower).transfer(loan.collateralAmount);
            emit CollateralWithdrawn(_loanId, loan.collateralToken, loan.collateralAmount);
        }

        emit LoanRepaid(_loanId, totalRepayment);
    }

    function liquidateLoan(bytes32 _loanId) external validLoan(_loanId) {
        Loan storage loan = loans[_loanId];
        require(loan.isActive, "Loan not active");
        require(block.timestamp > loan.startTime + loan.duration, "Loan not overdue");
        require(msg.sender == loan.lender || msg.sender == owner, "Not authorized");

        loan.isActive = false;
        borrowers[loan.borrower].activeLoans--;


        if (loan.collateralAmount > 0) {
            payable(loan.lender).transfer(loan.collateralAmount);
        }

        emit CollateralWithdrawn(_loanId, loan.collateralToken, loan.collateralAmount);
    }

    function calculateInterest(bytes32 _loanId) public view validLoan(_loanId) returns (uint256) {
        Loan memory loan = loans[_loanId];
        uint256 timeElapsed = block.timestamp - loan.startTime;
        if (timeElapsed > loan.duration) {
            timeElapsed = loan.duration;
        }
        return (loan.principal * loan.interestRate * timeElapsed) / (10000 * 365 days);
    }

    function getLoanDetails(bytes32 _loanId) external view validLoan(_loanId) returns (
        address borrower,
        address lender,
        uint256 principal,
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
            loan.principal,
            loan.interestRate,
            loan.duration,
            loan.startTime,
            loan.isActive,
            loan.isRepaid
        );
    }

    function withdrawFunds(uint256 _amount) external {
        require(lenders[msg.sender].isRegistered, "Not registered as lender");
        require(_amount <= lenders[msg.sender].availableBalance, "Insufficient balance");

        lenders[msg.sender].availableBalance -= _amount;
        payable(msg.sender).transfer(_amount);
    }

    function updateCreditScore(address _borrower, uint8 _newScore) external onlyOwner {
        require(borrowers[_borrower].isRegistered, "Borrower not registered");
        require(_newScore <= 100, "Invalid credit score");

        borrowers[_borrower].creditScore = _newScore;
    }

    function pauseProtocol() external onlyOwner {
        protocolActive = false;
    }

    function resumeProtocol() external onlyOwner {
        protocolActive = true;
    }

    function updatePlatformFee(uint256 _newFeeRate) external onlyOwner {
        require(_newFeeRate <= 1000, "Fee rate too high");
        platformFeeRate = _newFeeRate;
    }

    function getActiveLoanCount() external view returns (uint256) {
        return activeLoanIds.length;
    }

    receive() external payable {
        if (lenders[msg.sender].isRegistered) {
            lenders[msg.sender].availableBalance += msg.value;
        }
    }
}
