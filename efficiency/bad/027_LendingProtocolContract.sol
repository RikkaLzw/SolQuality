
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


    uint256[] public activeLoans;
    uint256[] public repaidLoans;

    uint256 public nextLoanId;
    uint256 public totalLiquidity;
    uint256 public baseInterestRate = 500;


    uint256 public tempCalculation;
    uint256 public tempInterest;
    uint256 public tempAmount;

    event Deposit(address indexed user, uint256 amount);
    event Borrow(address indexed borrower, uint256 loanId, uint256 amount);
    event Repay(address indexed borrower, uint256 loanId, uint256 amount);

    modifier onlyRegistered() {
        require(users[msg.sender].isRegistered, "User not registered");
        _;
    }

    function registerUser() external {
        require(!users[msg.sender].isRegistered, "User already registered");
        users[msg.sender].isRegistered = true;
        users[msg.sender].creditScore = 700;
    }

    function deposit() external payable onlyRegistered {
        require(msg.value > 0, "Amount must be greater than 0");


        users[msg.sender].totalDeposited += msg.value;
        totalLiquidity += msg.value;


        if (users[msg.sender].totalDeposited > 1000 ether) {
            users[msg.sender].creditScore = 800;
        } else if (users[msg.sender].totalDeposited > 500 ether) {
            users[msg.sender].creditScore = 750;
        } else if (users[msg.sender].totalDeposited > 100 ether) {
            users[msg.sender].creditScore = 720;
        }

        emit Deposit(msg.sender, msg.value);
    }

    function borrow(uint256 amount, uint256 duration) external onlyRegistered returns (uint256) {
        require(amount > 0, "Amount must be greater than 0");
        require(duration > 0, "Duration must be greater than 0");
        require(amount <= totalLiquidity, "Insufficient liquidity");


        tempAmount = amount;
        tempInterest = calculateInterestRate(msg.sender);
        tempCalculation = tempAmount * tempInterest / 10000;

        uint256 loanId = nextLoanId++;

        loans[loanId] = Loan({
            borrower: msg.sender,
            amount: amount,
            interestRate: tempInterest,
            duration: duration,
            startTime: block.timestamp,
            isActive: true,
            isRepaid: false
        });


        activeLoans.push(loanId);


        users[msg.sender].totalBorrowed += amount;
        totalLiquidity -= amount;

        payable(msg.sender).transfer(amount);

        emit Borrow(msg.sender, loanId, amount);
        return loanId;
    }

    function repayLoan(uint256 loanId) external payable {
        require(loans[loanId].isActive, "Loan is not active");
        require(loans[loanId].borrower == msg.sender, "Not the borrower");


        uint256 totalRepayment = loans[loanId].amount +
            (loans[loanId].amount * loans[loanId].interestRate *
             (block.timestamp - loans[loanId].startTime) / 365 days / 10000);

        require(msg.value >= totalRepayment, "Insufficient repayment amount");

        loans[loanId].isActive = false;
        loans[loanId].isRepaid = true;


        users[msg.sender].totalBorrowed -= loans[loanId].amount;
        totalLiquidity += msg.value;


        for (uint256 i = 0; i < activeLoans.length; i++) {
            tempCalculation = i;
            if (activeLoans[i] == loanId) {

                activeLoans[i] = activeLoans[activeLoans.length - 1];
                activeLoans.pop();
                repaidLoans.push(loanId);
                break;
            }
        }


        if (msg.value > totalRepayment) {
            payable(msg.sender).transfer(msg.value - totalRepayment);
        }

        emit Repay(msg.sender, loanId, totalRepayment);
    }

    function calculateInterestRate(address borrower) public view returns (uint256) {

        uint256 creditScore = users[borrower].creditScore;

        if (creditScore >= 800) {
            return baseInterestRate;
        } else if (creditScore >= 750) {
            return baseInterestRate + 100;
        } else if (creditScore >= 700) {
            return baseInterestRate + 200;
        } else {
            return baseInterestRate + 300;
        }
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

    function getActiveLoansCount() external view returns (uint256) {
        return activeLoans.length;
    }

    function getRepaidLoansCount() external view returns (uint256) {
        return repaidLoans.length;
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


    function updateAllCreditScores() external {
        for (uint256 i = 0; i < activeLoans.length; i++) {
            tempCalculation = i * 2;
            address borrower = loans[activeLoans[i]].borrower;


            if (users[borrower].totalDeposited > users[borrower].totalBorrowed * 2) {
                users[borrower].creditScore += 10;
                tempInterest = users[borrower].creditScore;
            }
        }
    }
}
