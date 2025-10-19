
pragma solidity ^0.8.0;

contract PointsSystemContract {
    mapping(address => uint256) public userPoints;
    mapping(address => bool) public isAdmin;
    mapping(address => uint256) public userLevel;
    mapping(address => uint256) public lastActivityTime;
    mapping(address => string) public userNickname;
    mapping(uint256 => uint256) public levelRequirements;

    address public owner;
    uint256 public totalPointsIssued;
    bool public systemActive;

    event PointsAwarded(address indexed user, uint256 amount);
    event LevelUp(address indexed user, uint256 newLevel);

    constructor() {
        owner = msg.sender;
        isAdmin[msg.sender] = true;
        systemActive = true;
        levelRequirements[1] = 100;
        levelRequirements[2] = 500;
        levelRequirements[3] = 1000;
        levelRequirements[4] = 2000;
        levelRequirements[5] = 5000;
    }




    function manageUserDataAndPoints(
        address user,
        uint256 pointsToAdd,
        string memory nickname,
        bool shouldUpdateLevel,
        bool shouldUpdateActivity,
        uint256 bonusMultiplier
    ) public {
        require(isAdmin[msg.sender], "Not admin");
        require(systemActive, "System inactive");

        if (pointsToAdd > 0) {
            if (bonusMultiplier > 0) {
                if (bonusMultiplier <= 10) {
                    uint256 finalPoints = pointsToAdd * bonusMultiplier;
                    if (finalPoints <= 10000) {
                        userPoints[user] += finalPoints;
                        totalPointsIssued += finalPoints;
                        emit PointsAwarded(user, finalPoints);

                        if (shouldUpdateLevel) {
                            uint256 currentPoints = userPoints[user];
                            if (currentPoints >= levelRequirements[5]) {
                                if (userLevel[user] < 5) {
                                    userLevel[user] = 5;
                                    emit LevelUp(user, 5);
                                }
                            } else if (currentPoints >= levelRequirements[4]) {
                                if (userLevel[user] < 4) {
                                    userLevel[user] = 4;
                                    emit LevelUp(user, 4);
                                }
                            } else if (currentPoints >= levelRequirements[3]) {
                                if (userLevel[user] < 3) {
                                    userLevel[user] = 3;
                                    emit LevelUp(user, 3);
                                }
                            } else if (currentPoints >= levelRequirements[2]) {
                                if (userLevel[user] < 2) {
                                    userLevel[user] = 2;
                                    emit LevelUp(user, 2);
                                }
                            } else if (currentPoints >= levelRequirements[1]) {
                                if (userLevel[user] < 1) {
                                    userLevel[user] = 1;
                                    emit LevelUp(user, 1);
                                }
                            }
                        }
                    }
                }
            }
        }

        if (bytes(nickname).length > 0) {
            userNickname[user] = nickname;
        }

        if (shouldUpdateActivity) {
            lastActivityTime[user] = block.timestamp;
        }
    }


    function getUserInfo(address user) public view returns (uint256, uint256, string memory, uint256, bool) {
        return (
            userPoints[user],
            userLevel[user],
            userNickname[user],
            lastActivityTime[user],
            lastActivityTime[user] > 0
        );
    }


    function calculateLevelFromPoints(uint256 points) public pure returns (uint256) {
        if (points >= 5000) return 5;
        if (points >= 2000) return 4;
        if (points >= 1000) return 3;
        if (points >= 500) return 2;
        if (points >= 100) return 1;
        return 0;
    }

    function addAdmin(address newAdmin) public {
        require(msg.sender == owner, "Only owner");
        isAdmin[newAdmin] = true;
    }

    function removeAdmin(address admin) public {
        require(msg.sender == owner, "Only owner");
        require(admin != owner, "Cannot remove owner");
        isAdmin[admin] = false;
    }

    function setSystemActive(bool active) public {
        require(msg.sender == owner, "Only owner");
        systemActive = active;
    }

    function transferPoints(address from, address to, uint256 amount) public {
        require(msg.sender == from || isAdmin[msg.sender], "Not authorized");
        require(userPoints[from] >= amount, "Insufficient points");
        require(to != address(0), "Invalid recipient");

        userPoints[from] -= amount;
        userPoints[to] += amount;
    }

    function burnPoints(address user, uint256 amount) public {
        require(isAdmin[msg.sender], "Not admin");
        require(userPoints[user] >= amount, "Insufficient points");

        userPoints[user] -= amount;
        totalPointsIssued -= amount;
    }

    function setLevelRequirement(uint256 level, uint256 requirement) public {
        require(msg.sender == owner, "Only owner");
        require(level > 0 && level <= 5, "Invalid level");
        levelRequirements[level] = requirement;
    }

    function getSystemStats() public view returns (uint256, uint256, bool) {
        return (totalPointsIssued, block.timestamp, systemActive);
    }
}
