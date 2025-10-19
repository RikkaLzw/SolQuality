
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LendingProtocol is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

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

    struct LenderPool {
        uint256 totalDeposited;
        uint256 availableAmount;
        uint256 interestEarned;
    }

    mapping(uint256 => Loan) public loans;
    mapping(address => mapping(address => LenderPool)) public lenderPools;
    mapping(address => uint256[]) public borrowerLoans;
    mapping(address => uint256[]) public lenderLoans;

    uint256 public nextLoanId;
    uint256 public constant COLLATERAL_RATIO = 150;
    uint256 public constant PLATFORM_FEE = 100;
    uint256 public constant BASIS_POINTS = 10000;

    event LoanCreated(uint256 indexed loanId, address indexed borrower, uint256 amount);
    event LoanFunded(uint256 indexed loanId, address indexed lender);
    event LoanRepaid(uint256 indexed loanId, uint256 repayAmount);
    event CollateralLiquidated(uint256 indexed loanId, uint256 collateralAmount);
    event FundsDeposited(address indexed lender, address indexed token, uint256 amount);
    event FundsWithdrawn(address indexed lender, address indexed token, uint256 amount);

    constructor() {}

    function depositFunds(address token, uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        lenderPools[msg.sender][token].totalDeposited += amount;
        lenderPools[msg.sender][token].availableAmount += amount;

        emit FundsDeposited(msg.sender, token, amount);
    }

    function withdrawFunds(address token, uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(lenderPools[msg.sender][token].availableAmount >= amount, "Insufficient available funds");

        lenderPools[msg.sender][token].availableAmount -= amount;
        lenderPools[msg.sender][token].totalDeposited -= amount;

        IERC20(token).safeTransfer(msg.sender, amount);

        emit FundsWithdrawn(msg.sender, token, amount);
    }

    function requestLoan(
        address token,
        uint256 amount,
        uint256 interestRate,
        uint256 duration
    ) external nonReentrant returns (uint256) {
        require(amount > 0, "Loan amount must be greater than 0");
        require(interestRate > 0 && interestRate <= 5000, "Invalid interest rate");
        require(duration > 0 && duration <= 365 days, "Invalid duration");

        uint256 requiredCollateral = _calculateCollateral(amount);
        require(requiredCollateral > 0, "Invalid collateral calculation");

        uint256 loanId = nextLoanId++;

        loans[loanId] = Loan({
            borrower: msg.sender,
            lender: address(0),
            token: token,
            amount: amount,
            interestRate: interestRate,
            duration: duration,
            startTime: 0,
            collateralAmount: requiredCollateral,
            isActive: false,
            isRepaid: false
        });

        borrowerLoans[msg.sender].push(loanId);

        emit LoanCreated(loanId, msg.sender, amount);
        return loanId;
    }

    function fundLoan(uint256 loanId) external nonReentrant {
        Loan storage loan = loans[loanId];
        require(loan.borrower != address(0), "Loan does not exist");
        require(!loan.isActive, "Loan already funded");
        require(loan.borrower != msg.sender, "Cannot fund own loan");

        require(
            lenderPools[msg.sender][loan.token].availableAmount >= loan.amount,
            "Insufficient funds to fund loan"
        );


        IERC20(loan.token).safeTransferFrom(
            loan.borrower,
            address(this),
            loan.collateralAmount
        );


        lenderPools[msg.sender][loan.token].availableAmount -= loan.amount;


        IERC20(loan.token).safeTransfer(loan.borrower, loan.amount);


        loan.lender = msg.sender;
        loan.isActive = true;
        loan.startTime = block.timestamp;

        lenderLoans[msg.sender].push(loanId);

        emit LoanFunded(loanId, msg.sender);
    }

    function repayLoan(uint256 loanId) external nonReentrant {
        Loan storage loan = loans[loanId];
        require(loan.isActive, "Loan is not active");
        require(!loan.isRepaid, "Loan already repaid");
        require(msg.sender == loan.borrower, "Only borrower can repay");

        uint256 repayAmount = _calculateRepayAmount(loanId);


        IERC20(loan.token).safeTransferFrom(msg.sender, address(this), repayAmount);


        uint256 platformFee = (repayAmount * PLATFORM_FEE) / BASIS_POINTS;
        uint256 lenderPayment = repayAmount - platformFee;


        lenderPools[loan.lender][loan.token].availableAmount += lenderPayment;
        lenderPools[loan.lender][loan.token].interestEarned += (lenderPayment - loan.amount);


        IERC20(loan.token).safeTransfer(loan.borrower, loan.collateralAmount);


        loan.isRepaid = true;
        loan.isActive = false;

        emit LoanRepaid(loanId, repayAmount);
    }

    function liquidateCollateral(uint256 loanId) external nonReentrant {
        Loan storage loan = loans[loanId];
        require(loan.isActive, "Loan is not active");
        require(!loan.isRepaid, "Loan already repaid");
        require(block.timestamp > loan.startTime + loan.duration, "Loan not yet expired");
        require(msg.sender == loan.lender, "Only lender can liquidate");


        IERC20(loan.token).safeTransfer(loan.lender, loan.collateralAmount);


        loan.isActive = false;

        emit CollateralLiquidated(loanId, loan.collateralAmount);
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

    function getLenderPool(address lender, address token) external view returns (LenderPool memory) {
        return lenderPools[lender][token];
    }

    function _calculateCollateral(uint256 loanAmount) internal pure returns (uint256) {
        return (loanAmount * COLLATERAL_RATIO) / 100;
    }

    function _calculateRepayAmount(uint256 loanId) internal view returns (uint256) {
        Loan memory loan = loans[loanId];
        uint256 interest = (loan.amount * loan.interestRate) / BASIS_POINTS;
        return loan.amount + interest;
    }
}
