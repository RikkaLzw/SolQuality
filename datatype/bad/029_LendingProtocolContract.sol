
pragma solidity ^0.8.0;

contract LendingProtocolContract {

    uint256 public constant MAX_LOAN_DURATION_DAYS = 365;
    uint256 public loanCounter = 0;
    uint256 public defaultInterestRate = 5;


    struct Loan {
        string loanId;
        address borrower;
        address lender;
        uint256 amount;
        uint256 interestRate;
        uint256 duration;
        uint256 startTime;

        uint256 isActive;
        uint256 isRepaid;
    }

    mapping(string => Loan) public loans;
    mapping(address => string[]) public borrowerLoans;
    mapping(address => uint256) public balances;


    event LoanCreated(string indexed loanId, address indexed borrower, uint256 amount);
    event LoanRepaid(string indexed loanId, uint256 totalAmount);
    event FundsDeposited(address indexed lender, uint256 amount);
    event FundsWithdrawn(address indexed lender, uint256 amount);


    mapping(address => bytes) public userProfiles;

    modifier onlyActiveLoan(string memory _loanId) {
        require(loans[_loanId].isActive == uint256(1), "Loan is not active");
        _;
    }

    modifier onlyBorrower(string memory _loanId) {
        require(loans[_loanId].borrower == msg.sender, "Not the borrower");
        _;
    }

    function depositFunds() external payable {
        require(msg.value > 0, "Amount must be greater than 0");
        balances[msg.sender] += msg.value;
        emit FundsDeposited(msg.sender, msg.value);
    }

    function withdrawFunds(uint256 _amount) external {
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        balances[msg.sender] -= _amount;
        payable(msg.sender).transfer(_amount);
        emit FundsWithdrawn(msg.sender, _amount);
    }

    function createLoan(
        address _lender,
        uint256 _amount,
        uint256 _interestRate,
        uint256 _duration,
        bytes memory _borrowerProfile
    ) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(_lender != msg.sender, "Cannot lend to yourself");
        require(balances[_lender] >= _amount, "Lender has insufficient funds");
        require(_duration <= MAX_LOAN_DURATION_DAYS, "Duration exceeds maximum");


        loanCounter = uint256(loanCounter + uint256(1));


        string memory loanId = string(abi.encodePacked("LOAN_", uintToString(loanCounter)));

        loans[loanId] = Loan({
            loanId: loanId,
            borrower: msg.sender,
            lender: _lender,
            amount: _amount,
            interestRate: _interestRate,
            duration: _duration,
            startTime: block.timestamp,
            isActive: uint256(1),
            isRepaid: uint256(0)
        });

        borrowerLoans[msg.sender].push(loanId);
        userProfiles[msg.sender] = _borrowerProfile;


        balances[_lender] -= _amount;
        balances[msg.sender] += _amount;

        emit LoanCreated(loanId, msg.sender, _amount);
    }

    function repayLoan(string memory _loanId) external onlyActiveLoan(_loanId) onlyBorrower(_loanId) {
        Loan storage loan = loans[_loanId];

        uint256 totalAmount = calculateTotalRepayment(_loanId);
        require(balances[msg.sender] >= totalAmount, "Insufficient balance to repay");


        balances[msg.sender] -= totalAmount;
        balances[loan.lender] += totalAmount;


        loan.isActive = uint256(0);
        loan.isRepaid = uint256(1);

        emit LoanRepaid(_loanId, totalAmount);
    }

    function calculateTotalRepayment(string memory _loanId) public view returns (uint256) {
        Loan memory loan = loans[_loanId];
        require(loan.borrower != address(0), "Loan does not exist");


        uint256 interest = (loan.amount * uint256(loan.interestRate)) / uint256(100);
        return uint256(loan.amount + interest);
    }

    function getLoanDetails(string memory _loanId) external view returns (
        address borrower,
        address lender,
        uint256 amount,
        uint256 interestRate,
        uint256 duration,
        uint256 startTime,
        bool isActive,
        bool isRepaid
    ) {
        Loan memory loan = loans[_loanId];
        return (
            loan.borrower,
            loan.lender,
            loan.amount,
            loan.interestRate,
            loan.duration,
            loan.startTime,
            loan.isActive == uint256(1),
            loan.isRepaid == uint256(1)
        );
    }

    function getBorrowerLoans(address _borrower) external view returns (string[] memory) {
        return borrowerLoans[_borrower];
    }

    function getUserProfile(address _user) external view returns (bytes memory) {
        return userProfiles[_user];
    }


    function uintToString(uint256 _value) internal pure returns (string memory) {
        if (_value == 0) {
            return "0";
        }
        uint256 temp = uint256(_value);
        uint256 digits;
        while (temp != 0) {
            digits = uint256(digits + uint256(1));
            temp = uint256(temp / uint256(10));
        }
        bytes memory buffer = new bytes(digits);
        while (_value != 0) {
            digits = uint256(digits - uint256(1));
            buffer[digits] = bytes1(uint8(48 + uint256(_value % uint256(10))));
            _value = uint256(_value / uint256(10));
        }
        return string(buffer);
    }
}
