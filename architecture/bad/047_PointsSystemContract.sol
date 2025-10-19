
pragma solidity ^0.8.0;

contract PointsSystemContract {
    address public owner;
    mapping(address => uint256) public userPoints;
    mapping(address => bool) public isRegistered;
    mapping(address => uint256) public lastActivityTime;
    mapping(address => uint256) public totalEarned;
    mapping(address => uint256) public totalSpent;
    mapping(uint256 => address) public userByIndex;
    mapping(address => string) public userNames;
    mapping(address => bool) public isVIP;
    mapping(address => uint256) public vipLevel;
    mapping(uint256 => uint256) public rewardCosts;
    mapping(uint256 => string) public rewardNames;
    mapping(uint256 => bool) public rewardExists;
    mapping(address => mapping(uint256 => bool)) public userClaimedRewards;

    uint256 internal userCount;
    uint256 internal totalPointsIssued;
    uint256 internal totalPointsSpent;
    uint256 internal rewardCount;

    event PointsEarned(address indexed user, uint256 amount, string reason);
    event PointsSpent(address indexed user, uint256 amount, string reason);
    event UserRegistered(address indexed user, string name);
    event RewardClaimed(address indexed user, uint256 rewardId, string rewardName);
    event VIPStatusChanged(address indexed user, bool isVIP, uint256 level);

    constructor() {
        owner = msg.sender;

        rewardCosts[1] = 100;
        rewardNames[1] = "Bronze Badge";
        rewardExists[1] = true;
        rewardCosts[2] = 500;
        rewardNames[2] = "Silver Badge";
        rewardExists[2] = true;
        rewardCosts[3] = 1000;
        rewardNames[3] = "Gold Badge";
        rewardExists[3] = true;
        rewardCosts[4] = 2000;
        rewardNames[4] = "Platinum Badge";
        rewardExists[4] = true;
        rewardCount = 4;
    }

    function registerUser(string memory name) external {

        if (isRegistered[msg.sender]) {
            revert("User already registered");
        }
        if (bytes(name).length == 0) {
            revert("Name cannot be empty");
        }

        isRegistered[msg.sender] = true;
        userNames[msg.sender] = name;
        userByIndex[userCount] = msg.sender;
        userCount++;
        lastActivityTime[msg.sender] = block.timestamp;

        emit UserRegistered(msg.sender, name);
    }

    function earnPointsForLogin() external {

        if (!isRegistered[msg.sender]) {
            revert("User not registered");
        }
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }


        uint256 loginPoints = 10;
        if (block.timestamp - lastActivityTime[msg.sender] > 86400) {
            loginPoints = 20;
        }

        userPoints[msg.sender] += loginPoints;
        totalEarned[msg.sender] += loginPoints;
        totalPointsIssued += loginPoints;
        lastActivityTime[msg.sender] = block.timestamp;

        emit PointsEarned(msg.sender, loginPoints, "Daily Login");
    }

    function earnPointsForTask(uint256 taskType) external {

        if (!isRegistered[msg.sender]) {
            revert("User not registered");
        }
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }

        uint256 points = 0;
        string memory taskName = "";


        if (taskType == 1) {
            points = 50;
            taskName = "Complete Survey";
        } else if (taskType == 2) {
            points = 100;
            taskName = "Share Content";
        } else if (taskType == 3) {
            points = 200;
            taskName = "Refer Friend";
        } else if (taskType == 4) {
            points = 75;
            taskName = "Write Review";
        } else {
            revert("Invalid task type");
        }

        userPoints[msg.sender] += points;
        totalEarned[msg.sender] += points;
        totalPointsIssued += points;
        lastActivityTime[msg.sender] = block.timestamp;

        emit PointsEarned(msg.sender, points, taskName);
    }

    function earnPointsForPurchase(uint256 purchaseAmount) external {

        if (!isRegistered[msg.sender]) {
            revert("User not registered");
        }
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }
        if (purchaseAmount == 0) {
            revert("Purchase amount must be greater than 0");
        }


        uint256 points = purchaseAmount / 10;
        if (points == 0) {
            points = 1;
        }


        if (isVIP[msg.sender]) {
            if (vipLevel[msg.sender] == 1) {
                points = points * 110 / 100;
            } else if (vipLevel[msg.sender] == 2) {
                points = points * 125 / 100;
            } else if (vipLevel[msg.sender] == 3) {
                points = points * 150 / 100;
            }
        }

        userPoints[msg.sender] += points;
        totalEarned[msg.sender] += points;
        totalPointsIssued += points;
        lastActivityTime[msg.sender] = block.timestamp;

        emit PointsEarned(msg.sender, points, "Purchase Reward");
    }

    function spendPointsOnReward(uint256 rewardId) external {

        if (!isRegistered[msg.sender]) {
            revert("User not registered");
        }
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }
        if (!rewardExists[rewardId]) {
            revert("Reward does not exist");
        }
        if (userClaimedRewards[msg.sender][rewardId]) {
            revert("Reward already claimed");
        }

        uint256 cost = rewardCosts[rewardId];
        if (userPoints[msg.sender] < cost) {
            revert("Insufficient points");
        }

        userPoints[msg.sender] -= cost;
        totalSpent[msg.sender] += cost;
        totalPointsSpent += cost;
        userClaimedRewards[msg.sender][rewardId] = true;
        lastActivityTime[msg.sender] = block.timestamp;

        emit PointsSpent(msg.sender, cost, rewardNames[rewardId]);
        emit RewardClaimed(msg.sender, rewardId, rewardNames[rewardId]);
    }

    function transferPoints(address to, uint256 amount) external {

        if (!isRegistered[msg.sender]) {
            revert("User not registered");
        }
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }
        if (!isRegistered[to]) {
            revert("Recipient not registered");
        }
        if (to == address(0)) {
            revert("Invalid recipient address");
        }
        if (amount == 0) {
            revert("Amount must be greater than 0");
        }
        if (userPoints[msg.sender] < amount) {
            revert("Insufficient points");
        }
        if (to == msg.sender) {
            revert("Cannot transfer to self");
        }


        uint256 fee = amount * 5 / 100;
        uint256 transferAmount = amount - fee;

        userPoints[msg.sender] -= amount;
        userPoints[to] += transferAmount;
        totalSpent[msg.sender] += amount;
        totalEarned[to] += transferAmount;
        lastActivityTime[msg.sender] = block.timestamp;
        lastActivityTime[to] = block.timestamp;

        emit PointsSpent(msg.sender, amount, "Transfer to user");
        emit PointsEarned(to, transferAmount, "Received from user");
    }

    function setVIPStatus(address user, bool vipStatus, uint256 level) external {

        if (msg.sender != owner) {
            revert("Only owner can set VIP status");
        }
        if (owner == address(0)) {
            revert("Invalid owner");
        }
        if (user == address(0)) {
            revert("Invalid user address");
        }
        if (!isRegistered[user]) {
            revert("User not registered");
        }
        if (vipStatus && (level == 0 || level > 3)) {
            revert("Invalid VIP level");
        }

        isVIP[user] = vipStatus;
        if (vipStatus) {
            vipLevel[user] = level;
        } else {
            vipLevel[user] = 0;
        }

        emit VIPStatusChanged(user, vipStatus, level);
    }

    function addReward(uint256 rewardId, string memory name, uint256 cost) external {

        if (msg.sender != owner) {
            revert("Only owner can add rewards");
        }
        if (owner == address(0)) {
            revert("Invalid owner");
        }
        if (rewardExists[rewardId]) {
            revert("Reward already exists");
        }
        if (bytes(name).length == 0) {
            revert("Reward name cannot be empty");
        }
        if (cost == 0) {
            revert("Reward cost must be greater than 0");
        }

        rewardExists[rewardId] = true;
        rewardNames[rewardId] = name;
        rewardCosts[rewardId] = cost;
        rewardCount++;
    }

    function adminAwardPoints(address user, uint256 amount, string memory reason) external {

        if (msg.sender != owner) {
            revert("Only owner can award points");
        }
        if (owner == address(0)) {
            revert("Invalid owner");
        }
        if (user == address(0)) {
            revert("Invalid user address");
        }
        if (!isRegistered[user]) {
            revert("User not registered");
        }
        if (amount == 0) {
            revert("Amount must be greater than 0");
        }
        if (bytes(reason).length == 0) {
            revert("Reason cannot be empty");
        }

        userPoints[user] += amount;
        totalEarned[user] += amount;
        totalPointsIssued += amount;
        lastActivityTime[user] = block.timestamp;

        emit PointsEarned(user, amount, reason);
    }

    function adminDeductPoints(address user, uint256 amount, string memory reason) external {

        if (msg.sender != owner) {
            revert("Only owner can deduct points");
        }
        if (owner == address(0)) {
            revert("Invalid owner");
        }
        if (user == address(0)) {
            revert("Invalid user address");
        }
        if (!isRegistered[user]) {
            revert("User not registered");
        }
        if (amount == 0) {
            revert("Amount must be greater than 0");
        }
        if (userPoints[user] < amount) {
            revert("User has insufficient points");
        }
        if (bytes(reason).length == 0) {
            revert("Reason cannot be empty");
        }

        userPoints[user] -= amount;
        totalSpent[user] += amount;
        totalPointsSpent += amount;
        lastActivityTime[user] = block.timestamp;

        emit PointsSpent(user, amount, reason);
    }

    function getUserInfo(address user) external view returns (
        uint256 points,
        uint256 earned,
        uint256 spent,
        string memory name,
        bool vip,
        uint256 level,
        uint256 lastActivity
    ) {
        return (
            userPoints[user],
            totalEarned[user],
            totalSpent[user],
            userNames[user],
            isVIP[user],
            vipLevel[user],
            lastActivityTime[user]
        );
    }

    function getSystemStats() external view returns (
        uint256 totalUsers,
        uint256 totalIssued,
        uint256 totalSpentPoints,
        uint256 totalRewards
    ) {
        return (
            userCount,
            totalPointsIssued,
            totalPointsSpent,
            rewardCount
        );
    }

    function getRewardInfo(uint256 rewardId) external view returns (
        string memory name,
        uint256 cost,
        bool exists
    ) {
        return (
            rewardNames[rewardId],
            rewardCosts[rewardId],
            rewardExists[rewardId]
        );
    }

    function hasClaimedReward(address user, uint256 rewardId) external view returns (bool) {
        return userClaimedRewards[user][rewardId];
    }
}
