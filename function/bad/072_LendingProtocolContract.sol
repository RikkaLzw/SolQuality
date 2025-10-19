
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
    uint256 public nextLoanId = 1;
    uint256 public platformFee = 100;
    address public owner;

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




    function createLoanAndUpdateUserDataAndCalculateRisk(
        uint256 _amount,
        uint256 _interestRate,
        uint256 _duration,
        bool _updateCreditScore,
        uint256 _riskLevel,
        string memory _purpose
    ) public {

        if (!users[msg.sender].isRegistered) {
            users[msg.sender].isRegistered = true;
            users[msg.sender].creditScore = 500;

            if (_riskLevel > 5) {
                if (_amount > 1000 ether) {
                    if (_duration > 365 days) {
                        if (_interestRate < 500) {
                            users[msg.sender].creditScore = 400;

                            if (keccak256(abi.encodePacked(_purpose)) == keccak256(abi.encodePacked("business"))) {
                                users[msg.sender].creditScore += 50;

                                if (totalLiquidity > _amount * 2) {
                                    users[msg.sender].creditScore += 25;
                                }
                            }
                        }
                    }
                }
            }
        }

        require(_amount > 0 && _amount <= totalLiquidity, "Invalid amount");
        require(_interestRate >= 100 && _interestRate <= 2000, "Invalid interest rate");
        require(_duration >= 1 days && _duration <= 365 days, "Invalid duration");


        loans[nextLoanId] = Loan({
            borrower: msg.sender,
            amount: _amount,
            interestRate: _interestRate,
            duration: _duration,
            startTime: block.timestamp,
            isActive: true,
            isRepaid: false
        });

        userLoans[msg.sender].push(nextLoanId);
        users[msg.sender].totalBorrowed += _amount;
        totalLiquidity -= _amount;


        if (_updateCreditScore) {
            if (users[msg.sender].totalBorrowed > users[msg.sender].totalDeposited) {
                users[msg.sender].creditScore = users[msg.sender].creditScore > 50 ?
                    users[msg.sender].creditScore - 50 : 0;
            } else {
                users[msg.sender].creditScore += 25;
            }
        }


        payable(msg.sender).transfer(_amount);

        emit LoanCreated(nextLoanId, msg.sender, _amount);
        nextLoanId++;
    }


    function calculateInterest(uint256 _principal, uint256 _rate, uint256 _time) public pure returns (uint256) {
        return (_principal * _rate * _time) / (10000 * 365 days);
    }


    function validateLoanParameters(uint256 _amount, uint256 _rate) public view returns (bool) {
        return _amount > 0 && _amount <= totalLiquidity && _rate >= 100 && _rate <= 2000;
    }

    function repayLoan(uint256 _loanId) public payable {
        Loan storage loan = loans[_loanId];
        require(loan.borrower == msg.sender, "Not your loan");
        require(loan.isActive && !loan.isRepaid, "Loan not active");

        uint256 timeElapsed = block.timestamp - loan.startTime;
        uint256 interest = calculateInterest(loan.amount, loan.interestRate, timeElapsed);
        uint256 totalRepayment = loan.amount + interest;
        uint256 fee = (totalRepayment * platformFee) / 10000;

        require(msg.value >= totalRepayment + fee, "Insufficient payment");

        loan.isRepaid = true;
        loan.isActive = false;

        users[msg.sender].totalBorrowed -= loan.amount;
        users[msg.sender].creditScore += 10;

        totalLiquidity += loan.amount + interest;


        if (msg.value > totalRepayment + fee) {
            payable(msg.sender).transfer(msg.value - totalRepayment - fee);
        }

        emit LoanRepaid(_loanId, msg.sender, totalRepayment);
    }

    function deposit() public payable {
        require(msg.value > 0, "Must deposit something");

        if (!users[msg.sender].isRegistered) {
            users[msg.sender].isRegistered = true;
            users[msg.sender].creditScore = 600;
        }

        users[msg.sender].totalDeposited += msg.value;
        users[msg.sender].creditScore += 5;
        totalLiquidity += msg.value;

        emit DepositMade(msg.sender, msg.value);
    }

    function withdraw(uint256 _amount) public {
        require(users[msg.sender].totalDeposited >= _amount, "Insufficient balance");
        require(totalLiquidity >= _amount, "Insufficient liquidity");

        users[msg.sender].totalDeposited -= _amount;
        totalLiquidity -= _amount;

        payable(msg.sender).transfer(_amount);
    }



    function getUserCompleteInfo(
        address _user,
        bool _includeCreditHistory,
        bool _includeActiveLoans,
        uint256 _maxLoansToReturn,
        bool _calculateRisk,
        string memory _reportType
    ) public view returns (uint256, uint256, uint256, bool, uint256[] memory, bool) {
        User memory user = users[_user];
        uint256[] memory activeLoanIds;

        if (_includeActiveLoans && userLoans[_user].length > 0) {
            uint256 activeCount = 0;
            uint256 maxReturns = _maxLoansToReturn > 0 ? _maxLoansToReturn : userLoans[_user].length;


            for (uint i = 0; i < userLoans[_user].length && activeCount < maxReturns; i++) {
                if (loans[userLoans[_user][i]].isActive) {
                    if (_calculateRisk) {
                        if (loans[userLoans[_user][i]].amount > 100 ether) {
                            if (block.timestamp - loans[userLoans[_user][i]].startTime > 30 days) {
                                if (keccak256(abi.encodePacked(_reportType)) == keccak256(abi.encodePacked("detailed"))) {
                                    activeCount++;
                                }
                            }
                        }
                    } else {
                        activeCount++;
                    }
                }
            }

            activeLoanIds = new uint256[](activeCount);
            uint256 index = 0;

            for (uint i = 0; i < userLoans[_user].length && index < activeCount; i++) {
                if (loans[userLoans[_user][i]].isActive) {
                    activeLoanIds[index] = userLoans[_user][i];
                    index++;
                }
            }
        }

        bool isHighRisk = _calculateRisk &&
            (user.totalBorrowed > user.totalDeposited * 2 || user.creditScore < 300);

        return (
            user.totalDeposited,
            user.totalBorrowed,
            user.creditScore,
            user.isRegistered,
            activeLoanIds,
            isHighRisk
        );
    }

    function getLoanDetails(uint256 _loanId) public view returns (Loan memory) {
        return loans[_loanId];
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function emergencyWithdraw() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {
        totalLiquidity += msg.value;
    }
}
