
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract PointsSystem is Ownable, ReentrancyGuard, Pausable {

    event PointsEarned(address indexed user, uint256 amount, string reason);
    event PointsSpent(address indexed user, uint256 amount, string reason);
    event PointsTransferred(address indexed from, address indexed to, uint256 amount);
    event RewardClaimed(address indexed user, uint256 pointsCost, string reward);
    event MultiplierUpdated(address indexed user, uint256 newMultiplier);
    event ActivityRegistered(bytes32 indexed activityId, uint256 pointsReward);


    struct UserProfile {
        uint256 totalPoints;
        uint256 spentPoints;
        uint256 multiplier;
        uint256 lastActivityTime;
        bool isVIP;
    }

    struct Activity {
        uint256 pointsReward;
        uint256 dailyLimit;
        bool isActive;
    }

    struct Reward {
        uint256 pointsCost;
        uint256 stock;
        bool isActive;
    }


    mapping(address => UserProfile) public users;
    mapping(bytes32 => Activity) public activities;
    mapping(bytes32 => Reward) public rewards;
    mapping(address => mapping(bytes32 => uint256)) public dailyActivityCount;
    mapping(address => mapping(bytes32 => uint256)) public lastActivityDate;

    bytes32[] public activityList;
    bytes32[] public rewardList;

    uint256 public constant BASE_MULTIPLIER = 100;
    uint256 public constant VIP_THRESHOLD = 10000;
    uint256 public constant MAX_TRANSFER_AMOUNT = 1000;
    uint256 public totalPointsIssued;
    uint256 public totalPointsSpent;


    modifier validUser(address user) {
        require(user != address(0), "Invalid user address");
        _;
    }

    modifier activityExists(bytes32 activityId) {
        require(activities[activityId].pointsReward > 0, "Activity does not exist");
        _;
    }

    modifier rewardExists(bytes32 rewardId) {
        require(rewards[rewardId].pointsCost > 0, "Reward does not exist");
        _;
    }

    constructor() {
        _transferOwnership(msg.sender);
    }


    function earnPoints(
        address user,
        bytes32 activityId,
        string calldata reason
    ) external onlyOwner validUser(user) activityExists(activityId) whenNotPaused {
        Activity storage activity = activities[activityId];
        require(activity.isActive, "Activity is not active");


        uint256 today = block.timestamp / 86400;
        if (lastActivityDate[user][activityId] != today) {
            dailyActivityCount[user][activityId] = 0;
            lastActivityDate[user][activityId] = today;
        }

        require(
            dailyActivityCount[user][activityId] < activity.dailyLimit,
            "Daily activity limit reached"
        );

        UserProfile storage userProfile = users[user];


        uint256 basePoints = activity.pointsReward;
        uint256 multiplier = userProfile.multiplier > 0 ? userProfile.multiplier : BASE_MULTIPLIER;
        uint256 earnedPoints = (basePoints * multiplier) / BASE_MULTIPLIER;


        userProfile.totalPoints += earnedPoints;
        userProfile.lastActivityTime = block.timestamp;


        if (!userProfile.isVIP && userProfile.totalPoints >= VIP_THRESHOLD) {
            userProfile.isVIP = true;
            userProfile.multiplier = 120;
            emit MultiplierUpdated(user, 120);
        }


        dailyActivityCount[user][activityId]++;
        totalPointsIssued += earnedPoints;

        emit PointsEarned(user, earnedPoints, reason);
    }

    function spendPoints(
        address user,
        uint256 amount,
        string calldata reason
    ) external onlyOwner validUser(user) whenNotPaused {
        UserProfile storage userProfile = users[user];
        uint256 availablePoints = userProfile.totalPoints - userProfile.spentPoints;

        require(availablePoints >= amount, "Insufficient points");

        userProfile.spentPoints += amount;
        totalPointsSpent += amount;

        emit PointsSpent(user, amount, reason);
    }

    function transferPoints(
        address to,
        uint256 amount
    ) external validUser(to) whenNotPaused nonReentrant {
        require(to != msg.sender, "Cannot transfer to self");
        require(amount <= MAX_TRANSFER_AMOUNT, "Amount exceeds transfer limit");

        UserProfile storage senderProfile = users[msg.sender];
        uint256 senderAvailable = senderProfile.totalPoints - senderProfile.spentPoints;

        require(senderAvailable >= amount, "Insufficient points");

        UserProfile storage receiverProfile = users[to];


        senderProfile.spentPoints += amount;
        receiverProfile.totalPoints += amount;

        emit PointsTransferred(msg.sender, to, amount);
    }

    function claimReward(
        bytes32 rewardId
    ) external rewardExists(rewardId) whenNotPaused nonReentrant {
        Reward storage reward = rewards[rewardId];
        require(reward.isActive, "Reward is not active");
        require(reward.stock > 0, "Reward out of stock");

        UserProfile storage userProfile = users[msg.sender];
        uint256 availablePoints = userProfile.totalPoints - userProfile.spentPoints;

        require(availablePoints >= reward.pointsCost, "Insufficient points");


        userProfile.spentPoints += reward.pointsCost;
        reward.stock--;
        totalPointsSpent += reward.pointsCost;

        emit RewardClaimed(msg.sender, reward.pointsCost, "");
    }


    function registerActivity(
        bytes32 activityId,
        uint256 pointsReward,
        uint256 dailyLimit
    ) external onlyOwner {
        require(pointsReward > 0, "Points reward must be greater than 0");
        require(dailyLimit > 0, "Daily limit must be greater than 0");

        if (activities[activityId].pointsReward == 0) {
            activityList.push(activityId);
        }

        activities[activityId] = Activity({
            pointsReward: pointsReward,
            dailyLimit: dailyLimit,
            isActive: true
        });

        emit ActivityRegistered(activityId, pointsReward);
    }

    function addReward(
        bytes32 rewardId,
        uint256 pointsCost,
        uint256 stock
    ) external onlyOwner {
        require(pointsCost > 0, "Points cost must be greater than 0");

        if (rewards[rewardId].pointsCost == 0) {
            rewardList.push(rewardId);
        }

        rewards[rewardId] = Reward({
            pointsCost: pointsCost,
            stock: stock,
            isActive: true
        });
    }

    function setUserMultiplier(
        address user,
        uint256 multiplier
    ) external onlyOwner validUser(user) {
        require(multiplier >= BASE_MULTIPLIER && multiplier <= 300, "Invalid multiplier");

        users[user].multiplier = multiplier;
        emit MultiplierUpdated(user, multiplier);
    }

    function toggleActivity(bytes32 activityId) external onlyOwner activityExists(activityId) {
        activities[activityId].isActive = !activities[activityId].isActive;
    }

    function toggleReward(bytes32 rewardId) external onlyOwner rewardExists(rewardId) {
        rewards[rewardId].isActive = !rewards[rewardId].isActive;
    }

    function updateRewardStock(
        bytes32 rewardId,
        uint256 newStock
    ) external onlyOwner rewardExists(rewardId) {
        rewards[rewardId].stock = newStock;
    }


    function getAvailablePoints(address user) external view returns (uint256) {
        UserProfile memory userProfile = users[user];
        return userProfile.totalPoints - userProfile.spentPoints;
    }

    function getUserProfile(address user) external view returns (
        uint256 totalPoints,
        uint256 spentPoints,
        uint256 availablePoints,
        uint256 multiplier,
        bool isVIP,
        uint256 lastActivityTime
    ) {
        UserProfile memory profile = users[user];
        return (
            profile.totalPoints,
            profile.spentPoints,
            profile.totalPoints - profile.spentPoints,
            profile.multiplier > 0 ? profile.multiplier : BASE_MULTIPLIER,
            profile.isVIP,
            profile.lastActivityTime
        );
    }

    function getActivityInfo(bytes32 activityId) external view returns (
        uint256 pointsReward,
        uint256 dailyLimit,
        bool isActive
    ) {
        Activity memory activity = activities[activityId];
        return (activity.pointsReward, activity.dailyLimit, activity.isActive);
    }

    function getRewardInfo(bytes32 rewardId) external view returns (
        uint256 pointsCost,
        uint256 stock,
        bool isActive
    ) {
        Reward memory reward = rewards[rewardId];
        return (reward.pointsCost, reward.stock, reward.isActive);
    }

    function getDailyActivityStatus(
        address user,
        bytes32 activityId
    ) external view returns (uint256 count, uint256 limit, bool canPerform) {
        uint256 today = block.timestamp / 86400;
        uint256 dailyCount = lastActivityDate[user][activityId] == today
            ? dailyActivityCount[user][activityId]
            : 0;

        Activity memory activity = activities[activityId];

        return (
            dailyCount,
            activity.dailyLimit,
            dailyCount < activity.dailyLimit && activity.isActive
        );
    }

    function getSystemStats() external view returns (
        uint256 _totalPointsIssued,
        uint256 _totalPointsSpent,
        uint256 totalActivities,
        uint256 totalRewards
    ) {
        return (
            totalPointsIssued,
            totalPointsSpent,
            activityList.length,
            rewardList.length
        );
    }


    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
