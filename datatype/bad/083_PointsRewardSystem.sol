
pragma solidity ^0.8.0;

contract PointsRewardSystem {

    mapping(address => uint256) public userPoints;
    mapping(address => uint256) public userLevel;
    mapping(address => uint256) public dailyCheckInCount;


    mapping(address => string) public userCategory;
    mapping(uint256 => string) public taskId;


    mapping(address => bytes) public userSignature;
    mapping(uint256 => bytes) public rewardData;


    mapping(address => uint256) public isActive;
    mapping(address => uint256) public hasClaimedDaily;
    mapping(uint256 => uint256) public taskCompleted;

    uint256 public totalUsers;
    uint256 public nextTaskId;
    address public owner;

    event PointsEarned(address indexed user, uint256 points, string reason);
    event LevelUp(address indexed user, uint256 newLevel);
    event TaskCompleted(address indexed user, uint256 taskId, uint256 points);
    event DailyCheckIn(address indexed user, uint256 points);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier onlyActiveUser() {
        require(isActive[msg.sender] == 1, "User not active");
        _;
    }

    constructor() {
        owner = msg.sender;
        nextTaskId = 1;

        totalUsers = uint256(0);
        isActive[owner] = uint256(1);
        userCategory[owner] = "PREMIUM";
    }

    function registerUser(address user, string memory category) external onlyOwner {
        require(isActive[user] == 0, "User already registered");


        isActive[user] = uint256(1);
        userPoints[user] = uint256(0);
        userLevel[user] = uint256(1);
        dailyCheckInCount[user] = uint256(0);
        hasClaimedDaily[user] = uint256(0);

        userCategory[user] = category;
        totalUsers = totalUsers + uint256(1);
    }

    function dailyCheckIn() external onlyActiveUser {
        require(hasClaimedDaily[msg.sender] == 0, "Already checked in today");


        uint256 basePoints = uint256(10);
        uint256 bonusPoints = uint256(0);


        if (keccak256(bytes(userCategory[msg.sender])) == keccak256(bytes("VIP"))) {
            bonusPoints = uint256(5);
        } else if (keccak256(bytes(userCategory[msg.sender])) == keccak256(bytes("PREMIUM"))) {
            bonusPoints = uint256(10);
        }

        uint256 totalPoints = basePoints + bonusPoints;
        userPoints[msg.sender] += totalPoints;
        dailyCheckInCount[msg.sender] = uint256(1);
        hasClaimedDaily[msg.sender] = uint256(1);

        _checkLevelUp(msg.sender);

        emit DailyCheckIn(msg.sender, totalPoints);
        emit PointsEarned(msg.sender, totalPoints, "Daily Check-in");
    }

    function createTask(string memory taskIdentifier, bytes memory data) external onlyOwner {
        taskId[nextTaskId] = taskIdentifier;
        rewardData[nextTaskId] = data;
        taskCompleted[nextTaskId] = uint256(0);


        nextTaskId = nextTaskId + uint256(1);
    }

    function completeTask(uint256 _taskId, uint256 pointsReward) external onlyActiveUser {
        require(_taskId < nextTaskId, "Invalid task ID");
        require(taskCompleted[_taskId] == 0, "Task already completed");


        taskCompleted[_taskId] = uint256(1);
        userPoints[msg.sender] += uint256(pointsReward);

        _checkLevelUp(msg.sender);

        emit TaskCompleted(msg.sender, _taskId, pointsReward);
        emit PointsEarned(msg.sender, pointsReward, taskId[_taskId]);
    }

    function setUserSignature(bytes memory signature) external onlyActiveUser {
        userSignature[msg.sender] = signature;
    }

    function upgradeUserCategory(address user, string memory newCategory) external onlyOwner {
        require(isActive[user] == 1, "User not active");
        userCategory[user] = newCategory;
    }

    function deactivateUser(address user) external onlyOwner {

        isActive[user] = uint256(0);
    }

    function reactivateUser(address user) external onlyOwner {

        isActive[user] = uint256(1);
    }

    function resetDailyCheckIn() external onlyOwner {


        hasClaimedDaily[msg.sender] = uint256(0);
        dailyCheckInCount[msg.sender] = uint256(0);
    }

    function _checkLevelUp(address user) internal {
        uint256 currentPoints = userPoints[user];
        uint256 currentLevel = userLevel[user];
        uint256 newLevel = currentLevel;


        if (currentPoints >= uint256(1000) && currentLevel < uint256(10)) {
            newLevel = uint256(10);
        } else if (currentPoints >= uint256(500) && currentLevel < uint256(5)) {
            newLevel = uint256(5);
        } else if (currentPoints >= uint256(100) && currentLevel < uint256(2)) {
            newLevel = uint256(2);
        }

        if (newLevel > currentLevel) {
            userLevel[user] = newLevel;
            emit LevelUp(user, newLevel);
        }
    }

    function getUserInfo(address user) external view returns (
        uint256 points,
        uint256 level,
        string memory category,
        uint256 active,
        uint256 checkedInToday
    ) {
        return (
            userPoints[user],
            userLevel[user],
            userCategory[user],
            isActive[user],
            hasClaimedDaily[user]
        );
    }

    function getTaskInfo(uint256 _taskId) external view returns (
        string memory identifier,
        bytes memory data,
        uint256 completed
    ) {
        return (
            taskId[_taskId],
            rewardData[_taskId],
            taskCompleted[_taskId]
        );
    }
}
