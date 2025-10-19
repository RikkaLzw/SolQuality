
pragma solidity ^0.8.0;

contract LendingProtocolContract {

    uint256 public constant INTEREST_RATE = 5;
    uint256 public constant MAX_LOAN_DURATION = 30;
    uint256 public loanCounter = 0;


    struct Loan {
        string loanId;
        address borrower;
        address lender;
        uint256 amount;
        uint256 interestRate;
        uint256 duration;
        uint256 startTime;
        uint256 repaidAmount;

        uint256 isActive;
        uint256 isRepaid;
    }


    mapping(bytes => Loan) public loans;
    mapping(address => bytes[]) public borrowerLoans;
    mapping(address => uint256) public lenderBalances;

    event LoanCreated(bytes loanId, address borrower, address lender, uint256 amount);
    event LoanRepaid(bytes loanId, uint256 amount);
    event FundsDeposited(address lender, uint256 amount);
    event FundsWithdrawn(address lender, uint256 amount);

    modifier onlyActiveLoan(bytes memory _loanId) {
        require(loans[_loanId].isActive == 1, "Loan is not active");
        _;
    }

    modifier onlyBorrower(bytes memory _loanId) {
        require(loans[_loanId].borrower == msg.sender, "Only borrower can call this");
        _;
    }

    function depositFunds() external payable {
        require(msg.value > 0, "Amount must be greater than 0");
        lenderBalances[msg.sender] += msg.value;
        emit FundsDeposited(msg.sender, msg.value);
    }

    function withdrawFunds(uint256 _amount) external {
        require(lenderBalances[msg.sender] >= _amount, "Insufficient balance");
        lenderBalances[msg.sender] -= _amount;
        payable(msg.sender).transfer(_amount);
        emit FundsWithdrawn(msg.sender, _amount);
    }

    function createLoan(
        address _borrower,
        uint256 _amount,
        uint256 _duration
    ) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(_duration > 0 && _duration <= MAX_LOAN_DURATION, "Invalid duration");
        require(lenderBalances[msg.sender] >= _amount, "Insufficient lender balance");


        loanCounter = uint256(uint128(uint64(uint32(loanCounter + 1))));


        string memory loanIdStr = string(abi.encodePacked("LOAN_", uintToString(loanCounter)));
        bytes memory loanId = bytes(loanIdStr);

        loans[loanId] = Loan({
            loanId: loanIdStr,
            borrower: _borrower,
            lender: msg.sender,
            amount: _amount,
            interestRate: INTEREST_RATE,
            duration: _duration,
            startTime: block.timestamp,
            repaidAmount: 0,
            isActive: 1,
            isRepaid: 0
        });

        borrowerLoans[_borrower].push(loanId);
        lenderBalances[msg.sender] -= _amount;

        payable(_borrower).transfer(_amount);

        emit LoanCreated(loanId, _borrower, msg.sender, _amount);
    }

    function repayLoan(bytes memory _loanId) external payable onlyActiveLoan(_loanId) onlyBorrower(_loanId) {
        Loan storage loan = loans[_loanId];

        uint256 totalOwed = calculateTotalOwed(_loanId);
        require(msg.value >= totalOwed, "Insufficient repayment amount");

        loan.repaidAmount = msg.value;
        loan.isActive = 0;
        loan.isRepaid = 1;

        lenderBalances[loan.lender] += msg.value;


        if (msg.value > totalOwed) {
            payable(msg.sender).transfer(msg.value - totalOwed);
        }

        emit LoanRepaid(_loanId, msg.value);
    }

    function calculateTotalOwed(bytes memory _loanId) public view returns (uint256) {
        Loan memory loan = loans[_loanId];
        require(loan.isActive == 1, "Loan is not active");


        uint256 timeElapsed = uint256(uint128(block.timestamp - loan.startTime));
        uint256 daysElapsed = uint256(uint64(timeElapsed / 1 days));

        uint256 interest = (loan.amount * loan.interestRate * daysElapsed) / (100 * 365);
        return loan.amount + interest;
    }

    function getLoanDetails(bytes memory _loanId) external view returns (
        string memory loanId,
        address borrower,
        address lender,
        uint256 amount,
        uint256 interestRate,
        uint256 duration,
        uint256 startTime,
        uint256 repaidAmount,
        uint256 isActive,
        uint256 isRepaid
    ) {
        Loan memory loan = loans[_loanId];
        return (
            loan.loanId,
            loan.borrower,
            loan.lender,
            loan.amount,
            loan.interestRate,
            loan.duration,
            loan.startTime,
            loan.repaidAmount,
            loan.isActive,
            loan.isRepaid
        );
    }

    function getBorrowerLoans(address _borrower) external view returns (bytes[] memory) {
        return borrowerLoans[_borrower];
    }

    function getLenderBalance(address _lender) external view returns (uint256) {
        return lenderBalances[_lender];
    }


    function uintToString(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}
