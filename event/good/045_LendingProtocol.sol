
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

    uint256 public nextLoanId;
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

    event CollateralLiquidated(
        uint256 indexed loanId,
        address indexed liquidator,
        uint256 collateralAmount
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

    modifier validLoan(uint256 _loanId) {
        require(_loanId < nextLoanId, "Invalid loan ID");
        _;
    }

    modifier onlyBorrower(uint256 _loanId) {
        require(loans[_loanId].borrower == msg.sender, "Only borrower can perform this action");
        _;
    }

    modifier loanActive(uint256 _loanId) {
        require(loans[_loanId].isActive, "Loan is not active");
        _;
    }

    function deposit(address _token, uint256 _amount) external {
        require(_token != address(0), "Invalid token address");
        require(_amount > 0, "Deposit amount must be greater than zero");

        IERC20 token = IERC20(_token);
        require(token.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");

        deposits[msg.sender][_token] += _amount;

        emit DepositMade(msg.sender, _token, _amount);
    }

    function withdraw(address _token, uint256 _amount) external {
        require(_token != address(0), "Invalid token address");
        require(_amount > 0, "Withdrawal amount must be greater than zero");
        require(deposits[msg.sender][_token] >= _amount, "Insufficient balance");

        deposits[msg.sender][_token] -= _amount;

        IERC20 token = IERC20(_token);
        require(token.transfer(msg.sender, _amount), "Token transfer failed");

        emit WithdrawalMade(msg.sender, _token, _amount);
    }

    function requestLoan(
        address _tokenAddress,
        uint256 _principal,
        uint256 _interestRate,
        uint256 _duration,
        address _collateralToken,
        uint256 _collateralAmount
    ) external returns (uint256) {
        require(_tokenAddress != address(0), "Invalid loan token address");
        require(_collateralToken != address(0), "Invalid collateral token address");
        require(_principal > 0, "Principal must be greater than zero");
        require(_interestRate > 0 && _interestRate <= 5000, "Interest rate must be between 0.01% and 50%");
        require(_duration >= 86400, "Loan duration must be at least 1 day");
        require(_duration <= 31536000, "Loan duration cannot exceed 1 year");
        require(_collateralAmount > 0, "Collateral amount must be greater than zero");


        require(_collateralAmount * 100 >= _principal * COLLATERAL_RATIO, "Insufficient collateral");


        IERC20 collateralToken = IERC20(_collateralToken);
        require(collateralToken.transferFrom(msg.sender, address(this), _collateralAmount), "Collateral transfer failed");

        uint256 loanId = nextLoanId++;

        loans[loanId] = Loan({
            borrower: msg.sender,
            lender: address(0),
            tokenAddress: _tokenAddress,
            principal: _principal,
            interestRate: _interestRate,
            duration: _duration,
            startTime: 0,
            collateralAmount: _collateralAmount,
            collateralToken: _collateralToken,
            isActive: false,
            isRepaid: false
        });

        borrowerLoans[msg.sender].push(loanId);

        emit LoanRequested(
            loanId,
            msg.sender,
            _tokenAddress,
            _principal,
            _interestRate,
            _duration,
            _collateralAmount,
            _collateralToken
        );

        return loanId;
    }

    function fundLoan(uint256 _loanId) external validLoan(_loanId) {
        Loan storage loan = loans[_loanId];

        require(!loan.isActive, "Loan is already funded");
        require(loan.lender == address(0), "Loan already has a lender");
        require(msg.sender != loan.borrower, "Borrower cannot fund their own loan");
        require(deposits[msg.sender][loan.tokenAddress] >= loan.principal, "Insufficient lender balance");


        deposits[msg.sender][loan.tokenAddress] -= loan.principal;

        IERC20 token = IERC20(loan.tokenAddress);
        require(token.transfer(loan.borrower, loan.principal), "Loan transfer failed");

        loan.lender = msg.sender;
        loan.isActive = true;
        loan.startTime = block.timestamp;

        lenderLoans[msg.sender].push(_loanId);

        emit LoanFunded(_loanId, msg.sender, loan.borrower, loan.principal);
    }

    function repayLoan(uint256 _loanId) external validLoan(_loanId) onlyBorrower(_loanId) loanActive(_loanId) {
        Loan storage loan = loans[_loanId];

        require(!loan.isRepaid, "Loan is already repaid");

        uint256 interest = calculateInterest(_loanId);
        uint256 totalRepayment = loan.principal + interest;

        IERC20 token = IERC20(loan.tokenAddress);
        require(token.transferFrom(msg.sender, loan.lender, totalRepayment), "Repayment transfer failed");


        IERC20 collateralToken = IERC20(loan.collateralToken);
        require(collateralToken.transfer(msg.sender, loan.collateralAmount), "Collateral return failed");

        loan.isRepaid = true;
        loan.isActive = false;

        emit LoanRepaid(_loanId, msg.sender, loan.principal, interest);
    }

    function liquidateLoan(uint256 _loanId) external validLoan(_loanId) loanActive(_loanId) {
        Loan storage loan = loans[_loanId];

        require(!loan.isRepaid, "Loan is already repaid");
        require(block.timestamp > loan.startTime + loan.duration, "Loan has not expired yet");


        IERC20 collateralToken = IERC20(loan.collateralToken);
        require(collateralToken.transfer(loan.lender, loan.collateralAmount), "Collateral liquidation failed");

        loan.isActive = false;

        emit CollateralLiquidated(_loanId, msg.sender, loan.collateralAmount);
    }

    function calculateInterest(uint256 _loanId) public view validLoan(_loanId) returns (uint256) {
        Loan memory loan = loans[_loanId];

        if (!loan.isActive || loan.startTime == 0) {
            return 0;
        }

        uint256 timeElapsed = block.timestamp - loan.startTime;
        if (timeElapsed > loan.duration) {
            timeElapsed = loan.duration;
        }


        return (loan.principal * loan.interestRate * timeElapsed) / (365 days * BASIS_POINTS);
    }

    function getLoanDetails(uint256 _loanId) external view validLoan(_loanId) returns (
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
        Loan memory loan = loans[_loanId];
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

    function getBorrowerLoans(address _borrower) external view returns (uint256[] memory) {
        return borrowerLoans[_borrower];
    }

    function getLenderLoans(address _lender) external view returns (uint256[] memory) {
        return lenderLoans[_lender];
    }

    function getUserDeposit(address _user, address _token) external view returns (uint256) {
        return deposits[_user][_token];
    }
}
