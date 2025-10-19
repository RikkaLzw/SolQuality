
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

    event LoanRequested(
        uint256 indexed loanId,
        address indexed borrower,
        address indexed tokenAddress,
        uint256 principal,
        uint256 interestRate,
        uint256 duration,
        uint256 collateralAmount,
        address collateralToken
    );

    event LoanFunded(
        uint256 indexed loanId,
        address indexed lender,
        address indexed borrower,
        uint256 amount
    );

    event LoanRepaid(
        uint256 indexed loanId,
        address indexed borrower,
        uint256 principal,
        uint256 interest
    );

    event CollateralSeized(
        uint256 indexed loanId,
        address indexed lender,
        uint256 collateralAmount
    );

    event Deposit(
        address indexed user,
        address indexed token,
        uint256 amount
    );

    event Withdrawal(
        address indexed user,
        address indexed token,
        uint256 amount
    );

    modifier loanExists(uint256 loanId) {
        require(loanId > 0 && loanId < nextLoanId, "Loan does not exist");
        _;
    }

    modifier onlyBorrower(uint256 loanId) {
        require(loans[loanId].borrower == msg.sender, "Only borrower can perform this action");
        _;
    }

    modifier onlyLender(uint256 loanId) {
        require(loans[loanId].lender == msg.sender, "Only lender can perform this action");
        _;
    }

    function deposit(address tokenAddress, uint256 amount) external {
        require(tokenAddress != address(0), "Invalid token address");
        require(amount > 0, "Deposit amount must be greater than zero");

        IERC20 token = IERC20(tokenAddress);
        require(token.transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        deposits[msg.sender][tokenAddress] += amount;

        emit Deposit(msg.sender, tokenAddress, amount);
    }

    function withdraw(address tokenAddress, uint256 amount) external {
        require(tokenAddress != address(0), "Invalid token address");
        require(amount > 0, "Withdrawal amount must be greater than zero");
        require(deposits[msg.sender][tokenAddress] >= amount, "Insufficient balance");

        deposits[msg.sender][tokenAddress] -= amount;

        IERC20 token = IERC20(tokenAddress);
        require(token.transfer(msg.sender, amount), "Token transfer failed");

        emit Withdrawal(msg.sender, tokenAddress, amount);
    }

    function requestLoan(
        address tokenAddress,
        uint256 principal,
        uint256 interestRate,
        uint256 duration,
        address collateralToken,
        uint256 collateralAmount
    ) external returns (uint256) {
        require(tokenAddress != address(0), "Invalid loan token address");
        require(collateralToken != address(0), "Invalid collateral token address");
        require(principal > 0, "Principal must be greater than zero");
        require(interestRate > 0 && interestRate <= 10000, "Interest rate must be between 0.01% and 100%");
        require(duration > 0, "Duration must be greater than zero");
        require(collateralAmount > 0, "Collateral amount must be greater than zero");


        require(
            collateralAmount * 100 >= principal * COLLATERAL_RATIO,
            "Insufficient collateral provided"
        );


        IERC20 collateral = IERC20(collateralToken);
        require(
            collateral.transferFrom(msg.sender, address(this), collateralAmount),
            "Collateral transfer failed"
        );

        uint256 loanId = nextLoanId++;

        loans[loanId] = Loan({
            borrower: msg.sender,
            lender: address(0),
            tokenAddress: tokenAddress,
            principal: principal,
            interestRate: interestRate,
            duration: duration,
            startTime: 0,
            collateralAmount: collateralAmount,
            collateralToken: collateralToken,
            isActive: false,
            isRepaid: false
        });

        borrowerLoans[msg.sender].push(loanId);

        emit LoanRequested(
            loanId,
            msg.sender,
            tokenAddress,
            principal,
            interestRate,
            duration,
            collateralAmount,
            collateralToken
        );

        return loanId;
    }

    function fundLoan(uint256 loanId) external loanExists(loanId) {
        Loan storage loan = loans[loanId];

        require(loan.lender == address(0), "Loan already funded");
        require(loan.borrower != msg.sender, "Cannot fund your own loan");
        require(!loan.isActive, "Loan is already active");


        require(
            deposits[msg.sender][loan.tokenAddress] >= loan.principal,
            "Insufficient lender balance"
        );


        deposits[msg.sender][loan.tokenAddress] -= loan.principal;

        IERC20 token = IERC20(loan.tokenAddress);
        require(token.transfer(loan.borrower, loan.principal), "Loan transfer failed");

        loan.lender = msg.sender;
        loan.isActive = true;
        loan.startTime = block.timestamp;

        lenderLoans[msg.sender].push(loanId);

        emit LoanFunded(loanId, msg.sender, loan.borrower, loan.principal);
    }

    function repayLoan(uint256 loanId) external loanExists(loanId) onlyBorrower(loanId) {
        Loan storage loan = loans[loanId];

        require(loan.isActive, "Loan is not active");
        require(!loan.isRepaid, "Loan already repaid");

        uint256 interest = calculateInterest(loanId);
        uint256 totalRepayment = loan.principal + interest;

        IERC20 token = IERC20(loan.tokenAddress);
        require(
            token.transferFrom(msg.sender, loan.lender, totalRepayment),
            "Repayment transfer failed"
        );


        IERC20 collateral = IERC20(loan.collateralToken);
        require(
            collateral.transfer(msg.sender, loan.collateralAmount),
            "Collateral return failed"
        );

        loan.isRepaid = true;
        loan.isActive = false;

        emit LoanRepaid(loanId, msg.sender, loan.principal, interest);
    }

    function liquidateLoan(uint256 loanId) external loanExists(loanId) onlyLender(loanId) {
        Loan storage loan = loans[loanId];

        require(loan.isActive, "Loan is not active");
        require(!loan.isRepaid, "Loan already repaid");
        require(block.timestamp > loan.startTime + loan.duration, "Loan not yet due");


        IERC20 collateral = IERC20(loan.collateralToken);
        require(
            collateral.transfer(msg.sender, loan.collateralAmount),
            "Collateral seizure failed"
        );

        loan.isActive = false;

        emit CollateralSeized(loanId, msg.sender, loan.collateralAmount);
    }

    function calculateInterest(uint256 loanId) public view loanExists(loanId) returns (uint256) {
        Loan memory loan = loans[loanId];

        if (!loan.isActive || loan.startTime == 0) {
            return 0;
        }

        uint256 timeElapsed = block.timestamp - loan.startTime;
        if (timeElapsed > loan.duration) {
            timeElapsed = loan.duration;
        }


        return (loan.principal * loan.interestRate * timeElapsed) / (BASIS_POINTS * 365 days);
    }

    function getLoanDetails(uint256 loanId) external view loanExists(loanId) returns (
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

    function getBalance(address user, address token) external view returns (uint256) {
        return deposits[user][token];
    }
}
