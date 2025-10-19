
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
        address token;
        uint256 amount;
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
    mapping(address => mapping(address => uint256)) public deposits;

    uint256 public nextLoanId;
    uint256 public constant COLLATERAL_RATIO = 150;
    uint256 public constant BASIS_POINTS = 10000;

    event LoanCreated(uint256 indexed loanId, address indexed borrower, address indexed lender, uint256 amount);
    event LoanRepaid(uint256 indexed loanId, uint256 repaymentAmount);
    event CollateralLiquidated(uint256 indexed loanId, uint256 collateralAmount);
    event DepositMade(address indexed user, address indexed token, uint256 amount);
    event WithdrawalMade(address indexed user, address indexed token, uint256 amount);

    modifier onlyActiveLoan(uint256 loanId) {
        require(loans[loanId].isActive && !loans[loanId].isRepaid, "Loan not active");
        _;
    }

    modifier onlyBorrower(uint256 loanId) {
        require(msg.sender == loans[loanId].borrower, "Not borrower");
        _;
    }

    function deposit(address token, uint256 amount) external {
        require(amount > 0, "Amount must be positive");
        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Transfer failed");

        deposits[msg.sender][token] += amount;
        emit DepositMade(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount) external {
        require(deposits[msg.sender][token] >= amount, "Insufficient balance");

        deposits[msg.sender][token] -= amount;
        require(IERC20(token).transfer(msg.sender, amount), "Transfer failed");

        emit WithdrawalMade(msg.sender, token, amount);
    }

    function createLoan(
        address borrower,
        address token,
        uint256 amount,
        uint256 interestRate
    ) external returns (uint256) {
        require(amount > 0, "Amount must be positive");
        require(interestRate <= 5000, "Interest rate too high");
        require(deposits[msg.sender][token] >= amount, "Insufficient lender balance");

        uint256 requiredCollateral = _calculateCollateral(amount);
        require(deposits[borrower][token] >= requiredCollateral, "Insufficient collateral");

        uint256 loanId = nextLoanId++;
        uint256 duration = 30 days;

        loans[loanId] = Loan({
            borrower: borrower,
            lender: msg.sender,
            token: token,
            amount: amount,
            interestRate: interestRate,
            duration: duration,
            startTime: block.timestamp,
            collateralAmount: requiredCollateral,
            isActive: true,
            isRepaid: false
        });

        _processLoanCreation(loanId, amount, requiredCollateral, token);

        emit LoanCreated(loanId, borrower, msg.sender, amount);
        return loanId;
    }

    function repayLoan(uint256 loanId) external onlyActiveLoan(loanId) onlyBorrower(loanId) {
        Loan storage loan = loans[loanId];
        uint256 repaymentAmount = calculateRepaymentAmount(loanId);

        require(IERC20(loan.token).transferFrom(msg.sender, address(this), repaymentAmount), "Repayment failed");

        loan.isRepaid = true;
        loan.isActive = false;

        _processLoanRepayment(loanId, repaymentAmount);

        emit LoanRepaid(loanId, repaymentAmount);
    }

    function liquidateCollateral(uint256 loanId) external onlyActiveLoan(loanId) {
        Loan storage loan = loans[loanId];
        require(block.timestamp > loan.startTime + loan.duration, "Loan not expired");
        require(msg.sender == loan.lender, "Not lender");

        uint256 collateralAmount = loan.collateralAmount;
        loan.isActive = false;

        deposits[loan.borrower][loan.token] -= collateralAmount;
        deposits[loan.lender][loan.token] += collateralAmount;

        emit CollateralLiquidated(loanId, collateralAmount);
    }

    function calculateRepaymentAmount(uint256 loanId) public view returns (uint256) {
        Loan memory loan = loans[loanId];
        uint256 interest = (loan.amount * loan.interestRate) / BASIS_POINTS;
        return loan.amount + interest;
    }

    function getLoanDetails(uint256 loanId) external view returns (Loan memory) {
        return loans[loanId];
    }

    function getUserDeposit(address user, address token) external view returns (uint256) {
        return deposits[user][token];
    }

    function _calculateCollateral(uint256 amount) private pure returns (uint256) {
        return (amount * COLLATERAL_RATIO) / 100;
    }

    function _processLoanCreation(
        uint256 loanId,
        uint256 amount,
        uint256 collateralAmount,
        address token
    ) private {
        Loan memory loan = loans[loanId];

        deposits[loan.lender][token] -= amount;
        deposits[loan.borrower][token] -= collateralAmount;
        deposits[loan.borrower][token] += amount;

        borrowerLoans[loan.borrower].push(loanId);
        lenderLoans[loan.lender].push(loanId);
    }

    function _processLoanRepayment(uint256 loanId, uint256 repaymentAmount) private {
        Loan memory loan = loans[loanId];

        deposits[loan.lender][token] += repaymentAmount;
        deposits[loan.borrower][token] += loan.collateralAmount;
    }
}
