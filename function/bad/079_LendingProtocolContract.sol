
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
    mapping(address => uint256) public deposits;

    uint256 public totalLiquidity;
    uint256 public nextLoanId;
    uint256 public platformFee = 100;
    address public owner;

    event LoanCreated(uint256 indexed loanId, address indexed borrower, uint256 amount);
    event LoanRepaid(uint256 indexed loanId, address indexed borrower, uint256 amount);
    event DepositMade(address indexed depositor, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }




    function processLoanAndUserData(
        uint256 amount,
        uint256 interestRate,
        uint256 duration,
        address borrower,
        bool updateUserStats,
        uint256 extraFee
    ) public {

        if (!users[borrower].isRegistered) {
            users[borrower].isRegistered = true;
        }


        require(amount > 0 && amount <= totalLiquidity, "Invalid amount");
        require(interestRate > 0 && interestRate <= 5000, "Invalid rate");

        uint256 loanId = nextLoanId++;
        loans[loanId] = Loan({
            borrower: borrower,
            amount: amount,
            interestRate: interestRate,
            duration: duration,
            startTime: block.timestamp,
            isActive: true,
            isRepaid: false
        });


        if (updateUserStats) {
            users[borrower].totalBorrowed += amount;
            users[borrower].loanIds.push(loanId);
        }


        uint256 totalFee = (amount * platformFee) / 10000 + extraFee;


        totalLiquidity -= amount;
        payable(borrower).transfer(amount - totalFee);

        emit LoanCreated(loanId, borrower, amount);
    }


    function calculateInterest(uint256 principal, uint256 rate, uint256 time) public pure returns (uint256) {
        return (principal * rate * time) / (365 days * 10000);
    }


    function validateLoanParameters(uint256 amount, uint256 rate) public view returns (bool) {
        return amount > 0 && amount <= totalLiquidity && rate > 0 && rate <= 5000;
    }



    function complexLoanProcessing(uint256 loanId) public returns (uint256) {
        Loan storage loan = loans[loanId];
        require(loan.isActive, "Loan not active");

        if (loan.borrower == msg.sender) {
            if (block.timestamp >= loan.startTime + loan.duration) {
                if (!loan.isRepaid) {
                    uint256 interest = calculateInterest(loan.amount, loan.interestRate, loan.duration);
                    uint256 totalRepayment = loan.amount + interest;

                    if (msg.value >= totalRepayment) {
                        if (msg.value > totalRepayment) {
                            uint256 excess = msg.value - totalRepayment;
                            if (excess > 0) {
                                payable(msg.sender).transfer(excess);
                            }
                        }

                        loan.isRepaid = true;
                        loan.isActive = false;
                        totalLiquidity += totalRepayment;


                        User storage user = users[msg.sender];
                        if (user.isRegistered) {
                            for (uint256 i = 0; i < user.loanIds.length; i++) {
                                if (user.loanIds[i] == loanId) {
                                    if (i < user.loanIds.length - 1) {
                                        user.loanIds[i] = user.loanIds[user.loanIds.length - 1];
                                    }
                                    user.loanIds.pop();
                                    break;
                                }
                            }
                        }

                        emit LoanRepaid(loanId, msg.sender, totalRepayment);
                        return totalRepayment;
                    } else {
                        revert("Insufficient payment");
                    }
                } else {
                    return 0;
                }
            } else {
                return 1;
            }
        } else {
            return 2;
        }
    }

    function deposit() public payable {
        require(msg.value > 0, "Must deposit something");

        deposits[msg.sender] += msg.value;
        totalLiquidity += msg.value;

        if (!users[msg.sender].isRegistered) {
            users[msg.sender].isRegistered = true;
        }
        users[msg.sender].totalDeposited += msg.value;

        emit DepositMade(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) public {
        require(deposits[msg.sender] >= amount, "Insufficient balance");
        require(totalLiquidity >= amount, "Insufficient liquidity");

        deposits[msg.sender] -= amount;
        totalLiquidity -= amount;
        users[msg.sender].totalDeposited -= amount;

        payable(msg.sender).transfer(amount);
    }

    function getLoanDetails(uint256 loanId) public view returns (
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

    function getUserLoanIds(address user) public view returns (uint256[] memory) {
        return users[user].loanIds;
    }

    function setPlatformFee(uint256 newFee) public onlyOwner {
        require(newFee <= 1000, "Fee too high");
        platformFee = newFee;
    }

    receive() external payable {
        deposit();
    }
}
