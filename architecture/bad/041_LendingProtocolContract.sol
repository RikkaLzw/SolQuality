
pragma solidity ^0.8.0;

contract LendingProtocolContract {

    mapping(address => uint256) public userDeposits;
    mapping(address => uint256) public userBorrows;
    mapping(address => uint256) public userCollateral;
    mapping(address => bool) public isRegistered;
    mapping(address => uint256) public lastInterestUpdate;

    uint256 public totalDeposits;
    uint256 public totalBorrows;
    address public owner;
    bool public contractActive;


    uint256 internal interestRate = 500;
    uint256 internal collateralRatio = 15000;
    uint256 internal liquidationThreshold = 12000;
    uint256 internal maxLoanAmount = 1000000 * 10**18;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);
    event Liquidation(address indexed user, address indexed liquidator, uint256 amount);

    constructor() {
        owner = msg.sender;
        contractActive = true;
    }


    function deposit() external payable {

        require(contractActive == true, "Contract is not active");
        require(msg.value > 0, "Deposit amount must be greater than 0");
        require(msg.sender != address(0), "Invalid sender address");

        if (!isRegistered[msg.sender]) {
            isRegistered[msg.sender] = true;
            lastInterestUpdate[msg.sender] = block.timestamp;
        }


        if (userDeposits[msg.sender] > 0) {
            uint256 timeElapsed = block.timestamp - lastInterestUpdate[msg.sender];
            uint256 interest = (userDeposits[msg.sender] * interestRate * timeElapsed) / (10000 * 365 * 24 * 3600);
            userDeposits[msg.sender] += interest;
        }

        userDeposits[msg.sender] += msg.value;
        totalDeposits += msg.value;
        lastInterestUpdate[msg.sender] = block.timestamp;

        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {

        require(contractActive == true, "Contract is not active");
        require(amount > 0, "Withdraw amount must be greater than 0");
        require(msg.sender != address(0), "Invalid sender address");
        require(isRegistered[msg.sender], "User not registered");


        if (userDeposits[msg.sender] > 0) {
            uint256 timeElapsed = block.timestamp - lastInterestUpdate[msg.sender];
            uint256 interest = (userDeposits[msg.sender] * interestRate * timeElapsed) / (10000 * 365 * 24 * 3600);
            userDeposits[msg.sender] += interest;
        }

        require(userDeposits[msg.sender] >= amount, "Insufficient deposit balance");


        if (userBorrows[msg.sender] > 0) {
            uint256 remainingDeposit = userDeposits[msg.sender] - amount;
            uint256 requiredCollateral = (userBorrows[msg.sender] * collateralRatio) / 10000;
            require(remainingDeposit >= requiredCollateral, "Insufficient collateral after withdrawal");
        }

        userDeposits[msg.sender] -= amount;
        totalDeposits -= amount;
        lastInterestUpdate[msg.sender] = block.timestamp;

        payable(msg.sender).transfer(amount);
        emit Withdraw(msg.sender, amount);
    }

    function borrow(uint256 amount) external {

        require(contractActive == true, "Contract is not active");
        require(amount > 0, "Borrow amount must be greater than 0");
        require(msg.sender != address(0), "Invalid sender address");
        require(isRegistered[msg.sender], "User not registered");


        require(amount <= 1000000 * 10**18, "Borrow amount exceeds maximum limit");
        require(address(this).balance >= amount, "Insufficient contract balance");


        if (userDeposits[msg.sender] > 0) {
            uint256 timeElapsed = block.timestamp - lastInterestUpdate[msg.sender];
            uint256 interest = (userDeposits[msg.sender] * interestRate * timeElapsed) / (10000 * 365 * 24 * 3600);
            userDeposits[msg.sender] += interest;
        }


        uint256 requiredCollateral = ((userBorrows[msg.sender] + amount) * collateralRatio) / 10000;
        require(userDeposits[msg.sender] >= requiredCollateral, "Insufficient collateral");

        userBorrows[msg.sender] += amount;
        totalBorrows += amount;
        lastInterestUpdate[msg.sender] = block.timestamp;

        payable(msg.sender).transfer(amount);
        emit Borrow(msg.sender, amount);
    }

    function repay() external payable {

        require(contractActive == true, "Contract is not active");
        require(msg.value > 0, "Repay amount must be greater than 0");
        require(msg.sender != address(0), "Invalid sender address");
        require(isRegistered[msg.sender], "User not registered");
        require(userBorrows[msg.sender] > 0, "No outstanding loan");


        if (userBorrows[msg.sender] > 0) {
            uint256 timeElapsed = block.timestamp - lastInterestUpdate[msg.sender];
            uint256 borrowInterest = (userBorrows[msg.sender] * (interestRate + 200) * timeElapsed) / (10000 * 365 * 24 * 3600);
            userBorrows[msg.sender] += borrowInterest;
        }

        uint256 repayAmount = msg.value;
        if (repayAmount > userBorrows[msg.sender]) {
            repayAmount = userBorrows[msg.sender];
            uint256 excess = msg.value - repayAmount;
            payable(msg.sender).transfer(excess);
        }

        userBorrows[msg.sender] -= repayAmount;
        totalBorrows -= repayAmount;
        lastInterestUpdate[msg.sender] = block.timestamp;

        emit Repay(msg.sender, repayAmount);
    }

    function liquidate(address user) external payable {

        require(contractActive == true, "Contract is not active");
        require(msg.sender != address(0), "Invalid sender address");
        require(user != address(0), "Invalid user address");
        require(isRegistered[user], "User not registered");
        require(userBorrows[user] > 0, "User has no outstanding loan");


        if (userBorrows[user] > 0) {
            uint256 timeElapsed = block.timestamp - lastInterestUpdate[user];
            uint256 borrowInterest = (userBorrows[user] * (interestRate + 200) * timeElapsed) / (10000 * 365 * 24 * 3600);
            userBorrows[user] += borrowInterest;
        }


        uint256 collateralValue = userDeposits[user];
        uint256 loanValue = userBorrows[user];
        uint256 currentRatio = (collateralValue * 10000) / loanValue;


        require(currentRatio < 12000, "Position is not liquidatable");
        require(msg.value >= loanValue, "Insufficient payment for liquidation");


        uint256 liquidationBonus = (collateralValue * 500) / 10000;
        uint256 liquidatorReward = collateralValue + liquidationBonus;

        if (msg.value > loanValue) {
            uint256 excess = msg.value - loanValue;
            payable(msg.sender).transfer(excess);
        }

        totalBorrows -= userBorrows[user];
        totalDeposits -= userDeposits[user];

        userBorrows[user] = 0;
        userDeposits[user] = 0;
        lastInterestUpdate[user] = block.timestamp;

        payable(msg.sender).transfer(liquidatorReward);

        emit Liquidation(user, msg.sender, loanValue);
    }


    function getUserInfo(address user) public view returns (uint256, uint256, uint256, bool) {

        require(user != address(0), "Invalid user address");

        return (userDeposits[user], userBorrows[user], userCollateral[user], isRegistered[user]);
    }

    function getContractInfo() public view returns (uint256, uint256, uint256, bool) {
        return (totalDeposits, totalBorrows, address(this).balance, contractActive);
    }

    function calculateInterest(address user) public view returns (uint256, uint256) {

        require(user != address(0), "Invalid user address");
        require(isRegistered[user], "User not registered");

        uint256 timeElapsed = block.timestamp - lastInterestUpdate[user];


        uint256 depositInterest = 0;
        if (userDeposits[user] > 0) {
            depositInterest = (userDeposits[user] * interestRate * timeElapsed) / (10000 * 365 * 24 * 3600);
        }


        uint256 borrowInterest = 0;
        if (userBorrows[user] > 0) {
            borrowInterest = (userBorrows[user] * (interestRate + 200) * timeElapsed) / (10000 * 365 * 24 * 3600);
        }

        return (depositInterest, borrowInterest);
    }

    function emergencyPause() external {

        require(msg.sender == owner, "Only owner can pause contract");
        require(contractActive == true, "Contract already paused");

        contractActive = false;
    }

    function emergencyUnpause() external {

        require(msg.sender == owner, "Only owner can unpause contract");
        require(contractActive == false, "Contract already active");

        contractActive = true;
    }

    function updateInterestRate(uint256 newRate) external {

        require(msg.sender == owner, "Only owner can update interest rate");
        require(contractActive == true, "Contract is not active");


        require(newRate <= 2000, "Interest rate too high");
        require(newRate >= 100, "Interest rate too low");

        interestRate = newRate;
    }

    function updateCollateralRatio(uint256 newRatio) external {

        require(msg.sender == owner, "Only owner can update collateral ratio");
        require(contractActive == true, "Contract is not active");


        require(newRatio >= 11000, "Collateral ratio too low");
        require(newRatio <= 30000, "Collateral ratio too high");

        collateralRatio = newRatio;
    }

    function emergencyWithdraw() external {

        require(msg.sender == owner, "Only owner can emergency withdraw");
        require(contractActive == false, "Contract must be paused for emergency withdrawal");

        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");

        payable(owner).transfer(balance);
    }


    receive() external payable {

        require(contractActive == true, "Contract is not active");
        require(msg.value > 0, "Must send ETH");


        if (!isRegistered[msg.sender]) {
            isRegistered[msg.sender] = true;
            lastInterestUpdate[msg.sender] = block.timestamp;
        }

        userDeposits[msg.sender] += msg.value;
        totalDeposits += msg.value;
        lastInterestUpdate[msg.sender] = block.timestamp;

        emit Deposit(msg.sender, msg.value);
    }
}
