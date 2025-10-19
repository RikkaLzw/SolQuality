
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
        address collateralToken;
        bool isActive;
        bool isRepaid;
    }

    mapping(uint256 => Loan) public loans;
    mapping(address => uint256[]) public borrowerLoans;
    mapping(address => uint256[]) public lenderLoans;
    mapping(address => mapping(address => uint256)) public deposits;

    uint256 public nextLoanId = 1;
    uint256 public constant COLLATERAL_RATIO = 150;
    uint256 public constant BASIS_POINTS = 10000;

    event LoanCreated(
        uint256 indexed loanId,
        address indexed borrower,
        address indexed lender,
        address tokenAddress,
        uint256 principal,
        uint256 interestRate,
        uint256 duration
    );

    event LoanRepaid(
        uint256 indexed loanId,
        address indexed borrower,
        uint256 principalAmount,
        uint256 interestAmount
    );

    event LoanDefaulted(
        uint256 indexed loanId,
        address indexed borrower,
        address indexed lender,
        uint256 collateralSeized
    );

    event DepositMade(
        address indexed user,
        address indexed token,
        uint256 amount
    );

    event WithdrawalMade(
        address indexed user,
        address indexed token,
        uint256 amount
    );

    event CollateralDeposited(
        uint256 indexed loanId,
        address indexed borrower,
        address collateralToken,
        uint256 amount
    );

    modifier onlyActiveLoan(uint256 loanId) {
        require(loans[loanId].isActive, "Loan is not active");
        _;
    }

    modifier onlyBorrower(uint256 loanId) {
        require(msg.sender == loans[loanId].borrower, "Only borrower can perform this action");
        _;
    }

    modifier onlyLender(uint256 loanId) {
        require(msg.sender == loans[loanId].lender, "Only lender can perform this action");
        _;
    }

    function deposit(address tokenAddress, uint256 amount) external {
        require(tokenAddress != address(0), "Invalid token address");
        require(amount > 0, "Deposit amount must be greater than zero");

        IERC20 token = IERC20(tokenAddress);
        require(token.transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        deposits[msg.sender][tokenAddress] += amount;

        emit DepositMade(msg.sender, tokenAddress, amount);
    }

    function withdraw(address tokenAddress, uint256 amount) external {
        require(tokenAddress != address(0), "Invalid token address");
        require(amount > 0, "Withdrawal amount must be greater than zero");
        require(deposits[msg.sender][tokenAddress] >= amount, "Insufficient balance");

        deposits[msg.sender][tokenAddress] -= amount;

        IERC20 token = IERC20(tokenAddress);
        require(token.transfer(msg.sender, amount), "Token transfer failed");

        emit WithdrawalMade(msg.sender, tokenAddress, amount);
    }

    function createLoan(
        address borrower,
        address tokenAddress,
        uint256 principal,
        uint256 interestRate,
        uint256 duration,
        address collateralToken,
        uint256 collateralAmount
    ) external {
        require(borrower != address(0), "Invalid borrower address");
        require(tokenAddress != address(0), "Invalid token address");
        require(collateralToken != address(0), "Invalid collateral token address");
        require(principal > 0, "Principal must be greater than zero");
        require(interestRate > 0 && interestRate <= 10000, "Interest rate must be between 0.01% and 100%");
        require(duration > 0, "Duration must be greater than zero");
        require(collateralAmount > 0, "Collateral amount must be greater than zero");
        require(deposits[msg.sender][tokenAddress] >= principal, "Insufficient lender balance");


        require(collateralAmount * 100 >= principal * COLLATERAL_RATIO, "Insufficient collateral ratio");

        uint256 loanId = nextLoanId++;

        loans[loanId] = Loan({
            borrower: borrower,
            lender: msg.sender,
            tokenAddress: tokenAddress,
            principal: principal,
            interestRate: interestRate,
            duration: duration,
            startTime: block.timestamp,
            collateralAmount: collateralAmount,
            collateralToken: collateralToken,
            isActive: true,
            isRepaid: false
        });

        borrowerLoans[borrower].push(loanId);
        lenderLoans[msg.sender].push(loanId);


        IERC20 collateralTokenContract = IERC20(collateralToken);
        require(collateralTokenContract.transferFrom(borrower, address(this), collateralAmount), "Collateral transfer failed");


        deposits[msg.sender][tokenAddress] -= principal;
        IERC20 token = IERC20(tokenAddress);
        require(token.transfer(borrower, principal), "Principal transfer failed");

        emit LoanCreated(loanId, borrower, msg.sender, tokenAddress, principal, interestRate, duration);
        emit CollateralDeposited(loanId, borrower, collateralToken, collateralAmount);
    }

    function repayLoan(uint256 loanId) external onlyActiveLoan(loanId) onlyBorrower(loanId) {
        Loan storage loan = loans[loanId];

        uint256 interestAmount = calculateInterest(loanId);
        uint256 totalRepayment = loan.principal + interestAmount;

        IERC20 token = IERC20(loan.tokenAddress);
        require(token.transferFrom(msg.sender, address(this), totalRepayment), "Repayment transfer failed");


        deposits[loan.lender][loan.tokenAddress] += totalRepayment;


        IERC20 collateralToken = IERC20(loan.collateralToken);
        require(collateralToken.transfer(msg.sender, loan.collateralAmount), "Collateral return failed");

        loan.isActive = false;
        loan.isRepaid = true;

        emit LoanRepaid(loanId, msg.sender, loan.principal, interestAmount);
    }

    function liquidateLoan(uint256 loanId) external onlyActiveLoan(loanId) onlyLender(loanId) {
        Loan storage loan = loans[loanId];

        require(block.timestamp > loan.startTime + loan.duration, "Loan has not expired yet");
        require(!loan.isRepaid, "Loan has already been repaid");


        IERC20 collateralToken = IERC20(loan.collateralToken);
        require(collateralToken.transfer(msg.sender, loan.collateralAmount), "Collateral transfer failed");

        loan.isActive = false;

        emit LoanDefaulted(loanId, loan.borrower, msg.sender, loan.collateralAmount);
    }

    function calculateInterest(uint256 loanId) public view returns (uint256) {
        Loan memory loan = loans[loanId];
        require(loan.isActive, "Loan is not active");

        uint256 timeElapsed = block.timestamp - loan.startTime;
        if (timeElapsed > loan.duration) {
            timeElapsed = loan.duration;
        }


        uint256 annualInterest = (loan.principal * loan.interestRate) / BASIS_POINTS;
        uint256 interest = (annualInterest * timeElapsed) / 365 days;

        return interest;
    }

    function getLoanDetails(uint256 loanId) external view returns (
        address borrower,
        address lender,
        address tokenAddress,
        uint256 principal,
        uint256 interestRate,
        uint256 duration,
        uint256 startTime,
        uint256 collateralAmount,
        address collateralToken,
        bool isActive,
        bool isRepaid
    ) {
        Loan memory loan = loans[loanId];
        return (
            loan.borrower,
            loan.lender,
            loan.tokenAddress,
            loan.principal,
            loan.interestRate,
            loan.duration,
            loan.startTime,
            loan.collateralAmount,
            loan.collateralToken,
            loan.isActive,
            loan.isRepaid
        );
    }

    function getBorrowerLoans(address borrower) external view returns (uint256[] memory) {
        return borrowerLoans[borrower];
    }

    function getLenderLoans(address lender) external view returns (uint256[] memory) {
        return lenderLoans[lender];
    }

    function getUserBalance(address user, address tokenAddress) external view returns (uint256) {
        return deposits[user][tokenAddress];
    }
}
