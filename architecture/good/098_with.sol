
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract LendingProtocolContract is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;


    uint256 public constant MAX_INTEREST_RATE = 10000;
    uint256 public constant MIN_LOAN_DURATION = 1 days;
    uint256 public constant MAX_LOAN_DURATION = 365 days;
    uint256 public constant LIQUIDATION_THRESHOLD = 8000;
    uint256 public constant BASIS_POINTS = 10000;


    struct Loan {
        uint256 id;
        address borrower;
        address lender;
        address tokenAddress;
        uint256 principal;
        uint256 interestRate;
        uint256 collateralAmount;
        address collateralToken;
        uint256 startTime;
        uint256 duration;
        uint256 repaidAmount;
        LoanStatus status;
    }

    struct LenderInfo {
        uint256 totalLent;
        uint256 availableBalance;
        mapping(address => uint256) tokenBalances;
    }

    struct BorrowerInfo {
        uint256 totalBorrowed;
        uint256 activeLoanCount;
        uint256[] loanIds;
    }

    enum LoanStatus {
        PENDING,
        ACTIVE,
        REPAID,
        DEFAULTED,
        LIQUIDATED
    }


    mapping(uint256 => Loan) public loans;
    mapping(address => LenderInfo) public lenders;
    mapping(address => BorrowerInfo) public borrowers;
    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public collateralRatios;

    uint256 public nextLoanId = 1;
    uint256 public totalActiveLoans;
    uint256 public platformFeeRate = 100;
    address public feeRecipient;


    event LoanCreated(
        uint256 indexed loanId,
        address indexed borrower,
        address indexed lender,
        uint256 amount,
        uint256 interestRate
    );

    event LoanFunded(uint256 indexed loanId, address indexed lender);
    event LoanRepaid(uint256 indexed loanId, uint256 amount);
    event LoanLiquidated(uint256 indexed loanId, address indexed liquidator);
    event TokenSupported(address indexed token, bool supported);
    event CollateralRatioSet(address indexed token, uint256 ratio);


    modifier onlyValidToken(address token) {
        require(supportedTokens[token], "Token not supported");
        _;
    }

    modifier onlyLoanBorrower(uint256 loanId) {
        require(loans[loanId].borrower == msg.sender, "Not loan borrower");
        _;
    }

    modifier onlyActiveLoan(uint256 loanId) {
        require(loans[loanId].status == LoanStatus.ACTIVE, "Loan not active");
        _;
    }

    modifier validLoanId(uint256 loanId) {
        require(loanId > 0 && loanId < nextLoanId, "Invalid loan ID");
        _;
    }

    constructor(address _feeRecipient) {
        require(_feeRecipient != address(0), "Invalid fee recipient");
        feeRecipient = _feeRecipient;
    }


    function createLoan(
        address tokenAddress,
        uint256 principal,
        uint256 interestRate,
        uint256 duration,
        address collateralToken,
        uint256 collateralAmount
    ) external nonReentrant whenNotPaused onlyValidToken(tokenAddress) {
        require(principal > 0, "Principal must be positive");
        require(interestRate <= MAX_INTEREST_RATE, "Interest rate too high");
        require(duration >= MIN_LOAN_DURATION && duration <= MAX_LOAN_DURATION, "Invalid duration");
        require(collateralAmount > 0, "Collateral required");
        require(supportedTokens[collateralToken], "Collateral token not supported");

        uint256 requiredCollateral = _calculateRequiredCollateral(tokenAddress, principal, collateralToken);
        require(collateralAmount >= requiredCollateral, "Insufficient collateral");


        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), collateralAmount);

        uint256 loanId = nextLoanId++;

        loans[loanId] = Loan({
            id: loanId,
            borrower: msg.sender,
            lender: address(0),
            tokenAddress: tokenAddress,
            principal: principal,
            interestRate: interestRate,
            collateralAmount: collateralAmount,
            collateralToken: collateralToken,
            startTime: 0,
            duration: duration,
            repaidAmount: 0,
            status: LoanStatus.PENDING
        });

        borrowers[msg.sender].loanIds.push(loanId);

        emit LoanCreated(loanId, msg.sender, address(0), principal, interestRate);
    }


    function fundLoan(uint256 loanId)
        external
        nonReentrant
        whenNotPaused
        validLoanId(loanId)
    {
        Loan storage loan = loans[loanId];
        require(loan.status == LoanStatus.PENDING, "Loan not pending");
        require(loan.borrower != msg.sender, "Cannot fund own loan");


        IERC20(loan.tokenAddress).safeTransferFrom(msg.sender, loan.borrower, loan.principal);


        loan.lender = msg.sender;
        loan.startTime = block.timestamp;
        loan.status = LoanStatus.ACTIVE;


        totalActiveLoans++;
        borrowers[loan.borrower].totalBorrowed += loan.principal;
        borrowers[loan.borrower].activeLoanCount++;
        lenders[msg.sender].totalLent += loan.principal;

        emit LoanFunded(loanId, msg.sender);
    }


    function repayLoan(uint256 loanId, uint256 amount)
        external
        nonReentrant
        whenNotPaused
        validLoanId(loanId)
        onlyLoanBorrower(loanId)
        onlyActiveLoan(loanId)
    {
        Loan storage loan = loans[loanId];
        uint256 totalOwed = calculateTotalOwed(loanId);
        uint256 remainingDebt = totalOwed - loan.repaidAmount;

        require(amount > 0 && amount <= remainingDebt, "Invalid repayment amount");


        uint256 platformFee = (amount * platformFeeRate) / BASIS_POINTS;
        uint256 lenderAmount = amount - platformFee;


        IERC20(loan.tokenAddress).safeTransferFrom(msg.sender, loan.lender, lenderAmount);
        if (platformFee > 0) {
            IERC20(loan.tokenAddress).safeTransferFrom(msg.sender, feeRecipient, platformFee);
        }

        loan.repaidAmount += amount;


        if (loan.repaidAmount >= totalOwed) {
            _completeLoanRepayment(loanId);
        }

        emit LoanRepaid(loanId, amount);
    }


    function liquidateLoan(uint256 loanId)
        external
        nonReentrant
        whenNotPaused
        validLoanId(loanId)
        onlyActiveLoan(loanId)
    {
        Loan storage loan = loans[loanId];
        require(block.timestamp > loan.startTime + loan.duration, "Loan not expired");

        uint256 totalOwed = calculateTotalOwed(loanId);
        require(loan.repaidAmount < totalOwed, "Loan already repaid");


        IERC20(loan.collateralToken).safeTransfer(msg.sender, loan.collateralAmount);


        loan.status = LoanStatus.LIQUIDATED;
        totalActiveLoans--;
        borrowers[loan.borrower].activeLoanCount--;

        emit LoanLiquidated(loanId, msg.sender);
    }


    function calculateTotalOwed(uint256 loanId) public view validLoanId(loanId) returns (uint256) {
        Loan memory loan = loans[loanId];
        if (loan.status != LoanStatus.ACTIVE && loan.status != LoanStatus.REPAID) {
            return 0;
        }

        uint256 timeElapsed = block.timestamp - loan.startTime;
        if (timeElapsed > loan.duration) {
            timeElapsed = loan.duration;
        }

        uint256 interest = (loan.principal * loan.interestRate * timeElapsed) / (BASIS_POINTS * 365 days);
        return loan.principal + interest;
    }


    function getLoanDetails(uint256 loanId)
        external
        view
        validLoanId(loanId)
        returns (Loan memory)
    {
        return loans[loanId];
    }


    function getBorrowerLoans(address borrower) external view returns (uint256[] memory) {
        return borrowers[borrower].loanIds;
    }


    function setSupportedToken(address token, bool supported) external onlyOwner {
        supportedTokens[token] = supported;
        emit TokenSupported(token, supported);
    }

    function setCollateralRatio(address token, uint256 ratio) external onlyOwner {
        require(ratio <= BASIS_POINTS, "Invalid ratio");
        collateralRatios[token] = ratio;
        emit CollateralRatioSet(token, ratio);
    }

    function setPlatformFeeRate(uint256 newRate) external onlyOwner {
        require(newRate <= 1000, "Fee rate too high");
        platformFeeRate = newRate;
    }

    function setFeeRecipient(address newRecipient) external onlyOwner {
        require(newRecipient != address(0), "Invalid recipient");
        feeRecipient = newRecipient;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }


    function _calculateRequiredCollateral(
        address loanToken,
        uint256 loanAmount,
        address collateralToken
    ) internal view returns (uint256) {
        uint256 ratio = collateralRatios[collateralToken];
        if (ratio == 0) {
            ratio = 15000;
        }


        return (loanAmount * ratio) / BASIS_POINTS;
    }

    function _completeLoanRepayment(uint256 loanId) internal {
        Loan storage loan = loans[loanId];


        IERC20(loan.collateralToken).safeTransfer(loan.borrower, loan.collateralAmount);


        loan.status = LoanStatus.REPAID;
        totalActiveLoans--;
        borrowers[loan.borrower].activeLoanCount--;
    }
}
