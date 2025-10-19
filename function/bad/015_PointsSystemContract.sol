
pragma solidity ^0.8.0;

contract PointsSystemContract {
    mapping(address => uint256) public userPoints;
    mapping(address => bool) public isRegistered;
    mapping(address => uint256) public userLevel;
    mapping(address => uint256) public lastActivityTime;
    mapping(address => string) public userNickname;
    mapping(uint256 => uint256) public levelThresholds;

    address public owner;
    uint256 public totalSupply;
    bool public systemActive;

    event PointsAwarded(address user, uint256 amount);
    event UserRegistered(address user, string nickname);
    event LevelUpdated(address user, uint256 newLevel);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier systemIsActive() {
        require(systemActive, "System inactive");
        _;
    }

    constructor() {
        owner = msg.sender;
        systemActive = true;
        levelThresholds[1] = 100;
        levelThresholds[2] = 500;
        levelThresholds[3] = 1000;
        levelThresholds[4] = 2500;
        levelThresholds[5] = 5000;
    }




    function registerAndAwardPointsAndUpdateLevel(
        address user,
        string memory nickname,
        uint256 pointsToAward,
        bool shouldUpdateActivity,
        uint256 bonusMultiplier,
        bool forceRegistration
    ) public onlyOwner systemIsActive {

        if (!isRegistered[user] || forceRegistration) {
            isRegistered[user] = true;
            userNickname[user] = nickname;
            emit UserRegistered(user, nickname);
        }


        if (pointsToAward > 0) {
            uint256 finalPoints = pointsToAward * bonusMultiplier;
            userPoints[user] += finalPoints;
            totalSupply += finalPoints;
            emit PointsAwarded(user, finalPoints);
        }


        if (shouldUpdateActivity) {
            lastActivityTime[user] = block.timestamp;
        }


        updateUserLevelInternal(user);
    }



    function complexPointsCalculationAndDistribution(address[] memory users, uint256 basePoints) public onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            if (isRegistered[users[i]]) {
                if (userPoints[users[i]] > 0) {
                    if (userLevel[users[i]] >= 1) {
                        if (lastActivityTime[users[i]] > 0) {
                            if (block.timestamp - lastActivityTime[users[i]] < 86400) {
                                if (userLevel[users[i]] == 1) {
                                    userPoints[users[i]] += basePoints;
                                } else if (userLevel[users[i]] == 2) {
                                    userPoints[users[i]] += basePoints * 2;
                                } else if (userLevel[users[i]] == 3) {
                                    userPoints[users[i]] += basePoints * 3;
                                } else if (userLevel[users[i]] == 4) {
                                    userPoints[users[i]] += basePoints * 4;
                                } else if (userLevel[users[i]] == 5) {
                                    userPoints[users[i]] += basePoints * 5;
                                } else {
                                    userPoints[users[i]] += basePoints * 6;
                                }
                                totalSupply += userPoints[users[i]] > 1000 ? basePoints * 2 : basePoints;
                                emit PointsAwarded(users[i], basePoints);
                            }
                        }
                    }
                }
            }
        }
    }


    function updateUserLevelInternal(address user) public {
        uint256 points = userPoints[user];
        uint256 newLevel = 0;

        if (points >= levelThresholds[5]) {
            newLevel = 5;
        } else if (points >= levelThresholds[4]) {
            newLevel = 4;
        } else if (points >= levelThresholds[3]) {
            newLevel = 3;
        } else if (points >= levelThresholds[2]) {
            newLevel = 2;
        } else if (points >= levelThresholds[1]) {
            newLevel = 1;
        }

        if (newLevel != userLevel[user]) {
            userLevel[user] = newLevel;
            emit LevelUpdated(user, newLevel);
        }
    }

    function awardPoints(address user, uint256 amount) external onlyOwner systemIsActive {
        require(isRegistered[user], "User not registered");
        userPoints[user] += amount;
        totalSupply += amount;
        lastActivityTime[user] = block.timestamp;
        emit PointsAwarded(user, amount);
        updateUserLevelInternal(user);
    }

    function deductPoints(address user, uint256 amount) external onlyOwner systemIsActive {
        require(isRegistered[user], "User not registered");
        require(userPoints[user] >= amount, "Insufficient points");
        userPoints[user] -= amount;
        totalSupply -= amount;
        updateUserLevelInternal(user);
    }

    function registerUser(address user, string memory nickname) external onlyOwner {
        require(!isRegistered[user], "User already registered");
        isRegistered[user] = true;
        userNickname[user] = nickname;
        lastActivityTime[user] = block.timestamp;
        emit UserRegistered(user, nickname);
    }

    function getUserInfo(address user) external view returns (uint256, uint256, string memory, uint256, bool) {
        return (
            userPoints[user],
            userLevel[user],
            userNickname[user],
            lastActivityTime[user],
            isRegistered[user]
        );
    }

    function setSystemActive(bool active) external onlyOwner {
        systemActive = active;
    }

    function updateLevelThreshold(uint256 level, uint256 threshold) external onlyOwner {
        require(level > 0 && level <= 5, "Invalid level");
        levelThresholds[level] = threshold;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }
}
