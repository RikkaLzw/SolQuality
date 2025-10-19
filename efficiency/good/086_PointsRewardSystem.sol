
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract PointsRewardSystem is Ownable, ReentrancyGuard, Pausable {

    struct UserInfo {
        uint128 points;
        uint64 lastActivityTime;
        uint32 level;
        uint32 totalEarned;
    }

    struct RewardTier {
        uint128 minPoints;
        uint64 multiplier;
        uint64 reserved;
    }


    mapping(address => UserInfo) public users;
    mapping(address => bool) public authorizedOperators;


    RewardTier[] public rewardTiers;


    uint256 public constant MAX_POINTS_PER_ACTION = 10000;
    uint256 public constant POINTS_DECIMALS = 18;
    uint256 public totalPointsSupply;
    uint256 public dailyPointsLimit = 1000000 * 10**POINTS_DECIMALS;


    mapping(uint256 => uint256) public dailyPointsIssued;


    event PointsEarned(address indexed user, uint256 amount, string reason);
    event PointsSpent(address indexed user, uint256 amount, string reason);
    event PointsTransferred(address indexed from, address indexed to, uint256 amount);
    event LevelUpdated(address indexed user, uint32 newLevel);
    event OperatorUpdated(address indexed operator, bool authorized);
    event RewardTierUpdated(uint256 indexed tierIndex, uint128 minPoints, uint64 multiplier);

    modifier onlyOperator() {
        require(authorizedOperators[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }

    modifier validAmount(uint256 amount) {
        require(amount > 0 && amount <= MAX_POINTS_PER_ACTION * 10**POINTS_DECIMALS, "Invalid amount");
        _;
    }

    constructor() {

        rewardTiers.push(RewardTier(0, 10000, 0));
        rewardTiers.push(RewardTier(1000 * 10**POINTS_DECIMALS, 11000, 0));
        rewardTiers.push(RewardTier(5000 * 10**POINTS_DECIMALS, 12000, 0));
        rewardTiers.push(RewardTier(15000 * 10**POINTS_DECIMALS, 13000, 0));
        rewardTiers.push(RewardTier(50000 * 10**POINTS_DECIMALS, 15000, 0));
    }


    function getCurrentDay() public view returns (uint256) {
        return block.timestamp / 86400;
    }


    function checkDailyLimit(uint256 amount) internal view returns (bool) {
        uint256 today = getCurrentDay();
        return dailyPointsIssued[today] + amount <= dailyPointsLimit;
    }


    function getUserLevel(address user) public view returns (uint32) {
        uint128 userPoints = users[user].points;


        for (uint256 i = rewardTiers.length; i > 0; i--) {
            if (userPoints >= rewardTiers[i - 1].minPoints) {
                return uint32(i - 1);
            }
        }
        return 0;
    }


    function getRewardMultiplier(address user) public view returns (uint64) {
        uint32 level = getUserLevel(user);
        return rewardTiers[level].multiplier;
    }


    function awardPoints(
        address user,
        uint256 baseAmount,
        string calldata reason
    ) external onlyOperator nonReentrant whenNotPaused validAmount(baseAmount) {
        require(user != address(0), "Invalid user address");
        require(checkDailyLimit(baseAmount), "Daily limit exceeded");


        UserInfo storage userInfo = users[user];


        uint64 multiplier = getRewardMultiplier(user);
        uint256 finalAmount = (baseAmount * multiplier) / 10000;


        userInfo.points += uint128(finalAmount);
        userInfo.totalEarned += uint32(baseAmount);
        userInfo.lastActivityTime = uint64(block.timestamp);


        uint32 newLevel = getUserLevel(user);
        if (newLevel > userInfo.level) {
            userInfo.level = newLevel;
            emit LevelUpdated(user, newLevel);
        }


        totalPointsSupply += finalAmount;
        uint256 today = getCurrentDay();
        dailyPointsIssued[today] += baseAmount;

        emit PointsEarned(user, finalAmount, reason);
    }


    function spendPoints(
        address user,
        uint256 amount,
        string calldata reason
    ) external onlyOperator nonReentrant whenNotPaused validAmount(amount) {
        require(user != address(0), "Invalid user address");

        UserInfo storage userInfo = users[user];
        require(userInfo.points >= amount, "Insufficient points");

        userInfo.points -= uint128(amount);
        userInfo.lastActivityTime = uint64(block.timestamp);

        totalPointsSupply -= amount;

        emit PointsSpent(user, amount, reason);
    }


    function transferPoints(
        address to,
        uint256 amount
    ) external nonReentrant whenNotPaused validAmount(amount) {
        require(to != address(0) && to != msg.sender, "Invalid recipient");

        UserInfo storage fromInfo = users[msg.sender];
        require(fromInfo.points >= amount, "Insufficient points");

        UserInfo storage toInfo = users[to];


        fromInfo.points -= uint128(amount);
        toInfo.points += uint128(amount);


        fromInfo.lastActivityTime = uint64(block.timestamp);
        toInfo.lastActivityTime = uint64(block.timestamp);


        uint32 newLevel = getUserLevel(to);
        if (newLevel > toInfo.level) {
            toInfo.level = newLevel;
            emit LevelUpdated(to, newLevel);
        }

        emit PointsTransferred(msg.sender, to, amount);
    }


    function batchAwardPoints(
        address[] calldata users_,
        uint256[] calldata amounts,
        string calldata reason
    ) external onlyOperator nonReentrant whenNotPaused {
        require(users_.length == amounts.length && users_.length > 0, "Invalid input arrays");
        require(users_.length <= 100, "Batch size too large");

        uint256 totalAmount = 0;


        for (uint256 i = 0; i < amounts.length; i++) {
            require(amounts[i] > 0 && amounts[i] <= MAX_POINTS_PER_ACTION * 10**POINTS_DECIMALS, "Invalid amount");
            totalAmount += amounts[i];
        }

        require(checkDailyLimit(totalAmount), "Daily limit exceeded");


        for (uint256 i = 0; i < users_.length; i++) {
            address user = users_[i];
            uint256 baseAmount = amounts[i];

            require(user != address(0), "Invalid user address");

            UserInfo storage userInfo = users[user];

            uint64 multiplier = getRewardMultiplier(user);
            uint256 finalAmount = (baseAmount * multiplier) / 10000;

            userInfo.points += uint128(finalAmount);
            userInfo.totalEarned += uint32(baseAmount);
            userInfo.lastActivityTime = uint64(block.timestamp);

            uint32 newLevel = getUserLevel(user);
            if (newLevel > userInfo.level) {
                userInfo.level = newLevel;
                emit LevelUpdated(user, newLevel);
            }

            totalPointsSupply += finalAmount;
            emit PointsEarned(user, finalAmount, reason);
        }


        uint256 today = getCurrentDay();
        dailyPointsIssued[today] += totalAmount;
    }


    function getUserInfo(address user) external view returns (
        uint128 points,
        uint64 lastActivityTime,
        uint32 level,
        uint32 totalEarned,
        uint64 rewardMultiplier
    ) {
        UserInfo memory userInfo = users[user];
        return (
            userInfo.points,
            userInfo.lastActivityTime,
            userInfo.level,
            userInfo.totalEarned,
            getRewardMultiplier(user)
        );
    }


    function setOperator(address operator, bool authorized) external onlyOwner {
        authorizedOperators[operator] = authorized;
        emit OperatorUpdated(operator, authorized);
    }


    function setDailyPointsLimit(uint256 newLimit) external onlyOwner {
        require(newLimit > 0, "Invalid limit");
        dailyPointsLimit = newLimit;
    }


    function addRewardTier(uint128 minPoints, uint64 multiplier) external onlyOwner {
        require(multiplier >= 10000, "Multiplier must be >= 1x");
        rewardTiers.push(RewardTier(minPoints, multiplier, 0));
        emit RewardTierUpdated(rewardTiers.length - 1, minPoints, multiplier);
    }


    function updateRewardTier(uint256 tierIndex, uint128 minPoints, uint64 multiplier) external onlyOwner {
        require(tierIndex < rewardTiers.length, "Invalid tier index");
        require(multiplier >= 10000, "Multiplier must be >= 1x");

        rewardTiers[tierIndex].minPoints = minPoints;
        rewardTiers[tierIndex].multiplier = multiplier;

        emit RewardTierUpdated(tierIndex, minPoints, multiplier);
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
    }


    function getRewardTiersCount() external view returns (uint256) {
        return rewardTiers.length;
    }


    function getTodayIssuedPoints() external view returns (uint256) {
        return dailyPointsIssued[getCurrentDay()];
    }
}
