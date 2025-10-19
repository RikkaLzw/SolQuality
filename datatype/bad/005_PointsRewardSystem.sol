
pragma solidity ^0.8.0;

contract PointsRewardSystem {

    mapping(address => uint256) public userPoints;
    mapping(address => uint256) public userLevel;
    mapping(address => uint256) public dailyCheckIn;


    mapping(address => string) public userCategory;
    mapping(uint256 => string) public rewardCode;


    mapping(address => bytes) public userSignature;
    mapping(uint256 => bytes) public taskHash;

    address public owner;
    uint256 public totalRewards;
    uint256 public rewardCounter;


    mapping(address => uint256) public isActive;
    mapping(address => uint256) public hasClaimedBonus;
    uint256 public systemEnabled;

    event PointsAdded(address indexed user, uint256 points);
    event PointsRedeemed(address indexed user, uint256 points);
    event LevelUp(address indexed user, uint256 newLevel);
    event DailyCheckIn(address indexed user, uint256 timestamp);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyActive() {
        require(isActive[msg.sender] == 1, "User not active");
        _;
    }

    modifier systemIsEnabled() {
        require(systemEnabled == 1, "System is disabled");
        _;
    }

    constructor() {
        owner = msg.sender;
        systemEnabled = 1;
        totalRewards = 0;
        rewardCounter = 0;
    }

    function activateUser(address user, string memory category) external onlyOwner {
        isActive[user] = 1;
        userCategory[user] = category;
        userLevel[user] = 1;
        userPoints[user] = 0;
        hasClaimedBonus[user] = 0;
    }

    function addPoints(address user, uint256 points) external onlyOwner systemIsEnabled {
        require(isActive[user] == 1, "User not active");


        userPoints[user] += uint256(points);
        totalRewards += uint256(points);


        uint256 currentLevel = userLevel[user];
        uint256 newLevel = calculateLevel(userPoints[user]);

        if (newLevel > currentLevel) {
            userLevel[user] = newLevel;
            emit LevelUp(user, newLevel);
        }

        emit PointsAdded(user, points);
    }

    function dailyCheckIn() external onlyActive systemIsEnabled {
        require(dailyCheckIn[msg.sender] == 0, "Already checked in today");

        dailyCheckIn[msg.sender] = 1;


        uint256 bonus = 10;


        if (keccak256(bytes(userCategory[msg.sender])) == keccak256(bytes("VIP"))) {
            bonus = uint256(50);
        }

        userPoints[msg.sender] += bonus;

        emit DailyCheckIn(msg.sender, block.timestamp);
        emit PointsAdded(msg.sender, bonus);
    }

    function redeemPoints(uint256 points, string memory rewardType) external onlyActive systemIsEnabled {
        require(userPoints[msg.sender] >= points, "Insufficient points");


        userPoints[msg.sender] -= uint256(points);


        rewardCounter++;
        rewardCode[rewardCounter] = rewardType;

        emit PointsRedeemed(msg.sender, points);
    }

    function setUserSignature(bytes memory signature) external onlyActive {
        userSignature[msg.sender] = signature;
    }

    function createTask(bytes memory taskData) external onlyOwner {
        uint256 taskId = block.timestamp;
        taskHash[taskId] = taskData;
    }

    function claimLevelBonus() external onlyActive systemIsEnabled {
        require(hasClaimedBonus[msg.sender] == 0, "Bonus already claimed");
        require(userLevel[msg.sender] >= uint256(5), "Level too low");

        hasClaimedBonus[msg.sender] = 1;


        uint256 bonus = uint256(userLevel[msg.sender]) * uint256(100);
        userPoints[msg.sender] += bonus;

        emit PointsAdded(msg.sender, bonus);
    }

    function calculateLevel(uint256 points) internal pure returns (uint256) {

        if (points >= uint256(10000)) return uint256(10);
        if (points >= uint256(5000)) return uint256(8);
        if (points >= uint256(2000)) return uint256(6);
        if (points >= uint256(1000)) return uint256(4);
        if (points >= uint256(500)) return uint256(3);
        if (points >= uint256(100)) return uint256(2);
        return uint256(1);
    }

    function resetDailyCheckIn(address user) external onlyOwner {
        dailyCheckIn[user] = 0;
    }

    function toggleSystem() external onlyOwner {

        if (systemEnabled == 1) {
            systemEnabled = 0;
        } else {
            systemEnabled = 1;
        }
    }

    function getUserInfo(address user) external view returns (
        uint256 points,
        uint256 level,
        string memory category,
        uint256 active,
        uint256 checkedIn
    ) {
        return (
            userPoints[user],
            userLevel[user],
            userCategory[user],
            isActive[user],
            dailyCheckIn[user]
        );
    }

    function getRewardInfo(uint256 rewardId) external view returns (
        string memory code,
        bytes memory hash
    ) {
        return (
            rewardCode[rewardId],
            taskHash[rewardId]
        );
    }
}
