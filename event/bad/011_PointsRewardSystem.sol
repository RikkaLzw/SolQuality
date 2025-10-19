
pragma solidity ^0.8.0;

contract PointsRewardSystem {
    mapping(address => uint256) public userPoints;
    mapping(address => bool) public isAdmin;
    mapping(uint256 => RewardTier) public rewardTiers;
    mapping(address => uint256) public userTier;

    address public owner;
    uint256 public totalPointsIssued;
    uint256 public nextTierId;

    struct RewardTier {
        string name;
        uint256 requiredPoints;
        uint256 multiplier;
        bool exists;
    }

    error InvalidAmount();
    error NotAuthorized();
    error TierExists();
    error InvalidTier();

    event PointsAwarded(address user, uint256 amount);
    event PointsRedeemed(address user, uint256 amount);
    event TierCreated(uint256 tierId, string name);
    event UserTierUpdated(address user, uint256 newTier);

    constructor() {
        owner = msg.sender;
        isAdmin[msg.sender] = true;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyAdmin() {
        require(isAdmin[msg.sender]);
        _;
    }

    function addAdmin(address newAdmin) external onlyOwner {
        require(newAdmin != address(0));
        isAdmin[newAdmin] = true;

    }

    function removeAdmin(address admin) external onlyOwner {
        require(admin != owner);
        isAdmin[admin] = false;

    }

    function awardPoints(address user, uint256 amount) external onlyAdmin {
        require(user != address(0));
        require(amount > 0);

        userPoints[user] += amount;
        totalPointsIssued += amount;

        _updateUserTier(user);

        emit PointsAwarded(user, amount);
    }

    function redeemPoints(uint256 amount) external {
        require(userPoints[msg.sender] >= amount);
        require(amount > 0);

        userPoints[msg.sender] -= amount;

        emit PointsRedeemed(msg.sender, amount);
    }

    function createRewardTier(string memory name, uint256 requiredPoints, uint256 multiplier) external onlyOwner {
        require(bytes(name).length > 0);
        require(requiredPoints > 0);
        require(multiplier > 0);

        uint256 tierId = nextTierId++;
        rewardTiers[tierId] = RewardTier({
            name: name,
            requiredPoints: requiredPoints,
            multiplier: multiplier,
            exists: true
        });

        emit TierCreated(tierId, name);
    }

    function updateRewardTier(uint256 tierId, uint256 newRequiredPoints, uint256 newMultiplier) external onlyOwner {
        require(rewardTiers[tierId].exists);
        require(newRequiredPoints > 0);
        require(newMultiplier > 0);

        rewardTiers[tierId].requiredPoints = newRequiredPoints;
        rewardTiers[tierId].multiplier = newMultiplier;

    }

    function batchAwardPoints(address[] calldata users, uint256[] calldata amounts) external onlyAdmin {
        require(users.length == amounts.length);
        require(users.length > 0);

        for (uint256 i = 0; i < users.length; i++) {
            require(users[i] != address(0));
            require(amounts[i] > 0);

            userPoints[users[i]] += amounts[i];
            totalPointsIssued += amounts[i];

            _updateUserTier(users[i]);

            emit PointsAwarded(users[i], amounts[i]);
        }
    }

    function transferPoints(address to, uint256 amount) external {
        require(to != address(0));
        require(userPoints[msg.sender] >= amount);
        require(amount > 0);

        userPoints[msg.sender] -= amount;
        userPoints[to] += amount;

        _updateUserTier(to);

    }

    function _updateUserTier(address user) internal {
        uint256 userPointBalance = userPoints[user];
        uint256 currentTier = userTier[user];
        uint256 newTier = 0;

        for (uint256 i = 0; i < nextTierId; i++) {
            if (rewardTiers[i].exists && userPointBalance >= rewardTiers[i].requiredPoints) {
                if (rewardTiers[i].requiredPoints > rewardTiers[newTier].requiredPoints || newTier == 0) {
                    newTier = i;
                }
            }
        }

        if (newTier != currentTier) {
            userTier[user] = newTier;
            emit UserTierUpdated(user, newTier);
        }
    }

    function getPointsWithMultiplier(address user) external view returns (uint256) {
        uint256 tier = userTier[user];
        if (rewardTiers[tier].exists) {
            return userPoints[user] * rewardTiers[tier].multiplier;
        }
        return userPoints[user];
    }

    function getUserTierInfo(address user) external view returns (string memory tierName, uint256 requiredPoints, uint256 multiplier) {
        uint256 tier = userTier[user];
        if (rewardTiers[tier].exists) {
            RewardTier memory tierInfo = rewardTiers[tier];
            return (tierInfo.name, tierInfo.requiredPoints, tierInfo.multiplier);
        }
        return ("No Tier", 0, 1);
    }

    function emergencyWithdrawPoints(address user) external onlyOwner {
        require(user != address(0));

        uint256 points = userPoints[user];
        userPoints[user] = 0;
        userTier[user] = 0;

    }
}
