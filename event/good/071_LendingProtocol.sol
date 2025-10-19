
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LendingProtocol is ReentrancyGuard, Ownable {
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

    struct LendingPool {
        address tokenAddress;
        uint256 totalDeposits;
        uint256 totalBorrowed;
        uint256 interestRate;
        uint256 collateralRatio;
        bool isActive;
    }

    mapping(uint256 => Loan) public loans;
    mapping(address => LendingPool) public lendingPools;
    mapping(address => mapping(address => uint256)) public userDeposits;
    mapping(address => uint256[]) public userLoans;

    uint256 public nextLoanId = 1;
    uint256 public constant MAX_INTEREST_RATE = 10000;
    uint256 public constant MIN_COLLATERAL_RATIO = 11000;
    uint256 public platformFeeRate = 100;

    event PoolCreated(
        address indexed tokenAddress,
        uint256 interestRate,
        uint256 collateralRatio
    );

    event Deposited(
        address indexed user,
        address indexed tokenAddress,
        uint256 amount
    );

    event Withdrawn(
        address indexed user,
        address indexed tokenAddress,
        uint256 amount
    );

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
        uint256 amount
    );

    event LoanRepaid(
        uint256 indexed loanId,
        address indexed borrower,
        uint256 principal,
        uint256 interest,
        uint256 platformFee
    );

    event LoanDefaulted(
        uint256 indexed loanId,
        address indexed borrower,
        uint256 collateralSeized
    );

    event CollateralSeized(
        uint256 indexed loanId,
        address indexed lender,
        uint256 collateralAmount
    );

    constructor() {}

    function createLendingPool(
        address _tokenAddress,
        uint256 _interestRate,
        uint256 _collateralRatio
    ) external onlyOwner {
        require(_tokenAddress != address(0), "LendingProtocol: Invalid token address");
        require(_interestRate <= MAX_INTEREST_RATE, "LendingProtocol: Interest rate too high");
        require(_collateralRatio >= MIN_COLLATERAL_RATIO, "LendingProtocol: Collateral ratio too low");
        require(!lendingPools[_tokenAddress].isActive, "LendingProtocol: Pool already exists");

        lendingPools[_tokenAddress] = LendingPool({
            tokenAddress: _tokenAddress,
            totalDeposits: 0,
            totalBorrowed: 0,
            interestRate: _interestRate,
            collateralRatio: _collateralRatio,
            isActive: true
        });

        emit PoolCreated(_tokenAddress, _interestRate, _collateralRatio);
    }

    function deposit(address _tokenAddress, uint256 _amount) external nonReentrant {
        require(_amount > 0, "LendingProtocol: Amount must be greater than zero");
        require(lendingPools[_tokenAddress].isActive, "LendingProtocol: Pool not active");

        IERC20 token = IERC20(_tokenAddress);
        require(token.transferFrom(msg.sender, address(this), _amount), "LendingProtocol: Transfer failed");

        userDeposits[msg.sender][_tokenAddress] += _amount;
        lendingPools[_tokenAddress].totalDeposits += _amount;

        emit Deposited(msg.sender, _tokenAddress, _amount);
    }

    function withdraw(address _tokenAddress, uint256 _amount) external nonReentrant {
        require(_amount > 0, "LendingProtocol: Amount must be greater than zero");
        require(userDeposits[msg.sender][_tokenAddress] >= _amount, "LendingProtocol: Insufficient balance");

        LendingPool storage pool = lendingPools[_tokenAddress];
        uint256 availableLiquidity = pool.totalDeposits - pool.totalBorrowed;
        require(availableLiquidity >= _amount, "LendingProtocol: Insufficient liquidity");

        userDeposits[msg.sender][_tokenAddress] -= _amount;
        pool.totalDeposits -= _amount;

        IERC20 token = IERC20(_tokenAddress);
        require(token.transfer(msg.sender, _amount), "LendingProtocol: Transfer failed");

        emit Withdrawn(msg.sender, _tokenAddress, _amount);
    }

    function requestLoan(
        address _tokenAddress,
        uint256 _principal,
        uint256 _duration,
        address _collateralToken,
        uint256 _collateralAmount
    ) external nonReentrant {
        require(_principal > 0, "LendingProtocol: Principal must be greater than zero");
        require(_duration > 0, "LendingProtocol: Duration must be greater than zero");
        require(_collateralAmount > 0, "LendingProtocol: Collateral amount must be greater than zero");

        LendingPool storage pool = lendingPools[_tokenAddress];
        require(pool.isActive, "LendingProtocol: Pool not active");
        require(pool.totalDeposits - pool.totalBorrowed >= _principal, "LendingProtocol: Insufficient liquidity");


        uint256 requiredCollateral = (_principal * pool.collateralRatio) / 10000;
        require(_collateralAmount >= requiredCollateral, "LendingProtocol: Insufficient collateral");


        IERC20 collateralToken = IERC20(_collateralToken);
        require(collateralToken.transferFrom(msg.sender, address(this), _collateralAmount), "LendingProtocol: Collateral transfer failed");

        uint256 loanId = nextLoanId++;
        loans[loanId] = Loan({
            borrower: msg.sender,
            lender: address(0),
            tokenAddress: _tokenAddress,
            principal: _principal,
            interestRate: pool.interestRate,
            duration: _duration,
            startTime: 0,
            collateralAmount: _collateralAmount,
            collateralToken: _collateralToken,
            isActive: false,
            isRepaid: false
        });

        userLoans[msg.sender].push(loanId);

        emit LoanRequested(loanId, msg.sender, _tokenAddress, _principal, pool.interestRate, _duration, _collateralAmount, _collateralToken);
    }

    function fundLoan(uint256 _loanId) external nonReentrant {
        Loan storage loan = loans[_loanId];
        require(loan.borrower != address(0), "LendingProtocol: Loan does not exist");
        require(!loan.isActive, "LendingProtocol: Loan already funded");
        require(loan.borrower != msg.sender, "LendingProtocol: Cannot fund own loan");

        LendingPool storage pool = lendingPools[loan.tokenAddress];
        require(pool.totalDeposits - pool.totalBorrowed >= loan.principal, "LendingProtocol: Insufficient liquidity");

        loan.lender = msg.sender;
        loan.isActive = true;
        loan.startTime = block.timestamp;
        pool.totalBorrowed += loan.principal;

        IERC20 token = IERC20(loan.tokenAddress);
        require(token.transfer(loan.borrower, loan.principal), "LendingProtocol: Transfer failed");

        emit LoanFunded(_loanId, msg.sender, loan.principal);
    }

    function repayLoan(uint256 _loanId) external nonReentrant {
        Loan storage loan = loans[_loanId];
        require(loan.borrower == msg.sender, "LendingProtocol: Not the borrower");
        require(loan.isActive, "LendingProtocol: Loan not active");
        require(!loan.isRepaid, "LendingProtocol: Loan already repaid");

        uint256 interest = calculateInterest(_loanId);
        uint256 platformFee = (interest * platformFeeRate) / 10000;
        uint256 totalRepayment = loan.principal + interest;

        IERC20 token = IERC20(loan.tokenAddress);
        require(token.transferFrom(msg.sender, address(this), totalRepayment), "LendingProtocol: Repayment transfer failed");


        require(token.transfer(loan.lender, loan.principal + interest - platformFee), "LendingProtocol: Lender payment failed");


        IERC20 collateralToken = IERC20(loan.collateralToken);
        require(collateralToken.transfer(loan.borrower, loan.collateralAmount), "LendingProtocol: Collateral return failed");

        loan.isRepaid = true;
        loan.isActive = false;
        lendingPools[loan.tokenAddress].totalBorrowed -= loan.principal;

        emit LoanRepaid(_loanId, msg.sender, loan.principal, interest, platformFee);
    }

    function liquidateLoan(uint256 _loanId) external nonReentrant {
        Loan storage loan = loans[_loanId];
        require(loan.isActive, "LendingProtocol: Loan not active");
        require(!loan.isRepaid, "LendingProtocol: Loan already repaid");
        require(block.timestamp > loan.startTime + loan.duration, "LendingProtocol: Loan not yet due");


        IERC20 collateralToken = IERC20(loan.collateralToken);
        require(collateralToken.transfer(loan.lender, loan.collateralAmount), "LendingProtocol: Collateral transfer failed");

        loan.isActive = false;
        lendingPools[loan.tokenAddress].totalBorrowed -= loan.principal;

        emit LoanDefaulted(_loanId, loan.borrower, loan.collateralAmount);
        emit CollateralSeized(_loanId, loan.lender, loan.collateralAmount);
    }

    function calculateInterest(uint256 _loanId) public view returns (uint256) {
        Loan storage loan = loans[_loanId];
        if (!loan.isActive || loan.startTime == 0) {
            return 0;
        }

        uint256 timeElapsed = block.timestamp - loan.startTime;
        uint256 interest = (loan.principal * loan.interestRate * timeElapsed) / (10000 * 365 days);
        return interest;
    }

    function getLoanDetails(uint256 _loanId) external view returns (Loan memory) {
        return loans[_loanId];
    }

    function getUserLoans(address _user) external view returns (uint256[] memory) {
        return userLoans[_user];
    }

    function getPoolInfo(address _tokenAddress) external view returns (LendingPool memory) {
        return lendingPools[_tokenAddress];
    }

    function getUserDeposit(address _user, address _tokenAddress) external view returns (uint256) {
        return userDeposits[_user][_tokenAddress];
    }

    function setPlatformFeeRate(uint256 _feeRate) external onlyOwner {
        require(_feeRate <= 1000, "LendingProtocol: Fee rate too high");
        platformFeeRate = _feeRate;
    }

    function withdrawPlatformFees(address _tokenAddress) external onlyOwner {
        IERC20 token = IERC20(_tokenAddress);
        uint256 balance = token.balanceOf(address(this));


        LendingPool storage pool = lendingPools[_tokenAddress];
        uint256 reservedAmount = pool.totalDeposits;

        require(balance > reservedAmount, "LendingProtocol: No fees available");
        uint256 availableFees = balance - reservedAmount;

        require(token.transfer(owner(), availableFees), "LendingProtocol: Fee withdrawal failed");
    }
}
