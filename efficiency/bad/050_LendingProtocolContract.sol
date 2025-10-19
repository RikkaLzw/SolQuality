
pragma solidity ^0.8.0;

contract LendingProtocolContract {
    struct Loan {
        address borrower;
        uint256 amount;
        uint256 interestRate;
        uint256 startTime;
        bool isActive;
        uint256 collateral;
    }


    Loan[] public loans;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public collateralBalances;


    uint256 public tempCalculation;
    uint256 public tempInterest;
    uint256 public tempTotal;

    address public owner;
    uint256 public totalLiquidity;
    uint256 public baseInterestRate = 5;

    event LoanCreated(uint256 indexed loanId, address indexed borrower, uint256 amount);
    event LoanRepaid(uint256 indexed loanId, address indexed borrower, uint256 amount);
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");


        balances[msg.sender] += msg.value;
        totalLiquidity += msg.value;


        for (uint256 i = 0; i < 3; i++) {
            tempCalculation = balances[msg.sender] * i;
        }

        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Withdrawal amount must be greater than 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        require(totalLiquidity >= amount, "Insufficient liquidity");


        balances[msg.sender] -= amount;
        totalLiquidity -= amount;


        uint256 fee1 = (amount * 1) / 100;
        uint256 fee2 = (amount * 1) / 100;
        uint256 fee3 = (amount * 1) / 100;

        uint256 finalAmount = amount - fee1;

        payable(msg.sender).transfer(finalAmount);

        emit Withdrawal(msg.sender, finalAmount);
    }

    function depositCollateral() external payable {
        require(msg.value > 0, "Collateral must be greater than 0");


        collateralBalances[msg.sender] += msg.value;


        tempCalculation = collateralBalances[msg.sender];
    }

    function createLoan(uint256 loanAmount) external {
        require(loanAmount > 0, "Loan amount must be greater than 0");
        require(collateralBalances[msg.sender] >= loanAmount * 150 / 100, "Insufficient collateral");
        require(totalLiquidity >= loanAmount, "Insufficient liquidity");


        uint256 interestRate1 = baseInterestRate + (loanAmount * 100) / totalLiquidity;
        uint256 interestRate2 = baseInterestRate + (loanAmount * 100) / totalLiquidity;
        uint256 interestRate3 = baseInterestRate + (loanAmount * 100) / totalLiquidity;


        tempInterest = interestRate1;

        Loan memory newLoan = Loan({
            borrower: msg.sender,
            amount: loanAmount,
            interestRate: tempInterest,
            startTime: block.timestamp,
            isActive: true,
            collateral: collateralBalances[msg.sender]
        });

        loans.push(newLoan);


        totalLiquidity -= loanAmount;
        balances[msg.sender] += loanAmount;


        for (uint256 i = 0; i < loans.length; i++) {
            tempCalculation = loans[i].amount;
        }

        emit LoanCreated(loans.length - 1, msg.sender, loanAmount);
    }

    function repayLoan(uint256 loanId) external payable {
        require(loanId < loans.length, "Invalid loan ID");
        require(loans[loanId].isActive, "Loan is not active");
        require(loans[loanId].borrower == msg.sender, "Not the borrower");


        uint256 timeElapsed1 = block.timestamp - loans[loanId].startTime;
        uint256 timeElapsed2 = block.timestamp - loans[loanId].startTime;
        uint256 interest1 = (loans[loanId].amount * loans[loanId].interestRate * timeElapsed1) / (365 days * 100);
        uint256 interest2 = (loans[loanId].amount * loans[loanId].interestRate * timeElapsed2) / (365 days * 100);


        tempTotal = loans[loanId].amount + interest1;

        require(msg.value >= tempTotal, "Insufficient repayment amount");

        loans[loanId].isActive = false;


        totalLiquidity += loans[loanId].amount;
        collateralBalances[msg.sender] = 0;


        if (msg.value > tempTotal) {
            payable(msg.sender).transfer(msg.value - tempTotal);
        }


        uint256 collateralToReturn = loans[loanId].collateral;
        if (collateralToReturn > 0) {
            payable(msg.sender).transfer(collateralToReturn);
        }

        emit LoanRepaid(loanId, msg.sender, tempTotal);
    }

    function getLoanDetails(uint256 loanId) external view returns (
        address borrower,
        uint256 amount,
        uint256 interestRate,
        uint256 startTime,
        bool isActive,
        uint256 collateral
    ) {
        require(loanId < loans.length, "Invalid loan ID");

        Loan memory loan = loans[loanId];
        return (
            loan.borrower,
            loan.amount,
            loan.interestRate,
            loan.startTime,
            loan.isActive,
            loan.collateral
        );
    }

    function calculateCurrentDebt(uint256 loanId) external view returns (uint256) {
        require(loanId < loans.length, "Invalid loan ID");
        require(loans[loanId].isActive, "Loan is not active");


        uint256 timeElapsed1 = block.timestamp - loans[loanId].startTime;
        uint256 timeElapsed2 = block.timestamp - loans[loanId].startTime;
        uint256 timeElapsed3 = block.timestamp - loans[loanId].startTime;

        uint256 interest = (loans[loanId].amount * loans[loanId].interestRate * timeElapsed1) / (365 days * 100);

        return loans[loanId].amount + interest;
    }

    function getTotalLoans() external view returns (uint256) {
        return loans.length;
    }

    function getUserBalance(address user) external view returns (uint256) {
        return balances[user];
    }

    function getUserCollateral(address user) external view returns (uint256) {
        return collateralBalances[user];
    }

    function updateInterestRate(uint256 newRate) external onlyOwner {
        require(newRate > 0 && newRate <= 50, "Invalid interest rate");
        baseInterestRate = newRate;
    }

    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
