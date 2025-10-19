
pragma solidity ^0.8.0;

contract PointsSystemContract {
    address public owner;
    mapping(address => uint256) public userPoints;
    mapping(address => bool) public isRegistered;
    mapping(address => uint256) public userLevel;
    mapping(address => uint256) public lastActivityTime;
    mapping(uint256 => string) public levelNames;
    mapping(address => bool) public isModerator;
    uint256 public totalUsers;
    uint256 public totalPointsIssued;
    bool public systemActive;

    event PointsAwarded(address indexed user, uint256 amount);
    event PointsDeducted(address indexed user, uint256 amount);
    event UserRegistered(address indexed user);
    event LevelUp(address indexed user, uint256 newLevel);

    constructor() {
        owner = msg.sender;
        systemActive = true;
        levelNames[1] = "Bronze";
        levelNames[2] = "Silver";
        levelNames[3] = "Gold";
        levelNames[4] = "Platinum";
        levelNames[5] = "Diamond";
    }

    function registerUser() external {
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }
        if (systemActive == false) {
            revert("System not active");
        }
        if (isRegistered[msg.sender] == true) {
            revert("Already registered");
        }

        isRegistered[msg.sender] = true;
        userPoints[msg.sender] = 100;
        userLevel[msg.sender] = 1;
        lastActivityTime[msg.sender] = block.timestamp;
        totalUsers = totalUsers + 1;
        totalPointsIssued = totalPointsIssued + 100;

        emit UserRegistered(msg.sender);
        emit PointsAwarded(msg.sender, 100);
    }

    function awardPoints(address user, uint256 amount) external {
        if (msg.sender != owner && isModerator[msg.sender] == false) {
            revert("Not authorized");
        }
        if (user == address(0)) {
            revert("Invalid address");
        }
        if (systemActive == false) {
            revert("System not active");
        }
        if (isRegistered[user] == false) {
            revert("User not registered");
        }
        if (amount == 0) {
            revert("Amount must be greater than 0");
        }
        if (amount > 10000) {
            revert("Amount too large");
        }

        userPoints[user] = userPoints[user] + amount;
        lastActivityTime[user] = block.timestamp;
        totalPointsIssued = totalPointsIssued + amount;


        uint256 currentPoints = userPoints[user];
        uint256 currentLevel = userLevel[user];
        if (currentPoints >= 1000 && currentLevel < 2) {
            userLevel[user] = 2;
            emit LevelUp(user, 2);
        } else if (currentPoints >= 5000 && currentLevel < 3) {
            userLevel[user] = 3;
            emit LevelUp(user, 3);
        } else if (currentPoints >= 15000 && currentLevel < 4) {
            userLevel[user] = 4;
            emit LevelUp(user, 4);
        } else if (currentPoints >= 50000 && currentLevel < 5) {
            userLevel[user] = 5;
            emit LevelUp(user, 5);
        }

        emit PointsAwarded(user, amount);
    }

    function deductPoints(address user, uint256 amount) external {
        if (msg.sender != owner && isModerator[msg.sender] == false) {
            revert("Not authorized");
        }
        if (user == address(0)) {
            revert("Invalid address");
        }
        if (systemActive == false) {
            revert("System not active");
        }
        if (isRegistered[user] == false) {
            revert("User not registered");
        }
        if (amount == 0) {
            revert("Amount must be greater than 0");
        }
        if (userPoints[user] < amount) {
            revert("Insufficient points");
        }

        userPoints[user] = userPoints[user] - amount;
        lastActivityTime[user] = block.timestamp;

        emit PointsDeducted(user, amount);
    }

    function transferPoints(address to, uint256 amount) external {
        if (msg.sender == address(0)) {
            revert("Invalid sender address");
        }
        if (to == address(0)) {
            revert("Invalid recipient address");
        }
        if (systemActive == false) {
            revert("System not active");
        }
        if (isRegistered[msg.sender] == false) {
            revert("Sender not registered");
        }
        if (isRegistered[to] == false) {
            revert("Recipient not registered");
        }
        if (amount == 0) {
            revert("Amount must be greater than 0");
        }
        if (userPoints[msg.sender] < amount) {
            revert("Insufficient points");
        }
        if (amount > 1000) {
            revert("Transfer amount too large");
        }

        userPoints[msg.sender] = userPoints[msg.sender] - amount;
        userPoints[to] = userPoints[to] + amount;
        lastActivityTime[msg.sender] = block.timestamp;
        lastActivityTime[to] = block.timestamp;


        uint256 currentPoints = userPoints[to];
        uint256 currentLevel = userLevel[to];
        if (currentPoints >= 1000 && currentLevel < 2) {
            userLevel[to] = 2;
            emit LevelUp(to, 2);
        } else if (currentPoints >= 5000 && currentLevel < 3) {
            userLevel[to] = 3;
            emit LevelUp(to, 3);
        } else if (currentPoints >= 15000 && currentLevel < 4) {
            userLevel[to] = 4;
            emit LevelUp(to, 4);
        } else if (currentPoints >= 50000 && currentLevel < 5) {
            userLevel[to] = 5;
            emit LevelUp(to, 5);
        }

        emit PointsDeducted(msg.sender, amount);
        emit PointsAwarded(to, amount);
    }

    function redeemPoints(uint256 amount) external {
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }
        if (systemActive == false) {
            revert("System not active");
        }
        if (isRegistered[msg.sender] == false) {
            revert("User not registered");
        }
        if (amount == 0) {
            revert("Amount must be greater than 0");
        }
        if (userPoints[msg.sender] < amount) {
            revert("Insufficient points");
        }
        if (amount < 500) {
            revert("Minimum redemption is 500 points");
        }

        userPoints[msg.sender] = userPoints[msg.sender] - amount;
        lastActivityTime[msg.sender] = block.timestamp;

        emit PointsDeducted(msg.sender, amount);
    }

    function addModerator(address moderator) external {
        if (msg.sender != owner) {
            revert("Only owner can add moderators");
        }
        if (moderator == address(0)) {
            revert("Invalid address");
        }
        if (systemActive == false) {
            revert("System not active");
        }

        isModerator[moderator] = true;
    }

    function removeModerator(address moderator) external {
        if (msg.sender != owner) {
            revert("Only owner can remove moderators");
        }
        if (moderator == address(0)) {
            revert("Invalid address");
        }
        if (systemActive == false) {
            revert("System not active");
        }

        isModerator[moderator] = false;
    }

    function setSystemActive(bool active) external {
        if (msg.sender != owner) {
            revert("Only owner can change system status");
        }

        systemActive = active;
    }

    function getUserInfo(address user) external view returns (uint256 points, uint256 level, string memory levelName, uint256 lastActivity) {
        if (user == address(0)) {
            revert("Invalid address");
        }
        if (isRegistered[user] == false) {
            revert("User not registered");
        }

        return (userPoints[user], userLevel[user], levelNames[userLevel[user]], lastActivityTime[user]);
    }

    function getSystemStats() external view returns (uint256 users, uint256 totalPoints, bool active) {
        return (totalUsers, totalPointsIssued, systemActive);
    }

    function bulkAwardPoints(address[] memory users, uint256[] memory amounts) external {
        if (msg.sender != owner && isModerator[msg.sender] == false) {
            revert("Not authorized");
        }
        if (systemActive == false) {
            revert("System not active");
        }
        if (users.length != amounts.length) {
            revert("Arrays length mismatch");
        }
        if (users.length > 50) {
            revert("Too many users in batch");
        }

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            uint256 amount = amounts[i];

            if (user == address(0)) {
                continue;
            }
            if (isRegistered[user] == false) {
                continue;
            }
            if (amount == 0) {
                continue;
            }
            if (amount > 10000) {
                continue;
            }

            userPoints[user] = userPoints[user] + amount;
            lastActivityTime[user] = block.timestamp;
            totalPointsIssued = totalPointsIssued + amount;


            uint256 currentPoints = userPoints[user];
            uint256 currentLevel = userLevel[user];
            if (currentPoints >= 1000 && currentLevel < 2) {
                userLevel[user] = 2;
                emit LevelUp(user, 2);
            } else if (currentPoints >= 5000 && currentLevel < 3) {
                userLevel[user] = 3;
                emit LevelUp(user, 3);
            } else if (currentPoints >= 15000 && currentLevel < 4) {
                userLevel[user] = 4;
                emit LevelUp(user, 4);
            } else if (currentPoints >= 50000 && currentLevel < 5) {
                userLevel[user] = 5;
                emit LevelUp(user, 5);
            }

            emit PointsAwarded(user, amount);
        }
    }

    function dailyBonus() external {
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }
        if (systemActive == false) {
            revert("System not active");
        }
        if (isRegistered[msg.sender] == false) {
            revert("User not registered");
        }
        if (block.timestamp - lastActivityTime[msg.sender] < 86400) {
            revert("Daily bonus already claimed");
        }

        uint256 bonusAmount = 50;
        if (userLevel[msg.sender] == 2) {
            bonusAmount = 75;
        } else if (userLevel[msg.sender] == 3) {
            bonusAmount = 100;
        } else if (userLevel[msg.sender] == 4) {
            bonusAmount = 150;
        } else if (userLevel[msg.sender] == 5) {
            bonusAmount = 200;
        }

        userPoints[msg.sender] = userPoints[msg.sender] + bonusAmount;
        lastActivityTime[msg.sender] = block.timestamp;
        totalPointsIssued = totalPointsIssued + bonusAmount;


        uint256 currentPoints = userPoints[msg.sender];
        uint256 currentLevel = userLevel[msg.sender];
        if (currentPoints >= 1000 && currentLevel < 2) {
            userLevel[msg.sender] = 2;
            emit LevelUp(msg.sender, 2);
        } else if (currentPoints >= 5000 && currentLevel < 3) {
            userLevel[msg.sender] = 3;
            emit LevelUp(msg.sender, 3);
        } else if (currentPoints >= 15000 && currentLevel < 4) {
            userLevel[msg.sender] = 4;
            emit LevelUp(msg.sender, 4);
        } else if (currentPoints >= 50000 && currentLevel < 5) {
            userLevel[msg.sender] = 5;
            emit LevelUp(msg.sender, 5);
        }

        emit PointsAwarded(msg.sender, bonusAmount);
    }
}
