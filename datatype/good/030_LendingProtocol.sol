
pragma solidity ^0.8.19;

contract LendingProtocol {

    uint256 public constant INTEREST_RATE_PRECISION = 10000;
    uint128 public totalLent;
    uint128 public totalBorrowed;
    uint64 public loanCounter;


    bytes32 public constant PROTOCOL_NAME = keccak256("LendingProtocol");

    struct Loan {
        address borrower;
        address lender;
        uint128 principal;
        uint128 interest;
        uint64 startTime;
        uint64 duration;
        uint16 interestRate;
        bool isActive;
        bool isRepaid;
    }

    struct UserProfile {
        uint128 totalLent;
        uint128 totalBorrowed;
        uint64 loanCount;
        bool isRegistered;
    }

    mapping(uint256 => Loan) public loans;
    mapping(address => UserProfile) public userProfiles;
    mapping(address => uint256[]) public userLoans;
    mapping(address => uint128) public deposits;

    event LoanCreated(
        uint256 indexed loanId,
        address indexed borrower,
        address indexed lender,
        uint128 principal,
        uint16 interestRate,
        uint64 duration
    );

    event LoanRepaid(
        uint256 indexed loanId,
        address indexed borrower,
        uint128 totalAmount
    );

    event DepositMade(address indexed user, uint128 amount);
    event WithdrawalMade(address indexed user, uint128 amount);

    modifier onlyRegistered() {
        require(userProfiles[msg.sender].isRegistered, "User not registered");
        _;
    }

    modifier loanExists(uint256 loanId) {
        require(loanId < loanCounter, "Loan does not exist");
        _;
    }

    modifier onlyBorrower(uint256 loanId) {
        require(loans[loanId].borrower == msg.sender, "Not the borrower");
        _;
    }

    modifier onlyLender(uint256 loanId) {
        require(loans[loanId].lender == msg.sender, "Not the lender");
        _;
    }

    function register() external {
        require(!userProfiles[msg.sender].isRegistered, "Already registered");

        userProfiles[msg.sender] = UserProfile({
            totalLent: 0,
            totalBorrowed: 0,
            loanCount: 0,
            isRegistered: true
        });
    }

    function deposit() external payable onlyRegistered {
        require(msg.value > 0, "Deposit must be greater than 0");

        uint128 amount = uint128(msg.value);
        deposits[msg.sender] += amount;

        emit DepositMade(msg.sender, amount);
    }

    function withdraw(uint128 amount) external onlyRegistered {
        require(amount > 0, "Amount must be greater than 0");
        require(deposits[msg.sender] >= amount, "Insufficient balance");

        deposits[msg.sender] -= amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");

        emit WithdrawalMade(msg.sender, amount);
    }

    function createLoan(
        address borrower,
        uint128 principal,
        uint16 interestRate,
        uint64 duration
    ) external onlyRegistered returns (uint256) {
        require(borrower != address(0), "Invalid borrower address");
        require(borrower != msg.sender, "Cannot lend to yourself");
        require(userProfiles[borrower].isRegistered, "Borrower not registered");
        require(principal > 0, "Principal must be greater than 0");
        require(interestRate <= 5000, "Interest rate too high");
        require(duration > 0, "Duration must be greater than 0");
        require(deposits[msg.sender] >= principal, "Insufficient lender balance");

        uint256 loanId = loanCounter++;
        uint128 interest = (principal * interestRate) / INTEREST_RATE_PRECISION;

        loans[loanId] = Loan({
            borrower: borrower,
            lender: msg.sender,
            principal: principal,
            interest: interest,
            startTime: uint64(block.timestamp),
            duration: duration,
            interestRate: interestRate,
            isActive: true,
            isRepaid: false
        });


        userProfiles[msg.sender].totalLent += principal;
        userProfiles[msg.sender].loanCount++;
        userProfiles[borrower].totalBorrowed += principal;


        userLoans[borrower].push(loanId);
        userLoans[msg.sender].push(loanId);


        deposits[msg.sender] -= principal;
        deposits[borrower] += principal;


        totalLent += principal;
        totalBorrowed += principal;

        emit LoanCreated(loanId, borrower, msg.sender, principal, interestRate, duration);

        return loanId;
    }

    function repayLoan(uint256 loanId)
        external
        loanExists(loanId)
        onlyBorrower(loanId)
    {
        Loan storage loan = loans[loanId];
        require(loan.isActive, "Loan is not active");
        require(!loan.isRepaid, "Loan already repaid");

        uint128 totalAmount = loan.principal + loan.interest;
        require(deposits[msg.sender] >= totalAmount, "Insufficient balance for repayment");


        loan.isActive = false;
        loan.isRepaid = true;


        deposits[msg.sender] -= totalAmount;
        deposits[loan.lender] += totalAmount;


        totalBorrowed -= loan.principal;

        emit LoanRepaid(loanId, msg.sender, totalAmount);
    }

    function getLoanDetails(uint256 loanId)
        external
        view
        loanExists(loanId)
        returns (
            address borrower,
            address lender,
            uint128 principal,
            uint128 interest,
            uint64 startTime,
            uint64 duration,
            uint16 interestRate,
            bool isActive,
            bool isRepaid
        )
    {
        Loan memory loan = loans[loanId];
        return (
            loan.borrower,
            loan.lender,
            loan.principal,
            loan.interest,
            loan.startTime,
            loan.duration,
            loan.interestRate,
            loan.isActive,
            loan.isRepaid
        );
    }

    function getUserLoans(address user) external view returns (uint256[] memory) {
        return userLoans[user];
    }

    function isLoanOverdue(uint256 loanId)
        external
        view
        loanExists(loanId)
        returns (bool)
    {
        Loan memory loan = loans[loanId];
        if (!loan.isActive || loan.isRepaid) {
            return false;
        }
        return block.timestamp > loan.startTime + loan.duration;
    }

    function getProtocolStats()
        external
        view
        returns (
            uint128 _totalLent,
            uint128 _totalBorrowed,
            uint64 _loanCounter
        )
    {
        return (totalLent, totalBorrowed, loanCounter);
    }

    function calculateRepaymentAmount(uint256 loanId)
        external
        view
        loanExists(loanId)
        returns (uint128)
    {
        Loan memory loan = loans[loanId];
        return loan.principal + loan.interest;
    }
}
