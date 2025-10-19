
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract LendingProtocolContract is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;


    uint256 public constant MAX_INTEREST_RATE = 10000;
    uint256 public constant MIN_LOAN_DURATION = 1 days;
    uint256 public constant MAX_LOAN_DURATION = 365 days;
    uint256 public constant LIQUIDATION_THRESHOLD = 8000;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant PLATFORM_FEE_RATE = 100;


    struct Loan {
        uint256 id;
        address borrower;
        address lender;
        address collateralToken;
        address loanToken;
        uint256 collateralAmount;
        uint256 loanAmount;
        uint256 interestRate;
        uint256 duration;
        uint256 startTime;
        uint256 repaymentAmount;
        LoanStatus status;
    }

    struct LendingPool {
        address token;
        uint256 totalDeposits;
        uint256 totalBorrowed;
        uint256 interestRate;
        bool isActive;
    }

    enum LoanStatus {
        Pending,
        Active,
        Repaid,
        Liquidated,
        Defaulted
    }


    mapping(uint256 => Loan) public loans;
    mapping(address => LendingPool) public lendingPools;
    mapping(address => mapping(address => uint256)) public userDeposits;
    mapping(address => uint256[]) public userLoans;
    mapping(address => bool) public supportedTokens;

    uint256 public nextLoanId;
    uint256 public totalLoans;
    address public feeRecipient;


    event LoanRequested(uint256 indexed loanId, address indexed borrower, uint256 amount);
    event LoanFunded(uint256 indexed loanId, address indexed lender);
    event LoanRepaid(uint256 indexed loanId, uint256 repaymentAmount);
    event LoanLiquidated(uint256 indexed loanId, address indexed liquidator);
    event DepositMade(address indexed user, address indexed token, uint256 amount);
    event WithdrawalMade(address indexed user, address indexed token, uint256 amount);
    event TokenSupported(address indexed token, bool supported);


    modifier onlyValidToken(address token) {
        require(supportedTokens[token], "Token not supported");
        _;
    }

    modifier onlyActiveLoan(uint256 loanId) {
        require(loans[loanId].status == LoanStatus.Active, "Loan not active");
        _;
    }

    modifier onlyBorrower(uint256 loanId) {
        require(msg.sender == loans[loanId].borrower, "Only borrower allowed");
        _;
    }

    modifier onlyLender(uint256 loanId) {
        require(msg.sender == loans[loanId].lender, "Only lender allowed");
        _;
    }

    modifier validLoanParams(uint256 amount, uint256 duration, uint256 interestRate) {
        require(amount > 0, "Loan amount must be positive");
        require(duration >= MIN_LOAN_DURATION && duration <= MAX_LOAN_DURATION, "Invalid loan duration");
        require(interestRate <= MAX_INTEREST_RATE, "Interest rate too high");
        _;
    }

    constructor(address _feeRecipient) {
        require(_feeRecipient != address(0), "Invalid fee recipient");
        feeRecipient = _feeRecipient;
        nextLoanId = 1;
    }


    function setSupportedToken(address token, bool supported) external onlyOwner {
        require(token != address(0), "Invalid token address");
        supportedTokens[token] = supported;

        if (supported && lendingPools[token].token == address(0)) {
            lendingPools[token] = LendingPool({
                token: token,
                totalDeposits: 0,
                totalBorrowed: 0,
                interestRate: 500,
                isActive: true
            });
        }

        emit TokenSupported(token, supported);
    }


    function deposit(address token, uint256 amount)
        external
        nonReentrant
        onlyValidToken(token)
    {
        require(amount > 0, "Deposit amount must be positive");
        require(lendingPools[token].isActive, "Lending pool not active");

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        userDeposits[msg.sender][token] = userDeposits[msg.sender][token].add(amount);
        lendingPools[token].totalDeposits = lendingPools[token].totalDeposits.add(amount);

        emit DepositMade(msg.sender, token, amount);
    }


    function withdraw(address token, uint256 amount)
        external
        nonReentrant
        onlyValidToken(token)
    {
        require(amount > 0, "Withdrawal amount must be positive");
        require(userDeposits[msg.sender][token] >= amount, "Insufficient deposit balance");

        uint256 availableLiquidity = getAvailableLiquidity(token);
        require(availableLiquidity >= amount, "Insufficient liquidity");

        userDeposits[msg.sender][token] = userDeposits[msg.sender][token].sub(amount);
        lendingPools[token].totalDeposits = lendingPools[token].totalDeposits.sub(amount);

        IERC20(token).safeTransfer(msg.sender, amount);

        emit WithdrawalMade(msg.sender, token, amount);
    }


    function requestLoan(
        address collateralToken,
        address loanToken,
        uint256 collateralAmount,
        uint256 loanAmount,
        uint256 interestRate,
        uint256 duration
    )
        external
        nonReentrant
        onlyValidToken(collateralToken)
        onlyValidToken(loanToken)
        validLoanParams(loanAmount, duration, interestRate)
        returns (uint256 loanId)
    {
        require(collateralAmount > 0, "Collateral amount must be positive");
        require(_isCollateralSufficient(collateralToken, loanToken, collateralAmount, loanAmount),
                "Insufficient collateral");


        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), collateralAmount);

        loanId = nextLoanId++;
        uint256 repaymentAmount = _calculateRepaymentAmount(loanAmount, interestRate, duration);

        loans[loanId] = Loan({
            id: loanId,
            borrower: msg.sender,
            lender: address(0),
            collateralToken: collateralToken,
            loanToken: loanToken,
            collateralAmount: collateralAmount,
            loanAmount: loanAmount,
            interestRate: interestRate,
            duration: duration,
            startTime: 0,
            repaymentAmount: repaymentAmount,
            status: LoanStatus.Pending
        });

        userLoans[msg.sender].push(loanId);
        totalLoans++;

        emit LoanRequested(loanId, msg.sender, loanAmount);
    }


    function fundLoan(uint256 loanId)
        external
        nonReentrant
    {
        Loan storage loan = loans[loanId];
        require(loan.status == LoanStatus.Pending, "Loan not pending");
        require(loan.borrower != msg.sender, "Cannot fund own loan");

        uint256 availableLiquidity = getAvailableLiquidity(loan.loanToken);
        require(availableLiquidity >= loan.loanAmount, "Insufficient pool liquidity");

        loan.lender = msg.sender;
        loan.status = LoanStatus.Active;
        loan.startTime = block.timestamp;

        lendingPools[loan.loanToken].totalBorrowed =
            lendingPools[loan.loanToken].totalBorrowed.add(loan.loanAmount);


        IERC20(loan.loanToken).safeTransfer(loan.borrower, loan.loanAmount);

        emit LoanFunded(loanId, msg.sender);
    }


    function repayLoan(uint256 loanId)
        external
        nonReentrant
        onlyActiveLoan(loanId)
        onlyBorrower(loanId)
    {
        Loan storage loan = loans[loanId];
        uint256 repaymentAmount = loan.repaymentAmount;
        uint256 platformFee = repaymentAmount.mul(PLATFORM_FEE_RATE).div(BASIS_POINTS);
        uint256 lenderAmount = repaymentAmount.sub(platformFee);


        IERC20(loan.loanToken).safeTransferFrom(msg.sender, address(this), repaymentAmount);


        IERC20(loan.loanToken).safeTransfer(loan.lender, lenderAmount);
        IERC20(loan.loanToken).safeTransfer(feeRecipient, platformFee);


        IERC20(loan.collateralToken).safeTransfer(loan.borrower, loan.collateralAmount);

        loan.status = LoanStatus.Repaid;
        lendingPools[loan.loanToken].totalBorrowed =
            lendingPools[loan.loanToken].totalBorrowed.sub(loan.loanAmount);

        emit LoanRepaid(loanId, repaymentAmount);
    }


    function liquidateLoan(uint256 loanId)
        external
        nonReentrant
        onlyActiveLoan(loanId)
    {
        Loan storage loan = loans[loanId];
        require(_isLiquidationEligible(loanId), "Loan not eligible for liquidation");

        uint256 repaymentAmount = loan.repaymentAmount;


        IERC20(loan.loanToken).safeTransferFrom(msg.sender, address(this), repaymentAmount);


        IERC20(loan.collateralToken).safeTransfer(msg.sender, loan.collateralAmount);


        uint256 platformFee = repaymentAmount.mul(PLATFORM_FEE_RATE).div(BASIS_POINTS);
        uint256 lenderAmount = repaymentAmount.sub(platformFee);
        IERC20(loan.loanToken).safeTransfer(loan.lender, lenderAmount);
        IERC20(loan.loanToken).safeTransfer(feeRecipient, platformFee);

        loan.status = LoanStatus.Liquidated;
        lendingPools[loan.loanToken].totalBorrowed =
            lendingPools[loan.loanToken].totalBorrowed.sub(loan.loanAmount);

        emit LoanLiquidated(loanId, msg.sender);
    }


    function getAvailableLiquidity(address token) public view returns (uint256) {
        LendingPool memory pool = lendingPools[token];
        return pool.totalDeposits.sub(pool.totalBorrowed);
    }


    function getUserLoans(address user) external view returns (uint256[] memory) {
        return userLoans[user];
    }


    function getLoan(uint256 loanId) external view returns (Loan memory) {
        return loans[loanId];
    }


    function _isCollateralSufficient(
        address collateralToken,
        address loanToken,
        uint256 collateralAmount,
        uint256 loanAmount
    ) internal pure returns (bool) {


        return collateralAmount.mul(BASIS_POINTS) >= loanAmount.mul(15000);
    }


    function _calculateRepaymentAmount(
        uint256 loanAmount,
        uint256 interestRate,
        uint256 duration
    ) internal pure returns (uint256) {
        uint256 interest = loanAmount.mul(interestRate).mul(duration).div(BASIS_POINTS).div(365 days);
        return loanAmount.add(interest);
    }


    function _isLiquidationEligible(uint256 loanId) internal view returns (bool) {
        Loan memory loan = loans[loanId];


        if (block.timestamp > loan.startTime.add(loan.duration)) {
            return true;
        }



        uint256 collateralValue = loan.collateralAmount;
        uint256 loanValue = loan.repaymentAmount;
        uint256 collateralRatio = collateralValue.mul(BASIS_POINTS).div(loanValue);

        return collateralRatio < LIQUIDATION_THRESHOLD;
    }


    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        require(newFeeRecipient != address(0), "Invalid fee recipient");
        feeRecipient = newFeeRecipient;
    }


    function setPoolInterestRate(address token, uint256 newRate)
        external
        onlyOwner
        onlyValidToken(token)
    {
        require(newRate <= MAX_INTEREST_RATE, "Interest rate too high");
        lendingPools[token].interestRate = newRate;
    }


    function setPoolActive(address token, bool active)
        external
        onlyOwner
        onlyValidToken(token)
    {
        lendingPools[token].isActive = active;
    }
}
