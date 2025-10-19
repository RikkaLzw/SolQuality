
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract OptimizedLendingProtocol is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    struct LoanInfo {
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

    struct UserBalance {
        uint256 deposited;
        uint256 borrowed;
        uint256 lastUpdateTime;
    }


    struct PoolInfo {
        uint128 totalDeposits;
        uint128 totalBorrows;
        uint64 baseInterestRate;
        uint64 utilizationRate;
    }


    mapping(address => PoolInfo) public pools;
    mapping(address => mapping(address => UserBalance)) public userBalances;
    mapping(uint256 => LoanInfo) public loans;
    mapping(address => uint256[]) private userLoanIds;

    uint256 private _loanIdCounter;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant MAX_UTILIZATION = 90;
    uint256 private constant LIQUIDATION_THRESHOLD = 120;

    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Withdraw(address indexed user, address indexed token, uint256 amount);
    event Borrow(address indexed user, uint256 indexed loanId, address collateralToken, address borrowToken, uint256 collateralAmount, uint256 borrowAmount);
    event Repay(address indexed user, uint256 indexed loanId, uint256 amount);
    event Liquidate(uint256 indexed loanId, address indexed liquidator, uint256 collateralSeized);

    modifier validToken(address token) {
        require(token != address(0), "Invalid token");
        _;
    }

    modifier loanExists(uint256 loanId) {
        require(loanId < _loanIdCounter, "Loan does not exist");
        _;
    }

    constructor() {}

    function deposit(address token, uint256 amount)
        external
        nonReentrant
        validToken(token)
    {
        require(amount > 0, "Amount must be greater than 0");


        PoolInfo memory poolCache = pools[token];
        UserBalance memory userCache = userBalances[token][msg.sender];

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);


        userCache.deposited += amount;
        userCache.lastUpdateTime = block.timestamp;


        poolCache.totalDeposits += uint128(amount);


        userBalances[token][msg.sender] = userCache;
        pools[token] = poolCache;

        emit Deposit(msg.sender, token, amount);
    }

    function withdraw(address token, uint256 amount)
        external
        nonReentrant
        validToken(token)
    {

        UserBalance memory userCache = userBalances[token][msg.sender];
        PoolInfo memory poolCache = pools[token];

        require(userCache.deposited >= amount, "Insufficient balance");
        require(poolCache.totalDeposits >= amount, "Insufficient pool liquidity");


        uint256 newTotalDeposits = poolCache.totalDeposits - amount;
        if (newTotalDeposits > 0) {
            uint256 newUtilization = (poolCache.totalBorrows * 100) / newTotalDeposits;
            require(newUtilization <= MAX_UTILIZATION, "Exceeds max utilization");
        }


        userCache.deposited -= amount;
        userCache.lastUpdateTime = block.timestamp;
        poolCache.totalDeposits -= uint128(amount);


        userBalances[token][msg.sender] = userCache;
        pools[token] = poolCache;

        IERC20(token).safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, token, amount);
    }

    function borrow(
        address collateralToken,
        address borrowToken,
        uint256 collateralAmount,
        uint256 borrowAmount,
        uint256 duration
    )
        external
        nonReentrant
        validToken(collateralToken)
        validToken(borrowToken)
    {
        require(collateralAmount > 0 && borrowAmount > 0, "Invalid amounts");
        require(duration > 0, "Invalid duration");
        require(collateralToken != borrowToken, "Same token not allowed");


        PoolInfo memory borrowPoolCache = pools[borrowToken];

        require(borrowPoolCache.totalDeposits >= borrowAmount, "Insufficient liquidity");


        require(collateralAmount * LIQUIDATION_THRESHOLD / 100 >= borrowAmount, "Insufficient collateral");

        uint256 loanId = _loanIdCounter++;


        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), collateralAmount);


        borrowPoolCache.totalBorrows += uint128(borrowAmount);
        pools[borrowToken] = borrowPoolCache;


        loans[loanId] = LoanInfo({
            borrower: msg.sender,
            collateralToken: collateralToken,
            borrowToken: borrowToken,
            collateralAmount: collateralAmount,
            borrowAmount: borrowAmount,
            interestRate: calculateInterestRate(borrowToken),
            startTime: block.timestamp,
            duration: duration,
            isActive: true
        });

        userLoanIds[msg.sender].push(loanId);


        IERC20(borrowToken).safeTransfer(msg.sender, borrowAmount);

        emit Borrow(msg.sender, loanId, collateralToken, borrowToken, collateralAmount, borrowAmount);
    }

    function repay(uint256 loanId, uint256 amount)
        external
        nonReentrant
        loanExists(loanId)
    {
        LoanInfo memory loanCache = loans[loanId];
        require(loanCache.isActive, "Loan not active");
        require(loanCache.borrower == msg.sender, "Not loan owner");

        uint256 totalOwed = calculateTotalOwed(loanId);
        require(amount <= totalOwed, "Amount exceeds debt");

        IERC20(loanCache.borrowToken).safeTransferFrom(msg.sender, address(this), amount);


        PoolInfo memory poolCache = pools[loanCache.borrowToken];
        poolCache.totalBorrows -= uint128(amount);
        pools[loanCache.borrowToken] = poolCache;

        if (amount >= totalOwed) {

            loanCache.isActive = false;
            IERC20(loanCache.collateralToken).safeTransfer(msg.sender, loanCache.collateralAmount);
        } else {

            loanCache.borrowAmount -= amount;
        }

        loans[loanId] = loanCache;

        emit Repay(msg.sender, loanId, amount);
    }

    function liquidate(uint256 loanId)
        external
        nonReentrant
        loanExists(loanId)
    {
        LoanInfo memory loanCache = loans[loanId];
        require(loanCache.isActive, "Loan not active");

        uint256 totalOwed = calculateTotalOwed(loanId);


        bool isExpired = block.timestamp > loanCache.startTime + loanCache.duration;
        bool isUndercollateralized = loanCache.collateralAmount * 100 < totalOwed * LIQUIDATION_THRESHOLD;

        require(isExpired || isUndercollateralized, "Loan not liquidatable");


        IERC20(loanCache.borrowToken).safeTransferFrom(msg.sender, address(this), totalOwed);


        PoolInfo memory poolCache = pools[loanCache.borrowToken];
        poolCache.totalBorrows -= uint128(loanCache.borrowAmount);
        pools[loanCache.borrowToken] = poolCache;


        IERC20(loanCache.collateralToken).safeTransfer(msg.sender, loanCache.collateralAmount);

        loanCache.isActive = false;
        loans[loanId] = loanCache;

        emit Liquidate(loanId, msg.sender, loanCache.collateralAmount);
    }

    function calculateInterestRate(address token) public view returns (uint256) {
        PoolInfo memory poolCache = pools[token];
        if (poolCache.totalDeposits == 0) return 5 * PRECISION / 100;

        uint256 utilization = (poolCache.totalBorrows * PRECISION) / poolCache.totalDeposits;
        return (5 * PRECISION / 100) + (utilization * 10 / 100);
    }

    function calculateTotalOwed(uint256 loanId) public view returns (uint256) {
        LoanInfo memory loanCache = loans[loanId];
        if (!loanCache.isActive) return 0;

        uint256 timeElapsed = block.timestamp - loanCache.startTime;
        uint256 interest = (loanCache.borrowAmount * loanCache.interestRate * timeElapsed) / (365 days * PRECISION);

        return loanCache.borrowAmount + interest;
    }

    function getUserLoanIds(address user) external view returns (uint256[] memory) {
        return userLoanIds[user];
    }

    function getPoolInfo(address token) external view returns (PoolInfo memory) {
        return pools[token];
    }

    function getUserBalance(address token, address user) external view returns (UserBalance memory) {
        return userBalances[token][user];
    }


    function emergencyWithdraw(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(owner(), balance);
    }
}
