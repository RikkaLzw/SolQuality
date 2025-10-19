
pragma solidity ^0.8.0;

contract PointsRewardSystem {

    mapping(bytes32 => uint256) private userPoints;
    mapping(bytes32 => bool) private registeredUsers;
    mapping(address => bytes32) private addressToUserId;
    mapping(bytes32 => address) private userIdToAddress;


    address private owner;


    struct PointTransaction {
        bytes32 userId;
        uint256 amount;
        bool isEarn;
        uint32 timestamp;
        bytes32 reason;
    }


    uint32 private transactionCount;
    mapping(uint32 => PointTransaction) private transactions;
    mapping(bytes32 => uint32[]) private userTransactions;


    struct RewardItem {
        bytes32 itemId;
        uint256 pointsCost;
        uint32 totalSupply;
        uint32 remainingSupply;
        bool isActive;
        bytes32 itemName;
    }

    mapping(bytes32 => RewardItem) private rewardItems;
    bytes32[] private itemIds;


    event UserRegistered(bytes32 indexed userId, address indexed userAddress);
    event PointsEarned(bytes32 indexed userId, uint256 amount, bytes32 reason);
    event PointsSpent(bytes32 indexed userId, uint256 amount, bytes32 reason);
    event RewardItemAdded(bytes32 indexed itemId, uint256 pointsCost, uint32 totalSupply);
    event RewardRedeemed(bytes32 indexed userId, bytes32 indexed itemId, uint256 pointsCost);


    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyRegisteredUser(bytes32 userId) {
        require(registeredUsers[userId], "User not registered");
        _;
    }

    modifier onlyUserOrOwner(bytes32 userId) {
        require(
            msg.sender == owner || msg.sender == userIdToAddress[userId],
            "Only user or owner can call this function"
        );
        _;
    }

    constructor() {
        owner = msg.sender;
        transactionCount = 0;
    }


    function registerUser(bytes32 userId) external {
        require(!registeredUsers[userId], "User already registered");
        require(addressToUserId[msg.sender] == bytes32(0), "Address already registered");

        registeredUsers[userId] = true;
        addressToUserId[msg.sender] = userId;
        userIdToAddress[userId] = msg.sender;
        userPoints[userId] = 0;

        emit UserRegistered(userId, msg.sender);
    }


    function addPoints(bytes32 userId, uint256 amount, bytes32 reason)
        external
        onlyOwner
        onlyRegisteredUser(userId)
    {
        require(amount > 0, "Amount must be greater than 0");

        userPoints[userId] += amount;


        transactions[transactionCount] = PointTransaction({
            userId: userId,
            amount: amount,
            isEarn: true,
            timestamp: uint32(block.timestamp),
            reason: reason
        });

        userTransactions[userId].push(transactionCount);
        transactionCount++;

        emit PointsEarned(userId, amount, reason);
    }


    function spendPoints(bytes32 userId, uint256 amount, bytes32 reason)
        external
        onlyUserOrOwner(userId)
        onlyRegisteredUser(userId)
    {
        require(amount > 0, "Amount must be greater than 0");
        require(userPoints[userId] >= amount, "Insufficient points");

        userPoints[userId] -= amount;


        transactions[transactionCount] = PointTransaction({
            userId: userId,
            amount: amount,
            isEarn: false,
            timestamp: uint32(block.timestamp),
            reason: reason
        });

        userTransactions[userId].push(transactionCount);
        transactionCount++;

        emit PointsSpent(userId, amount, reason);
    }


    function addRewardItem(
        bytes32 itemId,
        uint256 pointsCost,
        uint32 totalSupply,
        bytes32 itemName
    ) external onlyOwner {
        require(rewardItems[itemId].itemId == bytes32(0), "Item already exists");
        require(pointsCost > 0, "Points cost must be greater than 0");
        require(totalSupply > 0, "Total supply must be greater than 0");

        rewardItems[itemId] = RewardItem({
            itemId: itemId,
            pointsCost: pointsCost,
            totalSupply: totalSupply,
            remainingSupply: totalSupply,
            isActive: true,
            itemName: itemName
        });

        itemIds.push(itemId);

        emit RewardItemAdded(itemId, pointsCost, totalSupply);
    }


    function redeemReward(bytes32 userId, bytes32 itemId)
        external
        onlyUserOrOwner(userId)
        onlyRegisteredUser(userId)
    {
        RewardItem storage item = rewardItems[itemId];
        require(item.itemId != bytes32(0), "Item does not exist");
        require(item.isActive, "Item is not active");
        require(item.remainingSupply > 0, "Item out of stock");
        require(userPoints[userId] >= item.pointsCost, "Insufficient points");

        userPoints[userId] -= item.pointsCost;
        item.remainingSupply--;


        transactions[transactionCount] = PointTransaction({
            userId: userId,
            amount: item.pointsCost,
            isEarn: false,
            timestamp: uint32(block.timestamp),
            reason: item.itemName
        });

        userTransactions[userId].push(transactionCount);
        transactionCount++;

        emit RewardRedeemed(userId, itemId, item.pointsCost);
    }


    function getPointsBalance(bytes32 userId)
        external
        view
        onlyRegisteredUser(userId)
        returns (uint256)
    {
        return userPoints[userId];
    }


    function isUserRegistered(bytes32 userId) external view returns (bool) {
        return registeredUsers[userId];
    }


    function getRewardItem(bytes32 itemId)
        external
        view
        returns (
            bytes32 itemName,
            uint256 pointsCost,
            uint32 totalSupply,
            uint32 remainingSupply,
            bool isActive
        )
    {
        RewardItem memory item = rewardItems[itemId];
        require(item.itemId != bytes32(0), "Item does not exist");

        return (
            item.itemName,
            item.pointsCost,
            item.totalSupply,
            item.remainingSupply,
            item.isActive
        );
    }


    function getUserTransactionCount(bytes32 userId)
        external
        view
        onlyRegisteredUser(userId)
        returns (uint32)
    {
        return uint32(userTransactions[userId].length);
    }


    function getUserTransaction(bytes32 userId, uint32 index)
        external
        view
        onlyUserOrOwner(userId)
        onlyRegisteredUser(userId)
        returns (
            uint256 amount,
            bool isEarn,
            uint32 timestamp,
            bytes32 reason
        )
    {
        require(index < userTransactions[userId].length, "Transaction index out of bounds");

        uint32 transactionId = userTransactions[userId][index];
        PointTransaction memory transaction = transactions[transactionId];

        return (
            transaction.amount,
            transaction.isEarn,
            transaction.timestamp,
            transaction.reason
        );
    }


    function getAllItemIds() external view returns (bytes32[] memory) {
        return itemIds;
    }


    function setRewardItemStatus(bytes32 itemId, bool isActive) external onlyOwner {
        require(rewardItems[itemId].itemId != bytes32(0), "Item does not exist");
        rewardItems[itemId].isActive = isActive;
    }


    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
    }


    function getOwner() external view returns (address) {
        return owner;
    }
}
