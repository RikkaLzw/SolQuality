
pragma solidity ^0.8.0;


contract LendingProtocolContract {

    address public contractOwner;


    uint256 public constant ANNUAL_INTEREST_RATE = 500;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60;


    uint256 public constant COLLATERAL_RATIO = 15000;


    struct UserAccount {
        uint256 depositBalance;
        uint256 borrowBalance;
        uint256 collateralBalance;
        uint256 lastUpdateTime;
    }


    mapping(address => UserAccount) public userAccounts;


    uint256 public totalDeposits;
    uint256 public totalBorrows;
    uint256 public totalCollateral;


    event DepositMade(address indexed user, uint256 amount, uint256 timestamp);
    event WithdrawalMade(address indexed user, uint256 amount, uint256 timestamp);
    event LoanTaken(address indexed user, uint256 amount, uint256 collateralAmount, uint256 timestamp);
    event LoanRepaid(address indexed user, uint256 amount, uint256 timestamp);
    event CollateralDeposited(address indexed user, uint256 amount, uint256 timestamp);
    event CollateralWithdrawn(address indexed user, uint256 amount, uint256 timestamp);


    modifier onlyOwner() {
        require(msg.sender == contractOwner, "Only contract owner can call this function");
        _;
    }


    modifier validAmount(uint256 amount) {
        require(amount > 0, "Amount must be greater than zero");
        _;
    }


    constructor() {
        contractOwner = msg.sender;
    }


    function makeDeposit() external payable validAmount(msg.value) {
        UserAccount storage userAccount = userAccounts[msg.sender];


        updateUserInterest(msg.sender);


        userAccount.depositBalance += msg.value;
        totalDeposits += msg.value;

        emit DepositMade(msg.sender, msg.value, block.timestamp);
    }


    function withdrawDeposit(uint256 withdrawAmount) external validAmount(withdrawAmount) {
        UserAccount storage userAccount = userAccounts[msg.sender];


        updateUserInterest(msg.sender);

        require(userAccount.depositBalance >= withdrawAmount, "Insufficient deposit balance");
        require(address(this).balance >= withdrawAmount, "Insufficient contract balance");


        userAccount.depositBalance -= withdrawAmount;
        totalDeposits -= withdrawAmount;


        payable(msg.sender).transfer(withdrawAmount);

        emit WithdrawalMade(msg.sender, withdrawAmount, block.timestamp);
    }


    function depositCollateral() external payable validAmount(msg.value) {
        UserAccount storage userAccount = userAccounts[msg.sender];

        userAccount.collateralBalance += msg.value;
        totalCollateral += msg.value;

        emit CollateralDeposited(msg.sender, msg.value, block.timestamp);
    }


    function takeLoan(uint256 borrowAmount) external validAmount(borrowAmount) {
        UserAccount storage userAccount = userAccounts[msg.sender];


        updateUserInterest(msg.sender);


        uint256 requiredCollateral = (borrowAmount * COLLATERAL_RATIO) / BASIS_POINTS;
        require(userAccount.collateralBalance >= requiredCollateral, "Insufficient collateral");


        require(address(this).balance >= borrowAmount, "Insufficient contract balance for loan");


        userAccount.borrowBalance += borrowAmount;
        totalBorrows += borrowAmount;


        payable(msg.sender).transfer(borrowAmount);

        emit LoanTaken(msg.sender, borrowAmount, userAccount.collateralBalance, block.timestamp);
    }


    function repayLoan() external payable validAmount(msg.value) {
        UserAccount storage userAccount = userAccounts[msg.sender];


        updateUserInterest(msg.sender);

        require(userAccount.borrowBalance > 0, "No outstanding loan");

        uint256 repayAmount = msg.value;
        if (repayAmount > userAccount.borrowBalance) {
            repayAmount = userAccount.borrowBalance;

            uint256 excessAmount = msg.value - repayAmount;
            if (excessAmount > 0) {
                payable(msg.sender).transfer(excessAmount);
            }
        }


        userAccount.borrowBalance -= repayAmount;
        totalBorrows -= repayAmount;

        emit LoanRepaid(msg.sender, repayAmount, block.timestamp);
    }


    function withdrawCollateral(uint256 withdrawAmount) external validAmount(withdrawAmount) {
        UserAccount storage userAccount = userAccounts[msg.sender];


        updateUserInterest(msg.sender);

        require(userAccount.collateralBalance >= withdrawAmount, "Insufficient collateral balance");


        uint256 remainingCollateral = userAccount.collateralBalance - withdrawAmount;
        uint256 requiredCollateral = (userAccount.borrowBalance * COLLATERAL_RATIO) / BASIS_POINTS;
        require(remainingCollateral >= requiredCollateral, "Cannot withdraw, insufficient collateral for loan");


        userAccount.collateralBalance -= withdrawAmount;
        totalCollateral -= withdrawAmount;


        payable(msg.sender).transfer(withdrawAmount);

        emit CollateralWithdrawn(msg.sender, withdrawAmount, block.timestamp);
    }


    function updateUserInterest(address userAddress) internal {
        UserAccount storage userAccount = userAccounts[userAddress];

        if (userAccount.lastUpdateTime == 0) {
            userAccount.lastUpdateTime = block.timestamp;
            return;
        }

        uint256 timeElapsed = block.timestamp - userAccount.lastUpdateTime;

        if (timeElapsed > 0 && userAccount.borrowBalance > 0) {

            uint256 interest = (userAccount.borrowBalance * ANNUAL_INTEREST_RATE * timeElapsed) /
                              (BASIS_POINTS * SECONDS_PER_YEAR);


            userAccount.borrowBalance += interest;
            totalBorrows += interest;
        }

        userAccount.lastUpdateTime = block.timestamp;
    }


    function getUserAccount(address userAddress) external view returns (
        uint256 depositBalance,
        uint256 borrowBalance,
        uint256 collateralBalance,
        uint256 lastUpdateTime
    ) {
        UserAccount memory userAccount = userAccounts[userAddress];
        return (
            userAccount.depositBalance,
            userAccount.borrowBalance,
            userAccount.collateralBalance,
            userAccount.lastUpdateTime
        );
    }


    function getCurrentBorrowBalance(address userAddress) external view returns (uint256) {
        UserAccount memory userAccount = userAccounts[userAddress];

        if (userAccount.lastUpdateTime == 0 || userAccount.borrowBalance == 0) {
            return userAccount.borrowBalance;
        }

        uint256 timeElapsed = block.timestamp - userAccount.lastUpdateTime;
        uint256 interest = (userAccount.borrowBalance * ANNUAL_INTEREST_RATE * timeElapsed) /
                          (BASIS_POINTS * SECONDS_PER_YEAR);

        return userAccount.borrowBalance + interest;
    }


    function getContractInfo() external view returns (
        uint256,
        uint256,
        uint256,
        uint256
    ) {
        return (totalDeposits, totalBorrows, totalCollateral, address(this).balance);
    }


    function emergencyWithdraw(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient contract balance");
        payable(contractOwner).transfer(amount);
    }


    receive() external payable {

        if (msg.value > 0) {
            UserAccount storage userAccount = userAccounts[msg.sender];
            updateUserInterest(msg.sender);
            userAccount.depositBalance += msg.value;
            totalDeposits += msg.value;
            emit DepositMade(msg.sender, msg.value, block.timestamp);
        }
    }
}
