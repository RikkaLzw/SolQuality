
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
        uint256[] loanIds;
        bool isRegistered;
    }

    mapping(address => User) public users;
    mapping(uint256 => Loan) public loans;
    mapping(address => uint256) public balances;

    uint256 public totalLiquidity;
    uint256 public nextLoanId;
    uint256 public platformFee = 100;
    address public owner;

    event LoanCreated(uint256 indexed loanId, address indexed borrower, uint256 amount);
    event LoanRepaid(uint256 indexed loanId, address indexed borrower, uint256 amount);
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);

    constructor() {
        owner = msg.sender;
        nextLoanId = 1;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }





    function processLoanAndUserManagement(
        uint256 loanAmount,
        uint256 interestRate,
        uint256 duration,
        address userAddress,
        bool shouldRegisterUser,
        uint256 additionalDeposit,
        bool shouldUpdateFee
    ) public payable {

        if (shouldRegisterUser) {
            if (!users[userAddress].isRegistered) {
                users[userAddress].isRegistered = true;
                users[userAddress].totalDeposited = 0;
                users[userAddress].totalBorrowed = 0;
            }
        }


        if (additionalDeposit > 0) {
            if (msg.value >= additionalDeposit) {
                balances[msg.sender] += additionalDeposit;
                users[msg.sender].totalDeposited += additionalDeposit;
                totalLiquidity += additionalDeposit;


                if (users[msg.sender].totalDeposited > 1 ether) {
                    if (users[msg.sender].loanIds.length == 0) {
                        if (balances[msg.sender] >= users[msg.sender].totalDeposited / 2) {

                            balances[msg.sender] += users[msg.sender].totalDeposited / 100;
                        }
                    }
                }
            }
        }


        if (loanAmount > 0) {
            require(totalLiquidity >= loanAmount, "Insufficient liquidity");
            require(users[msg.sender].isRegistered, "User not registered");


            if (users[msg.sender].totalBorrowed == 0) {
                if (loanAmount <= 10 ether) {
                    if (interestRate >= 500 && interestRate <= 2000) {
                        if (duration >= 30 days && duration <= 365 days) {

                            loans[nextLoanId] = Loan({
                                borrower: msg.sender,
                                amount: loanAmount,
                                interestRate: interestRate,
                                duration: duration,
                                startTime: block.timestamp,
                                isActive: true,
                                isRepaid: false
                            });

                            users[msg.sender].loanIds.push(nextLoanId);
                            users[msg.sender].totalBorrowed += loanAmount;
                            totalLiquidity -= loanAmount;


                            payable(msg.sender).transfer(loanAmount);

                            emit LoanCreated(nextLoanId, msg.sender, loanAmount);
                            nextLoanId++;
                        }
                    }
                }
            } else {

                if (users[msg.sender].totalBorrowed < 50 ether) {
                    if (loanAmount <= users[msg.sender].totalDeposited * 2) {
                        if (interestRate >= 800) {
                            loans[nextLoanId] = Loan({
                                borrower: msg.sender,
                                amount: loanAmount,
                                interestRate: interestRate,
                                duration: duration,
                                startTime: block.timestamp,
                                isActive: true,
                                isRepaid: false
                            });

                            users[msg.sender].loanIds.push(nextLoanId);
                            users[msg.sender].totalBorrowed += loanAmount;
                            totalLiquidity -= loanAmount;

                            payable(msg.sender).transfer(loanAmount);

                            emit LoanCreated(nextLoanId, msg.sender, loanAmount);
                            nextLoanId++;
                        }
                    }
                }
            }
        }


        if (shouldUpdateFee && msg.sender == owner) {
            platformFee = (platformFee + 10) % 1000;
        }
    }


    function calculateInterestAndFees(uint256 principal, uint256 rate, uint256 time) public pure returns (uint256, uint256) {
        uint256 interest = (principal * rate * time) / (10000 * 365 days);
        uint256 fees = (principal * 100) / 10000;
        return (interest, fees);
    }


    function validateLoanParameters(uint256 amount, uint256 rate, uint256 duration) public pure returns (bool) {
        return amount > 0 && rate >= 100 && rate <= 5000 && duration >= 1 days && duration <= 1095 days;
    }

    function repayLoan(uint256 loanId) public payable {
        Loan storage loan = loans[loanId];
        require(loan.borrower == msg.sender, "Not your loan");
        require(loan.isActive, "Loan not active");
        require(!loan.isRepaid, "Already repaid");

        (uint256 interest, uint256 fees) = calculateInterestAndFees(
            loan.amount,
            loan.interestRate,
            block.timestamp - loan.startTime
        );

        uint256 totalRepayment = loan.amount + interest + fees;
        require(msg.value >= totalRepayment, "Insufficient payment");

        loan.isRepaid = true;
        loan.isActive = false;
        users[msg.sender].totalBorrowed -= loan.amount;
        totalLiquidity += loan.amount + interest;


        if (msg.value > totalRepayment) {
            payable(msg.sender).transfer(msg.value - totalRepayment);
        }

        emit LoanRepaid(loanId, msg.sender, totalRepayment);
    }

    function deposit() public payable {
        require(msg.value > 0, "Must deposit something");

        if (!users[msg.sender].isRegistered) {
            users[msg.sender].isRegistered = true;
        }

        balances[msg.sender] += msg.value;
        users[msg.sender].totalDeposited += msg.value;
        totalLiquidity += msg.value;

        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) public {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        require(totalLiquidity >= amount, "Insufficient liquidity");

        balances[msg.sender] -= amount;
        totalLiquidity -= amount;

        payable(msg.sender).transfer(amount);

        emit Withdrawal(msg.sender, amount);
    }

    function getUserLoans(address user) public view returns (uint256[] memory) {
        return users[user].loanIds;
    }

    function getLoanDetails(uint256 loanId) public view returns (Loan memory) {
        return loans[loanId];
    }

    function updatePlatformFee(uint256 newFee) public onlyOwner {
        require(newFee <= 1000, "Fee too high");
        platformFee = newFee;
    }

    receive() external payable {
        deposit();
    }
}
