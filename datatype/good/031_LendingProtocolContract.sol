
pragma solidity ^0.8.0;

contract LendingProtocolContract {

    uint256 public constant INTEREST_RATE_PRECISION = 10000;
    uint128 public totalSupply;
    uint128 public totalBorrowed;


    bytes32 public protocolName;
    bytes32 public version;


    struct LoanInfo {
        uint128 principal;
        uint128 interest;
        uint64 startTime;
        uint64 duration;
        uint16 interestRate;
        bool isActive;
        bool isRepaid;
    }

    struct UserBalance {
        uint128 deposited;
        uint128 borrowed;
        uint64 lastUpdateTime;
        bool isRegistered;
    }


    address public owner;
    uint16 public defaultInterestRate;
    uint64 public minLoanDuration;
    uint64 public maxLoanDuration;
    bool public protocolPaused;


    mapping(address => UserBalance) public userBalances;
    mapping(address => mapping(uint256 => LoanInfo)) public userLoans;
    mapping(address => uint256) public userLoanCount;
    mapping(address => bool) public authorizedLenders;


    event Deposit(address indexed user, uint128 amount, uint64 timestamp);
    event Withdraw(address indexed user, uint128 amount, uint64 timestamp);
    event LoanCreated(address indexed borrower, uint256 indexed loanId, uint128 amount, uint16 interestRate, uint64 duration);
    event LoanRepaid(address indexed borrower, uint256 indexed loanId, uint128 totalAmount);
    event InterestRateUpdated(uint16 oldRate, uint16 newRate);
    event ProtocolPaused(bool paused);


    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier notPaused() {
        require(!protocolPaused, "Protocol paused");
        _;
    }

    modifier validAmount(uint128 amount) {
        require(amount > 0, "Amount must be positive");
        _;
    }

    modifier registeredUser() {
        require(userBalances[msg.sender].isRegistered, "User not registered");
        _;
    }

    constructor(
        bytes32 _protocolName,
        bytes32 _version,
        uint16 _defaultInterestRate,
        uint64 _minLoanDuration,
        uint64 _maxLoanDuration
    ) {
        owner = msg.sender;
        protocolName = _protocolName;
        version = _version;
        defaultInterestRate = _defaultInterestRate;
        minLoanDuration = _minLoanDuration;
        maxLoanDuration = _maxLoanDuration;
        protocolPaused = false;


        userBalances[msg.sender].isRegistered = true;
        authorizedLenders[msg.sender] = true;
    }


    function registerUser() external {
        require(!userBalances[msg.sender].isRegistered, "Already registered");

        userBalances[msg.sender] = UserBalance({
            deposited: 0,
            borrowed: 0,
            lastUpdateTime: uint64(block.timestamp),
            isRegistered: true
        });
    }


    function deposit() external payable notPaused validAmount(uint128(msg.value)) registeredUser {
        uint128 amount = uint128(msg.value);

        userBalances[msg.sender].deposited += amount;
        userBalances[msg.sender].lastUpdateTime = uint64(block.timestamp);
        totalSupply += amount;

        emit Deposit(msg.sender, amount, uint64(block.timestamp));
    }


    function withdraw(uint128 amount) external notPaused validAmount(amount) registeredUser {
        require(userBalances[msg.sender].deposited >= amount, "Insufficient balance");
        require(address(this).balance >= amount, "Insufficient contract balance");

        userBalances[msg.sender].deposited -= amount;
        userBalances[msg.sender].lastUpdateTime = uint64(block.timestamp);
        totalSupply -= amount;

        payable(msg.sender).transfer(amount);

        emit Withdraw(msg.sender, amount, uint64(block.timestamp));
    }


    function createLoan(
        uint128 amount,
        uint64 duration,
        uint16 customInterestRate
    ) external notPaused validAmount(amount) registeredUser {
        require(duration >= minLoanDuration && duration <= maxLoanDuration, "Invalid duration");
        require(address(this).balance >= amount, "Insufficient liquidity");
        require(userBalances[msg.sender].borrowed + amount <= userBalances[msg.sender].deposited * 2, "Exceeds borrowing limit");

        uint16 rate = customInterestRate > 0 ? customInterestRate : defaultInterestRate;
        uint256 loanId = userLoanCount[msg.sender];


        uint128 interest = uint128((uint256(amount) * rate * duration) / (365 days * INTEREST_RATE_PRECISION));

        userLoans[msg.sender][loanId] = LoanInfo({
            principal: amount,
            interest: interest,
            startTime: uint64(block.timestamp),
            duration: duration,
            interestRate: rate,
            isActive: true,
            isRepaid: false
        });

        userLoanCount[msg.sender]++;
        userBalances[msg.sender].borrowed += amount;
        userBalances[msg.sender].lastUpdateTime = uint64(block.timestamp);
        totalBorrowed += amount;

        payable(msg.sender).transfer(amount);

        emit LoanCreated(msg.sender, loanId, amount, rate, duration);
    }


    function repayLoan(uint256 loanId) external payable notPaused registeredUser {
        LoanInfo storage loan = userLoans[msg.sender][loanId];
        require(loan.isActive && !loan.isRepaid, "Invalid loan");

        uint128 totalAmount = loan.principal + loan.interest;
        require(msg.value >= totalAmount, "Insufficient repayment amount");

        loan.isActive = false;
        loan.isRepaid = true;

        userBalances[msg.sender].borrowed -= loan.principal;
        userBalances[msg.sender].lastUpdateTime = uint64(block.timestamp);
        totalBorrowed -= loan.principal;


        if (msg.value > totalAmount) {
            payable(msg.sender).transfer(msg.value - totalAmount);
        }

        emit LoanRepaid(msg.sender, loanId, totalAmount);
    }


    function getLoanInfo(address borrower, uint256 loanId) external view returns (
        uint128 principal,
        uint128 interest,
        uint64 startTime,
        uint64 duration,
        uint16 interestRate,
        bool isActive,
        bool isRepaid
    ) {
        LoanInfo memory loan = userLoans[borrower][loanId];
        return (
            loan.principal,
            loan.interest,
            loan.startTime,
            loan.duration,
            loan.interestRate,
            loan.isActive,
            loan.isRepaid
        );
    }


    function isLoanOverdue(address borrower, uint256 loanId) external view returns (bool) {
        LoanInfo memory loan = userLoans[borrower][loanId];
        if (!loan.isActive || loan.isRepaid) {
            return false;
        }
        return block.timestamp > loan.startTime + loan.duration;
    }


    function setInterestRate(uint16 newRate) external onlyOwner {
        require(newRate <= 5000, "Rate too high");
        uint16 oldRate = defaultInterestRate;
        defaultInterestRate = newRate;
        emit InterestRateUpdated(oldRate, newRate);
    }

    function pauseProtocol(bool paused) external onlyOwner {
        protocolPaused = paused;
        emit ProtocolPaused(paused);
    }

    function setLoanDurationLimits(uint64 minDuration, uint64 maxDuration) external onlyOwner {
        require(minDuration < maxDuration, "Invalid duration limits");
        minLoanDuration = minDuration;
        maxLoanDuration = maxDuration;
    }

    function authorizeLender(address lender, bool authorized) external onlyOwner {
        authorizedLenders[lender] = authorized;
    }


    function emergencyWithdraw(uint128 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");
        payable(owner).transfer(amount);
    }


    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }


    function getUserInfo(address user) external view returns (
        uint128 deposited,
        uint128 borrowed,
        uint64 lastUpdateTime,
        bool isRegistered,
        uint256 loanCount
    ) {
        UserBalance memory balance = userBalances[user];
        return (
            balance.deposited,
            balance.borrowed,
            balance.lastUpdateTime,
            balance.isRegistered,
            userLoanCount[user]
        );
    }
}
