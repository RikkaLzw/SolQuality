
pragma solidity ^0.8.0;

contract PointsRewardSystem {

    mapping(address => uint256) public userPoints;
    mapping(address => uint256) public userLevel;
    mapping(address => uint256) public dailyCheckInCount;


    mapping(address => string) public userCategory;
    mapping(uint256 => string) public rewardType;


    mapping(address => bytes) public userSignature;
    mapping(uint256 => bytes) public transactionHash;


    mapping(address => uint256) public isActive;
    mapping(address => uint256) public hasClaimedDaily;
    mapping(address => uint256) public isVipMember;

    address public owner;
    uint256 public totalUsers;
    uint256 public constant DAILY_REWARD = 10;
    uint256 public constant WEEKLY_REWARD = 100;
    uint256 public constant MONTHLY_REWARD = 500;

    event PointsEarned(address indexed user, uint256 amount, string rewardType);
    event LevelUp(address indexed user, uint256 newLevel);
    event UserRegistered(address indexed user, string category);

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

        totalUsers = uint256(0);


        rewardType[1] = "DAILY";
        rewardType[2] = "WEEKLY";
        rewardType[3] = "MONTHLY";
    }

    function registerUser(string memory category, bytes memory signature) external {
        require(isActive[msg.sender] == 0, "User already registered");


        isActive[msg.sender] = uint256(1);
        userLevel[msg.sender] = uint256(1);
        userPoints[msg.sender] = uint256(0);
        dailyCheckInCount[msg.sender] = uint256(0);
        hasClaimedDaily[msg.sender] = uint256(0);


        userCategory[msg.sender] = category;


        userSignature[msg.sender] = signature;


        totalUsers = uint256(totalUsers + 1);

        emit UserRegistered(msg.sender, category);
    }

    function dailyCheckIn() external onlyActiveUser {
        require(hasClaimedDaily[msg.sender] == 0, "Already claimed today");


        hasClaimedDaily[msg.sender] = uint256(1);
        dailyCheckInCount[msg.sender] = uint256(dailyCheckInCount[msg.sender] + 1);

        uint256 reward = DAILY_REWARD;


        if (isVipMember[msg.sender] == 1) {

            reward = uint256(reward * 2);
        }

        userPoints[msg.sender] = uint256(userPoints[msg.sender] + reward);


        _checkLevelUp(msg.sender);

        emit PointsEarned(msg.sender, reward, rewardType[1]);
    }

    function claimWeeklyReward() external onlyActiveUser {
        require(dailyCheckInCount[msg.sender] >= 7, "Need 7 daily check-ins");

        uint256 reward = WEEKLY_REWARD;
        userPoints[msg.sender] = uint256(userPoints[msg.sender] + reward);


        dailyCheckInCount[msg.sender] = uint256(0);

        _checkLevelUp(msg.sender);

        emit PointsEarned(msg.sender, reward, rewardType[2]);
    }

    function claimMonthlyReward() external onlyActiveUser {
        require(userLevel[msg.sender] >= 5, "Need level 5 or higher");

        uint256 reward = MONTHLY_REWARD;
        userPoints[msg.sender] = uint256(userPoints[msg.sender] + reward);

        _checkLevelUp(msg.sender);

        emit PointsEarned(msg.sender, reward, rewardType[3]);
    }

    function setVipStatus(address user, uint256 status) external onlyOwner {
        require(status == 0 || status == 1, "Status must be 0 or 1");
        isVipMember[user] = status;
    }

    function spendPoints(uint256 amount) external onlyActiveUser {
        require(userPoints[msg.sender] >= amount, "Insufficient points");
        userPoints[msg.sender] = uint256(userPoints[msg.sender] - amount);
    }

    function resetDailyStatus() external onlyOwner {


        hasClaimedDaily[msg.sender] = uint256(0);
    }

    function setTransactionHash(uint256 id, bytes memory hash) external onlyOwner {
        transactionHash[id] = hash;
    }

    function _checkLevelUp(address user) internal {
        uint256 currentPoints = userPoints[user];
        uint256 currentLevel = userLevel[user];
        uint256 newLevel = currentLevel;


        if (currentPoints >= 1000 && currentLevel < 2) {
            newLevel = uint256(2);
        } else if (currentPoints >= 2500 && currentLevel < 3) {
            newLevel = uint256(3);
        } else if (currentPoints >= 5000 && currentLevel < 4) {
            newLevel = uint256(4);
        } else if (currentPoints >= 10000 && currentLevel < 5) {
            newLevel = uint256(5);
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
        uint256 vipStatus
    ) {
        return (
            userPoints[user],
            userLevel[user],
            userCategory[user],
            isActive[user],
            isVipMember[user]
        );
    }
}
