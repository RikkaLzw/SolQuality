
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract LendingProtocol is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;


    uint256 public constant MAX_INTEREST_RATE = 5000;
    uint256 public constant MIN_LOAN_DURATION = 1 days;
    uint256 public constant MAX_LOAN_DURATION = 365 days;
    uint256 public constant LIQUIDATION_THRESHOLD = 8000;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant PLATFORM_FEE_RATE = 100;

    struct Loan {
        address borrower;
        address lender;
        address collateralToken;
        address loanToken;
        uint256 principal;
        uint256 collateralAmount;
        uint256 interestRate;
        uint256 duration;
        uint256 startTime;
        uint256 repaidAmount;
        LoanStatus status;
    }

    enum LoanStatus {
        Pending,
        Active,
        Repaid,
        Liquidated,
        Cancelled
    }


    mapping(uint256 => Loan) public loans;
    mapping(address => uint256[]) public borrowerLoans;
    mapping(address => uint256[]) public lenderLoans;
    mapping(address => bool) public supportedTokens;

    uint256 public nextLoanId;
    uint256 public totalActiveLoans;
    address public treasury;


    event LoanCreated(uint256 indexed loanId, address indexed borrower, uint256 principal, uint256 collateralAmount);
    event LoanFunded(uint256 indexed loanId, address indexed lender);
    event LoanRepaid(uint256 indexed loanId, uint256 repaidAmount);
    event LoanLiquidated(uint256 indexed loanId, address indexed liquidator);
    event LoanCancelled(uint256 indexed loanId);
    event TokenSupportUpdated(address indexed token, bool supported);


    modifier onlyValidLoan(uint256 _loanId) {
        require(_loanId < nextLoanId, "Invalid loan ID");
        _;
    }

    modifier onlyBorrower(uint256 _loanId) {
        require(loans[_loanId].borrower == msg.sender, "Not the borrower");
        _;
    }

    modifier onlyActiveLoan(uint256 _loanId) {
        require(loans[_loanId].status == LoanStatus.Active, "Loan not active");
        _;
    }

    modifier onlySupportedToken(address _token) {
        require(supportedTokens[_token], "Token not supported");
        _;
    }

    constructor(address _treasury) {
        require(_treasury != address(0), "Invalid treasury address");
        treasury = _treasury;
    }


    function createLoan(
        address _collateralToken,
        address _loanToken,
        uint256 _principal,
        uint256 _collateralAmount,
        uint256 _interestRate,
        uint256 _duration
    ) external nonReentrant onlySupportedToken(_collateralToken) onlySupportedToken(_loanToken) {
        _validateLoanParameters(_principal, _collateralAmount, _interestRate, _duration);

        uint256 loanId = nextLoanId++;

        loans[loanId] = Loan({
            borrower: msg.sender,
            lender: address(0),
            collateralToken: _collateralToken,
            loanToken: _loanToken,
            principal: _principal,
            collateralAmount: _collateralAmount,
            interestRate: _interestRate,
            duration: _duration,
            startTime: 0,
            repaidAmount: 0,
            status: LoanStatus.Pending
        });

        borrowerLoans[msg.sender].push(loanId);


        IERC20(_collateralToken).safeTransferFrom(msg.sender, address(this), _collateralAmount);

        emit LoanCreated(loanId, msg.sender, _principal, _collateralAmount);
    }


    function fundLoan(uint256 _loanId) external nonReentrant onlyValidLoan(_loanId) {
        Loan storage loan = loans[_loanId];
        require(loan.status == LoanStatus.Pending, "Loan not pending");
        require(loan.borrower != msg.sender, "Cannot fund own loan");

        loan.lender = msg.sender;
        loan.status = LoanStatus.Active;
        loan.startTime = block.timestamp;
        totalActiveLoans++;

        lenderLoans[msg.sender].push(_loanId);


        IERC20(loan.loanToken).safeTransferFrom(msg.sender, loan.borrower, loan.principal);

        emit LoanFunded(_loanId, msg.sender);
    }


    function repayLoan(uint256 _loanId) external nonReentrant onlyValidLoan(_loanId) onlyActiveLoan(_loanId) {
        Loan storage loan = loans[_loanId];
        require(msg.sender == loan.borrower, "Only borrower can repay");

        uint256 repaymentAmount = _calculateRepaymentAmount(_loanId);
        uint256 platformFee = (repaymentAmount * PLATFORM_FEE_RATE) / BASIS_POINTS;
        uint256 lenderAmount = repaymentAmount - platformFee;

        loan.repaidAmount = repaymentAmount;
        loan.status = LoanStatus.Repaid;
        totalActiveLoans--;


        IERC20(loan.loanToken).safeTransferFrom(msg.sender, loan.lender, lenderAmount);
        IERC20(loan.loanToken).safeTransferFrom(msg.sender, treasury, platformFee);


        IERC20(loan.collateralToken).safeTransfer(loan.borrower, loan.collateralAmount);

        emit LoanRepaid(_loanId, repaymentAmount);
    }


    function liquidateLoan(uint256 _loanId) external nonReentrant onlyValidLoan(_loanId) onlyActiveLoan(_loanId) {
        Loan storage loan = loans[_loanId];
        require(_isLoanOverdue(_loanId), "Loan not overdue");

        loan.status = LoanStatus.Liquidated;
        totalActiveLoans--;

        uint256 repaymentAmount = _calculateRepaymentAmount(_loanId);
        uint256 platformFee = (loan.collateralAmount * PLATFORM_FEE_RATE) / BASIS_POINTS;
        uint256 lenderAmount = loan.collateralAmount - platformFee;


        IERC20(loan.collateralToken).safeTransfer(loan.lender, lenderAmount);
        IERC20(loan.collateralToken).safeTransfer(treasury, platformFee);

        emit LoanLiquidated(_loanId, msg.sender);
    }


    function cancelLoan(uint256 _loanId) external nonReentrant onlyValidLoan(_loanId) onlyBorrower(_loanId) {
        Loan storage loan = loans[_loanId];
        require(loan.status == LoanStatus.Pending, "Can only cancel pending loans");

        loan.status = LoanStatus.Cancelled;


        IERC20(loan.collateralToken).safeTransfer(loan.borrower, loan.collateralAmount);

        emit LoanCancelled(_loanId);
    }


    function _calculateRepaymentAmount(uint256 _loanId) internal view returns (uint256) {
        Loan storage loan = loans[_loanId];
        uint256 timeElapsed = block.timestamp - loan.startTime;
        uint256 interest = (loan.principal * loan.interestRate * timeElapsed) / (365 days * BASIS_POINTS);
        return loan.principal + interest;
    }


    function _isLoanOverdue(uint256 _loanId) internal view returns (bool) {
        Loan storage loan = loans[_loanId];
        return block.timestamp > loan.startTime + loan.duration;
    }


    function _validateLoanParameters(
        uint256 _principal,
        uint256 _collateralAmount,
        uint256 _interestRate,
        uint256 _duration
    ) internal pure {
        require(_principal > 0, "Principal must be greater than 0");
        require(_collateralAmount > 0, "Collateral must be greater than 0");
        require(_interestRate <= MAX_INTEREST_RATE, "Interest rate too high");
        require(_duration >= MIN_LOAN_DURATION && _duration <= MAX_LOAN_DURATION, "Invalid duration");
    }


    function getLoan(uint256 _loanId) external view onlyValidLoan(_loanId) returns (Loan memory) {
        return loans[_loanId];
    }


    function getBorrowerLoans(address _borrower) external view returns (uint256[] memory) {
        return borrowerLoans[_borrower];
    }


    function getLenderLoans(address _lender) external view returns (uint256[] memory) {
        return lenderLoans[_lender];
    }


    function getRepaymentAmount(uint256 _loanId) external view onlyValidLoan(_loanId) returns (uint256) {
        require(loans[_loanId].status == LoanStatus.Active, "Loan not active");
        return _calculateRepaymentAmount(_loanId);
    }


    function canLiquidate(uint256 _loanId) external view onlyValidLoan(_loanId) returns (bool) {
        return loans[_loanId].status == LoanStatus.Active && _isLoanOverdue(_loanId);
    }



    function setSupportedToken(address _token, bool _supported) external onlyOwner {
        require(_token != address(0), "Invalid token address");
        supportedTokens[_token] = _supported;
        emit TokenSupportUpdated(_token, _supported);
    }


    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Invalid treasury address");
        treasury = _treasury;
    }


    function emergencyWithdraw(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).safeTransfer(owner(), _amount);
    }
}
