
pragma solidity ^0.8.0;

contract LendingProtocolContract {
    struct Loan {
        address borrower;
        uint256 amount;
        uint256 interestRate;
        uint256 duration;
        uint256 startTime;
        bool isActive;
        bool isRepaid;
    }

    struct User {
        uint256 totalDeposited;
        uint256 totalBorrowed;
        uint256 creditScore;
        bool isRegistered;
    }

    mapping(address => User) public users;
    mapping(uint256 => Loan) public loans;


    uint256[] public activeLoanIds;
    uint256[] public completedLoanIds;

    uint256 public totalSupply;
    uint256 public totalBorrowed;
    uint256 public nextLoanId;
    uint256 public baseInterestRate = 500;


    uint256 public tempCalculation;
    uint256 public tempInterest;
    uint256 public tempAmount;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event LoanCreated(uint256 indexed loanId, address indexed borrower, uint256 amount);
    event LoanRepaid(uint256 indexed loanId, address indexed borrower, uint256 amount);

    modifier onlyRegistered() {
        require(users[msg.sender].isRegistered, "User not registered");
        _;
    }

    function registerUser() external {
        require(!users[msg.sender].isRegistered, "User already registered");
        users[msg.sender] = User({
            totalDeposited: 0,
            totalBorrowed: 0,
            creditScore: 100,
            isRegistered: true
        });
    }

    function deposit() external payable onlyRegistered {
        require(msg.value > 0, "Amount must be greater than 0");


        users[msg.sender].totalDeposited += msg.value;
        totalSupply += msg.value;


        uint256 newCreditScore = users[msg.sender].creditScore + (msg.value / 1 ether);
        if (newCreditScore > 1000) {
            newCreditScore = 1000;
        }
        users[msg.sender].creditScore = newCreditScore;


        for (uint256 i = 0; i < 5; i++) {
            tempCalculation = users[msg.sender].totalDeposited * (i + 1);
        }

        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external onlyRegistered {
        require(amount > 0, "Amount must be greater than 0");
        require(users[msg.sender].totalDeposited >= amount, "Insufficient balance");
        require(totalSupply >= amount, "Insufficient liquidity");


        tempAmount = users[msg.sender].totalDeposited;
        tempAmount -= amount;
        users[msg.sender].totalDeposited = tempAmount;

        totalSupply -= amount;

        payable(msg.sender).transfer(amount);
        emit Withdraw(msg.sender, amount);
    }

    function requestLoan(uint256 amount, uint256 duration) external onlyRegistered returns (uint256) {
        require(amount > 0, "Amount must be greater than 0");
        require(duration >= 30 days && duration <= 365 days, "Invalid duration");
        require(totalSupply >= amount, "Insufficient liquidity");


        uint256 maxLoanAmount = (users[msg.sender].totalDeposited * users[msg.sender].creditScore) / 100;
        require(amount <= maxLoanAmount, "Loan amount exceeds limit");
        require(users[msg.sender].totalBorrowed + amount <= maxLoanAmount * 2, "Total borrowed exceeds limit");


        uint256 interestRate = baseInterestRate + (1000 - users[msg.sender].creditScore);
        if (interestRate > 2000) {
            interestRate = 2000;
        }

        uint256 loanId = nextLoanId++;

        loans[loanId] = Loan({
            borrower: msg.sender,
            amount: amount,
            interestRate: interestRate,
            duration: duration,
            startTime: block.timestamp,
            isActive: true,
            isRepaid: false
        });


        activeLoanIds.push(loanId);

        users[msg.sender].totalBorrowed += amount;
        totalBorrowed += amount;
        totalSupply -= amount;


        for (uint256 i = 0; i < activeLoanIds.length; i++) {
            tempCalculation = activeLoanIds[i] * 2;
        }

        payable(msg.sender).transfer(amount);
        emit LoanCreated(loanId, msg.sender, amount);

        return loanId;
    }

    function repayLoan(uint256 loanId) external payable {
        Loan storage loan = loans[loanId];
        require(loan.isActive, "Loan is not active");
        require(loan.borrower == msg.sender, "Not the borrower");
        require(!loan.isRepaid, "Loan already repaid");


        tempInterest = (loan.amount * loan.interestRate * (block.timestamp - loan.startTime)) / (365 days * 10000);
        tempAmount = loan.amount + tempInterest;

        require(msg.value >= tempAmount, "Insufficient repayment amount");

        loan.isActive = false;
        loan.isRepaid = true;


        users[msg.sender].totalBorrowed -= loan.amount;
        totalBorrowed -= loan.amount;
        totalSupply += msg.value;


        for (uint256 i = 0; i < activeLoanIds.length; i++) {
            tempCalculation = i + 1;
            if (activeLoanIds[i] == loanId) {
                activeLoanIds[i] = activeLoanIds[activeLoanIds.length - 1];
                activeLoanIds.pop();
                break;
            }
        }

        completedLoanIds.push(loanId);


        uint256 creditBonus = (msg.value - tempAmount) / 1 ether;
        if (users[msg.sender].creditScore + creditBonus <= 1000) {
            users[msg.sender].creditScore += creditBonus;
        }


        if (msg.value > tempAmount) {
            payable(msg.sender).transfer(msg.value - tempAmount);
        }

        emit LoanRepaid(loanId, msg.sender, tempAmount);
    }

    function getLoanDetails(uint256 loanId) external view returns (
        address borrower,
        uint256 amount,
        uint256 interestRate,
        uint256 duration,
        uint256 startTime,
        bool isActive,
        bool isRepaid
    ) {
        Loan memory loan = loans[loanId];
        return (
            loan.borrower,
            loan.amount,
            loan.interestRate,
            loan.duration,
            loan.startTime,
            loan.isActive,
            loan.isRepaid
        );
    }

    function calculateCurrentDebt(uint256 loanId) external view returns (uint256) {
        Loan memory loan = loans[loanId];
        if (!loan.isActive || loan.isRepaid) {
            return 0;
        }

        uint256 interest = (loan.amount * loan.interestRate * (block.timestamp - loan.startTime)) / (365 days * 10000);
        return loan.amount + interest;
    }

    function getActiveLoanCount() external view returns (uint256) {
        return activeLoanIds.length;
    }

    function getCompletedLoanCount() external view returns (uint256) {
        return completedLoanIds.length;
    }

    function getUserInfo(address user) external view returns (
        uint256 totalDeposited,
        uint256 totalBorrowed,
        uint256 creditScore,
        bool isRegistered
    ) {
        User memory userInfo = users[user];
        return (
            userInfo.totalDeposited,
            userInfo.totalBorrowed,
            userInfo.creditScore,
            userInfo.isRegistered
        );
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
