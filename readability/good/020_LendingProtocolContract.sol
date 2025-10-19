
pragma solidity ^0.8.0;


contract LendingProtocolContract {

    address public contractOwner;


    uint256 public constant ANNUAL_INTEREST_RATE = 1000;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;


    uint256 public constant COLLATERAL_RATIO = 15000;
    uint256 public constant LIQUIDATION_THRESHOLD = 12000;


    struct UserAccount {
        uint256 depositBalance;
        uint256 borrowBalance;
        uint256 collateralBalance;
        uint256 lastUpdateTime;
        bool isActive;
    }


    struct LoanRecord {
        address borrower;
        uint256 loanAmount;
        uint256 collateralAmount;
        uint256 interestRate;
        uint256 startTime;
        uint256 lastPaymentTime;
        bool isActive;
    }


    mapping(address => UserAccount) public userAccounts;
    mapping(address => LoanRecord) public loanRecords;
    mapping(address => bool) public authorizedLenders;

    uint256 public totalDeposits;
    uint256 public totalBorrows;
    uint256 public totalCollateral;
    uint256 public reserveFund;


    event DepositMade(address indexed user, uint256 amount, uint256 timestamp);
    event WithdrawalMade(address indexed user, uint256 amount, uint256 timestamp);
    event LoanCreated(address indexed borrower, uint256 loanAmount, uint256 collateralAmount, uint256 timestamp);
    event LoanRepaid(address indexed borrower, uint256 repaymentAmount, uint256 timestamp);
    event CollateralLiquidated(address indexed borrower, uint256 collateralAmount, uint256 timestamp);
    event InterestAccrued(address indexed user, uint256 interestAmount, uint256 timestamp);


    modifier onlyOwner() {
        require(msg.sender == contractOwner, "Only contract owner can call this function");
        _;
    }

    modifier onlyActiveLender() {
        require(authorizedLenders[msg.sender] || msg.sender == contractOwner, "Not authorized lender");
        _;
    }

    modifier validAmount(uint256 amount) {
        require(amount > 0, "Amount must be greater than zero");
        _;
    }

    modifier accountExists(address user) {
        require(userAccounts[user].isActive, "User account does not exist");
        _;
    }


    constructor() {
        contractOwner = msg.sender;
        authorizedLenders[msg.sender] = true;
    }


    function makeDeposit() external payable validAmount(msg.value) {
        UserAccount storage account = userAccounts[msg.sender];


        if (!account.isActive) {
            account.isActive = true;
        }


        updateAccountInterest(msg.sender);


        account.depositBalance += msg.value;
        totalDeposits += msg.value;

        emit DepositMade(msg.sender, msg.value, block.timestamp);
    }


    function withdrawDeposit(uint256 withdrawAmount)
        external
        validAmount(withdrawAmount)
        accountExists(msg.sender)
    {
        UserAccount storage account = userAccounts[msg.sender];


        updateAccountInterest(msg.sender);

        require(account.depositBalance >= withdrawAmount, "Insufficient deposit balance");
        require(address(this).balance >= withdrawAmount, "Insufficient contract balance");


        account.depositBalance -= withdrawAmount;
        totalDeposits -= withdrawAmount;


        payable(msg.sender).transfer(withdrawAmount);

        emit WithdrawalMade(msg.sender, withdrawAmount, block.timestamp);
    }


    function createLoan(uint256 borrowAmount)
        external
        payable
        validAmount(borrowAmount)
        validAmount(msg.value)
    {
        require(msg.value >= calculateRequiredCollateral(borrowAmount), "Insufficient collateral");
        require(address(this).balance >= borrowAmount, "Insufficient liquidity in protocol");

        UserAccount storage account = userAccounts[msg.sender];


        if (!account.isActive) {
            account.isActive = true;
        }


        require(!loanRecords[msg.sender].isActive, "User already has an active loan");


        account.borrowBalance += borrowAmount;
        account.collateralBalance += msg.value;
        account.lastUpdateTime = block.timestamp;


        loanRecords[msg.sender] = LoanRecord({
            borrower: msg.sender,
            loanAmount: borrowAmount,
            collateralAmount: msg.value,
            interestRate: ANNUAL_INTEREST_RATE,
            startTime: block.timestamp,
            lastPaymentTime: block.timestamp,
            isActive: true
        });


        totalBorrows += borrowAmount;
        totalCollateral += msg.value;


        payable(msg.sender).transfer(borrowAmount);

        emit LoanCreated(msg.sender, borrowAmount, msg.value, block.timestamp);
    }


    function repayLoan() external payable accountExists(msg.sender) {
        require(loanRecords[msg.sender].isActive, "No active loan found");
        require(msg.value > 0, "Repayment amount must be greater than zero");

        UserAccount storage account = userAccounts[msg.sender];
        LoanRecord storage loan = loanRecords[msg.sender];


        uint256 currentDebt = calculateCurrentDebt(msg.sender);
        require(msg.value <= currentDebt, "Repayment amount exceeds debt");


        if (msg.value >= currentDebt) {

            uint256 excessAmount = msg.value - currentDebt;
            account.borrowBalance = 0;
            totalBorrows -= loan.loanAmount;


            uint256 collateralToReturn = account.collateralBalance;
            account.collateralBalance = 0;
            totalCollateral -= collateralToReturn;


            loan.isActive = false;


            if (collateralToReturn + excessAmount > 0) {
                payable(msg.sender).transfer(collateralToReturn + excessAmount);
            }
        } else {

            uint256 principalReduction = (msg.value * loan.loanAmount) / currentDebt;
            account.borrowBalance -= principalReduction;
            totalBorrows -= principalReduction;
            loan.lastPaymentTime = block.timestamp;
        }


        reserveFund += msg.value;

        emit LoanRepaid(msg.sender, msg.value, block.timestamp);
    }


    function liquidateCollateral(address borrowerAddress)
        external
        onlyActiveLender
        accountExists(borrowerAddress)
    {
        require(loanRecords[borrowerAddress].isActive, "No active loan found");
        require(isLiquidationEligible(borrowerAddress), "Loan is not eligible for liquidation");

        UserAccount storage account = userAccounts[borrowerAddress];
        LoanRecord storage loan = loanRecords[borrowerAddress];

        uint256 collateralAmount = account.collateralBalance;
        uint256 debtAmount = calculateCurrentDebt(borrowerAddress);


        account.collateralBalance = 0;
        account.borrowBalance = 0;
        totalCollateral -= collateralAmount;
        totalBorrows -= loan.loanAmount;


        loan.isActive = false;


        if (collateralAmount > debtAmount) {
            uint256 surplus = collateralAmount - debtAmount;
            payable(borrowerAddress).transfer(surplus);
            reserveFund += debtAmount;
        } else {
            reserveFund += collateralAmount;
        }

        emit CollateralLiquidated(borrowerAddress, collateralAmount, block.timestamp);
    }


    function updateAccountInterest(address userAddress) internal {
        UserAccount storage account = userAccounts[userAddress];

        if (account.lastUpdateTime == 0) {
            account.lastUpdateTime = block.timestamp;
            return;
        }

        uint256 timeElapsed = block.timestamp - account.lastUpdateTime;


        if (account.depositBalance > 0) {
            uint256 depositInterest = (account.depositBalance * ANNUAL_INTEREST_RATE * timeElapsed) /
                                    (BASIS_POINTS * SECONDS_PER_YEAR * 2);
            account.depositBalance += depositInterest;
            totalDeposits += depositInterest;
        }


        if (account.borrowBalance > 0) {
            uint256 borrowInterest = (account.borrowBalance * ANNUAL_INTEREST_RATE * timeElapsed) /
                                   (BASIS_POINTS * SECONDS_PER_YEAR);
            account.borrowBalance += borrowInterest;
            totalBorrows += borrowInterest;

            emit InterestAccrued(userAddress, borrowInterest, block.timestamp);
        }

        account.lastUpdateTime = block.timestamp;
    }


    function calculateRequiredCollateral(uint256 borrowAmount) public pure returns (uint256) {
        return (borrowAmount * COLLATERAL_RATIO) / BASIS_POINTS;
    }


    function calculateCurrentDebt(address borrowerAddress) public view returns (uint256) {
        LoanRecord memory loan = loanRecords[borrowerAddress];
        if (!loan.isActive) {
            return 0;
        }

        uint256 timeElapsed = block.timestamp - loan.lastPaymentTime;
        uint256 interest = (loan.loanAmount * loan.interestRate * timeElapsed) /
                          (BASIS_POINTS * SECONDS_PER_YEAR);

        return userAccounts[borrowerAddress].borrowBalance + interest;
    }


    function isLiquidationEligible(address borrowerAddress) public view returns (bool) {
        UserAccount memory account = userAccounts[borrowerAddress];
        if (account.collateralBalance == 0 || !loanRecords[borrowerAddress].isActive) {
            return false;
        }

        uint256 currentDebt = calculateCurrentDebt(borrowerAddress);
        uint256 collateralValue = account.collateralBalance;
        uint256 currentRatio = (collateralValue * BASIS_POINTS) / currentDebt;

        return currentRatio < LIQUIDATION_THRESHOLD;
    }


    function getUserAccountInfo(address userAddress)
        external
        view
        returns (uint256, uint256, uint256, bool)
    {
        UserAccount memory account = userAccounts[userAddress];
        return (
            account.depositBalance,
            account.borrowBalance,
            account.collateralBalance,
            account.isActive
        );
    }


    function getProtocolStats()
        external
        view
        returns (uint256, uint256, uint256, uint256)
    {
        return (totalDeposits, totalBorrows, totalCollateral, reserveFund);
    }


    function addAuthorizedLender(address lenderAddress) external onlyOwner {
        authorizedLenders[lenderAddress] = true;
    }


    function removeAuthorizedLender(address lenderAddress) external onlyOwner {
        authorizedLenders[lenderAddress] = false;
    }


    function emergencyWithdraw(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient contract balance");
        payable(contractOwner).transfer(amount);
    }


    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }


    receive() external payable {

    }


    fallback() external payable {
        revert("Function not found");
    }
}
