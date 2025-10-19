
pragma solidity ^0.8.0;

contract PointsSystemContract {
    address owner;
    mapping(address => uint256) userPoints;
    mapping(address => bool) userRegistered;
    mapping(address => uint256) userLevel;
    mapping(address => uint256) userLastActivity;
    mapping(address => uint256) userTotalEarned;
    mapping(address => uint256) userTotalSpent;
    mapping(uint256 => string) levelNames;
    mapping(uint256 => uint256) levelRequirements;
    mapping(address => bool) adminUsers;
    mapping(address => uint256) userReferralCount;
    mapping(address => address) userReferrer;
    mapping(address => uint256) userReferralRewards;

    uint256 totalUsers;
    uint256 totalPointsIssued;
    uint256 totalPointsSpent;
    bool systemActive;

    event PointsEarned(address user, uint256 amount, string reason);
    event PointsSpent(address user, uint256 amount, string item);
    event UserRegistered(address user);
    event LevelUp(address user, uint256 newLevel);
    event ReferralReward(address referrer, address referee, uint256 reward);

    constructor() {
        owner = msg.sender;
        systemActive = true;
        totalUsers = 0;
        totalPointsIssued = 0;
        totalPointsSpent = 0;


        levelNames[1] = "Bronze";
        levelNames[2] = "Silver";
        levelNames[3] = "Gold";
        levelNames[4] = "Platinum";
        levelNames[5] = "Diamond";

        levelRequirements[1] = 0;
        levelRequirements[2] = 1000;
        levelRequirements[3] = 5000;
        levelRequirements[4] = 15000;
        levelRequirements[5] = 50000;

        adminUsers[owner] = true;
    }

    function registerUser() public {

        if (msg.sender != owner && !adminUsers[msg.sender]) {
            require(systemActive == true, "System is not active");
        }

        require(!userRegistered[msg.sender], "User already registered");

        userRegistered[msg.sender] = true;
        userPoints[msg.sender] = 100;
        userLevel[msg.sender] = 1;
        userLastActivity[msg.sender] = block.timestamp;
        userTotalEarned[msg.sender] = 100;
        totalUsers++;
        totalPointsIssued += 100;

        emit UserRegistered(msg.sender);
        emit PointsEarned(msg.sender, 100, "Registration bonus");
    }

    function registerUserWithReferral(address referrer) public {

        if (msg.sender != owner && !adminUsers[msg.sender]) {
            require(systemActive == true, "System is not active");
        }

        require(!userRegistered[msg.sender], "User already registered");
        require(userRegistered[referrer], "Referrer not registered");
        require(referrer != msg.sender, "Cannot refer yourself");

        userRegistered[msg.sender] = true;
        userPoints[msg.sender] = 100;
        userLevel[msg.sender] = 1;
        userLastActivity[msg.sender] = block.timestamp;
        userTotalEarned[msg.sender] = 100;
        userReferrer[msg.sender] = referrer;


        userReferralCount[referrer]++;
        userReferralRewards[referrer] += 50;
        userPoints[referrer] += 50;
        userTotalEarned[referrer] += 50;

        totalUsers++;
        totalPointsIssued += 150;

        emit UserRegistered(msg.sender);
        emit PointsEarned(msg.sender, 100, "Registration bonus");
        emit ReferralReward(referrer, msg.sender, 50);
    }

    function earnPointsDaily() public {

        require(userRegistered[msg.sender], "User not registered");
        require(systemActive == true, "System is not active");

        require(block.timestamp >= userLastActivity[msg.sender] + 86400, "Daily reward already claimed");

        uint256 dailyReward = 10;


        if (userLevel[msg.sender] == 2) {
            dailyReward = dailyReward + 5;
        } else if (userLevel[msg.sender] == 3) {
            dailyReward = dailyReward + 10;
        } else if (userLevel[msg.sender] == 4) {
            dailyReward = dailyReward + 20;
        } else if (userLevel[msg.sender] == 5) {
            dailyReward = dailyReward + 50;
        }

        userPoints[msg.sender] += dailyReward;
        userTotalEarned[msg.sender] += dailyReward;
        userLastActivity[msg.sender] = block.timestamp;
        totalPointsIssued += dailyReward;


        uint256 currentLevel = userLevel[msg.sender];
        if (currentLevel < 5) {
            if (userTotalEarned[msg.sender] >= levelRequirements[currentLevel + 1]) {
                userLevel[msg.sender] = currentLevel + 1;
                emit LevelUp(msg.sender, currentLevel + 1);
            }
        }

        emit PointsEarned(msg.sender, dailyReward, "Daily reward");
    }

    function earnPointsTask(string memory taskName) public {

        require(userRegistered[msg.sender], "User not registered");
        require(systemActive == true, "System is not active");

        uint256 taskReward = 25;


        if (userLevel[msg.sender] == 2) {
            taskReward = taskReward + 5;
        } else if (userLevel[msg.sender] == 3) {
            taskReward = taskReward + 10;
        } else if (userLevel[msg.sender] == 4) {
            taskReward = taskReward + 20;
        } else if (userLevel[msg.sender] == 5) {
            taskReward = taskReward + 50;
        }

        userPoints[msg.sender] += taskReward;
        userTotalEarned[msg.sender] += taskReward;
        userLastActivity[msg.sender] = block.timestamp;
        totalPointsIssued += taskReward;


        uint256 currentLevel = userLevel[msg.sender];
        if (currentLevel < 5) {
            if (userTotalEarned[msg.sender] >= levelRequirements[currentLevel + 1]) {
                userLevel[msg.sender] = currentLevel + 1;
                emit LevelUp(msg.sender, currentLevel + 1);
            }
        }

        emit PointsEarned(msg.sender, taskReward, taskName);
    }

    function spendPointsItem1() public {

        require(userRegistered[msg.sender], "User not registered");
        require(systemActive == true, "System is not active");

        uint256 itemCost = 500;
        require(userPoints[msg.sender] >= itemCost, "Insufficient points");

        userPoints[msg.sender] -= itemCost;
        userTotalSpent[msg.sender] += itemCost;
        totalPointsSpent += itemCost;

        emit PointsSpent(msg.sender, itemCost, "Premium Item 1");
    }

    function spendPointsItem2() public {

        require(userRegistered[msg.sender], "User not registered");
        require(systemActive == true, "System is not active");

        uint256 itemCost = 1000;
        require(userPoints[msg.sender] >= itemCost, "Insufficient points");

        userPoints[msg.sender] -= itemCost;
        userTotalSpent[msg.sender] += itemCost;
        totalPointsSpent += itemCost;

        emit PointsSpent(msg.sender, itemCost, "Premium Item 2");
    }

    function spendPointsItem3() public {

        require(userRegistered[msg.sender], "User not registered");
        require(systemActive == true, "System is not active");

        uint256 itemCost = 2000;
        require(userPoints[msg.sender] >= itemCost, "Insufficient points");

        userPoints[msg.sender] -= itemCost;
        userTotalSpent[msg.sender] += itemCost;
        totalPointsSpent += itemCost;

        emit PointsSpent(msg.sender, itemCost, "Premium Item 3");
    }

    function adminAddPoints(address user, uint256 amount) public {

        if (msg.sender != owner && !adminUsers[msg.sender]) {
            revert("Not authorized");
        }

        require(userRegistered[user], "User not registered");

        userPoints[user] += amount;
        userTotalEarned[user] += amount;
        totalPointsIssued += amount;


        uint256 currentLevel = userLevel[user];
        if (currentLevel < 5) {
            if (userTotalEarned[user] >= levelRequirements[currentLevel + 1]) {
                userLevel[user] = currentLevel + 1;
                emit LevelUp(user, currentLevel + 1);
            }
        }

        emit PointsEarned(user, amount, "Admin reward");
    }

    function adminRemovePoints(address user, uint256 amount) public {

        if (msg.sender != owner && !adminUsers[msg.sender]) {
            revert("Not authorized");
        }

        require(userRegistered[user], "User not registered");
        require(userPoints[user] >= amount, "Insufficient points");

        userPoints[user] -= amount;
        userTotalSpent[user] += amount;
        totalPointsSpent += amount;

        emit PointsSpent(user, amount, "Admin deduction");
    }

    function addAdmin(address newAdmin) public {

        if (msg.sender != owner) {
            revert("Only owner can add admins");
        }

        adminUsers[newAdmin] = true;
    }

    function removeAdmin(address admin) public {

        if (msg.sender != owner) {
            revert("Only owner can remove admins");
        }

        adminUsers[admin] = false;
    }

    function toggleSystem() public {

        if (msg.sender != owner && !adminUsers[msg.sender]) {
            revert("Not authorized");
        }

        systemActive = !systemActive;
    }

    function getUserPoints(address user) public view returns (uint256) {
        return userPoints[user];
    }

    function getUserLevel(address user) public view returns (uint256) {
        return userLevel[user];
    }

    function getUserTotalEarned(address user) public view returns (uint256) {
        return userTotalEarned[user];
    }

    function getUserTotalSpent(address user) public view returns (uint256) {
        return userTotalSpent[user];
    }

    function getUserReferralCount(address user) public view returns (uint256) {
        return userReferralCount[user];
    }

    function getUserReferralRewards(address user) public view returns (uint256) {
        return userReferralRewards[user];
    }

    function isUserRegistered(address user) public view returns (bool) {
        return userRegistered[user];
    }

    function getSystemStats() public view returns (uint256, uint256, uint256, bool) {
        return (totalUsers, totalPointsIssued, totalPointsSpent, systemActive);
    }

    function getLevelName(uint256 level) public view returns (string memory) {
        return levelNames[level];
    }

    function getLevelRequirement(uint256 level) public view returns (uint256) {
        return levelRequirements[level];
    }

    function isAdmin(address user) public view returns (bool) {
        return adminUsers[user];
    }

    function getOwner() public view returns (address) {
        return owner;
    }
}
