
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

library LendingMath {
    uint256 constant SECONDS_PER_YEAR = 365 days;
    uint256 constant PRECISION = 1e18;

    function calculateInterest(
        uint256 principal,
        uint256 annualRate,
        uint256 timeElapsed
    ) internal pure returns (uint256) {
        return (principal * annualRate * timeElapsed) / (SECONDS_PER_YEAR * PRECISION);
    }

    function calculateCompoundInterest(
        uint256 principal,
        uint256 annualRate,
        uint256 timeElapsed
    ) internal pure returns (uint256) {
        if (timeElapsed == 0) return 0;


        uint256 simpleInterest = calculateInterest(principal, annualRate, timeElapsed);
        uint256 compoundFactor = (simpleInterest * timeElapsed) / (2 * SECONDS_PER_YEAR);
        return simpleInterest + compoundFactor;
    }
}

contract LendingProtocol is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using LendingMath for uint256;


    uint256 public constant MAX_INTEREST_RATE = 50e18;
    uint256 public constant MIN_LOAN_AMOUNT = 1e18;
    uint256 public constant MAX_LOAN_DURATION = 365 days;
    uint256 public constant LIQUIDATION_THRESHOLD = 80e16;
    uint256 public constant LIQUIDATION_BONUS = 5e16;


    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public interestRates;
    mapping(address => uint256) public collateralFactors;
    mapping(address => uint256) public totalDeposits;
    mapping(address => uint256) public totalBorrows;

    struct Loan {
        address borrower;
        address collateralToken;
        address borrowToken;
        uint256 collateralAmount;
        uint256 borrowAmount;
        uint256 interestRate;
        uint256 startTime;
        uint256 duration;
        bool isActive;
    }

    mapping(uint256 => Loan) public loans;
    mapping(address => uint256[]) public userLoans;
    mapping(address => mapping(address => uint256)) public userDeposits;

    uint256 public nextLoanId = 1;


    event TokenAdded(address indexed token, uint256 interestRate, uint256 collateralFactor);
    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount);
    event LoanCreated(uint256 indexed loanId, address indexed borrower, uint256 amount);
    event LoanRepaid(uint256 indexed loanId, uint256 repayAmount);
    event Liquidation(uint256 indexed loanId, address indexed liquidator, uint256 collateralSeized);


    modifier onlySupportedToken(address token) {
        require(supportedTokens[token], "Token not supported");
        _;
    }

    modifier validLoan(uint256 loanId) {
        require(loanId < nextLoanId && loans[loanId].isActive, "Invalid or inactive loan");
        _;
    }

    modifier onlyBorrower(uint256 loanId) {
        require(loans[loanId].borrower == msg.sender, "Not loan borrower");
        _;
    }

    constructor() {}


    function addSupportedToken(
        address token,
        uint256 interestRate,
        uint256 collateralFactor
    ) external onlyOwner {
        require(token != address(0), "Invalid token address");
        require(interestRate <= MAX_INTEREST_RATE, "Interest rate too high");
        require(collateralFactor > 0 && collateralFactor <= 100e16, "Invalid collateral factor");

        supportedTokens[token] = true;
        interestRates[token] = interestRate;
        collateralFactors[token] = collateralFactor;

        emit TokenAdded(token, interestRate, collateralFactor);
    }

    function updateInterestRate(address token, uint256 newRate) external onlyOwner onlySupportedToken(token) {
        require(newRate <= MAX_INTEREST_RATE, "Interest rate too high");
        interestRates[token] = newRate;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }


    function deposit(address token, uint256 amount)
        external
        nonReentrant
        whenNotPaused
        onlySupportedToken(token)
    {
        require(amount > 0, "Amount must be positive");

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        userDeposits[msg.sender][token] += amount;
        totalDeposits[token] += amount;

        emit Deposit(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount)
        external
        nonReentrant
        whenNotPaused
        onlySupportedToken(token)
    {
        require(amount > 0, "Amount must be positive");
        require(userDeposits[msg.sender][token] >= amount, "Insufficient deposit");
        require(_getAvailableLiquidity(token) >= amount, "Insufficient liquidity");

        userDeposits[msg.sender][token] -= amount;
        totalDeposits[token] -= amount;

        IERC20(token).safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, token, amount);
    }

    function createLoan(
        address collateralToken,
        address borrowToken,
        uint256 collateralAmount,
        uint256 borrowAmount,
        uint256 duration
    ) external nonReentrant whenNotPaused returns (uint256 loanId) {
        require(supportedTokens[collateralToken] && supportedTokens[borrowToken], "Unsupported token");
        require(collateralAmount > 0 && borrowAmount >= MIN_LOAN_AMOUNT, "Invalid amounts");
        require(duration > 0 && duration <= MAX_LOAN_DURATION, "Invalid duration");
        require(_getAvailableLiquidity(borrowToken) >= borrowAmount, "Insufficient liquidity");


        uint256 requiredCollateral = (borrowAmount * collateralFactors[borrowToken]) / 1e18;
        require(collateralAmount >= requiredCollateral, "Insufficient collateral");


        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), collateralAmount);


        loanId = nextLoanId++;
        loans[loanId] = Loan({
            borrower: msg.sender,
            collateralToken: collateralToken,
            borrowToken: borrowToken,
            collateralAmount: collateralAmount,
            borrowAmount: borrowAmount,
            interestRate: interestRates[borrowToken],
            startTime: block.timestamp,
            duration: duration,
            isActive: true
        });

        userLoans[msg.sender].push(loanId);
        totalBorrows[borrowToken] += borrowAmount;


        IERC20(borrowToken).safeTransfer(msg.sender, borrowAmount);

        emit LoanCreated(loanId, msg.sender, borrowAmount);
    }

    function repayLoan(uint256 loanId)
        external
        nonReentrant
        whenNotPaused
        validLoan(loanId)
        onlyBorrower(loanId)
    {
        Loan storage loan = loans[loanId];
        uint256 repayAmount = calculateRepayAmount(loanId);


        IERC20(loan.borrowToken).safeTransferFrom(msg.sender, address(this), repayAmount);


        IERC20(loan.collateralToken).safeTransfer(msg.sender, loan.collateralAmount);


        loan.isActive = false;
        totalBorrows[loan.borrowToken] -= loan.borrowAmount;

        emit LoanRepaid(loanId, repayAmount);
    }

    function liquidateLoan(uint256 loanId)
        external
        nonReentrant
        whenNotPaused
        validLoan(loanId)
    {
        Loan storage loan = loans[loanId];
        require(isLoanLiquidatable(loanId), "Loan not liquidatable");

        uint256 repayAmount = calculateRepayAmount(loanId);
        uint256 collateralToSeize = loan.collateralAmount;
        uint256 liquidationBonus = (collateralToSeize * LIQUIDATION_BONUS) / 1e18;


        IERC20(loan.borrowToken).safeTransferFrom(msg.sender, address(this), repayAmount);


        uint256 totalSeized = collateralToSeize + liquidationBonus;
        IERC20(loan.collateralToken).safeTransfer(msg.sender, totalSeized);


        loan.isActive = false;
        totalBorrows[loan.borrowToken] -= loan.borrowAmount;

        emit Liquidation(loanId, msg.sender, totalSeized);
    }


    function calculateRepayAmount(uint256 loanId) public view validLoan(loanId) returns (uint256) {
        Loan memory loan = loans[loanId];
        uint256 timeElapsed = block.timestamp - loan.startTime;
        uint256 interest = LendingMath.calculateCompoundInterest(
            loan.borrowAmount,
            loan.interestRate,
            timeElapsed
        );
        return loan.borrowAmount + interest;
    }

    function isLoanLiquidatable(uint256 loanId) public view validLoan(loanId) returns (bool) {
        Loan memory loan = loans[loanId];


        if (block.timestamp > loan.startTime + loan.duration) {
            return true;
        }


        uint256 currentDebt = calculateRepayAmount(loanId);
        uint256 collateralValue = loan.collateralAmount;
        uint256 collateralRatio = (collateralValue * 1e18) / currentDebt;

        return collateralRatio < LIQUIDATION_THRESHOLD;
    }

    function getUserLoans(address user) external view returns (uint256[] memory) {
        return userLoans[user];
    }

    function getLoanDetails(uint256 loanId) external view returns (
        address borrower,
        address collateralToken,
        address borrowToken,
        uint256 collateralAmount,
        uint256 borrowAmount,
        uint256 interestRate,
        uint256 startTime,
        uint256 duration,
        bool isActive,
        uint256 currentDebt
    ) {
        Loan memory loan = loans[loanId];
        return (
            loan.borrower,
            loan.collateralToken,
            loan.borrowToken,
            loan.collateralAmount,
            loan.borrowAmount,
            loan.interestRate,
            loan.startTime,
            loan.duration,
            loan.isActive,
            loan.isActive ? calculateRepayAmount(loanId) : 0
        );
    }


    function _getAvailableLiquidity(address token) internal view returns (uint256) {
        return totalDeposits[token] - totalBorrows[token];
    }
}
