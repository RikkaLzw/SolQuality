
pragma solidity ^0.8.0;

contract PointsRewardSystem {
    address public owner;
    uint256 public totalPointsIssued;

    mapping(address => uint256) public userPoints;
    mapping(address => bool) public authorizedMinters;
    mapping(uint256 => RewardItem) public rewards;
    mapping(address => uint256[]) public userPurchaseHistory;

    struct RewardItem {
        string name;
        uint256 pointsCost;
        uint256 stock;
        bool active;
    }

    uint256 public nextRewardId = 1;


    event PointsEarned(address user, uint256 amount, string reason);
    event PointsSpent(address user, uint256 amount, uint256 rewardId);
    event RewardAdded(uint256 rewardId, string name, uint256 cost);


    error InvalidOperation();
    error NotAllowed();
    error InsufficientBalance();

    modifier onlyOwner() {

        require(msg.sender == owner);
        _;
    }

    modifier onlyAuthorized() {
        require(msg.sender == owner || authorizedMinters[msg.sender]);
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedMinters[msg.sender] = true;
    }

    function addAuthorizedMinter(address minter) external onlyOwner {
        require(minter != address(0));
        authorizedMinters[minter] = true;

    }

    function removeAuthorizedMinter(address minter) external onlyOwner {
        require(minter != owner);
        authorizedMinters[minter] = false;

    }

    function earnPoints(address user, uint256 amount, string memory reason) external onlyAuthorized {
        require(user != address(0));
        require(amount > 0);

        userPoints[user] += amount;
        totalPointsIssued += amount;

        emit PointsEarned(user, amount, reason);
    }

    function addReward(string memory name, uint256 pointsCost, uint256 stock) external onlyOwner {
        require(bytes(name).length > 0);
        require(pointsCost > 0);

        rewards[nextRewardId] = RewardItem({
            name: name,
            pointsCost: pointsCost,
            stock: stock,
            active: true
        });

        emit RewardAdded(nextRewardId, name, pointsCost);
        nextRewardId++;
    }

    function updateRewardStock(uint256 rewardId, uint256 newStock) external onlyOwner {
        require(rewards[rewardId].active);
        rewards[rewardId].stock = newStock;

    }

    function deactivateReward(uint256 rewardId) external onlyOwner {
        require(rewards[rewardId].active);
        rewards[rewardId].active = false;

    }

    function purchaseReward(uint256 rewardId) external {
        RewardItem storage reward = rewards[rewardId];


        require(reward.active);
        require(reward.stock > 0);
        require(userPoints[msg.sender] >= reward.pointsCost);

        userPoints[msg.sender] -= reward.pointsCost;
        reward.stock--;
        userPurchaseHistory[msg.sender].push(rewardId);

        emit PointsSpent(msg.sender, reward.pointsCost, rewardId);
    }

    function transferPoints(address to, uint256 amount) external {
        require(to != address(0));
        require(to != msg.sender);
        require(userPoints[msg.sender] >= amount);
        require(amount > 0);

        userPoints[msg.sender] -= amount;
        userPoints[to] += amount;

    }

    function burnPoints(address user, uint256 amount) external onlyAuthorized {
        require(user != address(0));
        require(userPoints[user] >= amount);
        require(amount > 0);

        userPoints[user] -= amount;

    }

    function getReward(uint256 rewardId) external view returns (RewardItem memory) {
        return rewards[rewardId];
    }

    function getUserPurchaseHistory(address user) external view returns (uint256[] memory) {
        return userPurchaseHistory[user];
    }

    function getUserPoints(address user) external view returns (uint256) {
        return userPoints[user];
    }

    function isAuthorizedMinter(address minter) external view returns (bool) {
        return authorizedMinters[minter];
    }

    function emergencyWithdraw() external onlyOwner {

        require(address(this).balance > 0);
        payable(owner).transfer(address(this).balance);

    }

    receive() external payable {}
}
