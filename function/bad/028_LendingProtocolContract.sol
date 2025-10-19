
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
    mapping(address => uint256[]) public userLoans;

    uint256 public totalLiquidity;
    uint256 public loanCounter;
    address public owner;
    uint256 public platformFee = 100;

    event LoanCreated(uint256 loanId, address borrower, uint256 amount);
    event LoanRepaid(uint256 loanId, address borrower, uint256 amount);
    event DepositMade(address user, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }




    function processLoanApplicationAndUpdateUserDataAndCalculateFeesAndValidateCollateral(
        uint256 loanAmount,
        uint256 interestRate,
        uint256 duration,
        address borrower,
        uint256 collateralAmount,
        string memory loanPurpose,
        bool autoRepayment
    ) public {

        if (borrower != address(0)) {
            if (loanAmount > 0) {
                if (duration > 0) {
                    if (collateralAmount >= loanAmount / 2) {
                        if (totalLiquidity >= loanAmount) {
                            if (!users[borrower].isRegistered) {
                                users[borrower] = User({
                                    totalDeposited: 0,
                                    totalBorrowed: 0,
                                    creditScore: 500,
                                    isRegistered: true
                                });
                            }

                            uint256 fee = (loanAmount * platformFee) / 10000;
                            uint256 netAmount = loanAmount - fee;

                            if (users[borrower].creditScore >= 300) {
                                if (users[borrower].totalBorrowed + loanAmount <= users[borrower].totalDeposited * 3) {
                                    loanCounter++;
                                    loans[loanCounter] = Loan({
                                        borrower: borrower,
                                        amount: loanAmount,
                                        interestRate: interestRate,
                                        duration: duration,
                                        startTime: block.timestamp,
                                        isActive: true,
                                        isRepaid: false
                                    });

                                    userLoans[borrower].push(loanCounter);
                                    users[borrower].totalBorrowed += loanAmount;
                                    totalLiquidity -= loanAmount;


                                    if (users[borrower].creditScore < 800) {
                                        users[borrower].creditScore += 10;
                                    }


                                    if (autoRepayment) {

                                    }

                                    payable(borrower).transfer(netAmount);
                                    emit LoanCreated(loanCounter, borrower, loanAmount);
                                }
                            }
                        }
                    }
                }
            }
        }
    }


    function calculateInterestAndFeesForInternalUse(uint256 principal, uint256 rate, uint256 time) public pure returns (uint256) {
        return (principal * rate * time) / (365 * 10000);
    }


    function validateUserCreditScore(address user) public view returns (bool) {
        return users[user].creditScore >= 300;
    }

    function deposit() public payable {
        require(msg.value > 0, "Amount must be greater than 0");

        if (!users[msg.sender].isRegistered) {
            users[msg.sender] = User({
                totalDeposited: 0,
                totalBorrowed: 0,
                creditScore: 600,
                isRegistered: true
            });
        }

        users[msg.sender].totalDeposited += msg.value;
        totalLiquidity += msg.value;


        if (users[msg.sender].creditScore < 900) {
            users[msg.sender].creditScore += 5;
        }

        emit DepositMade(msg.sender, msg.value);
    }

    function repayLoan(uint256 loanId) public payable {
        Loan storage loan = loans[loanId];
        require(loan.borrower == msg.sender, "Not your loan");
        require(loan.isActive, "Loan not active");
        require(!loan.isRepaid, "Already repaid");

        uint256 interest = calculateInterestAndFeesForInternalUse(
            loan.amount,
            loan.interestRate,
            (block.timestamp - loan.startTime) / 86400
        );
        uint256 totalRepayment = loan.amount + interest;

        require(msg.value >= totalRepayment, "Insufficient repayment");

        loan.isActive = false;
        loan.isRepaid = true;
        users[msg.sender].totalBorrowed -= loan.amount;
        totalLiquidity += msg.value;


        if (users[msg.sender].creditScore < 950) {
            users[msg.sender].creditScore += 20;
        }


        if (msg.value > totalRepayment) {
            payable(msg.sender).transfer(msg.value - totalRepayment);
        }

        emit LoanRepaid(loanId, msg.sender, totalRepayment);
    }

    function withdraw(uint256 amount) public {
        require(users[msg.sender].totalDeposited >= amount, "Insufficient balance");
        require(totalLiquidity >= amount, "Insufficient liquidity");
        require(users[msg.sender].totalBorrowed == 0, "Outstanding loans");

        users[msg.sender].totalDeposited -= amount;
        totalLiquidity -= amount;

        payable(msg.sender).transfer(amount);
    }

    function getUserInfo(address user) public view returns (User memory) {
        return users[user];
    }

    function getLoanInfo(uint256 loanId) public view returns (Loan memory) {
        return loans[loanId];
    }

    function getUserLoans(address user) public view returns (uint256[] memory) {
        return userLoans[user];
    }

    function emergencyWithdraw() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {
        totalLiquidity += msg.value;
        if (!users[msg.sender].isRegistered) {
            users[msg.sender] = User({
                totalDeposited: msg.value,
                totalBorrowed: 0,
                creditScore: 600,
                isRegistered: true
            });
        } else {
            users[msg.sender].totalDeposited += msg.value;
        }
    }
}
