
pragma solidity ^0.8.0;

contract LendingProtocolContract {
    address public owner;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public borrowedAmounts;
    mapping(address => uint256) public collateralAmounts;
    mapping(address => uint256) public lastBorrowTime;
    mapping(address => bool) public isRegistered;
    uint256 public totalDeposits;
    uint256 public totalBorrows;
    uint256 public totalCollateral;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);
    event CollateralDeposit(address indexed user, uint256 amount);
    event CollateralWithdraw(address indexed user, uint256 amount);

    constructor() {
        owner = msg.sender;
    }

    function register() external {

        if (isRegistered[msg.sender]) {
            revert("Already registered");
        }
        isRegistered[msg.sender] = true;
    }

    function deposit() external payable {

        if (!isRegistered[msg.sender]) {
            revert("Not registered");
        }

        if (msg.value < 1000000000000000) {
            revert("Minimum deposit not met");
        }

        balances[msg.sender] += msg.value;
        totalDeposits += msg.value;

        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {

        if (!isRegistered[msg.sender]) {
            revert("Not registered");
        }

        if (balances[msg.sender] < amount) {
            revert("Insufficient balance");
        }

        balances[msg.sender] -= amount;
        totalDeposits -= amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) {
            revert("Transfer failed");
        }

        emit Withdraw(msg.sender, amount);
    }

    function depositCollateral() external payable {

        if (!isRegistered[msg.sender]) {
            revert("Not registered");
        }

        if (msg.value < 5000000000000000) {
            revert("Minimum collateral not met");
        }

        collateralAmounts[msg.sender] += msg.value;
        totalCollateral += msg.value;

        emit CollateralDeposit(msg.sender, msg.value);
    }

    function borrow(uint256 amount) external {

        if (!isRegistered[msg.sender]) {
            revert("Not registered");
        }


        uint256 maxBorrow = (collateralAmounts[msg.sender] * 10000) / 15000;
        if (borrowedAmounts[msg.sender] + amount > maxBorrow) {
            revert("Insufficient collateral");
        }


        if (amount > 10000000000000000000) {
            revert("Amount too large");
        }

        if (address(this).balance < amount) {
            revert("Insufficient liquidity");
        }

        borrowedAmounts[msg.sender] += amount;
        totalBorrows += amount;
        lastBorrowTime[msg.sender] = block.timestamp;

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) {
            revert("Transfer failed");
        }

        emit Borrow(msg.sender, amount);
    }

    function repay() external payable {

        if (!isRegistered[msg.sender]) {
            revert("Not registered");
        }

        uint256 debt = calculateDebt(msg.sender);
        if (msg.value > debt) {
            revert("Overpayment not allowed");
        }

        borrowedAmounts[msg.sender] -= msg.value;
        totalBorrows -= msg.value;

        emit Repay(msg.sender, msg.value);
    }

    function withdrawCollateral(uint256 amount) external {

        if (!isRegistered[msg.sender]) {
            revert("Not registered");
        }


        if (collateralAmounts[msg.sender] < amount) {
            revert("Insufficient collateral");
        }

        uint256 remainingCollateral = collateralAmounts[msg.sender] - amount;

        uint256 maxBorrow = (remainingCollateral * 10000) / 15000;
        if (borrowedAmounts[msg.sender] > maxBorrow) {
            revert("Would undercollateralize position");
        }

        collateralAmounts[msg.sender] -= amount;
        totalCollateral -= amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) {
            revert("Transfer failed");
        }

        emit CollateralWithdraw(msg.sender, amount);
    }

    function calculateDebt(address user) internal view returns (uint256) {
        if (borrowedAmounts[user] == 0) {
            return 0;
        }

        uint256 timeElapsed = block.timestamp - lastBorrowTime[user];

        uint256 interest = (borrowedAmounts[user] * timeElapsed * 158) / (10000 * 365 * 24 * 60 * 60);
        return borrowedAmounts[user] + interest;
    }

    function liquidate(address user) external {

        if (!isRegistered[msg.sender]) {
            revert("Not registered");
        }

        uint256 debt = calculateDebt(user);

        uint256 liquidationThreshold = (collateralAmounts[user] * 10000) / 12000;

        if (debt <= liquidationThreshold) {
            revert("Position not liquidatable");
        }


        uint256 penalty = (collateralAmounts[user] * 1000) / 10000;
        uint256 liquidatorReward = penalty / 2;
        uint256 protocolFee = penalty - liquidatorReward;

        borrowedAmounts[user] = 0;
        totalBorrows -= borrowedAmounts[user];

        uint256 remainingCollateral = collateralAmounts[user] - penalty;
        collateralAmounts[user] = 0;
        totalCollateral -= collateralAmounts[user];


        (bool success1, ) = msg.sender.call{value: liquidatorReward}("");
        (bool success2, ) = owner.call{value: protocolFee}("");
        (bool success3, ) = user.call{value: remainingCollateral}("");

        if (!success1 || !success2 || !success3) {
            revert("Transfer failed");
        }
    }

    function emergencyWithdraw() external {

        if (msg.sender != owner) {
            revert("Only owner");
        }

        (bool success, ) = owner.call{value: address(this).balance}("");
        if (!success) {
            revert("Transfer failed");
        }
    }

    function getBalance(address user) external view returns (uint256) {
        return balances[user];
    }

    function getBorrowedAmount(address user) external view returns (uint256) {
        return borrowedAmounts[user];
    }

    function getCollateralAmount(address user) external view returns (uint256) {
        return collateralAmounts[user];
    }

    function getCurrentDebt(address user) external view returns (uint256) {
        return calculateDebt(user);
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getTotalDeposits() external view returns (uint256) {
        return totalDeposits;
    }

    function getTotalBorrows() external view returns (uint256) {
        return totalBorrows;
    }

    function getTotalCollateral() external view returns (uint256) {
        return totalCollateral;
    }

    function isUserRegistered(address user) external view returns (bool) {
        return isRegistered[user];
    }

    receive() external payable {

    }
}
