
pragma solidity ^0.8.19;

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
    uint256 public platformFee;
    uint256 public totalLoansCount;
    uint16 public constant MAX_INTEREST_RATE = 5000;
    uint32 public constant MIN_LOAN_DURATION = 86400;
    uint32 public constant MAX_LOAN_DURATION = 31536000;

    event LoanCreated(bytes32 indexed loanId, address indexed borrower, address indexed lender, uint256 amount);
    event LoanRepaid(bytes32 indexed loanId, uint256 repaymentAmount);
    event CollateralSeized(bytes32 indexed loanId, uint256 collateralAmount);
    event LenderRegistered(address indexed lender);
    event BorrowerRegistered(address indexed borrower);

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

    modifier validLoan(bytes32 _loanId) {
        require(loans[_loanId].borrower != address(0), "Loan does not exist");
        _;
    }

    constructor(uint256 _platformFee) {
        owner = msg.sender;
        platformFee = _platformFee;
    }

    function registerAsLender() external payable {
        require(!lenders[msg.sender].isRegistered, "Already registered as lender");
        require(msg.value > 0, "Must deposit initial funds");

        lenders[msg.sender] = LenderInfo({
            totalLent: 0,
            availableBalance: msg.value,
            isRegistered: true
        });

        emit LenderRegistered(msg.sender);
    }

    function registerAsBorrower(uint8 _creditScore) external {
        require(!borrowers[msg.sender].isRegistered, "Already registered as borrower");
        require(_creditScore <= 100, "Invalid credit score");

        borrowers[msg.sender] = BorrowerInfo({
            totalBorrowed: 0,
            activeLoans: 0,
            isRegistered: true,
            creditScore: _creditScore
        });

        emit BorrowerRegistered(msg.sender);
    }

    function depositFunds() external payable onlyRegisteredLender {
        require(msg.value > 0, "Must deposit positive amount");
        lenders[msg.sender].availableBalance += msg.value;
    }

    function createLoan(
        address _borrower,
        uint256 _principal,
        uint256 _interestRate,
        uint256 _duration,
        uint256 _collateralAmount,
        address _collateralToken
    ) external onlyRegisteredLender returns (bytes32) {
        require(borrowers[_borrower].isRegistered, "Borrower not registered");
        require(_principal > 0, "Principal must be positive");
        require(_interestRate <= MAX_INTEREST_RATE, "Interest rate too high");
        require(_duration >= MIN_LOAN_DURATION && _duration <= MAX_LOAN_DURATION, "Invalid duration");
        require(lenders[msg.sender].availableBalance >= _principal, "Insufficient lender balance");
        require(_collateralAmount > 0, "Collateral required");

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
        borrowers[_borrower].activeLoans++;

        activeLoanIds.push(loanId);
        totalLoansCount++;


        payable(_borrower).transfer(_principal);

        emit LoanCreated(loanId, _borrower, msg.sender, _principal);
        return loanId;
    }

    function repayLoan(bytes32 _loanId) external payable validLoan(_loanId) {
        Loan storage loan = loans[_loanId];
        require(msg.sender == loan.borrower, "Only borrower can repay");
        require(loan.isActive, "Loan not active");
        require(!loan.isRepaid, "Loan already repaid");

        uint256 interest = calculateInterest(_loanId);
        uint256 totalRepayment = loan.principal + interest;
        uint256 fee = (totalRepayment * platformFee) / 10000;
        uint256 lenderAmount = totalRepayment - fee;

        require(msg.value >= totalRepayment, "Insufficient repayment amount");

        loan.isActive = false;
        loan.isRepaid = true;
        borrowers[msg.sender].activeLoans--;


        payable(loan.lender).transfer(lenderAmount);
        lenders[loan.lender].availableBalance += lenderAmount;


        if (fee > 0) {
            payable(owner).transfer(fee);
        }


        if (msg.value > totalRepayment) {
            payable(msg.sender).transfer(msg.value - totalRepayment);
        }

        _removeLoanFromActive(_loanId);
        emit LoanRepaid(_loanId, totalRepayment);
    }

    function seizeCollateral(bytes32 _loanId) external validLoan(_loanId) {
        Loan storage loan = loans[_loanId];
        require(msg.sender == loan.lender, "Only lender can seize collateral");
        require(loan.isActive, "Loan not active");
        require(block.timestamp > loan.startTime + loan.duration, "Loan not expired");
        require(!loan.isRepaid, "Loan already repaid");

        loan.isActive = false;
        borrowers[loan.borrower].activeLoans--;




        _removeLoanFromActive(_loanId);
        emit CollateralSeized(_loanId, loan.collateralAmount);
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

    function getActiveLoanIds() external view returns (bytes32[] memory) {
        return activeLoanIds;
    }

    function withdrawLenderFunds(uint256 _amount) external onlyRegisteredLender {
        require(_amount > 0, "Amount must be positive");
        require(lenders[msg.sender].availableBalance >= _amount, "Insufficient balance");

        lenders[msg.sender].availableBalance -= _amount;
        payable(msg.sender).transfer(_amount);
    }

    function updatePlatformFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 1000, "Fee too high");
        platformFee = _newFee;
    }

    function _removeLoanFromActive(bytes32 _loanId) internal {
        for (uint256 i = 0; i < activeLoanIds.length; i++) {
            if (activeLoanIds[i] == _loanId) {
                activeLoanIds[i] = activeLoanIds[activeLoanIds.length - 1];
                activeLoanIds.pop();
                break;
            }
        }
    }

    receive() external payable {
        if (lenders[msg.sender].isRegistered) {
            lenders[msg.sender].availableBalance += msg.value;
        }
    }
}
