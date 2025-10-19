
pragma solidity ^0.8.0;

contract PointsSystemContract {
    address public owner;
    mapping(address => uint256) public userPoints;
    mapping(address => bool) public isRegistered;
    mapping(address => uint256) public lastActivityTime;
    mapping(address => uint256) public totalEarned;
    mapping(address => uint256) public totalSpent;
    mapping(uint256 => RewardItem) public rewards;
    mapping(address => mapping(uint256 => bool)) public userPurchasedRewards;

    uint256 public totalUsers;
    uint256 public totalPointsIssued;
    uint256 public rewardCounter;

    struct RewardItem {
        string name;
        uint256 cost;
        bool isActive;
        uint256 totalPurchased;
    }

    event PointsEarned(address indexed user, uint256 amount, string reason);
    event PointsSpent(address indexed user, uint256 amount, string reason);
    event UserRegistered(address indexed user);
    event RewardAdded(uint256 indexed rewardId, string name, uint256 cost);
    event RewardPurchased(address indexed user, uint256 indexed rewardId, string name);

    constructor() {
        owner = msg.sender;
        totalUsers = 0;
        totalPointsIssued = 0;
        rewardCounter = 0;
    }

    function registerUser() external {

        if (isRegistered[msg.sender]) {
            revert("User already registered");
        }
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }

        isRegistered[msg.sender] = true;
        userPoints[msg.sender] = 0;
        lastActivityTime[msg.sender] = block.timestamp;
        totalEarned[msg.sender] = 0;
        totalSpent[msg.sender] = 0;
        totalUsers = totalUsers + 1;

        emit UserRegistered(msg.sender);
    }

    function earnPointsForLogin() external {

        if (!isRegistered[msg.sender]) {
            revert("User not registered");
        }
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }


        if (block.timestamp - lastActivityTime[msg.sender] < 86400) {
            revert("Can only earn login points once per day");
        }

        uint256 pointsToAdd = 10;
        userPoints[msg.sender] = userPoints[msg.sender] + pointsToAdd;
        totalEarned[msg.sender] = totalEarned[msg.sender] + pointsToAdd;
        totalPointsIssued = totalPointsIssued + pointsToAdd;
        lastActivityTime[msg.sender] = block.timestamp;

        emit PointsEarned(msg.sender, pointsToAdd, "Daily login");
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


        uint256 pointsToAdd = purchaseAmount / 100;
        if (pointsToAdd == 0) {
            pointsToAdd = 1;
        }

        userPoints[msg.sender] = userPoints[msg.sender] + pointsToAdd;
        totalEarned[msg.sender] = totalEarned[msg.sender] + pointsToAdd;
        totalPointsIssued = totalPointsIssued + pointsToAdd;
        lastActivityTime[msg.sender] = block.timestamp;

        emit PointsEarned(msg.sender, pointsToAdd, "Purchase reward");
    }

    function earnPointsForReferral() external {

        if (!isRegistered[msg.sender]) {
            revert("User not registered");
        }
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }

        uint256 pointsToAdd = 50;
        userPoints[msg.sender] = userPoints[msg.sender] + pointsToAdd;
        totalEarned[msg.sender] = totalEarned[msg.sender] + pointsToAdd;
        totalPointsIssued = totalPointsIssued + pointsToAdd;
        lastActivityTime[msg.sender] = block.timestamp;

        emit PointsEarned(msg.sender, pointsToAdd, "Referral bonus");
    }

    function addReward(string memory name, uint256 cost) external {

        if (msg.sender != owner) {
            revert("Only owner can add rewards");
        }

        if (bytes(name).length == 0) {
            revert("Reward name cannot be empty");
        }
        if (cost == 0) {
            revert("Reward cost must be greater than 0");
        }

        rewardCounter = rewardCounter + 1;
        rewards[rewardCounter] = RewardItem({
            name: name,
            cost: cost,
            isActive: true,
            totalPurchased: 0
        });

        emit RewardAdded(rewardCounter, name, cost);
    }

    function purchaseReward(uint256 rewardId) external {

        if (!isRegistered[msg.sender]) {
            revert("User not registered");
        }
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }

        if (rewardId == 0 || rewardId > rewardCounter) {
            revert("Invalid reward ID");
        }

        RewardItem storage reward = rewards[rewardId];
        if (!reward.isActive) {
            revert("Reward is not active");
        }

        if (userPoints[msg.sender] < reward.cost) {
            revert("Insufficient points");
        }

        if (userPurchasedRewards[msg.sender][rewardId]) {
            revert("Reward already purchased");
        }

        userPoints[msg.sender] = userPoints[msg.sender] - reward.cost;
        totalSpent[msg.sender] = totalSpent[msg.sender] + reward.cost;
        userPurchasedRewards[msg.sender][rewardId] = true;
        reward.totalPurchased = reward.totalPurchased + 1;
        lastActivityTime[msg.sender] = block.timestamp;

        emit PointsSpent(msg.sender, reward.cost, "Reward purchase");
        emit RewardPurchased(msg.sender, rewardId, reward.name);
    }

    function adminAddPoints(address user, uint256 amount) external {

        if (msg.sender != owner) {
            revert("Only owner can add points");
        }


        if (!isRegistered[user]) {
            revert("User not registered");
        }
        if (user == address(0)) {
            revert("Invalid address");
        }

        if (amount == 0) {
            revert("Amount must be greater than 0");
        }

        userPoints[user] = userPoints[user] + amount;
        totalEarned[user] = totalEarned[user] + amount;
        totalPointsIssued = totalPointsIssued + amount;

        emit PointsEarned(user, amount, "Admin bonus");
    }

    function adminRemovePoints(address user, uint256 amount) external {

        if (msg.sender != owner) {
            revert("Only owner can remove points");
        }


        if (!isRegistered[user]) {
            revert("User not registered");
        }
        if (user == address(0)) {
            revert("Invalid address");
        }

        if (amount == 0) {
            revert("Amount must be greater than 0");
        }

        if (userPoints[user] < amount) {
            revert("Insufficient points to remove");
        }

        userPoints[user] = userPoints[user] - amount;
        totalSpent[user] = totalSpent[user] + amount;

        emit PointsSpent(user, amount, "Admin penalty");
    }

    function deactivateReward(uint256 rewardId) external {

        if (msg.sender != owner) {
            revert("Only owner can deactivate rewards");
        }

        if (rewardId == 0 || rewardId > rewardCounter) {
            revert("Invalid reward ID");
        }

        rewards[rewardId].isActive = false;
    }

    function activateReward(uint256 rewardId) external {

        if (msg.sender != owner) {
            revert("Only owner can activate rewards");
        }

        if (rewardId == 0 || rewardId > rewardCounter) {
            revert("Invalid reward ID");
        }

        rewards[rewardId].isActive = true;
    }

    function getUserPoints(address user) external view returns (uint256) {
        return userPoints[user];
    }

    function getUserStats(address user) external view returns (uint256 points, uint256 earned, uint256 spent, uint256 lastActivity) {
        return (userPoints[user], totalEarned[user], totalSpent[user], lastActivityTime[user]);
    }

    function getRewardInfo(uint256 rewardId) external view returns (string memory name, uint256 cost, bool isActive, uint256 totalPurchased) {
        if (rewardId == 0 || rewardId > rewardCounter) {
            revert("Invalid reward ID");
        }

        RewardItem storage reward = rewards[rewardId];
        return (reward.name, reward.cost, reward.isActive, reward.totalPurchased);
    }

    function getSystemStats() external view returns (uint256 users, uint256 pointsIssued, uint256 totalRewards) {
        return (totalUsers, totalPointsIssued, rewardCounter);
    }

    function hasUserPurchasedReward(address user, uint256 rewardId) external view returns (bool) {
        return userPurchasedRewards[user][rewardId];
    }

    function transferOwnership(address newOwner) external {

        if (msg.sender != owner) {
            revert("Only owner can transfer ownership");
        }

        if (newOwner == address(0)) {
            revert("Invalid new owner address");
        }

        owner = newOwner;
    }

    function emergencyPause() external {

        if (msg.sender != owner) {
            revert("Only owner can pause");
        }



    }
}
