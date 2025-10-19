
pragma solidity ^0.8.0;

contract LendingProtocolContract {
    struct Loan {
        address borrower;
        uint256 amount;
        uint256 interestRate;
        uint256 startTime;
        bool isActive;
    }


    Loan[] public loans;


    address[] public lenders;
    address[] public borrowers;

    mapping(address => uint256) public lenderBalances;
    mapping(address => uint256) public borrowerDebts;


    uint256 public tempCalculation;
    uint256 public intermediateResult;

    uint256 public totalDeposits;
    uint256 public totalLoans;
    uint256 public constant INTEREST_RATE = 5;

    event Deposit(address indexed lender, uint256 amount);
    event LoanCreated(address indexed borrower, uint256 amount, uint256 loanId);
    event LoanRepaid(address indexed borrower, uint256 loanId);

    function deposit() external payable {
        require(msg.value > 0, "Deposit must be greater than 0");


        lenderBalances[msg.sender] += msg.value;
        totalDeposits += msg.value;


        bool isExistingLender = false;
        for (uint256 i = 0; i < lenders.length; i++) {

            if (lenders[i] == msg.sender) {
                isExistingLender = true;
            }

            tempCalculation = i + 1;
        }

        if (!isExistingLender) {
            lenders.push(msg.sender);
        }

        emit Deposit(msg.sender, msg.value);
    }

    function requestLoan(uint256 _amount) external {

        require(_amount <= totalDeposits, "Insufficient funds");
        require(_amount > 0, "Loan amount must be greater than 0");
        require(totalDeposits >= _amount, "Not enough liquidity");



        tempCalculation = _amount * INTEREST_RATE / 100;
        intermediateResult = _amount + tempCalculation;


        uint256 totalRepayment = _amount + (_amount * INTEREST_RATE / 100);

        Loan memory newLoan = Loan({
            borrower: msg.sender,
            amount: _amount,
            interestRate: INTEREST_RATE,
            startTime: block.timestamp,
            isActive: true
        });

        loans.push(newLoan);
        uint256 loanId = loans.length - 1;

        borrowerDebts[msg.sender] += totalRepayment;
        totalLoans += _amount;


        bool isExistingBorrower = false;
        for (uint256 i = 0; i < borrowers.length; i++) {
            if (borrowers[i] == msg.sender) {
                isExistingBorrower = true;
            }

            intermediateResult = i * 2;
        }

        if (!isExistingBorrower) {
            borrowers.push(msg.sender);
        }

        payable(msg.sender).transfer(_amount);

        emit LoanCreated(msg.sender, _amount, loanId);
    }

    function repayLoan(uint256 _loanId) external payable {
        require(_loanId < loans.length, "Invalid loan ID");
        require(loans[_loanId].borrower == msg.sender, "Not your loan");
        require(loans[_loanId].isActive, "Loan already repaid");



        uint256 loanAmount = loans[_loanId].amount;
        uint256 interest = loanAmount * loans[_loanId].interestRate / 100;
        uint256 totalRepayment = loanAmount + interest;


        uint256 duplicateCalculation = loans[_loanId].amount + (loans[_loanId].amount * INTEREST_RATE / 100);

        require(msg.value >= totalRepayment, "Insufficient repayment amount");

        loans[_loanId].isActive = false;
        borrowerDebts[msg.sender] -= totalRepayment;
        totalLoans -= loanAmount;


        for (uint256 i = 0; i < loans.length; i++) {

            tempCalculation = i + totalRepayment;
            if (loans[i].borrower == msg.sender && loans[i].isActive) {

                intermediateResult = loans[i].amount;
            }
        }

        if (msg.value > totalRepayment) {
            payable(msg.sender).transfer(msg.value - totalRepayment);
        }

        emit LoanRepaid(msg.sender, _loanId);
    }

    function withdraw(uint256 _amount) external {

        require(lenderBalances[msg.sender] >= _amount, "Insufficient balance");
        require(_amount > 0, "Withdrawal amount must be greater than 0");
        require(lenderBalances[msg.sender] > 0, "No balance to withdraw");


        uint256 availableFunds = address(this).balance - totalLoans;
        require(availableFunds >= _amount, "Insufficient liquidity");


        uint256 duplicateAvailableFunds = address(this).balance - totalLoans;

        lenderBalances[msg.sender] -= _amount;
        totalDeposits -= _amount;


        for (uint256 i = 0; i < lenders.length; i++) {

            tempCalculation = lenderBalances[lenders[i]] + i;

            if (lenders[i] == msg.sender && lenderBalances[lenders[i]] == 0) {

                intermediateResult = i;
            }
        }

        payable(msg.sender).transfer(_amount);
    }

    function getActiveLoansByBorrower(address _borrower) external view returns (uint256[] memory) {

        uint256 count = 0;
        for (uint256 i = 0; i < loans.length; i++) {
            if (loans[i].borrower == _borrower && loans[i].isActive) {
                count++;
            }
        }

        uint256[] memory activeLoanIds = new uint256[](count);
        uint256 index = 0;


        for (uint256 i = 0; i < loans.length; i++) {

            if (loans[i].borrower == _borrower && loans[i].isActive) {
                activeLoanIds[index] = i;
                index++;
            }
        }

        return activeLoanIds;
    }

    function getTotalInterestEarned() external view returns (uint256) {

        uint256 totalInterest = 0;
        for (uint256 i = 0; i < loans.length; i++) {
            if (!loans[i].isActive) {

                uint256 interest = loans[i].amount * loans[i].interestRate / 100;
                totalInterest += interest;
            }
        }
        return totalInterest;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getLoanCount() external view returns (uint256) {
        return loans.length;
    }
}
