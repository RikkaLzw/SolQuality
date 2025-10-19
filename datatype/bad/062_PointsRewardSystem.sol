
pragma solidity ^0.8.0;

contract PointsRewardSystem {

    mapping(address => uint256) public userPoints;
    mapping(address => uint256) public userLevel;
    mapping(address => uint256) public dailyCheckIns;


    mapping(string => uint256) public rewardCosts;
    mapping(address => string) public userCategories;


    mapping(address => bytes) public userSignatures;
    mapping(bytes => address) public signatureToUser;


    mapping(address => uint256) public isActive;
    mapping(address => uint256) public hasClaimedDaily;

    address public owner;
    uint256 public totalUsers;


    event PointsEarned(address indexed user, uint256 points, uint256 timestamp);
    event RewardClaimed(address indexed user, string rewardType, uint256 cost);
    event UserRegistered(address indexed user, string category);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyActive() {
        require(isActive[msg.sender] == 1, "User not active");
        _;
    }

    constructor() {
        owner = msg.sender;

        rewardCosts["bronze_badge"] = 100;
        rewardCosts["silver_badge"] = 500;
        rewardCosts["gold_badge"] = 1000;
        rewardCosts["premium_access"] = 2000;
    }

    function registerUser(string memory category, bytes memory signature) external {
        require(isActive[msg.sender] == 0, "Already registered");


        isActive[msg.sender] = uint256(1);
        userCategories[msg.sender] = category;
        userSignatures[msg.sender] = signature;
        signatureToUser[signature] = msg.sender;


        userLevel[msg.sender] = uint256(1);
        totalUsers++;

        emit UserRegistered(msg.sender, category);
    }

    function earnPoints(uint256 points) external onlyActive {

        userPoints[msg.sender] += uint256(points);


        uint256 newLevel = (userPoints[msg.sender] / 1000) + 1;
        if (newLevel > userLevel[msg.sender]) {
            userLevel[msg.sender] = newLevel;
        }

        emit PointsEarned(msg.sender, points, uint256(block.timestamp));
    }

    function dailyCheckIn() external onlyActive {
        require(hasClaimedDaily[msg.sender] == 0, "Already claimed today");


        hasClaimedDaily[msg.sender] = uint256(1);
        dailyCheckIns[msg.sender]++;


        uint256 bonus = dailyCheckIns[msg.sender] * 10;
        userPoints[msg.sender] += 50 + bonus;

        emit PointsEarned(msg.sender, 50 + bonus, uint256(block.timestamp));
    }

    function claimReward(string memory rewardType) external onlyActive {
        uint256 cost = rewardCosts[rewardType];
        require(cost > 0, "Invalid reward type");
        require(userPoints[msg.sender] >= cost, "Insufficient points");

        userPoints[msg.sender] -= cost;
        emit RewardClaimed(msg.sender, rewardType, cost);
    }

    function addRewardType(string memory rewardType, uint256 cost) external onlyOwner {
        rewardCosts[rewardType] = cost;
    }

    function resetDailyFlags() external onlyOwner {


        hasClaimedDaily[msg.sender] = uint256(0);
    }

    function deactivateUser(address user) external onlyOwner {

        isActive[user] = uint256(0);
    }

    function activateUser(address user) external onlyOwner {

        isActive[user] = uint256(1);
    }

    function getUserInfo(address user) external view returns (
        uint256 points,
        uint256 level,
        string memory category,
        uint256 checkIns,
        uint256 active
    ) {
        return (
            userPoints[user],
            userLevel[user],
            userCategories[user],
            dailyCheckIns[user],
            isActive[user]
        );
    }

    function getUserSignature(address user) external view returns (bytes memory) {
        return userSignatures[user];
    }

    function getRewardCost(string memory rewardType) external view returns (uint256) {
        return rewardCosts[rewardType];
    }
}
