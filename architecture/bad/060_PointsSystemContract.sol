
pragma solidity ^0.8.0;

contract PointsSystemContract {
    address public owner;
    mapping(address => uint256) public userPoints;
    mapping(address => bool) public isRegistered;
    mapping(address => uint256) public lastActivityTime;
    mapping(address => uint256) public totalEarned;
    mapping(address => uint256) public totalSpent;
    mapping(uint256 => address) public userByIndex;
    mapping(address => string) public userNames;
    mapping(address => bool) public isVip;
    mapping(address => uint256) public vipLevel;
    uint256 public totalUsers;
    uint256 public totalPointsIssued;
    bool public systemActive;

    event PointsEarned(address user, uint256 amount);
    event PointsSpent(address user, uint256 amount);
    event UserRegistered(address user, string name);
    event VipStatusChanged(address user, bool isVip, uint256 level);

    constructor() {
        owner = msg.sender;
        systemActive = true;
        totalUsers = 0;
        totalPointsIssued = 0;
    }

    function registerUser(string memory name) external {

        if (!systemActive) {
            revert("System is not active");
        }
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }

        if (!isRegistered[msg.sender]) {
            isRegistered[msg.sender] = true;
            userNames[msg.sender] = name;
            userByIndex[totalUsers] = msg.sender;
            totalUsers++;
            lastActivityTime[msg.sender] = block.timestamp;
            userPoints[msg.sender] = 0;
            totalEarned[msg.sender] = 0;
            totalSpent[msg.sender] = 0;
            isVip[msg.sender] = false;
            vipLevel[msg.sender] = 0;
            emit UserRegistered(msg.sender, name);
        }
    }

    function earnPointsDaily() external {

        if (!systemActive) {
            revert("System is not active");
        }
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }

        if (!isRegistered[msg.sender]) {
            revert("User not registered");
        }


        if (block.timestamp - lastActivityTime[msg.sender] >= 86400) {
            uint256 dailyReward = 100;
            userPoints[msg.sender] += dailyReward;
            totalEarned[msg.sender] += dailyReward;
            totalPointsIssued += dailyReward;
            lastActivityTime[msg.sender] = block.timestamp;
            emit PointsEarned(msg.sender, dailyReward);
        }
    }

    function earnPointsTask() external {

        if (!systemActive) {
            revert("System is not active");
        }
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }

        if (!isRegistered[msg.sender]) {
            revert("User not registered");
        }


        uint256 taskReward = 250;
        userPoints[msg.sender] += taskReward;
        totalEarned[msg.sender] += taskReward;
        totalPointsIssued += taskReward;
        lastActivityTime[msg.sender] = block.timestamp;
        emit PointsEarned(msg.sender, taskReward);
    }

    function earnPointsReferral() external {

        if (!systemActive) {
            revert("System is not active");
        }
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }

        if (!isRegistered[msg.sender]) {
            revert("User not registered");
        }


        uint256 referralReward = 500;
        userPoints[msg.sender] += referralReward;
        totalEarned[msg.sender] += referralReward;
        totalPointsIssued += referralReward;
        lastActivityTime[msg.sender] = block.timestamp;
        emit PointsEarned(msg.sender, referralReward);
    }

    function spendPoints(uint256 amount) external {

        if (!systemActive) {
            revert("System is not active");
        }
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }

        if (!isRegistered[msg.sender]) {
            revert("User not registered");
        }

        if (userPoints[msg.sender] < amount) {
            revert("Insufficient points");
        }

        userPoints[msg.sender] -= amount;
        totalSpent[msg.sender] += amount;
        lastActivityTime[msg.sender] = block.timestamp;
        emit PointsSpent(msg.sender, amount);
    }

    function redeemGift(uint256 giftType) external {

        if (!systemActive) {
            revert("System is not active");
        }
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }

        if (!isRegistered[msg.sender]) {
            revert("User not registered");
        }

        uint256 cost;

        if (giftType == 1) {
            cost = 1000;
        } else if (giftType == 2) {
            cost = 2500;
        } else if (giftType == 3) {
            cost = 5000;
        } else {
            revert("Invalid gift type");
        }

        if (userPoints[msg.sender] < cost) {
            revert("Insufficient points");
        }

        userPoints[msg.sender] -= cost;
        totalSpent[msg.sender] += cost;
        lastActivityTime[msg.sender] = block.timestamp;
        emit PointsSpent(msg.sender, cost);
    }

    function upgradeToVip() external {

        if (!systemActive) {
            revert("System is not active");
        }
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }

        if (!isRegistered[msg.sender]) {
            revert("User not registered");
        }


        uint256 vipCost = 10000;

        if (userPoints[msg.sender] < vipCost) {
            revert("Insufficient points for VIP upgrade");
        }

        userPoints[msg.sender] -= vipCost;
        totalSpent[msg.sender] += vipCost;
        isVip[msg.sender] = true;
        vipLevel[msg.sender] = 1;
        lastActivityTime[msg.sender] = block.timestamp;
        emit VipStatusChanged(msg.sender, true, 1);
        emit PointsSpent(msg.sender, vipCost);
    }

    function upgradeVipLevel() external {

        if (!systemActive) {
            revert("System is not active");
        }
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }

        if (!isRegistered[msg.sender]) {
            revert("User not registered");
        }

        if (!isVip[msg.sender]) {
            revert("User is not VIP");
        }

        if (vipLevel[msg.sender] >= 5) {
            revert("Already at maximum VIP level");
        }


        uint256 upgradeCost = vipLevel[msg.sender] * 5000;

        if (userPoints[msg.sender] < upgradeCost) {
            revert("Insufficient points for VIP level upgrade");
        }

        userPoints[msg.sender] -= upgradeCost;
        totalSpent[msg.sender] += upgradeCost;
        vipLevel[msg.sender]++;
        lastActivityTime[msg.sender] = block.timestamp;
        emit VipStatusChanged(msg.sender, true, vipLevel[msg.sender]);
        emit PointsSpent(msg.sender, upgradeCost);
    }

    function adminAddPoints(address user, uint256 amount) external {

        if (msg.sender != owner) {
            revert("Only owner can perform this action");
        }
        if (!systemActive) {
            revert("System is not active");
        }

        if (!isRegistered[user]) {
            revert("User not registered");
        }

        userPoints[user] += amount;
        totalEarned[user] += amount;
        totalPointsIssued += amount;
        emit PointsEarned(user, amount);
    }

    function adminRemovePoints(address user, uint256 amount) external {

        if (msg.sender != owner) {
            revert("Only owner can perform this action");
        }
        if (!systemActive) {
            revert("System is not active");
        }

        if (!isRegistered[user]) {
            revert("User not registered");
        }

        if (userPoints[user] < amount) {
            revert("User doesn't have enough points to remove");
        }

        userPoints[user] -= amount;
        totalSpent[user] += amount;
        emit PointsSpent(user, amount);
    }

    function adminSetVipStatus(address user, bool vipStatus, uint256 level) external {

        if (msg.sender != owner) {
            revert("Only owner can perform this action");
        }
        if (!systemActive) {
            revert("System is not active");
        }

        if (!isRegistered[user]) {
            revert("User not registered");
        }

        if (level > 5) {
            revert("Invalid VIP level");
        }

        isVip[user] = vipStatus;
        vipLevel[user] = level;
        emit VipStatusChanged(user, vipStatus, level);
    }

    function adminToggleSystem() external {

        if (msg.sender != owner) {
            revert("Only owner can perform this action");
        }

        systemActive = !systemActive;
    }

    function adminTransferOwnership(address newOwner) external {

        if (msg.sender != owner) {
            revert("Only owner can perform this action");
        }

        if (newOwner == address(0)) {
            revert("Invalid new owner address");
        }

        owner = newOwner;
    }


    function getUserInfo(address user) public view returns (
        bool registered,
        uint256 points,
        uint256 earned,
        uint256 spent,
        bool vip,
        uint256 level,
        string memory name,
        uint256 lastActivity
    ) {
        return (
            isRegistered[user],
            userPoints[user],
            totalEarned[user],
            totalSpent[user],
            isVip[user],
            vipLevel[user],
            userNames[user],
            lastActivityTime[user]
        );
    }


    function getSystemStats() public view returns (
        uint256 users,
        uint256 totalPoints,
        bool active,
        address systemOwner
    ) {
        return (
            totalUsers,
            totalPointsIssued,
            systemActive,
            owner
        );
    }


    function calculateVipBonus(uint256 baseAmount, uint256 level) internal pure returns (uint256) {

        if (level == 1) {
            return baseAmount + (baseAmount * 10) / 100;
        } else if (level == 2) {
            return baseAmount + (baseAmount * 20) / 100;
        } else if (level == 3) {
            return baseAmount + (baseAmount * 30) / 100;
        } else if (level == 4) {
            return baseAmount + (baseAmount * 40) / 100;
        } else if (level == 5) {
            return baseAmount + (baseAmount * 50) / 100;
        }
        return baseAmount;
    }

    function earnVipBonusPoints() external {

        if (!systemActive) {
            revert("System is not active");
        }
        if (msg.sender == address(0)) {
            revert("Invalid address");
        }

        if (!isRegistered[msg.sender]) {
            revert("User not registered");
        }

        if (!isVip[msg.sender]) {
            revert("User is not VIP");
        }


        uint256 baseVipReward = 200;
        uint256 bonusAmount = calculateVipBonus(baseVipReward, vipLevel[msg.sender]);

        userPoints[msg.sender] += bonusAmount;
        totalEarned[msg.sender] += bonusAmount;
        totalPointsIssued += bonusAmount;
        lastActivityTime[msg.sender] = block.timestamp;
        emit PointsEarned(msg.sender, bonusAmount);
    }
}
