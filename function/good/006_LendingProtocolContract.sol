
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LendingProtocolContract is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    struct Loan {
        address borrower;
        address lender;
        address tokenAddress;
        uint256 principal;
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
    uint256 public constant BASIS_POINTS = 10000;

    event LoanCreated(uint256 indexed loanId, address indexed borrower, uint256 amount);
    event LoanFunded(uint256 indexed loanId, address indexed lender);
    event LoanRepaid(uint256 indexed loanId, uint256 totalAmount);
    event CollateralLiquidated(uint256 indexed loanId, uint256 collateralAmount);
    event FundsDeposited(address indexed lender, address indexed token, uint256 amount);
    event FundsWithdrawn(address indexed lender, address indexed token, uint256 amount);

    modifier validLoan(uint256 _loanId) {
        require(_loanId < nextLoanId, "Invalid loan ID");
        _;
    }

    modifier onlyBorrower(uint256 _loanId) {
        require(loans[_loanId].borrower == msg.sender, "Not the borrower");
        _;
    }

    modifier onlyLender(uint256 _loanId) {
        require(loans[_loanId].lender == msg.sender, "Not the lender");
        _;
    }

    constructor() {}

    function depositFunds(address _token, uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be greater than 0");

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        lenderPools[msg.sender][_token].totalDeposited += _amount;
        lenderPools[msg.sender][_token].availableAmount += _amount;

        emit FundsDeposited(msg.sender, _token, _amount);
    }

    function withdrawFunds(address _token, uint256 _amount) external nonReentrant {
        LenderPool storage pool = lenderPools[msg.sender][_token];
        require(pool.availableAmount >= _amount, "Insufficient available funds");

        pool.availableAmount -= _amount;
        pool.totalDeposited -= _amount;

        IERC20(_token).safeTransfer(msg.sender, _amount);

        emit FundsWithdrawn(msg.sender, _token, _amount);
    }

    function createLoanRequest(
        address _token,
        uint256 _amount,
        uint256 _interestRate,
        uint256 _duration
    ) external nonReentrant returns (uint256) {
        require(_amount > 0, "Loan amount must be greater than 0");
        require(_interestRate > 0, "Interest rate must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");

        uint256 requiredCollateral = _calculateCollateral(_amount);
        IERC20(_token).safeTransferFrom(msg.sender, address(this), requiredCollateral);

        uint256 loanId = nextLoanId++;

        loans[loanId] = Loan({
            borrower: msg.sender,
            lender: address(0),
            tokenAddress: _token,
            principal: _amount,
            interestRate: _interestRate,
            duration: _duration,
            startTime: 0,
            collateralAmount: requiredCollateral,
            isActive: false,
            isRepaid: false
        });

        borrowerLoans[msg.sender].push(loanId);

        emit LoanCreated(loanId, msg.sender, _amount);
        return loanId;
    }

    function fundLoan(uint256 _loanId) external validLoan(_loanId) nonReentrant {
        Loan storage loan = loans[_loanId];
        require(loan.lender == address(0), "Loan already funded");
        require(!loan.isActive, "Loan already active");

        LenderPool storage pool = lenderPools[msg.sender][loan.tokenAddress];
        require(pool.availableAmount >= loan.principal, "Insufficient funds");

        pool.availableAmount -= loan.principal;
        loan.lender = msg.sender;
        loan.isActive = true;
        loan.startTime = block.timestamp;

        lenderLoans[msg.sender].push(_loanId);

        IERC20(loan.tokenAddress).safeTransfer(loan.borrower, loan.principal);

        emit LoanFunded(_loanId, msg.sender);
    }

    function repayLoan(uint256 _loanId) external validLoan(_loanId) onlyBorrower(_loanId) nonReentrant {
        Loan storage loan = loans[_loanId];
        require(loan.isActive, "Loan not active");
        require(!loan.isRepaid, "Loan already repaid");

        uint256 totalAmount = _calculateRepaymentAmount(_loanId);

        IERC20(loan.tokenAddress).safeTransferFrom(msg.sender, address(this), totalAmount);

        LenderPool storage pool = lenderPools[loan.lender][loan.tokenAddress];
        pool.availableAmount += loan.principal;
        pool.interestEarned += (totalAmount - loan.principal);

        IERC20(loan.tokenAddress).safeTransfer(msg.sender, loan.collateralAmount);

        loan.isRepaid = true;
        loan.isActive = false;

        emit LoanRepaid(_loanId, totalAmount);
    }

    function liquidateCollateral(uint256 _loanId) external validLoan(_loanId) onlyLender(_loanId) nonReentrant {
        Loan storage loan = loans[_loanId];
        require(loan.isActive, "Loan not active");
        require(_isLoanDefaulted(_loanId), "Loan not defaulted");

        uint256 collateralAmount = loan.collateralAmount;

        loan.isActive = false;
        loan.collateralAmount = 0;

        IERC20(loan.tokenAddress).safeTransfer(msg.sender, collateralAmount);

        emit CollateralLiquidated(_loanId, collateralAmount);
    }

    function getLoanDetails(uint256 _loanId) external view validLoan(_loanId) returns (Loan memory) {
        return loans[_loanId];
    }

    function getBorrowerLoans(address _borrower) external view returns (uint256[] memory) {
        return borrowerLoans[_borrower];
    }

    function getLenderLoans(address _lender) external view returns (uint256[] memory) {
        return lenderLoans[_lender];
    }

    function getLenderPool(address _lender, address _token) external view returns (LenderPool memory) {
        return lenderPools[_lender][_token];
    }

    function _calculateCollateral(uint256 _amount) internal pure returns (uint256) {
        return (_amount * COLLATERAL_RATIO) / 100;
    }

    function _calculateRepaymentAmount(uint256 _loanId) internal view returns (uint256) {
        Loan storage loan = loans[_loanId];
        uint256 interest = (loan.principal * loan.interestRate) / BASIS_POINTS;
        return loan.principal + interest;
    }

    function _isLoanDefaulted(uint256 _loanId) internal view returns (bool) {
        Loan storage loan = loans[_loanId];
        return block.timestamp > loan.startTime + loan.duration;
    }
}
