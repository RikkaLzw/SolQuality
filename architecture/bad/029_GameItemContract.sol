
pragma solidity ^0.8.0;

contract GameItemContract {
    address public owner;
    mapping(address => mapping(uint256 => uint256)) public playerItems;
    mapping(uint256 => string) public itemNames;
    mapping(uint256 => uint256) public itemPrices;
    mapping(uint256 => bool) public itemExists;
    mapping(address => uint256) public playerGold;
    mapping(address => bool) public isPlayer;
    uint256 public totalItems;
    uint256 public totalPlayers;

    event ItemPurchased(address player, uint256 itemId, uint256 quantity);
    event ItemSold(address player, uint256 itemId, uint256 quantity);
    event ItemCrafted(address player, uint256 itemId, uint256 quantity);
    event GoldAdded(address player, uint256 amount);

    constructor() {
        owner = msg.sender;
        totalItems = 0;
        totalPlayers = 0;


        itemNames[1] = "Iron Sword";
        itemPrices[1] = 100;
        itemExists[1] = true;
        totalItems++;

        itemNames[2] = "Health Potion";
        itemPrices[2] = 50;
        itemExists[2] = true;
        totalItems++;

        itemNames[3] = "Magic Staff";
        itemPrices[3] = 200;
        itemExists[3] = true;
        totalItems++;

        itemNames[4] = "Shield";
        itemPrices[4] = 150;
        itemExists[4] = true;
        totalItems++;

        itemNames[5] = "Bow";
        itemPrices[5] = 120;
        itemExists[5] = true;
        totalItems++;
    }

    function registerPlayer() external {

        if (msg.sender != owner) {
            revert("Only owner can register players");
        }

        if (!isPlayer[msg.sender]) {
            isPlayer[msg.sender] = true;
            totalPlayers++;
            playerGold[msg.sender] = 1000;
        }
    }

    function addPlayer(address player) external {

        if (msg.sender != owner) {
            revert("Only owner can add players");
        }

        if (!isPlayer[player]) {
            isPlayer[player] = true;
            totalPlayers++;
            playerGold[player] = 1000;
        }
    }

    function purchaseItem(uint256 itemId, uint256 quantity) external {

        if (!isPlayer[msg.sender]) {
            revert("Player not registered");
        }

        if (!itemExists[itemId]) {
            revert("Item does not exist");
        }

        if (quantity == 0) {
            revert("Quantity must be greater than 0");
        }

        uint256 totalCost = itemPrices[itemId] * quantity;

        if (playerGold[msg.sender] < totalCost) {
            revert("Insufficient gold");
        }

        playerGold[msg.sender] -= totalCost;
        playerItems[msg.sender][itemId] += quantity;

        emit ItemPurchased(msg.sender, itemId, quantity);
    }

    function sellItem(uint256 itemId, uint256 quantity) external {

        if (!isPlayer[msg.sender]) {
            revert("Player not registered");
        }

        if (!itemExists[itemId]) {
            revert("Item does not exist");
        }

        if (quantity == 0) {
            revert("Quantity must be greater than 0");
        }

        if (playerItems[msg.sender][itemId] < quantity) {
            revert("Insufficient items");
        }

        uint256 sellPrice = (itemPrices[itemId] * quantity * 80) / 100;

        playerItems[msg.sender][itemId] -= quantity;
        playerGold[msg.sender] += sellPrice;

        emit ItemSold(msg.sender, itemId, quantity);
    }

    function craftItem(uint256 itemId, uint256 quantity) external {

        if (!isPlayer[msg.sender]) {
            revert("Player not registered");
        }

        if (!itemExists[itemId]) {
            revert("Item does not exist");
        }

        if (quantity == 0) {
            revert("Quantity must be greater than 0");
        }


        if (itemId == 1) {
            if (playerItems[msg.sender][6] < quantity * 2) {
                revert("Insufficient materials");
            }
            playerItems[msg.sender][6] -= quantity * 2;
        } else if (itemId == 2) {
            if (playerItems[msg.sender][7] < quantity * 1) {
                revert("Insufficient materials");
            }
            playerItems[msg.sender][7] -= quantity * 1;
        } else if (itemId == 3) {
            if (playerItems[msg.sender][8] < quantity * 3) {
                revert("Insufficient materials");
            }
            playerItems[msg.sender][8] -= quantity * 3;
        } else {
            revert("Item cannot be crafted");
        }

        playerItems[msg.sender][itemId] += quantity;

        emit ItemCrafted(msg.sender, itemId, quantity);
    }

    function addGold(address player, uint256 amount) external {

        if (msg.sender != owner) {
            revert("Only owner can add gold");
        }


        if (!isPlayer[player]) {
            revert("Player not registered");
        }

        if (amount == 0) {
            revert("Amount must be greater than 0");
        }

        playerGold[player] += amount;

        emit GoldAdded(player, amount);
    }

    function addItem(uint256 itemId, string memory name, uint256 price) external {

        if (msg.sender != owner) {
            revert("Only owner can add items");
        }

        if (itemExists[itemId]) {
            revert("Item already exists");
        }

        if (price == 0) {
            revert("Price must be greater than 0");
        }

        itemNames[itemId] = name;
        itemPrices[itemId] = price;
        itemExists[itemId] = true;
        totalItems++;
    }

    function giveItemToPlayer(address player, uint256 itemId, uint256 quantity) external {

        if (msg.sender != owner) {
            revert("Only owner can give items");
        }


        if (!isPlayer[player]) {
            revert("Player not registered");
        }

        if (!itemExists[itemId]) {
            revert("Item does not exist");
        }

        if (quantity == 0) {
            revert("Quantity must be greater than 0");
        }

        playerItems[player][itemId] += quantity;
    }

    function removeItemFromPlayer(address player, uint256 itemId, uint256 quantity) external {

        if (msg.sender != owner) {
            revert("Only owner can remove items");
        }


        if (!isPlayer[player]) {
            revert("Player not registered");
        }

        if (!itemExists[itemId]) {
            revert("Item does not exist");
        }

        if (quantity == 0) {
            revert("Quantity must be greater than 0");
        }

        if (playerItems[player][itemId] < quantity) {
            revert("Insufficient items");
        }

        playerItems[player][itemId] -= quantity;
    }

    function updateItemPrice(uint256 itemId, uint256 newPrice) external {

        if (msg.sender != owner) {
            revert("Only owner can update prices");
        }

        if (!itemExists[itemId]) {
            revert("Item does not exist");
        }

        if (newPrice == 0) {
            revert("Price must be greater than 0");
        }

        itemPrices[itemId] = newPrice;
    }

    function getPlayerItemCount(address player, uint256 itemId) external view returns (uint256) {
        return playerItems[player][itemId];
    }

    function getPlayerGold(address player) external view returns (uint256) {
        return playerGold[player];
    }

    function getItemInfo(uint256 itemId) external view returns (string memory name, uint256 price, bool exists) {
        return (itemNames[itemId], itemPrices[itemId], itemExists[itemId]);
    }

    function isPlayerRegistered(address player) external view returns (bool) {
        return isPlayer[player];
    }

    function getTotalItems() external view returns (uint256) {
        return totalItems;
    }

    function getTotalPlayers() external view returns (uint256) {
        return totalPlayers;
    }

    function transferOwnership(address newOwner) external {

        if (msg.sender != owner) {
            revert("Only owner can transfer ownership");
        }

        if (newOwner == address(0)) {
            revert("New owner cannot be zero address");
        }

        owner = newOwner;
    }

    function emergencyWithdraw() external {

        if (msg.sender != owner) {
            revert("Only owner can withdraw");
        }

        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {}

    fallback() external payable {}
}
