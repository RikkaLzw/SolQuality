
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
        uint256 balance;
        uint256 totalBorrowed;
        uint256 totalLent;
        bool isRegistered;
    }

    mapping(address => User) public users;
    mapping(uint256 => Loan) public loans;
    mapping(address => uint256[]) public userLoans;

    uint256 public totalSupply;
    uint256 public totalBorrowed;
    uint256 public loanCounter;
    address public owner;

    event LoanCreated(uint256 loanId, address borrower, uint256 amount);
    event LoanRepaid(uint256 loanId, address borrower, uint256 amount);
    event DepositMade(address user, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyRegistered() {
        require(users[msg.sender].isRegistered, "Not registered");
        _;
    }

    constructor() {
        owner = msg.sender;
    }




    function createLoanAndUpdateUserDataAndCheckEligibility(
        uint256 _amount,
        uint256 _interestRate,
        uint256 _duration,
        address _borrower,
        bool _autoApprove,
        uint256 _collateralAmount,
        string memory _purpose
    ) public {

        if (_borrower != address(0)) {
            if (!users[_borrower].isRegistered) {
                users[_borrower].isRegistered = true;
                users[_borrower].balance = 0;
                users[_borrower].totalBorrowed = 0;
                users[_borrower].totalLent = 0;

                if (_autoApprove) {
                    if (_amount > 0 && _amount <= 1000000 ether) {
                        if (_interestRate >= 5 && _interestRate <= 20) {
                            if (_duration >= 30 days && _duration <= 365 days) {
                                if (_collateralAmount >= _amount / 2) {
                                    loanCounter++;
                                    loans[loanCounter] = Loan({
                                        borrower: _borrower,
                                        amount: _amount,
                                        interestRate: _interestRate,
                                        duration: _duration,
                                        startTime: block.timestamp,
                                        isActive: true,
                                        isRepaid: false
                                    });

                                    userLoans[_borrower].push(loanCounter);
                                    users[_borrower].totalBorrowed += _amount;
                                    totalBorrowed += _amount;

                                    if (totalSupply >= _amount) {
                                        totalSupply -= _amount;
                                        users[_borrower].balance += _amount;
                                        emit LoanCreated(loanCounter, _borrower, _amount);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }


    function calculateInterestAndFeesAndPenalties(uint256 _loanId, uint256 _extraParam1, uint256 _extraParam2, uint256 _extraParam3, uint256 _extraParam4, bool _includePenalty) public view returns (uint256) {
        Loan memory loan = loans[_loanId];
        if (!loan.isActive) return 0;

        uint256 timeElapsed = block.timestamp - loan.startTime;
        uint256 interest = (loan.amount * loan.interestRate * timeElapsed) / (365 days * 100);

        if (_includePenalty && timeElapsed > loan.duration) {
            uint256 penalty = (loan.amount * 5 * (timeElapsed - loan.duration)) / (365 days * 100);
            interest += penalty;
        }

        return interest + _extraParam1 + _extraParam2 + _extraParam3 + _extraParam4;
    }

    function deposit() public payable {
        require(msg.value > 0, "Amount must be greater than 0");

        if (!users[msg.sender].isRegistered) {
            users[msg.sender].isRegistered = true;
            users[msg.sender].balance = 0;
            users[msg.sender].totalBorrowed = 0;
            users[msg.sender].totalLent = 0;
        }

        users[msg.sender].balance += msg.value;
        users[msg.sender].totalLent += msg.value;
        totalSupply += msg.value;

        emit DepositMade(msg.sender, msg.value);
    }

    function repayLoan(uint256 _loanId) public payable {
        Loan storage loan = loans[_loanId];
        require(loan.borrower == msg.sender, "Not your loan");
        require(loan.isActive, "Loan not active");
        require(!loan.isRepaid, "Loan already repaid");

        uint256 interest = calculateInterestAndFeesAndPenalties(_loanId, 0, 0, 0, 0, true);
        uint256 totalAmount = loan.amount + interest;

        require(msg.value >= totalAmount, "Insufficient payment");

        loan.isActive = false;
        loan.isRepaid = true;
        users[msg.sender].totalBorrowed -= loan.amount;
        totalBorrowed -= loan.amount;
        totalSupply += msg.value;

        if (msg.value > totalAmount) {
            payable(msg.sender).transfer(msg.value - totalAmount);
        }

        emit LoanRepaid(_loanId, msg.sender, totalAmount);
    }

    function withdraw(uint256 _amount) public onlyRegistered {
        require(_amount > 0, "Amount must be greater than 0");
        require(users[msg.sender].balance >= _amount, "Insufficient balance");
        require(address(this).balance >= _amount, "Insufficient contract balance");

        users[msg.sender].balance -= _amount;
        totalSupply -= _amount;
        payable(msg.sender).transfer(_amount);
    }


    function getUserInfoAndContractStatsAndLoanDetails(address _user, uint256 _loanId) public view returns (uint256, uint256, uint256, bool, uint256, uint256, address, bool) {
        User memory user = users[_user];
        Loan memory loan = loans[_loanId];

        return (
            user.balance,
            user.totalBorrowed,
            user.totalLent,
            user.isRegistered,
            totalSupply,
            totalBorrowed,
            loan.borrower,
            loan.isActive
        );
    }

    function emergencyWithdraw() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {
        deposit();
    }
}
