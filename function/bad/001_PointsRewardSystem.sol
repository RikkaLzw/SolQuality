
pragma solidity ^0.8.0;

contract PointsRewardSystem {
    mapping(address => uint256) public userPoints;
    mapping(address => bool) public isRegistered;
    mapping(address => uint256) public lastActivityTime;
    mapping(address => uint256) public userLevel;
    mapping(address => string) public userNickname;
    mapping(uint256 => uint256) public levelRequirements;

    address public owner;
    uint256 public totalPointsIssued;
    bool public systemActive;

    event PointsAwarded(address user, uint256 amount);
    event UserRegistered(address user, string nickname);
    event LevelUp(address user, uint256 newLevel);

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
        levelRequirements[1] = 100;
        levelRequirements[2] = 500;
        levelRequirements[3] = 1000;
        levelRequirements[4] = 2500;
        levelRequirements[5] = 5000;
    }




    function registerUserAndAwardPointsAndUpdateActivity(
        address userAddress,
        string memory nickname,
        uint256 initialPoints,
        uint256 bonusPoints,
        bool isVip,
        uint256 referralBonus
    ) public onlyOwner systemIsActive {

        if (!isRegistered[userAddress]) {
            isRegistered[userAddress] = true;
            userNickname[userAddress] = nickname;
            emit UserRegistered(userAddress, nickname);
        }


        uint256 totalAward = initialPoints;
        if (isVip) {
            totalAward += bonusPoints * 2;
        } else {
            totalAward += bonusPoints;
        }
        totalAward += referralBonus;

        userPoints[userAddress] += totalAward;
        totalPointsIssued += totalAward;


        lastActivityTime[userAddress] = block.timestamp;


        _checkAndUpdateUserLevel(userAddress);

        emit PointsAwarded(userAddress, totalAward);
    }


    function calculateUserRewards(address userAddress) public view returns (uint256) {
        if (!isRegistered[userAddress]) {
            return 0;
        }

        uint256 baseReward = userPoints[userAddress] / 10;
        uint256 levelMultiplier = userLevel[userAddress] + 1;

        return baseReward * levelMultiplier;
    }


    function processComplexPointsTransaction(
        address fromUser,
        address toUser,
        uint256 amount,
        bool isTransfer
    ) public systemIsActive {
        if (isRegistered[fromUser] && isRegistered[toUser]) {
            if (userPoints[fromUser] >= amount) {
                if (isTransfer) {
                    if (amount > 0) {
                        if (lastActivityTime[fromUser] + 86400 < block.timestamp) {
                            if (userLevel[fromUser] >= 2) {
                                if (amount <= userPoints[fromUser] / 2) {
                                    userPoints[fromUser] -= amount;
                                    userPoints[toUser] += amount;
                                    lastActivityTime[fromUser] = block.timestamp;
                                    lastActivityTime[toUser] = block.timestamp;

                                    if (userLevel[toUser] < 3) {
                                        uint256 bonus = amount / 10;
                                        userPoints[toUser] += bonus;
                                        totalPointsIssued += bonus;

                                        if (userPoints[toUser] >= levelRequirements[userLevel[toUser] + 1]) {
                                            userLevel[toUser]++;
                                            emit LevelUp(toUser, userLevel[toUser]);

                                            if (userLevel[toUser] == 3) {
                                                uint256 levelBonus = 100;
                                                userPoints[toUser] += levelBonus;
                                                totalPointsIssued += levelBonus;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function _checkAndUpdateUserLevel(address userAddress) internal {
        uint256 currentPoints = userPoints[userAddress];
        uint256 currentLevel = userLevel[userAddress];

        for (uint256 i = currentLevel + 1; i <= 5; i++) {
            if (currentPoints >= levelRequirements[i]) {
                userLevel[userAddress] = i;
                emit LevelUp(userAddress, i);
            } else {
                break;
            }
        }
    }

    function awardPoints(address user, uint256 amount) public onlyOwner systemIsActive {
        require(isRegistered[user], "User not registered");
        userPoints[user] += amount;
        totalPointsIssued += amount;
        lastActivityTime[user] = block.timestamp;
        _checkAndUpdateUserLevel(user);
        emit PointsAwarded(user, amount);
    }

    function deductPoints(address user, uint256 amount) public onlyOwner systemIsActive {
        require(isRegistered[user], "User not registered");
        require(userPoints[user] >= amount, "Insufficient points");
        userPoints[user] -= amount;
        lastActivityTime[user] = block.timestamp;
    }

    function toggleSystemStatus() public onlyOwner {
        systemActive = !systemActive;
    }

    function getUserInfo(address user) public view returns (
        uint256 points,
        uint256 level,
        string memory nickname,
        uint256 lastActivity,
        bool registered
    ) {
        return (
            userPoints[user],
            userLevel[user],
            userNickname[user],
            lastActivityTime[user],
            isRegistered[user]
        );
    }
}
