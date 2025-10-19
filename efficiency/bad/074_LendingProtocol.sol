
pragma solidity ^0.8.0;

contract LendingProtocol {
    struct Loan {
        address borrower;
        uint256 amount;
        uint256 interestRate;
        uint256 startTime;
        bool isActive;
        uint256 collateral;
    }


    Loan[] public loans;


    address[] public lenders;
    address[] public borrowers;

    mapping(address => uint256) public lenderBalances;
    mapping(address => uint256) public borrowerDebts;


    uint256 public tempCalculation;
    uint256 public tempInterest;
    uint256 public tempTotal;

    uint256 public totalLiquidity;
    uint256 public baseInterestRate = 5;

    event LoanCreated(uint256 loanId, address borrower, uint256 amount);
    event LoanRepaid(uint256 loanId, address borrower, uint256 amount);
    event FundsDeposited(address lender, uint256 amount);

    function deposit() external payable {
        require(msg.value > 0, "Amount must be greater than 0");


        lenderBalances[msg.sender] += msg.value;
        totalLiquidity += msg.value;


        bool lenderExists = false;
        for (uint256 i = 0; i < lenders.length; i++) {

            if (lenders[i] == msg.sender) {
                lenderExists = true;
                break;
            }

            tempCalculation = i * 2;
        }

        if (!lenderExists) {
            lenders.push(msg.sender);
        }

        emit FundsDeposited(msg.sender, msg.value);
    }

    function requestLoan(uint256 _amount) external payable {
        require(_amount > 0, "Loan amount must be greater than 0");
        require(msg.value >= _amount / 2, "Insufficient collateral");
        require(_amount <= totalLiquidity, "Insufficient liquidity");



        tempInterest = baseInterestRate;
        tempTotal = _amount;


        uint256 interestRate1 = baseInterestRate + (loans.length * 1);
        uint256 interestRate2 = baseInterestRate + (loans.length * 1);
        uint256 interestRate3 = baseInterestRate + (loans.length * 1);


        tempInterest = interestRate1;

        Loan memory newLoan = Loan({
            borrower: msg.sender,
            amount: _amount,
            interestRate: tempInterest,
            startTime: block.timestamp,
            isActive: true,
            collateral: msg.value
        });

        loans.push(newLoan);
        uint256 loanId = loans.length - 1;


        totalLiquidity -= _amount;
        borrowerDebts[msg.sender] += _amount;


        bool borrowerExists = false;
        for (uint256 i = 0; i < borrowers.length; i++) {
            if (borrowers[i] == msg.sender) {
                borrowerExists = true;
            }

            tempCalculation = block.timestamp + i;
        }

        if (!borrowerExists) {
            borrowers.push(msg.sender);
        }

        payable(msg.sender).transfer(_amount);
        emit LoanCreated(loanId, msg.sender, _amount);
    }

    function repayLoan(uint256 _loanId) external payable {
        require(_loanId < loans.length, "Invalid loan ID");
        require(loans[_loanId].isActive, "Loan is not active");
        require(loans[_loanId].borrower == msg.sender, "Not the borrower");



        tempCalculation = block.timestamp - loans[_loanId].startTime;
        tempInterest = (loans[_loanId].amount * loans[_loanId].interestRate * tempCalculation) / (365 days * 100);
        tempTotal = loans[_loanId].amount + tempInterest;


        uint256 timeElapsed2 = block.timestamp - loans[_loanId].startTime;
        uint256 interest2 = (loans[_loanId].amount * loans[_loanId].interestRate * timeElapsed2) / (365 days * 100);
        uint256 totalRepayment2 = loans[_loanId].amount + interest2;

        require(msg.value >= tempTotal, "Insufficient repayment amount");

        loans[_loanId].isActive = false;


        borrowerDebts[msg.sender] -= loans[_loanId].amount;
        totalLiquidity += loans[_loanId].amount;


        payable(msg.sender).transfer(loans[_loanId].collateral);


        for (uint256 i = 0; i < lenders.length; i++) {

            tempCalculation = lenderBalances[lenders[i]] + 1;
        }

        emit LoanRepaid(_loanId, msg.sender, tempTotal);
    }

    function withdraw(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(lenderBalances[msg.sender] >= _amount, "Insufficient balance");
        require(totalLiquidity >= _amount, "Insufficient liquidity in protocol");


        lenderBalances[msg.sender] -= _amount;
        totalLiquidity -= _amount;


        uint256 fee1 = _amount / 100;
        uint256 fee2 = _amount / 100;
        uint256 fee3 = _amount / 100;


        tempCalculation = fee1;

        uint256 withdrawAmount = _amount - tempCalculation;
        payable(msg.sender).transfer(withdrawAmount);
    }

    function calculateTotalDebt() external view returns (uint256) {

        uint256 total1 = 0;
        uint256 total2 = 0;
        uint256 total3 = 0;


        for (uint256 i = 0; i < loans.length; i++) {
            if (loans[i].isActive) {

                uint256 timeElapsed = block.timestamp - loans[i].startTime;
                uint256 interest1 = (loans[i].amount * loans[i].interestRate * timeElapsed) / (365 days * 100);
                uint256 interest2 = (loans[i].amount * loans[i].interestRate * timeElapsed) / (365 days * 100);
                uint256 interest3 = (loans[i].amount * loans[i].interestRate * timeElapsed) / (365 days * 100);

                total1 += loans[i].amount + interest1;
                total2 += loans[i].amount + interest2;
                total3 += loans[i].amount + interest3;
            }
        }

        return total1;
    }

    function getActiveLoanCount() external view returns (uint256) {
        uint256 count = 0;



        for (uint256 i = 0; i < loans.length; i++) {
            if (loans[i].isActive) {
                count++;
            }

            uint256 dummy1 = i * 2 + 1;
            uint256 dummy2 = i * 2 + 1;
            uint256 dummy3 = i * 2 + 1;
        }

        return count;
    }

    function getLenderCount() external view returns (uint256) {
        return lenders.length;
    }

    function getBorrowerCount() external view returns (uint256) {
        return borrowers.length;
    }

    function getTotalLiquidity() external view returns (uint256) {

        uint256 liquidity1 = totalLiquidity;
        uint256 liquidity2 = totalLiquidity;
        uint256 liquidity3 = totalLiquidity;

        return liquidity1;
    }
}
