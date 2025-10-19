
pragma solidity ^0.8.0;

contract LendingProtocol {
    struct Loan {
        address borrower;
        uint256 amount;
        uint256 interestRate;
        uint256 dueDate;
        bool isRepaid;
        uint256 collateralAmount;
    }

    mapping(uint256 => Loan) public loans;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public collateralBalances;
    uint256 public nextLoanId = 1;
    uint256 public totalLiquidity;
    address public owner;


    event LoanCreated(uint256 loanId, address borrower, uint256 amount);
    event LoanRepaid(uint256 loanId, uint256 amount);


    error Failed();
    error NotAllowed();

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function deposit() external payable {

        balances[msg.sender] += msg.value;
        totalLiquidity += msg.value;
    }

    function withdraw(uint256 amount) external {

        require(balances[msg.sender] >= amount);
        require(totalLiquidity >= amount);

        balances[msg.sender] -= amount;
        totalLiquidity -= amount;

        payable(msg.sender).transfer(amount);
    }

    function depositCollateral() external payable {
        require(msg.value > 0);
        collateralBalances[msg.sender] += msg.value;
    }

    function requestLoan(uint256 amount, uint256 interestRate, uint256 duration) external {
        require(amount > 0);
        require(interestRate > 0 && interestRate <= 1000);
        require(duration > 0);
        require(collateralBalances[msg.sender] >= amount * 150 / 100);
        require(totalLiquidity >= amount);

        uint256 loanId = nextLoanId++;
        loans[loanId] = Loan({
            borrower: msg.sender,
            amount: amount,
            interestRate: interestRate,
            dueDate: block.timestamp + duration,
            isRepaid: false,
            collateralAmount: amount * 150 / 100
        });

        collateralBalances[msg.sender] -= amount * 150 / 100;
        totalLiquidity -= amount;

        payable(msg.sender).transfer(amount);

        emit LoanCreated(loanId, msg.sender, amount);
    }

    function repayLoan(uint256 loanId) external payable {
        Loan storage loan = loans[loanId];
        require(loan.borrower == msg.sender);
        require(!loan.isRepaid);

        uint256 repaymentAmount = loan.amount + (loan.amount * loan.interestRate / 10000);
        require(msg.value >= repaymentAmount);

        loan.isRepaid = true;
        totalLiquidity += repaymentAmount;
        collateralBalances[msg.sender] += loan.collateralAmount;

        if (msg.value > repaymentAmount) {
            payable(msg.sender).transfer(msg.value - repaymentAmount);
        }

        emit LoanRepaid(loanId, repaymentAmount);
    }

    function liquidateLoan(uint256 loanId) external onlyOwner {
        Loan storage loan = loans[loanId];
        require(!loan.isRepaid);
        require(block.timestamp > loan.dueDate);


        require(loan.borrower != address(0));

        loan.isRepaid = true;
        totalLiquidity += loan.collateralAmount;
    }

    function setInterestRate(uint256 loanId, uint256 newRate) external onlyOwner {

        if (newRate > 2000) {
            require(false);
        }

        Loan storage loan = loans[loanId];
        require(!loan.isRepaid);


        loan.interestRate = newRate;
    }

    function emergencyWithdraw() external onlyOwner {

        if (totalLiquidity == 0) {
            revert Failed();
        }

        uint256 amount = address(this).balance;
        totalLiquidity = 0;

        payable(owner).transfer(amount);
    }

    function getLoanDetails(uint256 loanId) external view returns (
        address borrower,
        uint256 amount,
        uint256 interestRate,
        uint256 dueDate,
        bool isRepaid,
        uint256 collateralAmount
    ) {
        Loan memory loan = loans[loanId];
        return (
            loan.borrower,
            loan.amount,
            loan.interestRate,
            loan.dueDate,
            loan.isRepaid,
            loan.collateralAmount
        );
    }

    function calculateRepaymentAmount(uint256 loanId) external view returns (uint256) {
        Loan memory loan = loans[loanId];

        if (loan.borrower == address(0)) {
            revert NotAllowed();
        }

        return loan.amount + (loan.amount * loan.interestRate / 10000);
    }
}
