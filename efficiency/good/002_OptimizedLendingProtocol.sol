
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract OptimizedLendingProtocol is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;


    struct LoanInfo {
        uint128 amount;
        uint64 interestRate;
        uint32 duration;
        uint32 startTime;
        address borrower;
        address collateralToken;
        uint128 collateralAmount;
        bool isActive;
        bool isRepaid;
    }

    struct PoolInfo {
        uint128 totalDeposits;
        uint128 totalBorrowed;
        uint64 utilizationRate;
        uint64 baseInterestRate;
        uint32 lastUpdateTime;
        bool isActive;
    }


    mapping(address => PoolInfo) public pools;
    mapping(address => mapping(address => uint256)) public userDeposits;
    mapping(uint256 => LoanInfo) public loans;
    mapping(address => uint256[]) private userLoans;

    uint256 private loanCounter;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant MAX_UTILIZATION = 90;
    uint256 private constant LIQUIDATION_THRESHOLD = 150;

    event Deposited(address indexed user, address indexed token, uint256 amount);
    event Withdrawn(address indexed user, address indexed token, uint256 amount);
    event LoanCreated(uint256 indexed loanId, address indexed borrower, uint256 amount);
    event LoanRepaid(uint256 indexed loanId, address indexed borrower);
    event LoanLiquidated(uint256 indexed loanId, address indexed liquidator);

    modifier validPool(address token) {
        require(pools[token].isActive, "Pool not active");
        _;
    }

    modifier loanExists(uint256 loanId) {
        require(loanId < loanCounter, "Loan does not exist");
        _;
    }

    constructor() {}

    function createPool(
        address token,
        uint64 baseRate
    ) external onlyOwner {
        require(token != address(0), "Invalid token");
        require(!pools[token].isActive, "Pool exists");

        pools[token] = PoolInfo({
            totalDeposits: 0,
            totalBorrowed: 0,
            utilizationRate: 0,
            baseInterestRate: baseRate,
            lastUpdateTime: uint32(block.timestamp),
            isActive: true
        });
    }

    function deposit(address token, uint256 amount)
        external
        nonReentrant
        validPool(token)
    {
        require(amount > 0, "Amount must be positive");


        PoolInfo storage pool = pools[token];
        uint256 currentDeposit = userDeposits[msg.sender][token];


        userDeposits[msg.sender][token] = currentDeposit + amount;
        pool.totalDeposits = uint128(uint256(pool.totalDeposits) + amount);


        _updateUtilizationRate(token, pool);

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposited(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount)
        external
        nonReentrant
        validPool(token)
    {
        require(amount > 0, "Amount must be positive");

        uint256 userBalance = userDeposits[msg.sender][token];
        require(userBalance >= amount, "Insufficient balance");


        PoolInfo storage pool = pools[token];
        uint256 availableLiquidity = uint256(pool.totalDeposits) - uint256(pool.totalBorrowed);
        require(availableLiquidity >= amount, "Insufficient liquidity");


        userDeposits[msg.sender][token] = userBalance - amount;
        pool.totalDeposits = uint128(uint256(pool.totalDeposits) - amount);


        _updateUtilizationRate(token, pool);

        IERC20(token).safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, token, amount);
    }

    function createLoan(
        address borrowToken,
        uint128 borrowAmount,
        address collateralToken,
        uint128 collateralAmount,
        uint32 duration
    ) external nonReentrant validPool(borrowToken) returns (uint256) {
        require(borrowAmount > 0, "Invalid borrow amount");
        require(collateralAmount > 0, "Invalid collateral amount");
        require(duration >= 1 days && duration <= 365 days, "Invalid duration");


        PoolInfo storage pool = pools[borrowToken];
        uint256 availableLiquidity = uint256(pool.totalDeposits) - uint256(pool.totalBorrowed);
        require(availableLiquidity >= borrowAmount, "Insufficient liquidity");


        uint256 newUtilization = ((uint256(pool.totalBorrowed) + borrowAmount) * 100) / uint256(pool.totalDeposits);
        require(newUtilization <= MAX_UTILIZATION, "Utilization too high");


        require(_checkCollateralRatio(collateralAmount, borrowAmount), "Insufficient collateral");

        uint256 loanId = loanCounter++;
        uint64 interestRate = _calculateInterestRate(borrowToken, pool);

        loans[loanId] = LoanInfo({
            amount: borrowAmount,
            interestRate: interestRate,
            duration: duration,
            startTime: uint32(block.timestamp),
            borrower: msg.sender,
            collateralToken: collateralToken,
            collateralAmount: collateralAmount,
            isActive: true,
            isRepaid: false
        });

        userLoans[msg.sender].push(loanId);
        pool.totalBorrowed = uint128(uint256(pool.totalBorrowed) + borrowAmount);


        _updateUtilizationRate(borrowToken, pool);


        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), collateralAmount);
        IERC20(borrowToken).safeTransfer(msg.sender, borrowAmount);

        emit LoanCreated(loanId, msg.sender, borrowAmount);

        return loanId;
    }

    function repayLoan(uint256 loanId)
        external
        nonReentrant
        loanExists(loanId)
    {
        LoanInfo storage loan = loans[loanId];
        require(loan.isActive, "Loan not active");
        require(loan.borrower == msg.sender, "Not borrower");

        uint256 repayAmount = calculateRepayAmount(loanId);


        loan.isActive = false;
        loan.isRepaid = true;


        address borrowToken = _getBorrowToken(loanId);
        PoolInfo storage pool = pools[borrowToken];
        pool.totalBorrowed = uint128(uint256(pool.totalBorrowed) - uint256(loan.amount));


        _updateUtilizationRate(borrowToken, pool);


        IERC20(borrowToken).safeTransferFrom(msg.sender, address(this), repayAmount);
        IERC20(loan.collateralToken).safeTransfer(msg.sender, loan.collateralAmount);

        emit LoanRepaid(loanId, msg.sender);
    }

    function liquidateLoan(uint256 loanId)
        external
        nonReentrant
        loanExists(loanId)
    {
        LoanInfo storage loan = loans[loanId];
        require(loan.isActive, "Loan not active");
        require(_isLiquidatable(loanId), "Loan not liquidatable");

        uint256 repayAmount = calculateRepayAmount(loanId);


        loan.isActive = false;


        address borrowToken = _getBorrowToken(loanId);
        PoolInfo storage pool = pools[borrowToken];
        pool.totalBorrowed = uint128(uint256(pool.totalBorrowed) - uint256(loan.amount));


        _updateUtilizationRate(borrowToken, pool);


        IERC20(borrowToken).safeTransferFrom(msg.sender, address(this), repayAmount);
        IERC20(loan.collateralToken).safeTransfer(msg.sender, loan.collateralAmount);

        emit LoanLiquidated(loanId, msg.sender);
    }

    function calculateRepayAmount(uint256 loanId)
        public
        view
        loanExists(loanId)
        returns (uint256)
    {
        LoanInfo memory loan = loans[loanId];
        if (!loan.isActive) return 0;

        uint256 timeElapsed = block.timestamp - loan.startTime;
        uint256 interest = (uint256(loan.amount) * uint256(loan.interestRate) * timeElapsed) / (365 days * PRECISION);

        return uint256(loan.amount) + interest;
    }

    function getUserLoans(address user) external view returns (uint256[] memory) {
        return userLoans[user];
    }

    function getPoolUtilization(address token) external view returns (uint256) {
        PoolInfo memory pool = pools[token];
        if (pool.totalDeposits == 0) return 0;
        return (uint256(pool.totalBorrowed) * PRECISION) / uint256(pool.totalDeposits);
    }

    function _updateUtilizationRate(address token, PoolInfo storage pool) private {
        if (pool.totalDeposits == 0) {
            pool.utilizationRate = 0;
        } else {
            pool.utilizationRate = uint64((uint256(pool.totalBorrowed) * PRECISION) / uint256(pool.totalDeposits));
        }
        pool.lastUpdateTime = uint32(block.timestamp);
    }

    function _calculateInterestRate(address token, PoolInfo memory pool) private pure returns (uint64) {
        if (pool.totalDeposits == 0) return pool.baseInterestRate;

        uint256 utilization = (uint256(pool.totalBorrowed) * PRECISION) / uint256(pool.totalDeposits);
        uint256 dynamicRate = uint256(pool.baseInterestRate) + (utilization * 2);

        return uint64(dynamicRate);
    }

    function _checkCollateralRatio(uint256 collateralAmount, uint256 borrowAmount) private pure returns (bool) {


        return (collateralAmount * 100) >= (borrowAmount * LIQUIDATION_THRESHOLD);
    }

    function _isLiquidatable(uint256 loanId) private view returns (bool) {
        LoanInfo memory loan = loans[loanId];


        if (block.timestamp > loan.startTime + loan.duration) {
            return true;
        }


        uint256 currentDebt = calculateRepayAmount(loanId);
        return (uint256(loan.collateralAmount) * 100) < (currentDebt * LIQUIDATION_THRESHOLD);
    }

    function _getBorrowToken(uint256 loanId) private view returns (address) {


        return address(0);
    }
}
