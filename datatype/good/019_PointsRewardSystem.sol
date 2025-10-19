
pragma solidity ^0.8.0;

contract PointsRewardSystem {

    mapping(address => uint256) public userPoints;
    mapping(address => bool) public isRegistered;
    mapping(bytes32 => uint256) public taskRewards;
    mapping(address => mapping(bytes32 => bool)) public completedTasks;
    mapping(address => uint256) public userLevel;

    address public owner;
    uint256 public totalPointsIssued;
    uint8 public constant MAX_LEVEL = 10;
    uint16 public constant POINTS_PER_LEVEL = 1000;


    event UserRegistered(address indexed user);
    event PointsEarned(address indexed user, uint256 points, bytes32 taskId);
    event PointsSpent(address indexed user, uint256 points);
    event TaskCreated(bytes32 indexed taskId, uint256 reward);
    event LevelUp(address indexed user, uint256 newLevel);


    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyRegistered() {
        require(isRegistered[msg.sender], "User not registered");
        _;
    }

    constructor() {
        owner = msg.sender;
        totalPointsIssued = 0;
    }


    function registerUser() external {
        require(!isRegistered[msg.sender], "User already registered");

        isRegistered[msg.sender] = true;
        userPoints[msg.sender] = 0;
        userLevel[msg.sender] = 1;

        emit UserRegistered(msg.sender);
    }


    function createTask(bytes32 _taskId, uint256 _reward) external onlyOwner {
        require(_reward > 0, "Reward must be greater than 0");
        require(taskRewards[_taskId] == 0, "Task already exists");

        taskRewards[_taskId] = _reward;

        emit TaskCreated(_taskId, _reward);
    }


    function completeTask(bytes32 _taskId) external onlyRegistered {
        require(taskRewards[_taskId] > 0, "Task does not exist");
        require(!completedTasks[msg.sender][_taskId], "Task already completed");

        uint256 reward = taskRewards[_taskId];
        completedTasks[msg.sender][_taskId] = true;
        userPoints[msg.sender] += reward;
        totalPointsIssued += reward;


        uint256 currentLevel = userLevel[msg.sender];
        uint256 newLevel = (userPoints[msg.sender] / POINTS_PER_LEVEL) + 1;

        if (newLevel > currentLevel && newLevel <= MAX_LEVEL) {
            userLevel[msg.sender] = newLevel;
            emit LevelUp(msg.sender, newLevel);
        }

        emit PointsEarned(msg.sender, reward, _taskId);
    }


    function spendPoints(uint256 _amount) external onlyRegistered {
        require(_amount > 0, "Amount must be greater than 0");
        require(userPoints[msg.sender] >= _amount, "Insufficient points");

        userPoints[msg.sender] -= _amount;


        uint256 newLevel = (userPoints[msg.sender] / POINTS_PER_LEVEL) + 1;
        if (newLevel < userLevel[msg.sender]) {
            userLevel[msg.sender] = newLevel;
        }

        emit PointsSpent(msg.sender, _amount);
    }


    function awardPoints(address _user, uint256 _points) external onlyOwner {
        require(isRegistered[_user], "User not registered");
        require(_points > 0, "Points must be greater than 0");

        userPoints[_user] += _points;
        totalPointsIssued += _points;


        uint256 currentLevel = userLevel[_user];
        uint256 newLevel = (userPoints[_user] / POINTS_PER_LEVEL) + 1;

        if (newLevel > currentLevel && newLevel <= MAX_LEVEL) {
            userLevel[_user] = newLevel;
            emit LevelUp(_user, newLevel);
        }

        emit PointsEarned(_user, _points, bytes32(0));
    }


    function getUserInfo(address _user) external view returns (
        uint256 points,
        uint256 level,
        bool registered
    ) {
        return (
            userPoints[_user],
            userLevel[_user],
            isRegistered[_user]
        );
    }


    function isTaskCompleted(address _user, bytes32 _taskId) external view returns (bool) {
        return completedTasks[_user][_taskId];
    }


    function getTaskReward(bytes32 _taskId) external view returns (uint256) {
        return taskRewards[_taskId];
    }


    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        owner = _newOwner;
    }


    function createMultipleTasks(bytes32[] calldata _taskIds, uint256[] calldata _rewards) external onlyOwner {
        require(_taskIds.length == _rewards.length, "Arrays length mismatch");

        for (uint8 i = 0; i < _taskIds.length; i++) {
            require(_rewards[i] > 0, "Reward must be greater than 0");
            require(taskRewards[_taskIds[i]] == 0, "Task already exists");

            taskRewards[_taskIds[i]] = _rewards[i];
            emit TaskCreated(_taskIds[i], _rewards[i]);
        }
    }


    function getPointsToNextLevel(address _user) external view returns (uint256) {
        if (!isRegistered[_user] || userLevel[_user] >= MAX_LEVEL) {
            return 0;
        }

        uint256 currentPoints = userPoints[_user];
        uint256 nextLevelThreshold = userLevel[_user] * POINTS_PER_LEVEL;

        if (currentPoints >= nextLevelThreshold) {
            return 0;
        }

        return nextLevelThreshold - currentPoints;
    }
}
