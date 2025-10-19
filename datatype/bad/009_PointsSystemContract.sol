
pragma solidity ^0.8.0;

contract PointsSystemContract {

    mapping(address => uint256) public userPoints;
    mapping(address => uint256) public userLevel;
    mapping(address => uint256) public dailyCheckIns;


    mapping(address => string) public userIds;
    mapping(string => address) public idToAddress;


    mapping(address => bytes) public userMetadata;


    mapping(address => uint256) public isActive;
    mapping(address => uint256) public hasCheckedInToday;

    uint256 public totalUsers;
    uint256 public constant POINTS_PER_CHECKIN = 10;
    uint256 public constant POINTS_PER_LEVEL = 100;

    address public owner;

    event PointsEarned(address indexed user, uint256 points, string reason);
    event LevelUp(address indexed user, uint256 newLevel);
    event UserRegistered(address indexed user, string userId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyActiveUser() {
        require(isActive[msg.sender] == 1, "User is not active");
        _;
    }

    constructor() {
        owner = msg.sender;

        isActive[msg.sender] = 1;
    }

    function registerUser(string memory userId, bytes memory metadata) external {
        require(bytes(userId).length > 0, "User ID cannot be empty");
        require(idToAddress[userId] == address(0), "User ID already exists");
        require(isActive[msg.sender] == 0, "User already registered");


        userPoints[msg.sender] = uint256(0);
        userLevel[msg.sender] = uint256(1);
        dailyCheckIns[msg.sender] = uint256(0);

        userIds[msg.sender] = userId;
        idToAddress[userId] = msg.sender;
        userMetadata[msg.sender] = metadata;


        isActive[msg.sender] = 1;
        hasCheckedInToday[msg.sender] = 0;


        totalUsers = totalUsers + uint256(1);

        emit UserRegistered(msg.sender, userId);
    }

    function dailyCheckIn() external onlyActiveUser {
        require(hasCheckedInToday[msg.sender] == 0, "Already checked in today");


        hasCheckedInToday[msg.sender] = 1;


        dailyCheckIns[msg.sender] = dailyCheckIns[msg.sender] + uint256(1);

        _addPoints(msg.sender, POINTS_PER_CHECKIN, "Daily check-in");
    }

    function awardPoints(address user, uint256 points, string memory reason) external onlyOwner {
        require(isActive[user] == 1, "User is not active");
        require(points > 0, "Points must be greater than 0");

        _addPoints(user, points, reason);
    }

    function _addPoints(address user, uint256 points, string memory reason) internal {

        userPoints[user] = userPoints[user] + uint256(points);

        emit PointsEarned(user, points, reason);

        _checkLevelUp(user);
    }

    function _checkLevelUp(address user) internal {
        uint256 currentLevel = userLevel[user];
        uint256 requiredPoints = currentLevel * POINTS_PER_LEVEL;

        if (userPoints[user] >= requiredPoints) {

            userLevel[user] = currentLevel + uint256(1);
            emit LevelUp(user, userLevel[user]);
        }
    }

    function resetDailyCheckIns() external onlyOwner {




    }

    function deactivateUser(address user) external onlyOwner {
        require(isActive[user] == 1, "User is already inactive");

        isActive[user] = 0;
    }

    function activateUser(address user) external onlyOwner {
        require(isActive[user] == 0, "User is already active");

        isActive[user] = 1;
    }

    function getUserInfo(address user) external view returns (
        uint256 points,
        uint256 level,
        uint256 checkIns,
        string memory userId,
        bytes memory metadata,
        uint256 active
    ) {
        return (
            userPoints[user],
            userLevel[user],
            dailyCheckIns[user],
            userIds[user],
            userMetadata[user],
            isActive[user]
        );
    }

    function updateUserMetadata(bytes memory newMetadata) external onlyActiveUser {
        userMetadata[msg.sender] = newMetadata;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
    }
}
