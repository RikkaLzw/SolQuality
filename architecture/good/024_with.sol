
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract LendingProtocolContract is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;


    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_INTEREST_RATE = 5000;
    uint256 public constant MIN_COLLATERAL_RATIO = 15000;
    uint256 public constant LIQUIDATION_THRESHOLD = 12000;
    uint256 public constant LIQUIDATION_BONUS = 500;


    struct Market {
        IERC20 token;
        uint256 totalSupply;
        uint256 totalBorrow;
        uint256 supplyRate;
        uint256 borrowRate;
        uint256 lastUpdateTime;
        uint256 reserveFactor;
        bool isActive;
    }

    struct UserAccount {
        uint256 supplied;
        uint256 borrowed;
        uint256 lastInterestIndex;
        uint256 collateralValue;
    }

    struct LoanPosition {
        address borrower;
        address collateralToken;
        address borrowToken;
        uint256 collateralAmount;
        uint256 borrowAmount;
        uint256 interestRate;
        uint256 startTime;
        uint256 lastUpdateTime;
        bool isActive;
    }


    mapping(address => Market) public markets;
    mapping(address => mapping(address => UserAccount)) public userAccounts;
    mapping(uint256 => LoanPosition) public loanPositions;
    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public tokenPrices;

    address[] public marketTokens;
    uint256 public nextLoanId;
    uint256 public protocolReserves;


    event MarketAdded(address indexed token, uint256 supplyRate, uint256 borrowRate);
    event Supplied(address indexed user, address indexed token, uint256 amount);
    event Withdrawn(address indexed user, address indexed token, uint256 amount);
    event Borrowed(address indexed user, address indexed token, uint256 amount, uint256 loanId);
    event Repaid(address indexed user, uint256 indexed loanId, uint256 amount);
    event Liquidated(uint256 indexed loanId, address indexed liquidator, uint256 collateralSeized);
    event InterestRateUpdated(address indexed token, uint256 newSupplyRate, uint256 newBorrowRate);


    modifier onlyActiveMarket(address token) {
        require(markets[token].isActive, "Market not active");
        _;
    }

    modifier onlyValidLoan(uint256 loanId) {
        require(loanId < nextLoanId, "Invalid loan ID");
        require(loanPositions[loanId].isActive, "Loan not active");
        _;
    }

    modifier onlyBorrower(uint256 loanId) {
        require(msg.sender == loanPositions[loanId].borrower, "Not loan borrower");
        _;
    }

    modifier updateInterest(address token) {
        _updateMarketInterest(token);
        _;
    }

    constructor() {}


    function addMarket(
        address token,
        uint256 initialSupplyRate,
        uint256 initialBorrowRate,
        uint256 reserveFactor
    ) external onlyOwner {
        require(token != address(0), "Invalid token address");
        require(!markets[token].isActive, "Market already exists");
        require(initialBorrowRate <= MAX_INTEREST_RATE, "Borrow rate too high");
        require(reserveFactor <= BASIS_POINTS, "Invalid reserve factor");

        markets[token] = Market({
            token: IERC20(token),
            totalSupply: 0,
            totalBorrow: 0,
            supplyRate: initialSupplyRate,
            borrowRate: initialBorrowRate,
            lastUpdateTime: block.timestamp,
            reserveFactor: reserveFactor,
            isActive: true
        });

        supportedTokens[token] = true;
        marketTokens.push(token);

        emit MarketAdded(token, initialSupplyRate, initialBorrowRate);
    }


    function supply(address token, uint256 amount)
        external
        nonReentrant
        onlyActiveMarket(token)
        updateInterest(token)
    {
        require(amount > 0, "Amount must be positive");

        Market storage market = markets[token];
        UserAccount storage account = userAccounts[msg.sender][token];


        market.token.safeTransferFrom(msg.sender, address(this), amount);


        account.supplied = account.supplied.add(amount);


        market.totalSupply = market.totalSupply.add(amount);

        emit Supplied(msg.sender, token, amount);
    }


    function withdraw(address token, uint256 amount)
        external
        nonReentrant
        onlyActiveMarket(token)
        updateInterest(token)
    {
        require(amount > 0, "Amount must be positive");

        Market storage market = markets[token];
        UserAccount storage account = userAccounts[msg.sender][token];

        require(account.supplied >= amount, "Insufficient balance");
        require(market.totalSupply >= amount, "Insufficient market liquidity");


        _validateCollateralAfterWithdrawal(msg.sender, token, amount);


        account.supplied = account.supplied.sub(amount);


        market.totalSupply = market.totalSupply.sub(amount);


        market.token.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, token, amount);
    }


    function borrow(
        address borrowToken,
        address collateralToken,
        uint256 borrowAmount,
        uint256 collateralAmount
    )
        external
        nonReentrant
        onlyActiveMarket(borrowToken)
        onlyActiveMarket(collateralToken)
        updateInterest(borrowToken)
        returns (uint256 loanId)
    {
        require(borrowAmount > 0, "Borrow amount must be positive");
        require(collateralAmount > 0, "Collateral amount must be positive");
        require(borrowToken != collateralToken, "Cannot borrow same token as collateral");

        Market storage borrowMarket = markets[borrowToken];
        require(borrowMarket.totalSupply >= borrowAmount, "Insufficient market liquidity");


        _validateCollateralRatio(borrowToken, collateralToken, borrowAmount, collateralAmount);


        markets[collateralToken].token.safeTransferFrom(msg.sender, address(this), collateralAmount);


        loanId = nextLoanId++;
        loanPositions[loanId] = LoanPosition({
            borrower: msg.sender,
            collateralToken: collateralToken,
            borrowToken: borrowToken,
            collateralAmount: collateralAmount,
            borrowAmount: borrowAmount,
            interestRate: borrowMarket.borrowRate,
            startTime: block.timestamp,
            lastUpdateTime: block.timestamp,
            isActive: true
        });


        borrowMarket.totalBorrow = borrowMarket.totalBorrow.add(borrowAmount);


        borrowMarket.token.safeTransfer(msg.sender, borrowAmount);

        emit Borrowed(msg.sender, borrowToken, borrowAmount, loanId);
    }


    function repay(uint256 loanId, uint256 amount)
        external
        nonReentrant
        onlyValidLoan(loanId)
        onlyBorrower(loanId)
    {
        require(amount > 0, "Amount must be positive");

        LoanPosition storage loan = loanPositions[loanId];
        uint256 totalDebt = _calculateTotalDebt(loanId);

        require(amount <= totalDebt, "Repay amount exceeds debt");

        Market storage borrowMarket = markets[loan.borrowToken];


        borrowMarket.token.safeTransferFrom(msg.sender, address(this), amount);

        if (amount >= totalDebt) {

            _returnCollateral(loanId);
            loan.isActive = false;
        } else {

            uint256 interestPaid = amount.mul(loan.interestRate).div(BASIS_POINTS);
            uint256 principalPaid = amount.sub(interestPaid);

            loan.borrowAmount = loan.borrowAmount.sub(principalPaid);
            loan.lastUpdateTime = block.timestamp;


            protocolReserves = protocolReserves.add(interestPaid.mul(borrowMarket.reserveFactor).div(BASIS_POINTS));
        }


        borrowMarket.totalBorrow = borrowMarket.totalBorrow.sub(amount);

        emit Repaid(msg.sender, loanId, amount);
    }


    function liquidate(uint256 loanId)
        external
        nonReentrant
        onlyValidLoan(loanId)
    {
        LoanPosition storage loan = loanPositions[loanId];


        require(_isLiquidatable(loanId), "Loan not liquidatable");

        uint256 totalDebt = _calculateTotalDebt(loanId);
        Market storage borrowMarket = markets[loan.borrowToken];


        uint256 liquidationBonus = totalDebt.mul(LIQUIDATION_BONUS).div(BASIS_POINTS);
        uint256 collateralToSeize = totalDebt.add(liquidationBonus);

        require(collateralToSeize <= loan.collateralAmount, "Insufficient collateral");


        borrowMarket.token.safeTransferFrom(msg.sender, address(this), totalDebt);


        markets[loan.collateralToken].token.safeTransfer(msg.sender, collateralToSeize);


        uint256 remainingCollateral = loan.collateralAmount.sub(collateralToSeize);
        if (remainingCollateral > 0) {
            markets[loan.collateralToken].token.safeTransfer(loan.borrower, remainingCollateral);
        }


        borrowMarket.totalBorrow = borrowMarket.totalBorrow.sub(loan.borrowAmount);


        loan.isActive = false;

        emit Liquidated(loanId, msg.sender, collateralToSeize);
    }


    function updateInterestRates(address token) external onlyOwner onlyActiveMarket(token) {
        _updateMarketInterest(token);
        _recalculateInterestRates(token);
    }


    function setTokenPrice(address token, uint256 price) external onlyOwner {
        require(supportedTokens[token], "Token not supported");
        tokenPrices[token] = price;
    }


    function _updateMarketInterest(address token) internal {
        Market storage market = markets[token];
        uint256 timePassed = block.timestamp.sub(market.lastUpdateTime);

        if (timePassed > 0 && market.totalBorrow > 0) {
            uint256 interestAccrued = market.totalBorrow.mul(market.borrowRate).mul(timePassed).div(SECONDS_PER_YEAR).div(BASIS_POINTS);
            market.totalBorrow = market.totalBorrow.add(interestAccrued);

            uint256 reserveIncrease = interestAccrued.mul(market.reserveFactor).div(BASIS_POINTS);
            protocolReserves = protocolReserves.add(reserveIncrease);
        }

        market.lastUpdateTime = block.timestamp;
    }

    function _recalculateInterestRates(address token) internal {
        Market storage market = markets[token];

        if (market.totalSupply == 0) {
            market.supplyRate = 0;
            return;
        }

        uint256 utilizationRate = market.totalBorrow.mul(BASIS_POINTS).div(market.totalSupply);


        market.borrowRate = utilizationRate.mul(2);
        if (market.borrowRate > MAX_INTEREST_RATE) {
            market.borrowRate = MAX_INTEREST_RATE;
        }

        market.supplyRate = market.borrowRate.mul(utilizationRate).div(BASIS_POINTS).mul(BASIS_POINTS.sub(market.reserveFactor)).div(BASIS_POINTS);

        emit InterestRateUpdated(token, market.supplyRate, market.borrowRate);
    }

    function _validateCollateralRatio(
        address borrowToken,
        address collateralToken,
        uint256 borrowAmount,
        uint256 collateralAmount
    ) internal view {
        uint256 borrowValue = borrowAmount.mul(tokenPrices[borrowToken]);
        uint256 collateralValue = collateralAmount.mul(tokenPrices[collateralToken]);
        uint256 collateralRatio = collateralValue.mul(BASIS_POINTS).div(borrowValue);

        require(collateralRatio >= MIN_COLLATERAL_RATIO, "Insufficient collateral ratio");
    }

    function _validateCollateralAfterWithdrawal(address user, address token, uint256 amount) internal view {


        for (uint256 i = 0; i < nextLoanId; i++) {
            LoanPosition storage loan = loanPositions[i];
            if (loan.borrower == user && loan.isActive && loan.collateralToken == token) {
                uint256 remainingCollateral = loan.collateralAmount.sub(amount);
                uint256 totalDebt = _calculateTotalDebt(i);

                uint256 collateralValue = remainingCollateral.mul(tokenPrices[token]);
                uint256 debtValue = totalDebt.mul(tokenPrices[loan.borrowToken]);
                uint256 collateralRatio = collateralValue.mul(BASIS_POINTS).div(debtValue);

                require(collateralRatio >= MIN_COLLATERAL_RATIO, "Withdrawal would violate collateral ratio");
            }
        }
    }

    function _calculateTotalDebt(uint256 loanId) internal view returns (uint256) {
        LoanPosition storage loan = loanPositions[loanId];
        uint256 timePassed = block.timestamp.sub(loan.lastUpdateTime);
        uint256 interest = loan.borrowAmount.mul(loan.interestRate).mul(timePassed).div(SECONDS_PER_YEAR).div(BASIS_POINTS);
        return loan.borrowAmount.add(interest);
    }

    function _isLiquidatable(uint256 loanId) internal view returns (bool) {
        LoanPosition storage loan = loanPositions[loanId];
        uint256 totalDebt = _calculateTotalDebt(loanId);

        uint256 collateralValue = loan.collateralAmount.mul(tokenPrices[loan.collateralToken]);
        uint256 debtValue = totalDebt.mul(tokenPrices[loan.borrowToken]);
        uint256 collateralRatio = collateralValue.mul(BASIS_POINTS).div(debtValue);

        return collateralRatio < LIQUIDATION_THRESHOLD;
    }

    function _returnCollateral(uint256 loanId) internal {
        LoanPosition storage loan = loanPositions[loanId];
        markets[loan.collateralToken].token.safeTransfer(loan.borrower, loan.collateralAmount);
    }


    function getMarketInfo(address token) external view returns (Market memory) {
        return markets[token];
    }

    function getUserAccount(address user, address token) external view returns (UserAccount memory) {
        return userAccounts[user][token];
    }

    function getLoanInfo(uint256 loanId) external view returns (LoanPosition memory) {
        return loanPositions[loanId];
    }

    function calculateTotalDebt(uint256 loanId) external view returns (uint256) {
        return _calculateTotalDebt(loanId);
    }

    function isLoanLiquidatable(uint256 loanId) external view returns (bool) {
        return _isLiquidatable(loanId);
    }

    function getMarketTokens() external view returns (address[] memory) {
        return marketTokens;
    }
}
