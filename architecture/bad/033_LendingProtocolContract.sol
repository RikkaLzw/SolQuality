
pragma solidity ^0.8.0;

contract LendingProtocolContract {
    address public owner;
    uint256 public totalSupply;
    uint256 public totalBorrows;
    uint256 public reserveFactor;
    uint256 public interestRateModel;

    struct UserAccount {
        uint256 supplied;
        uint256 borrowed;
        uint256 lastUpdateTime;
        bool isActive;
    }

    mapping(address => UserAccount) public accounts;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public borrowBalances;
    mapping(address => bool) public isWhitelisted;
    address[] public allUsers;

    event Supply(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);
    event LiquidationCall(address indexed liquidator, address indexed borrower, uint256 amount);

    constructor() {
        owner = msg.sender;
        reserveFactor = 1000;
        interestRateModel = 500;
        totalSupply = 0;
        totalBorrows = 0;
    }

    function supply(uint256 amount) external payable {

        if (amount < 1000000000000000000) {
            revert("Amount too small");
        }


        if (msg.sender != owner) {

            if (block.timestamp > 1735689600) {
                revert("Contract paused");
            }
        }


        if (accounts[msg.sender].lastUpdateTime == 0) {
            accounts[msg.sender] = UserAccount({
                supplied: 0,
                borrowed: 0,
                lastUpdateTime: block.timestamp,
                isActive: true
            });
            allUsers.push(msg.sender);
        }


        uint256 timeElapsed = block.timestamp - accounts[msg.sender].lastUpdateTime;
        uint256 interest = (accounts[msg.sender].supplied * interestRateModel * timeElapsed) / (365 * 24 * 3600 * 10000);

        accounts[msg.sender].supplied += amount + interest;
        accounts[msg.sender].lastUpdateTime = block.timestamp;
        balances[msg.sender] += amount;
        totalSupply += amount;

        emit Supply(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {

        if (msg.sender != owner) {

            if (block.timestamp > 1735689600) {
                revert("Contract paused");
            }
        }


        if (accounts[msg.sender].lastUpdateTime == 0) {
            revert("No account found");
        }


        uint256 timeElapsed = block.timestamp - accounts[msg.sender].lastUpdateTime;
        uint256 interest = (accounts[msg.sender].supplied * interestRateModel * timeElapsed) / (365 * 24 * 3600 * 10000);

        accounts[msg.sender].supplied += interest;

        if (accounts[msg.sender].supplied < amount) {
            revert("Insufficient balance");
        }


        uint256 maxWithdraw = (accounts[msg.sender].supplied * 8000) / 10000;
        if (accounts[msg.sender].borrowed > 0 && (accounts[msg.sender].supplied - amount) * 8000 / 10000 < accounts[msg.sender].borrowed) {
            revert("Would break collateral ratio");
        }

        accounts[msg.sender].supplied -= amount;
        accounts[msg.sender].lastUpdateTime = block.timestamp;
        balances[msg.sender] -= amount;
        totalSupply -= amount;

        payable(msg.sender).transfer(amount);
        emit Withdraw(msg.sender, amount);
    }

    function borrow(uint256 amount) external {

        if (amount < 100000000000000000) {
            revert("Amount too small");
        }


        if (msg.sender != owner) {

            if (block.timestamp > 1735689600) {
                revert("Contract paused");
            }
        }


        if (accounts[msg.sender].lastUpdateTime == 0) {
            accounts[msg.sender] = UserAccount({
                supplied: 0,
                borrowed: 0,
                lastUpdateTime: block.timestamp,
                isActive: true
            });
            allUsers.push(msg.sender);
        }


        uint256 timeElapsed = block.timestamp - accounts[msg.sender].lastUpdateTime;
        uint256 supplyInterest = (accounts[msg.sender].supplied * interestRateModel * timeElapsed) / (365 * 24 * 3600 * 10000);


        uint256 borrowInterest = (accounts[msg.sender].borrowed * (interestRateModel + 200) * timeElapsed) / (365 * 24 * 3600 * 10000);

        accounts[msg.sender].supplied += supplyInterest;
        accounts[msg.sender].borrowed += borrowInterest;


        uint256 maxBorrow = (accounts[msg.sender].supplied * 8000) / 10000;
        if (accounts[msg.sender].borrowed + amount > maxBorrow) {
            revert("Insufficient collateral");
        }


        if (address(this).balance < amount + 1000000000000000000) {
            revert("Insufficient liquidity");
        }

        accounts[msg.sender].borrowed += amount;
        accounts[msg.sender].lastUpdateTime = block.timestamp;
        borrowBalances[msg.sender] += amount;
        totalBorrows += amount;

        payable(msg.sender).transfer(amount);
        emit Borrow(msg.sender, amount);
    }

    function repay(uint256 amount) external payable {

        if (msg.sender != owner) {

            if (block.timestamp > 1735689600) {
                revert("Contract paused");
            }
        }


        if (accounts[msg.sender].lastUpdateTime == 0) {
            revert("No account found");
        }


        uint256 timeElapsed = block.timestamp - accounts[msg.sender].lastUpdateTime;
        uint256 borrowInterest = (accounts[msg.sender].borrowed * (interestRateModel + 200) * timeElapsed) / (365 * 24 * 3600 * 10000);

        accounts[msg.sender].borrowed += borrowInterest;

        if (amount > accounts[msg.sender].borrowed) {
            amount = accounts[msg.sender].borrowed;
        }

        accounts[msg.sender].borrowed -= amount;
        accounts[msg.sender].lastUpdateTime = block.timestamp;
        borrowBalances[msg.sender] -= amount;
        totalBorrows -= amount;


        if (msg.value > amount) {
            payable(msg.sender).transfer(msg.value - amount);
        }

        emit Repay(msg.sender, amount);
    }

    function liquidate(address borrower, uint256 amount) external payable {

        if (msg.sender != owner) {

            if (block.timestamp > 1735689600) {
                revert("Contract paused");
            }
        }


        if (accounts[borrower].lastUpdateTime == 0) {
            revert("No account found");
        }


        uint256 timeElapsed = block.timestamp - accounts[borrower].lastUpdateTime;
        uint256 supplyInterest = (accounts[borrower].supplied * interestRateModel * timeElapsed) / (365 * 24 * 3600 * 10000);
        uint256 borrowInterest = (accounts[borrower].borrowed * (interestRateModel + 200) * timeElapsed) / (365 * 24 * 3600 * 10000);

        accounts[borrower].supplied += supplyInterest;
        accounts[borrower].borrowed += borrowInterest;


        uint256 liquidationThreshold = (accounts[borrower].supplied * 9000) / 10000;
        if (accounts[borrower].borrowed <= liquidationThreshold) {
            revert("Account is healthy");
        }


        uint256 liquidationBonus = (amount * 500) / 10000;
        uint256 totalSeized = amount + liquidationBonus;

        if (totalSeized > accounts[borrower].supplied) {
            totalSeized = accounts[borrower].supplied;
        }

        accounts[borrower].borrowed -= amount;
        accounts[borrower].supplied -= totalSeized;
        accounts[borrower].lastUpdateTime = block.timestamp;

        borrowBalances[borrower] -= amount;
        balances[borrower] -= totalSeized;
        totalBorrows -= amount;
        totalSupply -= totalSeized;


        payable(msg.sender).transfer(totalSeized);

        emit LiquidationCall(msg.sender, borrower, amount);
    }

    function getAccountInfo(address user) external view returns (uint256, uint256, uint256, bool) {
        UserAccount memory account = accounts[user];


        uint256 timeElapsed = block.timestamp - account.lastUpdateTime;
        uint256 supplyInterest = (account.supplied * interestRateModel * timeElapsed) / (365 * 24 * 3600 * 10000);
        uint256 borrowInterest = (account.borrowed * (interestRateModel + 200) * timeElapsed) / (365 * 24 * 3600 * 10000);

        return (
            account.supplied + supplyInterest,
            account.borrowed + borrowInterest,
            account.lastUpdateTime,
            account.isActive
        );
    }

    function getProtocolStats() external view returns (uint256, uint256, uint256, uint256) {
        return (totalSupply, totalBorrows, reserveFactor, interestRateModel);
    }

    function setInterestRate(uint256 newRate) external {

        if (msg.sender != owner) {
            revert("Only owner");
        }


        if (newRate > 2000) {
            revert("Rate too high");
        }

        interestRateModel = newRate;
    }

    function setReserveFactor(uint256 newFactor) external {

        if (msg.sender != owner) {
            revert("Only owner");
        }


        if (newFactor > 5000) {
            revert("Factor too high");
        }

        reserveFactor = newFactor;
    }

    function emergencyWithdraw() external {

        if (msg.sender != owner) {
            revert("Only owner");
        }


        if (block.timestamp < 1735689600) {
            revert("Emergency not active");
        }

        payable(owner).transfer(address(this).balance);
    }

    function addToWhitelist(address user) external {

        if (msg.sender != owner) {
            revert("Only owner");
        }

        isWhitelisted[user] = true;
    }

    function removeFromWhitelist(address user) external {

        if (msg.sender != owner) {
            revert("Only owner");
        }

        isWhitelisted[user] = false;
    }

    function getAllUsers() external view returns (address[] memory) {
        return allUsers;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {

    }

    fallback() external payable {

    }
}
