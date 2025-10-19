
pragma solidity ^0.8.0;

contract LendingProtocolContract {
    struct Loan {
        address borrower;
        uint256 amount;
        uint256 collateral;
        uint256 interestRate;
        uint256 dueDate;
        bool isActive;
        bool isRepaid;
    }

    mapping(address => uint256) public deposits;
    mapping(address => uint256) public collateralBalance;
    mapping(uint256 => Loan) public loans;
    mapping(address => uint256[]) public userLoans;

    uint256 public totalDeposits;
    uint256 public totalLoans;
    uint256 public nextLoanId;
    uint256 public constant COLLATERAL_RATIO = 150;
    uint256 public constant BASE_INTEREST_RATE = 500;

    address public owner;


    event Deposit(address user, uint256 amount);
    event Withdrawal(address user, uint256 amount);
    event LoanCreated(uint256 loanId, address borrower, uint256 amount);
    event LoanRepaid(uint256 loanId, address borrower, uint256 amount);
    event CollateralDeposited(address user, uint256 amount);


    error Err1();
    error Err2();
    error Err3();

    modifier onlyOwner() {

        require(msg.sender == owner);
        _;
    }

    constructor() {
        owner = msg.sender;
        nextLoanId = 1;
    }

    function deposit() external payable {

        require(msg.value > 0);

        deposits[msg.sender] += msg.value;
        totalDeposits += msg.value;



    }

    function withdraw(uint256 amount) external {

        require(deposits[msg.sender] >= amount);
        require(address(this).balance >= amount);

        deposits[msg.sender] -= amount;
        totalDeposits -= amount;

        payable(msg.sender).transfer(amount);
        emit Withdrawal(msg.sender, amount);
    }

    function depositCollateral() external payable {

        require(msg.value > 0);

        collateralBalance[msg.sender] += msg.value;
        emit CollateralDeposited(msg.sender, msg.value);
    }

    function withdrawCollateral(uint256 amount) external {

        require(collateralBalance[msg.sender] >= amount);


        uint256[] memory userLoanIds = userLoans[msg.sender];
        uint256 totalBorrowed = 0;

        for (uint256 i = 0; i < userLoanIds.length; i++) {
            Loan storage loan = loans[userLoanIds[i]];
            if (loan.isActive && !loan.isRepaid) {
                totalBorrowed += loan.amount;
            }
        }

        uint256 remainingCollateral = collateralBalance[msg.sender] - amount;
        uint256 requiredCollateral = (totalBorrowed * COLLATERAL_RATIO) / 100;


        if (remainingCollateral < requiredCollateral) {
            revert Err1();
        }

        collateralBalance[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);


    }

    function createLoan(uint256 amount) external {

        require(amount > 0);
        require(totalDeposits >= amount);

        uint256 requiredCollateral = (amount * COLLATERAL_RATIO) / 100;


        require(collateralBalance[msg.sender] >= requiredCollateral);

        uint256 loanId = nextLoanId++;
        uint256 dueDate = block.timestamp + 30 days;

        loans[loanId] = Loan({
            borrower: msg.sender,
            amount: amount,
            collateral: requiredCollateral,
            interestRate: BASE_INTEREST_RATE,
            dueDate: dueDate,
            isActive: true,
            isRepaid: false
        });

        userLoans[msg.sender].push(loanId);
        totalLoans += amount;

        payable(msg.sender).transfer(amount);
        emit LoanCreated(loanId, msg.sender, amount);
    }

    function repayLoan(uint256 loanId) external payable {
        Loan storage loan = loans[loanId];


        require(loan.borrower == msg.sender);
        require(loan.isActive);
        require(!loan.isRepaid);

        uint256 interest = (loan.amount * loan.interestRate) / 10000;
        uint256 totalRepayment = loan.amount + interest;


        require(msg.value >= totalRepayment);

        loan.isActive = false;
        loan.isRepaid = true;
        totalLoans -= loan.amount;


        if (msg.value > totalRepayment) {
            payable(msg.sender).transfer(msg.value - totalRepayment);
        }

        emit LoanRepaid(loanId, msg.sender, loan.amount);


    }

    function liquidateLoan(uint256 loanId) external {
        Loan storage loan = loans[loanId];


        require(loan.isActive);
        require(!loan.isRepaid);
        require(block.timestamp > loan.dueDate);

        address borrower = loan.borrower;
        uint256 collateralToSeize = loan.collateral;


        if (collateralBalance[borrower] < collateralToSeize) {
            revert Err2();
        }

        loan.isActive = false;
        collateralBalance[borrower] -= collateralToSeize;
        totalLoans -= loan.amount;


        payable(msg.sender).transfer(collateralToSeize);


    }

    function getLoanDetails(uint256 loanId) external view returns (
        address borrower,
        uint256 amount,
        uint256 collateral,
        uint256 interestRate,
        uint256 dueDate,
        bool isActive,
        bool isRepaid
    ) {
        Loan storage loan = loans[loanId];
        return (
            loan.borrower,
            loan.amount,
            loan.collateral,
            loan.interestRate,
            loan.dueDate,
            loan.isActive,
            loan.isRepaid
        );
    }

    function getUserLoans(address user) external view returns (uint256[] memory) {
        return userLoans[user];
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function emergencyWithdraw() external onlyOwner {

        if (address(this).balance == 0) {
            revert Err3();
        }

        payable(owner).transfer(address(this).balance);


    }

    receive() external payable {
        deposits[msg.sender] += msg.value;
        totalDeposits += msg.value;
    }
}
