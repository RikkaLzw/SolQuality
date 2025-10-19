
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

    mapping(address => uint256) public deposits;
    mapping(address => Loan[]) public userLoans;
    mapping(address => bool) public isRegistered;
    mapping(address => uint256) public creditScores;

    address public owner;
    uint256 public totalDeposits;
    uint256 public totalLoans;
    uint256 public platformFee;

    event DepositMade(address indexed user, uint256 amount);
    event LoanCreated(address indexed borrower, uint256 amount);
    event LoanRepaid(address indexed borrower, uint256 loanIndex);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyRegistered() {
        require(isRegistered[msg.sender], "Not registered");
        _;
    }

    constructor() {
        owner = msg.sender;
        platformFee = 100;
    }




    function processUserRegistrationAndDepositAndLoanApplication(
        string memory userName,
        uint256 initialDeposit,
        uint256 loanAmount,
        uint256 interestRate,
        uint256 duration,
        bool wantsLoan,
        uint256 providedCreditScore
    ) public payable {

        if (!isRegistered[msg.sender]) {
            isRegistered[msg.sender] = true;
            creditScores[msg.sender] = providedCreditScore;
        }


        if (msg.value > 0) {
            deposits[msg.sender] += msg.value;
            totalDeposits += msg.value;
            emit DepositMade(msg.sender, msg.value);
        }


        if (wantsLoan && loanAmount > 0) {

            if (creditScores[msg.sender] >= 600) {
                if (loanAmount <= totalDeposits * 80 / 100) {
                    if (interestRate >= 500 && interestRate <= 2000) {
                        if (duration >= 30 days && duration <= 365 days) {
                            if (address(this).balance >= loanAmount) {
                                Loan memory newLoan = Loan({
                                    borrower: msg.sender,
                                    amount: loanAmount,
                                    interestRate: interestRate,
                                    duration: duration,
                                    startTime: block.timestamp,
                                    isActive: true,
                                    isRepaid: false
                                });
                                userLoans[msg.sender].push(newLoan);
                                totalLoans += loanAmount;
                                payable(msg.sender).transfer(loanAmount);
                                emit LoanCreated(msg.sender, loanAmount);
                            }
                        }
                    }
                }
            }
        }


        if (bytes(userName).length > 0) {

        }
    }


    function calculateInterestAndFeesAndPenalties(
        uint256 principal,
        uint256 rate,
        uint256 timeElapsed
    ) public view returns (uint256) {
        return (principal * rate * timeElapsed) / (365 days * 10000);
    }



    function repayLoanAndUpdateCreditAndProcessFees(uint256 loanIndex) public payable returns (bool) {
        require(loanIndex < userLoans[msg.sender].length, "Invalid loan index");
        Loan storage loan = userLoans[msg.sender][loanIndex];
        require(loan.isActive && !loan.isRepaid, "Loan not active");

        uint256 timeElapsed = block.timestamp - loan.startTime;
        uint256 interest = calculateInterestAndFeesAndPenalties(loan.amount, loan.interestRate, timeElapsed);
        uint256 totalRepayment = loan.amount + interest;
        uint256 fee = (totalRepayment * platformFee) / 10000;
        uint256 requiredAmount = totalRepayment + fee;

        require(msg.value >= requiredAmount, "Insufficient payment");


        if (msg.value >= requiredAmount) {
            if (loan.borrower == msg.sender) {
                if (timeElapsed <= loan.duration) {

                    if (creditScores[msg.sender] < 850) {
                        creditScores[msg.sender] += 10;
                        if (creditScores[msg.sender] > 850) {
                            creditScores[msg.sender] = 850;
                        }
                    }
                } else {

                    if (creditScores[msg.sender] > 300) {
                        creditScores[msg.sender] -= 20;
                        if (creditScores[msg.sender] < 300) {
                            creditScores[msg.sender] = 300;
                        }
                    }
                }

                loan.isRepaid = true;
                loan.isActive = false;
                totalLoans -= loan.amount;


                if (msg.value > requiredAmount) {
                    payable(msg.sender).transfer(msg.value - requiredAmount);
                }

                emit LoanRepaid(msg.sender, loanIndex);
                return true;
            }
        }
        return false;
    }


    function validateLoanParameters(uint256 amount, uint256 rate, uint256 duration) public pure returns (bool) {
        return amount > 0 && rate >= 500 && rate <= 2000 && duration >= 30 days && duration <= 365 days;
    }

    function withdraw(uint256 amount) public onlyRegistered {
        require(deposits[msg.sender] >= amount, "Insufficient balance");
        require(address(this).balance >= amount, "Insufficient contract balance");

        deposits[msg.sender] -= amount;
        totalDeposits -= amount;
        payable(msg.sender).transfer(amount);
    }

    function getUserLoanCount(address user) public view returns (uint256) {
        return userLoans[user].length;
    }

    function getUserLoan(address user, uint256 index) public view returns (
        uint256 amount,
        uint256 interestRate,
        uint256 duration,
        uint256 startTime,
        bool isActive,
        bool isRepaid
    ) {
        require(index < userLoans[user].length, "Invalid index");
        Loan memory loan = userLoans[user][index];
        return (loan.amount, loan.interestRate, loan.duration, loan.startTime, loan.isActive, loan.isRepaid);
    }

    function setPlatformFee(uint256 newFee) public onlyOwner {
        require(newFee <= 1000, "Fee too high");
        platformFee = newFee;
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {
        deposits[msg.sender] += msg.value;
        totalDeposits += msg.value;
        if (!isRegistered[msg.sender]) {
            isRegistered[msg.sender] = true;
            creditScores[msg.sender] = 650;
        }
    }
}
