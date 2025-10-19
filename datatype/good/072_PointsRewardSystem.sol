
pragma solidity ^0.8.0;

contract PointsRewardSystem {

    mapping(address => uint256) public userPoints;
    mapping(address => bool) public isRegistered;
    mapping(bytes32 => uint256) public taskRewards;
    mapping(address => mapping(bytes32 => bool)) public completedTasks;
    mapping(address => uint256) public totalEarned;
    mapping(address => uint256) public totalSpent;

    address public owner;
    uint256 public totalPointsIssued;
    uint256 public totalPointsRedeemed;
    bool public systemActive;


    mapping(address => uint8) public userLevel;


    mapping(address => uint32) public lastActivity;

    event PointsEarned(address indexed user, uint256 amount, bytes32 taskId);
    event PointsSpent(address indexed user, uint256 amount, bytes32 reason);
    event UserRegistered(address indexed user);
    event TaskCreated(bytes32 indexed taskId, uint256 reward);
    event LevelUpdated(address indexed user, uint8 newLevel);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyRegistered() {
        require(isRegistered[msg.sender], "User not registered");
        _;
    }

    modifier systemIsActive() {
        require(systemActive, "System is not active");
        _;
    }

    constructor() {
        owner = msg.sender;
        systemActive = true;
    }

    function registerUser() external systemIsActive {
        require(!isRegistered[msg.sender], "User already registered");

        isRegistered[msg.sender] = true;
        userPoints[msg.sender] = 0;
        userLevel[msg.sender] = 1;
        lastActivity[msg.sender] = uint32(block.timestamp);

        emit UserRegistered(msg.sender);
    }

    function createTask(bytes32 _taskId, uint256 _reward) external onlyOwner {
        require(_reward > 0, "Reward must be greater than 0");
        require(taskRewards[_taskId] == 0, "Task already exists");

        taskRewards[_taskId] = _reward;
        emit TaskCreated(_taskId, _reward);
    }

    function completeTask(bytes32 _taskId) external onlyRegistered systemIsActive {
        require(taskRewards[_taskId] > 0, "Task does not exist");
        require(!completedTasks[msg.sender][_taskId], "Task already completed");

        completedTasks[msg.sender][_taskId] = true;
        uint256 reward = taskRewards[_taskId];

        userPoints[msg.sender] += reward;
        totalEarned[msg.sender] += reward;
        totalPointsIssued += reward;
        lastActivity[msg.sender] = uint32(block.timestamp);

        _updateUserLevel(msg.sender);

        emit PointsEarned(msg.sender, reward, _taskId);
    }

    function spendPoints(uint256 _amount, bytes32 _reason) external onlyRegistered systemIsActive {
        require(_amount > 0, "Amount must be greater than 0");
        require(userPoints[msg.sender] >= _amount, "Insufficient points");

        userPoints[msg.sender] -= _amount;
        totalSpent[msg.sender] += _amount;
        totalPointsRedeemed += _amount;
        lastActivity[msg.sender] = uint32(block.timestamp);

        emit PointsSpent(msg.sender, _amount, _reason);
    }

    function awardPoints(address _user, uint256 _amount, bytes32 _reason) external onlyOwner {
        require(isRegistered[_user], "User not registered");
        require(_amount > 0, "Amount must be greater than 0");

        userPoints[_user] += _amount;
        totalEarned[_user] += _amount;
        totalPointsIssued += _amount;
        lastActivity[_user] = uint32(block.timestamp);

        _updateUserLevel(_user);

        emit PointsEarned(_user, _amount, _reason);
    }

    function _updateUserLevel(address _user) internal {
        uint256 totalPoints = totalEarned[_user];
        uint8 newLevel;

        if (totalPoints >= 10000) {
            newLevel = 5;
        } else if (totalPoints >= 5000) {
            newLevel = 4;
        } else if (totalPoints >= 2000) {
            newLevel = 3;
        } else if (totalPoints >= 500) {
            newLevel = 2;
        } else {
            newLevel = 1;
        }

        if (newLevel != userLevel[_user]) {
            userLevel[_user] = newLevel;
            emit LevelUpdated(_user, newLevel);
        }
    }

    function getUserInfo(address _user) external view returns (
        uint256 points,
        uint256 earned,
        uint256 spent,
        uint8 level,
        uint32 lastActivityTime,
        bool registered
    ) {
        return (
            userPoints[_user],
            totalEarned[_user],
            totalSpent[_user],
            userLevel[_user],
            lastActivity[_user],
            isRegistered[_user]
        );
    }

    function getSystemStats() external view returns (
        uint256 totalIssued,
        uint256 totalRedeemed,
        bool active
    ) {
        return (totalPointsIssued, totalPointsRedeemed, systemActive);
    }

    function toggleSystem() external onlyOwner {
        systemActive = !systemActive;
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        owner = _newOwner;
    }

    function hasCompletedTask(address _user, bytes32 _taskId) external view returns (bool) {
        return completedTasks[_user][_taskId];
    }

    function getTaskReward(bytes32 _taskId) external view returns (uint256) {
        return taskRewards[_taskId];
    }
}
