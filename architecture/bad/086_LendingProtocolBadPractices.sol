
pragma solidity ^0.8.0;

contract LendingProtocolBadPractices {

    address public owner;
    mapping(address => uint256) public userDeposits;
    mapping(address => uint256) public userBorrows;
    mapping(address => uint256) public userCollateral;
    mapping(address => bool) public isApprovedToken;
    mapping(address => uint256) public tokenPrices;
    uint256 public totalDeposits;
    uint256 public totalBorrows;
    bool public paused;


    uint256 public interestRate = 500;
    uint256 public collateralRatio = 15000;
    uint256 public liquidationThreshold = 12000;
    uint256 public maxLoanAmount = 1000000 * 10**18;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);
    event Liquidate(address indexed liquidator, address indexed borrower, uint256 amount);

    constructor() {
        owner = msg.sender;
        paused = false;
    }


    function deposit(uint256 amount) external {

        require(!paused, "Contract is paused");
        require(amount > 0, "Amount must be greater than 0");


        userDeposits[msg.sender] += amount;
        totalDeposits += amount;


        require(msg.sender.balance >= amount, "Insufficient balance");

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {

        require(!paused, "Contract is paused");
        require(amount > 0, "Amount must be greater than 0");


        require(userDeposits[msg.sender] >= amount, "Insufficient deposits");


        uint256 availableLiquidity = totalDeposits - totalBorrows;
        require(availableLiquidity >= amount, "Insufficient liquidity");


        userDeposits[msg.sender] -= amount;
        totalDeposits -= amount;


        payable(msg.sender).transfer(amount);

        emit Withdraw(msg.sender, amount);
    }

    function borrow(uint256 amount) external {

        require(!paused, "Contract is paused");
        require(amount > 0, "Amount must be greater than 0");


        require(amount <= 1000000 * 10**18, "Amount exceeds maximum loan");


        uint256 requiredCollateral = (amount * 15000) / 10000;
        require(userCollateral[msg.sender] >= requiredCollateral, "Insufficient collateral");


        uint256 availableLiquidity = totalDeposits - totalBorrows;
        require(availableLiquidity >= amount, "Insufficient liquidity");


        uint256 interest = (amount * 500) / 10000;
        uint256 totalBorrowAmount = amount + interest;


        userBorrows[msg.sender] += totalBorrowAmount;
        totalBorrows += totalBorrowAmount;


        payable(msg.sender).transfer(amount);

        emit Borrow(msg.sender, amount);
    }

    function repay(uint256 amount) external payable {

        require(!paused, "Contract is paused");
        require(amount > 0, "Amount must be greater than 0");


        require(userBorrows[msg.sender] >= amount, "Amount exceeds borrowed amount");
        require(msg.value >= amount, "Insufficient payment");


        userBorrows[msg.sender] -= amount;
        totalBorrows -= amount;


        if (msg.value > amount) {
            payable(msg.sender).transfer(msg.value - amount);
        }

        emit Repay(msg.sender, amount);
    }

    function addCollateral() external payable {

        require(!paused, "Contract is paused");
        require(msg.value > 0, "Amount must be greater than 0");


        userCollateral[msg.sender] += msg.value;
    }

    function removeCollateral(uint256 amount) external {

        require(!paused, "Contract is paused");
        require(amount > 0, "Amount must be greater than 0");

        require(userCollateral[msg.sender] >= amount, "Insufficient collateral");


        uint256 remainingCollateral = userCollateral[msg.sender] - amount;
        uint256 requiredCollateral = (userBorrows[msg.sender] * 15000) / 10000;
        require(remainingCollateral >= requiredCollateral, "Would leave insufficient collateral");

        userCollateral[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }

    function liquidate(address borrower) external {

        require(!paused, "Contract is paused");


        uint256 collateralValue = userCollateral[borrower];
        uint256 borrowAmount = userBorrows[borrower];
        uint256 collateralRatioCheck = (collateralValue * 10000) / borrowAmount;


        require(collateralRatioCheck < 12000, "Position is healthy");


        uint256 liquidationAmount = userBorrows[borrower];
        require(msg.sender.balance >= liquidationAmount, "Insufficient balance for liquidation");


        userBorrows[borrower] = 0;
        totalBorrows -= liquidationAmount;

        uint256 collateralToTransfer = userCollateral[borrower];
        userCollateral[borrower] = 0;

        payable(msg.sender).transfer(collateralToTransfer);

        emit Liquidate(msg.sender, borrower, liquidationAmount);
    }

    function calculateInterest(address user) external view returns (uint256) {

        uint256 borrowAmount = userBorrows[user];
        uint256 interest = (borrowAmount * 500) / 10000;
        return interest;
    }

    function getCollateralRatio(address user) external view returns (uint256) {

        if (userBorrows[user] == 0) return 0;
        return (userCollateral[user] * 10000) / userBorrows[user];
    }

    function checkLiquidationEligible(address user) external view returns (bool) {

        if (userBorrows[user] == 0) return false;
        uint256 collateralRatioCheck = (userCollateral[user] * 10000) / userBorrows[user];
        return collateralRatioCheck < 12000;
    }


    function pauseContract() external {

        require(msg.sender == owner, "Only owner can pause");
        paused = true;
    }

    function unpauseContract() external {

        require(msg.sender == owner, "Only owner can unpause");
        paused = false;
    }

    function updateInterestRate(uint256 newRate) external {

        require(msg.sender == owner, "Only owner can update rate");
        require(newRate <= 2000, "Rate too high");
        interestRate = newRate;
    }

    function updateCollateralRatio(uint256 newRatio) external {

        require(msg.sender == owner, "Only owner can update ratio");
        require(newRatio >= 11000 && newRatio <= 20000, "Invalid ratio");
        collateralRatio = newRatio;
    }

    function emergencyWithdraw() external {

        require(msg.sender == owner, "Only owner can emergency withdraw");
        payable(owner).transfer(address(this).balance);
    }


    function getTotalDeposits() public view returns (uint256) {
        return totalDeposits;
    }

    function getTotalBorrows() public view returns (uint256) {
        return totalBorrows;
    }

    function getUserDeposits(address user) public view returns (uint256) {
        return userDeposits[user];
    }

    function getUserBorrows(address user) public view returns (uint256) {
        return userBorrows[user];
    }

    function getUserCollateral(address user) public view returns (uint256) {
        return userCollateral[user];
    }

    receive() external payable {

        userCollateral[msg.sender] += msg.value;
    }
}
