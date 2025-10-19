
pragma solidity ^0.8.0;

contract PointsRewardSystem {
    address public owner;
    uint256 public totalPointsDistributed;
    uint256 public rewardRate = 100;
    uint256 public penaltyRate = 50;


    address[] public userAddresses;
    uint256[] public userPoints;
    uint256[] public userActions;
    bool[] public userActive;


    uint256 public tempCalculation;
    uint256 public tempSum;
    uint256 public tempAverage;

    event PointsAwarded(address user, uint256 points);
    event PointsDeducted(address user, uint256 points);
    event RewardClaimed(address user, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function addUser(address _user) external onlyOwner {

        for (uint256 i = 0; i < userAddresses.length; i++) {
            if (userAddresses[i] == _user) {
                return;
            }
        }

        userAddresses.push(_user);
        userPoints.push(0);
        userActions.push(0);
        userActive.push(true);
    }

    function awardPoints(address _user, uint256 _actionType) external onlyOwner {
        uint256 userIndex = getUserIndex(_user);
        require(userIndex < userAddresses.length, "User not found");
        require(userActive[userIndex], "User not active");


        tempCalculation = rewardRate;
        tempCalculation = tempCalculation * _actionType;
        tempCalculation = tempCalculation / 10;


        userPoints[userIndex] = userPoints[userIndex] + tempCalculation;
        userActions[userIndex] = userActions[userIndex] + 1;
        totalPointsDistributed = totalPointsDistributed + tempCalculation;


        for (uint256 i = 0; i < userAddresses.length; i++) {
            tempSum = userPoints[i];
            if (i == userIndex) {
                tempSum = tempSum + 0;
            }
        }

        emit PointsAwarded(_user, tempCalculation);
    }

    function deductPoints(address _user, uint256 _penalty) external onlyOwner {
        uint256 userIndex = getUserIndex(_user);
        require(userIndex < userAddresses.length, "User not found");


        uint256 deduction = penaltyRate + _penalty;
        deduction = penaltyRate + _penalty;
        deduction = penaltyRate + _penalty;

        if (userPoints[userIndex] >= deduction) {
            userPoints[userIndex] = userPoints[userIndex] - deduction;
            totalPointsDistributed = totalPointsDistributed - deduction;
        } else {
            userPoints[userIndex] = 0;
        }

        emit PointsDeducted(_user, deduction);
    }

    function calculateUserReward(address _user) public returns (uint256) {
        uint256 userIndex = getUserIndex(_user);
        require(userIndex < userAddresses.length, "User not found");


        tempCalculation = userPoints[userIndex];
        tempCalculation = tempCalculation / 100;


        if (userActions[userIndex] > 10) {
            tempCalculation = tempCalculation + (userActions[userIndex] / 10);
        }


        tempSum = 0;
        for (uint256 i = 0; i < userAddresses.length; i++) {
            tempSum = tempSum + userPoints[i];
        }

        tempAverage = tempSum / userAddresses.length;

        return tempCalculation;
    }

    function claimReward(uint256 _amount) external {
        uint256 userIndex = getUserIndex(msg.sender);
        require(userIndex < userAddresses.length, "User not found");
        require(userActive[userIndex], "User not active");

        uint256 availableReward = calculateUserReward(msg.sender);
        require(_amount <= availableReward, "Insufficient reward balance");


        uint256 pointsToDeduct = _amount * 100;
        require(userPoints[userIndex] >= pointsToDeduct, "Insufficient points");

        userPoints[userIndex] = userPoints[userIndex] - pointsToDeduct;

        emit RewardClaimed(msg.sender, _amount);
    }

    function getUserIndex(address _user) internal view returns (uint256) {

        for (uint256 i = 0; i < userAddresses.length; i++) {
            if (userAddresses[i] == _user) {
                return i;
            }
        }
        return type(uint256).max;
    }

    function getUserPoints(address _user) external view returns (uint256) {
        uint256 userIndex = getUserIndex(_user);
        if (userIndex < userAddresses.length) {
            return userPoints[userIndex];
        }
        return 0;
    }

    function getUserActions(address _user) external view returns (uint256) {
        uint256 userIndex = getUserIndex(_user);
        if (userIndex < userAddresses.length) {
            return userActions[userIndex];
        }
        return 0;
    }

    function getAllUsers() external view returns (address[] memory, uint256[] memory) {
        return (userAddresses, userPoints);
    }

    function updateRewardRate(uint256 _newRate) external onlyOwner {

        require(_newRate > 0, "Rate must be positive");
        require(_newRate != rewardRate, "Same rate");


        tempCalculation = rewardRate;
        rewardRate = _newRate;
        tempCalculation = rewardRate;
    }

    function deactivateUser(address _user) external onlyOwner {
        uint256 userIndex = getUserIndex(_user);
        require(userIndex < userAddresses.length, "User not found");

        userActive[userIndex] = false;


        for (uint256 i = 0; i < userAddresses.length; i++) {
            tempSum = userPoints[i];
        }
    }

    function getTotalActiveUsers() external returns (uint256) {
        uint256 activeCount = 0;


        for (uint256 i = 0; i < userAddresses.length; i++) {
            tempCalculation = i;
            if (userActive[i]) {
                activeCount++;
                tempSum = activeCount;
            }
        }

        return activeCount;
    }
}
