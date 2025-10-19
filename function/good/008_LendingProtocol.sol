
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract LendingProtocol {
    struct Loan {
        address borrower;
        address lender;
        address tokenAddress;
        uint256 principal;
        uint256 interestRate;
        uint256 duration;
        uint256 startTime;
        uint256 collateralAmount;
        bool isActive;
        bool isRepaid;
    }

    mapping(uint256 => Loan) public loans;
    mapping(address => uint256[]) public borrowerLoans;
    mapping(address => uint256[]) public lenderLoans;
    mapping(address => uint256) public collateralBalances;

    uint256 public nextLoanId;
    uint256 public constant COLLATERAL_RATIO = 150;
    uint256 public constant BASIS_POINTS = 10000;

    event LoanCreated(uint256 indexed loanId, address indexed borrower, address indexed lender);
    event LoanRepaid(uint256 indexed loanId, uint256 totalAmount);
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event LoanDefaulted(uint256 indexed loanId);

    modifier onlyActiveLoan(uint256 loanId) {
        require(loans[loanId].isActive, "Loan is not active");
        _;
    }

    modifier onlyBorrower(uint256 loanId) {
        require(msg.sender == loans[loanId].borrower, "Only borrower can call this");
        _;
    }

    modifier onlyLender(uint256 loanId) {
        require(msg.sender == loans[loanId].lender, "Only lender can call this");
        _;
    }

    function depositCollateral(address tokenAddress, uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");

        IERC20 token = IERC20(tokenAddress);
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        collateralBalances[msg.sender] += amount;
        emit CollateralDeposited(msg.sender, amount);
    }

    function withdrawCollateral(address tokenAddress, uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(collateralBalances[msg.sender] >= amount, "Insufficient collateral");

        collateralBalances[msg.sender] -= amount;

        IERC20 token = IERC20(tokenAddress);
        require(token.transfer(msg.sender, amount), "Transfer failed");

        emit CollateralWithdrawn(msg.sender, amount);
    }

    function createLoan(
        address borrower,
        address tokenAddress,
        uint256 principal,
        uint256 interestRate
    ) external returns (uint256) {
        require(principal > 0, "Principal must be greater than 0");
        require(interestRate <= 5000, "Interest rate too high");

        uint256 requiredCollateral = _calculateRequiredCollateral(principal);
        require(collateralBalances[borrower] >= requiredCollateral, "Insufficient collateral");

        uint256 loanId = nextLoanId++;

        loans[loanId] = Loan({
            borrower: borrower,
            lender: msg.sender,
            tokenAddress: tokenAddress,
            principal: principal,
            interestRate: interestRate,
            duration: 30 days,
            startTime: block.timestamp,
            collateralAmount: requiredCollateral,
            isActive: true,
            isRepaid: false
        });

        borrowerLoans[borrower].push(loanId);
        lenderLoans[msg.sender].push(loanId);
        collateralBalances[borrower] -= requiredCollateral;

        IERC20 token = IERC20(tokenAddress);
        require(token.transferFrom(msg.sender, borrower, principal), "Transfer failed");

        emit LoanCreated(loanId, borrower, msg.sender);
        return loanId;
    }

    function repayLoan(uint256 loanId) external onlyActiveLoan(loanId) onlyBorrower(loanId) {
        Loan storage loan = loans[loanId];
        uint256 totalAmount = _calculateTotalRepayment(loanId);

        IERC20 token = IERC20(loan.tokenAddress);
        require(token.transferFrom(msg.sender, loan.lender, totalAmount), "Transfer failed");

        loan.isActive = false;
        loan.isRepaid = true;

        collateralBalances[msg.sender] += loan.collateralAmount;

        emit LoanRepaid(loanId, totalAmount);
    }

    function liquidateLoan(uint256 loanId) external onlyActiveLoan(loanId) onlyLender(loanId) {
        Loan storage loan = loans[loanId];
        require(_isLoanDefaulted(loanId), "Loan is not in default");

        loan.isActive = false;

        emit LoanDefaulted(loanId);
    }

    function getLoanDetails(uint256 loanId) external view returns (Loan memory) {
        return loans[loanId];
    }

    function getBorrowerLoans(address borrower) external view returns (uint256[] memory) {
        return borrowerLoans[borrower];
    }

    function getLenderLoans(address lender) external view returns (uint256[] memory) {
        return lenderLoans[lender];
    }

    function calculateTotalRepayment(uint256 loanId) external view returns (uint256) {
        return _calculateTotalRepayment(loanId);
    }

    function _calculateTotalRepayment(uint256 loanId) internal view returns (uint256) {
        Loan memory loan = loans[loanId];
        uint256 interest = (loan.principal * loan.interestRate) / BASIS_POINTS;
        return loan.principal + interest;
    }

    function _calculateRequiredCollateral(uint256 principal) internal pure returns (uint256) {
        return (principal * COLLATERAL_RATIO) / 100;
    }

    function _isLoanDefaulted(uint256 loanId) internal view returns (bool) {
        Loan memory loan = loans[loanId];
        return block.timestamp > loan.startTime + loan.duration;
    }
}
