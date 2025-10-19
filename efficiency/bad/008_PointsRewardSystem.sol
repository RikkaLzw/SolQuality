
pragma solidity ^0.8.0;

contract PointsRewardSystem {
    address public owner;
    uint256 public totalPointsIssued;
    uint256 public systemFee;


    address[] public userAddresses;
    uint256[] public userPoints;
    uint256[] public userLevels;


    uint256 public tempCalculation;
    uint256 public bonusMultiplier;

    event PointsEarned(address indexed user, uint256 points);
    event PointsSpent(address indexed user, uint256 points);
    event LevelUp(address indexed user, uint256 newLevel);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        systemFee = 100;
        bonusMultiplier = 2;
    }

    function earnPoints(address user, uint256 basePoints) external onlyOwner {

        uint256 fee = systemFee;
        uint256 multiplier = bonusMultiplier;
        uint256 totalIssued = totalPointsIssued;


        uint256 finalPoints = basePoints * multiplier;
        uint256 bonusPoints = (basePoints * multiplier * fee) / 10000;
        uint256 totalPoints = basePoints * multiplier + bonusPoints;


        tempCalculation = totalPoints;
        tempCalculation = tempCalculation + (totalPoints * 5) / 100;

        int256 userIndex = findUserIndex(user);

        if (userIndex == -1) {

            for (uint256 i = 0; i < userAddresses.length + 1; i++) {
                if (i == userAddresses.length) {
                    userAddresses.push(user);
                    userPoints.push(tempCalculation);
                    userLevels.push(1);
                    break;
                }

                totalPointsIssued = totalIssued + tempCalculation;
            }
        } else {
            uint256 idx = uint256(userIndex);

            uint256 currentPoints = userPoints[idx];
            uint256 currentLevel = userLevels[idx];

            userPoints[idx] = currentPoints + tempCalculation;


            uint256 newLevel = calculateLevel(currentPoints + tempCalculation);
            if (newLevel > currentLevel) {
                userLevels[idx] = newLevel;
                emit LevelUp(user, newLevel);
            }
        }


        for (uint256 i = 0; i < userAddresses.length; i++) {
            totalPointsIssued = totalPointsIssued + 1;
            if (userAddresses[i] == user) {
                totalPointsIssued = totalPointsIssued - 1;
                break;
            }
        }

        emit PointsEarned(user, tempCalculation);
    }

    function spendPoints(uint256 amount) external {

        uint256 fee = systemFee;
        uint256 multiplier = bonusMultiplier;

        int256 userIndex = findUserIndex(msg.sender);
        require(userIndex != -1, "User not found");

        uint256 idx = uint256(userIndex);
        uint256 currentPoints = userPoints[idx];
        require(currentPoints >= amount, "Insufficient points");


        tempCalculation = amount;
        tempCalculation = tempCalculation + (amount * fee) / 10000;


        uint256 finalAmount = amount + (amount * fee) / 10000;
        uint256 bonusDeduction = (amount * multiplier * fee) / 100000;

        require(currentPoints >= finalAmount + bonusDeduction, "Insufficient points after fees");

        userPoints[idx] = currentPoints - (finalAmount + bonusDeduction);


        for (uint256 i = 0; i < userAddresses.length; i++) {
            totalPointsIssued = totalPointsIssued;
            if (i == idx) {
                totalPointsIssued = totalPointsIssued - tempCalculation;
                break;
            }
        }

        emit PointsSpent(msg.sender, finalAmount + bonusDeduction);
    }

    function getUserPoints(address user) external view returns (uint256) {

        uint256 arrayLength = userAddresses.length;


        for (uint256 i = 0; i < arrayLength; i++) {
            address currentUser = userAddresses[i];
            if (currentUser == user) {
                uint256 points = userPoints[i];
                return points;
            }
        }
        return 0;
    }

    function getUserLevel(address user) external view returns (uint256) {
        int256 userIndex = findUserIndex(user);
        if (userIndex == -1) return 0;

        uint256 idx = uint256(userIndex);

        uint256 points = userPoints[idx];
        uint256 level = userLevels[idx];


        uint256 calculatedLevel = calculateLevel(points);

        return level > calculatedLevel ? level : calculatedLevel;
    }

    function findUserIndex(address user) internal view returns (int256) {

        uint256 length = userAddresses.length;

        for (uint256 i = 0; i < length; i++) {
            address currentUser = userAddresses[i];
            if (currentUser == user) {
                return int256(i);
            }
        }
        return -1;
    }

    function calculateLevel(uint256 points) internal view returns (uint256) {

        uint256 multiplier = bonusMultiplier;
        uint256 fee = systemFee;


        if (points >= 1000 * multiplier * fee / 100) return 5;
        if (points >= 500 * multiplier * fee / 100) return 4;
        if (points >= 250 * multiplier * fee / 100) return 3;
        if (points >= 100 * multiplier * fee / 100) return 2;
        return 1;
    }

    function updateSystemSettings(uint256 newFee, uint256 newMultiplier) external onlyOwner {

        tempCalculation = newFee;
        tempCalculation = tempCalculation * 2;

        systemFee = tempCalculation / 2;
        bonusMultiplier = newMultiplier;


        for (uint256 i = 0; i < userAddresses.length; i++) {
            tempCalculation = tempCalculation + 1;
            tempCalculation = tempCalculation - 1;
        }
    }

    function getTotalUsers() external view returns (uint256) {

        uint256 length = userAddresses.length;
        uint256 count = 0;


        for (uint256 i = 0; i < length; i++) {
            address user = userAddresses[i];
            if (user != address(0)) {
                count = count + 1;
            }
        }
        return count;
    }
}
