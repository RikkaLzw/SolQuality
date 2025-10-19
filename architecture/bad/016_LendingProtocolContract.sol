
pragma solidity ^0.8.0;

contract LendingProtocolContract {

    mapping(address => uint256) public userDeposits;
    mapping(address => uint256) public userBorrows;
    mapping(address => uint256) public userCollateral;
    mapping(address => bool) public isRegistered;
    mapping(address => uint256) public lastInterestUpdate;

    uint256 public totalDeposits;
    uint256 public totalBorrows;
    uint256 public totalCollateral;

    address public owner;
    bool public paused;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);

    constructor() {
        owner = msg.sender;
        paused = false;
    }


    function deposit(uint256 amount) external payable {

        require(!paused, "Contract is paused");
        require(msg.sender != address(0), "Invalid address");
        require(amount > 0, "Amount must be greater than 0");


        require(amount >= 1000000000000000, "Minimum deposit is 0.001 ETH");
        require(msg.value == amount, "ETH value mismatch");

        if (!isRegistered[msg.sender]) {
            isRegistered[msg.sender] = true;
        }


        if (lastInterestUpdate[msg.sender] > 0) {
            uint256 timeElapsed = block.timestamp - lastInterestUpdate[msg.sender];
            uint256 interest = (userDeposits[msg.sender] * timeElapsed * 5) / (365 * 24 * 3600 * 100);
            userDeposits[msg.sender] += interest;
        }

        userDeposits[msg.sender] += amount;
        totalDeposits += amount;
        lastInterestUpdate[msg.sender] = block.timestamp;

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {

        require(!paused, "Contract is paused");
        require(msg.sender != address(0), "Invalid address");
        require(amount > 0, "Amount must be greater than 0");


        if (lastInterestUpdate[msg.sender] > 0) {
            uint256 timeElapsed = block.timestamp - lastInterestUpdate[msg.sender];
            uint256 interest = (userDeposits[msg.sender] * timeElapsed * 5) / (365 * 24 * 3600 * 100);
            userDeposits[msg.sender] += interest;
        }

        require(userDeposits[msg.sender] >= amount, "Insufficient balance");

        userDeposits[msg.sender] -= amount;
        totalDeposits -= amount;
        lastInterestUpdate[msg.sender] = block.timestamp;

        payable(msg.sender).transfer(amount);

        emit Withdraw(msg.sender, amount);
    }

    function depositCollateral() external payable {

        require(!paused, "Contract is paused");
        require(msg.sender != address(0), "Invalid address");
        require(msg.value > 0, "Amount must be greater than 0");


        require(msg.value >= 5000000000000000, "Minimum collateral is 0.005 ETH");

        if (!isRegistered[msg.sender]) {
            isRegistered[msg.sender] = true;
        }

        userCollateral[msg.sender] += msg.value;
        totalCollateral += msg.value;

        emit CollateralDeposited(msg.sender, msg.value);
    }

    function withdrawCollateral(uint256 amount) external {

        require(!paused, "Contract is paused");
        require(msg.sender != address(0), "Invalid address");
        require(amount > 0, "Amount must be greater than 0");

        require(userCollateral[msg.sender] >= amount, "Insufficient collateral");


        uint256 remainingCollateral = userCollateral[msg.sender] - amount;
        uint256 requiredCollateral = (userBorrows[msg.sender] * 150) / 100;
        require(remainingCollateral >= requiredCollateral, "Insufficient collateral ratio");

        userCollateral[msg.sender] -= amount;
        totalCollateral -= amount;

        payable(msg.sender).transfer(amount);

        emit CollateralWithdrawn(msg.sender, amount);
    }

    function borrow(uint256 amount) external {

        require(!paused, "Contract is paused");
        require(msg.sender != address(0), "Invalid address");
        require(amount > 0, "Amount must be greater than 0");

        require(isRegistered[msg.sender], "User not registered");


        require(amount >= 500000000000000, "Minimum borrow is 0.0005 ETH");
        require(amount <= 10000000000000000000, "Maximum borrow is 10 ETH");


        uint256 newBorrowAmount = userBorrows[msg.sender] + amount;
        uint256 requiredCollateral = (newBorrowAmount * 150) / 100;
        require(userCollateral[msg.sender] >= requiredCollateral, "Insufficient collateral");

        require(address(this).balance >= amount, "Insufficient liquidity");


        if (lastInterestUpdate[msg.sender] > 0 && userBorrows[msg.sender] > 0) {
            uint256 timeElapsed = block.timestamp - lastInterestUpdate[msg.sender];
            uint256 borrowInterest = (userBorrows[msg.sender] * timeElapsed * 8) / (365 * 24 * 3600 * 100);
            userBorrows[msg.sender] += borrowInterest;
        }

        userBorrows[msg.sender] += amount;
        totalBorrows += amount;
        lastInterestUpdate[msg.sender] = block.timestamp;

        payable(msg.sender).transfer(amount);

        emit Borrow(msg.sender, amount);
    }

    function repay() external payable {

        require(!paused, "Contract is paused");
        require(msg.sender != address(0), "Invalid address");
        require(msg.value > 0, "Amount must be greater than 0");

        require(userBorrows[msg.sender] > 0, "No outstanding debt");


        if (lastInterestUpdate[msg.sender] > 0) {
            uint256 timeElapsed = block.timestamp - lastInterestUpdate[msg.sender];
            uint256 borrowInterest = (userBorrows[msg.sender] * timeElapsed * 8) / (365 * 24 * 3600 * 100);
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


    function getUserInfo(address user) public view returns (
        uint256 deposits,
        uint256 borrows,
        uint256 collateral,
        bool registered,
        uint256 lastUpdate
    ) {
        return (
            userDeposits[user],
            userBorrows[user],
            userCollateral[user],
            isRegistered[user],
            lastInterestUpdate[user]
        );
    }


    function getContractInfo() public view returns (
        uint256 totalDep,
        uint256 totalBor,
        uint256 totalCol,
        uint256 contractBalance
    ) {
        return (
            totalDeposits,
            totalBorrows,
            totalCollateral,
            address(this).balance
        );
    }

    function calculateUserHealth(address user) external view returns (uint256) {
        if (userBorrows[user] == 0) {
            return 10000;
        }


        uint256 collateralValue = userCollateral[user];
        uint256 borrowValue = userBorrows[user];


        if (lastInterestUpdate[user] > 0) {
            uint256 timeElapsed = block.timestamp - lastInterestUpdate[user];
            uint256 borrowInterest = (borrowValue * timeElapsed * 8) / (365 * 24 * 3600 * 100);
            borrowValue += borrowInterest;
        }

        return (collateralValue * 10000) / (borrowValue * 150 / 100);
    }

    function liquidate(address user) external {

        require(!paused, "Contract is paused");
        require(msg.sender != address(0), "Invalid address");
        require(user != address(0), "Invalid user address");

        require(userBorrows[user] > 0, "User has no debt");


        uint256 collateralValue = userCollateral[user];
        uint256 borrowValue = userBorrows[user];


        if (lastInterestUpdate[user] > 0) {
            uint256 timeElapsed = block.timestamp - lastInterestUpdate[user];
            uint256 borrowInterest = (borrowValue * timeElapsed * 8) / (365 * 24 * 3600 * 100);
            borrowValue += borrowInterest;
            userBorrows[user] = borrowValue;
        }

        uint256 healthFactor = (collateralValue * 10000) / (borrowValue * 150 / 100);
        require(healthFactor < 10000, "User is healthy, cannot liquidate");


        uint256 liquidationReward = (userCollateral[user] * 10) / 100;
        uint256 liquidationAmount = userCollateral[user] - liquidationReward;

        userCollateral[user] = 0;
        userBorrows[user] = 0;
        totalCollateral -= (liquidationAmount + liquidationReward);
        totalBorrows -= borrowValue;

        payable(msg.sender).transfer(liquidationReward);
    }


    function pauseContract() public {

        require(msg.sender == owner, "Only owner can pause");
        paused = true;
    }


    function unpauseContract() public {

        require(msg.sender == owner, "Only owner can unpause");
        paused = false;
    }


    function emergencyWithdraw(uint256 amount) public {

        require(msg.sender == owner, "Only owner can emergency withdraw");
        require(amount <= address(this).balance, "Insufficient balance");

        payable(owner).transfer(amount);
    }


    function updateInterestForUser(address user) public {
        require(isRegistered[user], "User not registered");


        if (lastInterestUpdate[user] > 0) {
            uint256 timeElapsed = block.timestamp - lastInterestUpdate[user];

            if (userDeposits[user] > 0) {
                uint256 depositInterest = (userDeposits[user] * timeElapsed * 5) / (365 * 24 * 3600 * 100);
                userDeposits[user] += depositInterest;
                totalDeposits += depositInterest;
            }

            if (userBorrows[user] > 0) {
                uint256 borrowInterest = (userBorrows[user] * timeElapsed * 8) / (365 * 24 * 3600 * 100);
                userBorrows[user] += borrowInterest;
                totalBorrows += borrowInterest;
            }
        }

        lastInterestUpdate[user] = block.timestamp;
    }

    receive() external payable {

    }

    fallback() external payable {

    }
}
