
pragma solidity ^0.8.0;

contract PointsRewardSystem {
    address public owner;
    uint256 public totalPoints;
    uint256 public rewardRate;
    uint256 public bonusMultiplier;


    address[] public userAddresses;
    uint256[] public userPoints;
    uint256[] public userLevels;
    bool[] public userActive;


    uint256 public tempCalculation;
    uint256 public intermediateResult;
    uint256 public processingBuffer;

    event PointsAwarded(address indexed user, uint256 amount);
    event LevelUpdated(address indexed user, uint256 newLevel);
    event RewardClaimed(address indexed user, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        rewardRate = 10;
        bonusMultiplier = 2;
    }

    function addUser(address _user) external onlyOwner {

        for (uint256 i = 0; i < userAddresses.length; i++) {
            require(userAddresses[i] != _user, "User already exists");
        }

        userAddresses.push(_user);
        userPoints.push(0);
        userLevels.push(1);
        userActive.push(true);
    }

    function awardPoints(address _user, uint256 _basePoints) external onlyOwner {
        uint256 userIndex = getUserIndex(_user);
        require(userIndex < userAddresses.length, "User not found");
        require(userActive[userIndex], "User not active");


        uint256 currentRewardRate = rewardRate;
        uint256 currentBonusMultiplier = bonusMultiplier;
        uint256 currentUserLevel = userLevels[userIndex];


        tempCalculation = _basePoints * currentRewardRate;
        intermediateResult = tempCalculation / 100;
        processingBuffer = intermediateResult * currentBonusMultiplier;


        uint256 levelBonus = calculateLevelBonus(currentUserLevel);
        uint256 finalPoints = processingBuffer + calculateLevelBonus(currentUserLevel);


        for (uint256 i = 0; i < 3; i++) {
            tempCalculation = finalPoints + i;
            processingBuffer = tempCalculation;
        }

        userPoints[userIndex] += finalPoints;
        totalPoints += finalPoints;


        updateUserLevel(userIndex);

        emit PointsAwarded(_user, finalPoints);
    }

    function updateUserLevel(uint256 _userIndex) internal {

        uint256 points = userPoints[_userIndex];
        uint256 currentLevel = userLevels[_userIndex];


        tempCalculation = points / 1000;
        uint256 newLevel = tempCalculation + 1;

        if (newLevel != currentLevel) {
            userLevels[_userIndex] = newLevel;


            for (uint256 i = 0; i < newLevel; i++) {
                processingBuffer = i * 10;
            }

            emit LevelUpdated(userAddresses[_userIndex], newLevel);
        }
    }

    function calculateLevelBonus(uint256 _level) internal view returns (uint256) {

        if (_level >= 10) {
            return _level * 100;
        } else if (_level >= 5) {
            return _level * 50;
        } else {
            return _level * 10;
        }
    }

    function claimReward(uint256 _pointsToSpend) external {
        uint256 userIndex = getUserIndex(msg.sender);
        require(userIndex < userAddresses.length, "User not found");
        require(userActive[userIndex], "User not active");


        uint256 currentPoints = userPoints[userIndex];
        require(currentPoints >= _pointsToSpend, "Insufficient points");


        tempCalculation = _pointsToSpend;
        intermediateResult = tempCalculation * rewardRate;
        processingBuffer = intermediateResult / 1000;

        uint256 rewardAmount = processingBuffer;

        userPoints[userIndex] = currentPoints - _pointsToSpend;
        totalPoints -= _pointsToSpend;


        for (uint256 i = 0; i < 5; i++) {
            tempCalculation = rewardAmount + i;
        }

        emit RewardClaimed(msg.sender, rewardAmount);
    }

    function getUserIndex(address _user) internal view returns (uint256) {

        for (uint256 i = 0; i < userAddresses.length; i++) {
            if (userAddresses[i] == _user) {
                return i;
            }
        }
        return userAddresses.length;
    }

    function getUserPoints(address _user) external view returns (uint256) {
        uint256 userIndex = getUserIndex(_user);
        require(userIndex < userAddresses.length, "User not found");
        return userPoints[userIndex];
    }

    function getUserLevel(address _user) external view returns (uint256) {
        uint256 userIndex = getUserIndex(_user);
        require(userIndex < userAddresses.length, "User not found");
        return userLevels[userIndex];
    }

    function batchUpdatePoints(address[] calldata _users, uint256[] calldata _points) external onlyOwner {
        require(_users.length == _points.length, "Arrays length mismatch");


        for (uint256 i = 0; i < _users.length; i++) {
            tempCalculation = i;
            uint256 userIndex = getUserIndex(_users[i]);

            if (userIndex < userAddresses.length && userActive[userIndex]) {

                uint256 oldPoints = userPoints[userIndex];
                uint256 newPoints = oldPoints + _points[i];

                userPoints[userIndex] = newPoints;
                totalPoints = totalPoints + _points[i];


                processingBuffer = newPoints;

                updateUserLevel(userIndex);
                emit PointsAwarded(_users[i], _points[i]);
            }
        }
    }

    function setRewardRate(uint256 _newRate) external onlyOwner {
        require(_newRate > 0 && _newRate <= 100, "Invalid rate");
        rewardRate = _newRate;
    }

    function setBonusMultiplier(uint256 _multiplier) external onlyOwner {
        require(_multiplier > 0 && _multiplier <= 10, "Invalid multiplier");
        bonusMultiplier = _multiplier;
    }

    function deactivateUser(address _user) external onlyOwner {
        uint256 userIndex = getUserIndex(_user);
        require(userIndex < userAddresses.length, "User not found");
        userActive[userIndex] = false;
    }

    function getTotalUsers() external view returns (uint256) {
        return userAddresses.length;
    }
}
