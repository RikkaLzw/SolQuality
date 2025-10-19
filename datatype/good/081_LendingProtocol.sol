
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
    uint256 public totalLoansCount;
    uint256 public constant MAX_INTEREST_RATE = 5000;
    uint256 public constant MIN_LOAN_DURATION = 86400;
    uint256 public constant MAX_LOAN_DURATION = 31536000;

    bool public contractPaused;

    event LoanCreated(bytes32 indexed loanId, address indexed borrower, address indexed lender, uint256 amount);
    event LoanRepaid(bytes32 indexed loanId, uint256 repaymentAmount);
    event CollateralSeized(bytes32 indexed loanId, uint256 collateralAmount);
    event LenderRegistered(address indexed lender);
    event BorrowerRegistered(address indexed borrower);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier whenNotPaused() {
        require(!contractPaused, "Contract is paused");
        _;
    }

    modifier validLoan(bytes32 _loanId) {
        require(loans[_loanId].borrower != address(0), "Loan does not exist");
        _;
    }

    constructor(uint256 _platformFeeRate) {
        owner = msg.sender;
        platformFeeRate = _platformFeeRate;
        contractPaused = false;
    }

    function registerAsLender() external {
        require(!lenders[msg.sender].isRegistered, "Already registered as lender");

        lenders[msg.sender] = LenderInfo({
            totalLent: 0,
            availableBalance: 0,
            isRegistered: true
        });

        emit LenderRegistered(msg.sender);
    }

    function registerAsBorrower() external {
        require(!borrowers[msg.sender].isRegistered, "Already registered as borrower");

        borrowers[msg.sender] = BorrowerInfo({
            totalBorrowed: 0,
            activeLoans: 0,
            isRegistered: true,
            creditScore: 50
        });

        emit BorrowerRegistered(msg.sender);
    }

    function depositFunds() external payable whenNotPaused {
        require(lenders[msg.sender].isRegistered, "Must be registered as lender");
        require(msg.value > 0, "Deposit amount must be greater than 0");

        lenders[msg.sender].availableBalance += msg.value;
    }

    function createLoan(
        address _borrower,
        uint256 _principal,
        uint256 _interestRate,
        uint256 _duration,
        uint256 _collateralAmount,
        address _collateralToken
    ) external whenNotPaused returns (bytes32) {
        require(lenders[msg.sender].isRegistered, "Must be registered as lender");
        require(borrowers[_borrower].isRegistered, "Borrower must be registered");
        require(_principal > 0, "Principal must be greater than 0");
        require(_interestRate <= MAX_INTEREST_RATE, "Interest rate too high");
        require(_duration >= MIN_LOAN_DURATION && _duration <= MAX_LOAN_DURATION, "Invalid loan duration");
        require(lenders[msg.sender].availableBalance >= _principal, "Insufficient lender balance");
        require(_collateralAmount > 0, "Collateral amount must be greater than 0");

        bytes32 loanId = keccak256(abi.encodePacked(
            msg.sender,
            _borrower,
            _principal,
            block.timestamp,
            totalLoansCount
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

        lenders[msg.sender].availableBalance -= _principal;
        lenders[msg.sender].totalLent += _principal;
        borrowers[_borrower].totalBorrowed += _principal;
        borrowers[_borrower].activeLoans += 1;

        activeLoanIds.push(loanId);
        totalLoansCount += 1;

        payable(_borrower).transfer(_principal);

        emit LoanCreated(loanId, _borrower, msg.sender, _principal);
        return loanId;
    }

    function repayLoan(bytes32 _loanId) external payable validLoan(_loanId) whenNotPaused {
        Loan storage loan = loans[_loanId];
        require(msg.sender == loan.borrower, "Only borrower can repay");
        require(loan.isActive, "Loan is not active");
        require(!loan.isRepaid, "Loan already repaid");

        uint256 repaymentAmount = calculateRepaymentAmount(_loanId);
        require(msg.value >= repaymentAmount, "Insufficient repayment amount");

        loan.isActive = false;
        loan.isRepaid = true;

        borrowers[loan.borrower].activeLoans -= 1;

        uint256 platformFee = (repaymentAmount * platformFeeRate) / 10000;
        uint256 lenderAmount = repaymentAmount - platformFee;

        lenders[loan.lender].availableBalance += lenderAmount;

        if (msg.value > repaymentAmount) {
            payable(msg.sender).transfer(msg.value - repaymentAmount);
        }

        _removeLoanFromActive(_loanId);

        emit LoanRepaid(_loanId, repaymentAmount);
    }

    function seizeCollateral(bytes32 _loanId) external validLoan(_loanId) whenNotPaused {
        Loan storage loan = loans[_loanId];
        require(msg.sender == loan.lender, "Only lender can seize collateral");
        require(loan.isActive, "Loan is not active");
        require(block.timestamp > loan.startTime + loan.duration, "Loan not yet due");
        require(!loan.isRepaid, "Loan already repaid");

        loan.isActive = false;
        borrowers[loan.borrower].activeLoans -= 1;

        _removeLoanFromActive(_loanId);

        emit CollateralSeized(_loanId, loan.collateralAmount);
    }

    function calculateRepaymentAmount(bytes32 _loanId) public view validLoan(_loanId) returns (uint256) {
        Loan memory loan = loans[_loanId];
        uint256 timeElapsed = block.timestamp - loan.startTime;
        uint256 interest = (loan.principal * loan.interestRate * timeElapsed) / (10000 * 365 days);
        return loan.principal + interest;
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

    function getActiveLoanCount() external view returns (uint256) {
        return activeLoanIds.length;
    }

    function withdrawFunds(uint256 _amount) external {
        require(lenders[msg.sender].isRegistered, "Must be registered as lender");
        require(_amount > 0, "Withdrawal amount must be greater than 0");
        require(lenders[msg.sender].availableBalance >= _amount, "Insufficient balance");

        lenders[msg.sender].availableBalance -= _amount;
        payable(msg.sender).transfer(_amount);
    }

    function updateCreditScore(address _borrower, uint8 _newScore) external onlyOwner {
        require(borrowers[_borrower].isRegistered, "Borrower not registered");
        require(_newScore <= 100, "Credit score cannot exceed 100");

        borrowers[_borrower].creditScore = _newScore;
    }

    function pauseContract() external onlyOwner {
        contractPaused = true;
    }

    function unpauseContract() external onlyOwner {
        contractPaused = false;
    }

    function updatePlatformFeeRate(uint256 _newFeeRate) external onlyOwner {
        require(_newFeeRate <= 1000, "Fee rate cannot exceed 10%");
        platformFeeRate = _newFeeRate;
    }

    function withdrawPlatformFees() external onlyOwner {
        uint256 balance = address(this).balance;
        uint256 totalLenderBalances = 0;

        for (uint256 i = 0; i < activeLoanIds.length; i++) {
            bytes32 loanId = activeLoanIds[i];
            if (loans[loanId].isActive) {
                totalLenderBalances += lenders[loans[loanId].lender].availableBalance;
            }
        }

        uint256 platformFees = balance - totalLenderBalances;
        if (platformFees > 0) {
            payable(owner).transfer(platformFees);
        }
    }

    function _removeLoanFromActive(bytes32 _loanId) private {
        for (uint256 i = 0; i < activeLoanIds.length; i++) {
            if (activeLoanIds[i] == _loanId) {
                activeLoanIds[i] = activeLoanIds[activeLoanIds.length - 1];
                activeLoanIds.pop();
                break;
            }
        }
    }

    receive() external payable {
        require(lenders[msg.sender].isRegistered, "Must be registered as lender to deposit");
        lenders[msg.sender].availableBalance += msg.value;
    }
}
