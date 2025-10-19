
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract OptimizedLendingProtocol {
    struct LoanInfo {
        uint128 principal;
        uint128 interest;
        uint64 startTime;
        uint64 duration;
        address borrower;
        address collateralToken;
        uint256 collateralAmount;
        bool isActive;
    }

    struct UserStats {
        uint128 totalBorrowed;
        uint128 totalLent;
        uint32 loanCount;
        uint32 lastActivityBlock;
    }

    IERC20 public immutable lendingToken;
    address public immutable owner;

    uint256 private constant INTEREST_RATE_BASE = 10000;
    uint256 private constant COLLATERAL_RATIO = 15000;
    uint256 private constant MAX_LOAN_DURATION = 365 days;

    uint256 public totalLiquidity;
    uint256 public totalBorrowed;
    uint256 public nextLoanId = 1;

    mapping(uint256 => LoanInfo) public loans;
    mapping(address => UserStats) public userStats;
    mapping(address => uint256) public userDeposits;
    mapping(address => uint256[]) private userLoanIds;
    mapping(address => bool) public approvedCollaterals;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event LoanCreated(uint256 indexed loanId, address indexed borrower, uint256 principal);
    event LoanRepaid(uint256 indexed loanId, uint256 totalAmount);
    event CollateralLiquidated(uint256 indexed loanId, address indexed liquidator);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier validLoan(uint256 loanId) {
        require(loanId < nextLoanId && loans[loanId].isActive, "Invalid loan");
        _;
    }

    constructor(address _lendingToken) {
        lendingToken = IERC20(_lendingToken);
        owner = msg.sender;
    }

    function addApprovedCollateral(address token) external onlyOwner {
        approvedCollaterals[token] = true;
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be positive");

        require(lendingToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        userDeposits[msg.sender] += amount;
        totalLiquidity += amount;

        UserStats storage stats = userStats[msg.sender];
        stats.totalLent += uint128(amount);
        stats.lastActivityBlock = uint32(block.number);

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        uint256 userBalance = userDeposits[msg.sender];
        require(amount > 0 && amount <= userBalance, "Invalid amount");
        require(amount <= getAvailableLiquidity(), "Insufficient liquidity");

        userDeposits[msg.sender] = userBalance - amount;
        totalLiquidity -= amount;

        require(lendingToken.transfer(msg.sender, amount), "Transfer failed");

        emit Withdraw(msg.sender, amount);
    }

    function createLoan(
        uint256 principal,
        uint256 duration,
        address collateralToken,
        uint256 collateralAmount
    ) external returns (uint256 loanId) {
        require(principal > 0, "Principal must be positive");
        require(duration > 0 && duration <= MAX_LOAN_DURATION, "Invalid duration");
        require(approvedCollaterals[collateralToken], "Collateral not approved");
        require(principal <= getAvailableLiquidity(), "Insufficient liquidity");

        uint256 requiredCollateral = (principal * COLLATERAL_RATIO) / INTEREST_RATE_BASE;
        require(collateralAmount >= requiredCollateral, "Insufficient collateral");

        require(IERC20(collateralToken).transferFrom(msg.sender, address(this), collateralAmount), "Collateral transfer failed");

        loanId = nextLoanId++;

        uint256 interest = calculateInterest(principal, duration);

        loans[loanId] = LoanInfo({
            principal: uint128(principal),
            interest: uint128(interest),
            startTime: uint64(block.timestamp),
            duration: uint64(duration),
            borrower: msg.sender,
            collateralToken: collateralToken,
            collateralAmount: collateralAmount,
            isActive: true
        });

        userLoanIds[msg.sender].push(loanId);

        UserStats storage stats = userStats[msg.sender];
        stats.totalBorrowed += uint128(principal);
        stats.loanCount++;
        stats.lastActivityBlock = uint32(block.number);

        totalBorrowed += principal;

        require(lendingToken.transfer(msg.sender, principal), "Principal transfer failed");

        emit LoanCreated(loanId, msg.sender, principal);
    }

    function repayLoan(uint256 loanId) external validLoan(loanId) {
        LoanInfo storage loan = loans[loanId];
        require(msg.sender == loan.borrower, "Not borrower");

        uint256 totalRepayment = uint256(loan.principal) + uint256(loan.interest);

        require(lendingToken.transferFrom(msg.sender, address(this), totalRepayment), "Repayment failed");

        loan.isActive = false;
        totalBorrowed -= loan.principal;

        require(IERC20(loan.collateralToken).transfer(msg.sender, loan.collateralAmount), "Collateral return failed");

        emit LoanRepaid(loanId, totalRepayment);
    }

    function liquidateLoan(uint256 loanId) external validLoan(loanId) {
        LoanInfo storage loan = loans[loanId];
        require(block.timestamp > loan.startTime + loan.duration, "Loan not expired");

        loan.isActive = false;
        totalBorrowed -= loan.principal;

        require(IERC20(loan.collateralToken).transfer(msg.sender, loan.collateralAmount), "Liquidation transfer failed");

        emit CollateralLiquidated(loanId, msg.sender);
    }

    function calculateInterest(uint256 principal, uint256 duration) public pure returns (uint256) {
        uint256 annualRate = 500;
        return (principal * annualRate * duration) / (INTEREST_RATE_BASE * 365 days);
    }

    function getAvailableLiquidity() public view returns (uint256) {
        return totalLiquidity > totalBorrowed ? totalLiquidity - totalBorrowed : 0;
    }

    function getUserLoanIds(address user) external view returns (uint256[] memory) {
        return userLoanIds[user];
    }

    function getLoanInfo(uint256 loanId) external view returns (
        uint256 principal,
        uint256 interest,
        uint256 startTime,
        uint256 duration,
        address borrower,
        address collateralToken,
        uint256 collateralAmount,
        bool isActive
    ) {
        LoanInfo storage loan = loans[loanId];
        return (
            loan.principal,
            loan.interest,
            loan.startTime,
            loan.duration,
            loan.borrower,
            loan.collateralToken,
            loan.collateralAmount,
            loan.isActive
        );
    }

    function isLoanOverdue(uint256 loanId) external view returns (bool) {
        LoanInfo storage loan = loans[loanId];
        return loan.isActive && block.timestamp > loan.startTime + loan.duration;
    }
}
