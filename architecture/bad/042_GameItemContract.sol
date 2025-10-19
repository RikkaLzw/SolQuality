
pragma solidity ^0.8.0;

contract GameItemContract {
    address public owner;
    uint256 public totalItems;
    uint256 public nextItemId;

    struct GameItem {
        uint256 id;
        string name;
        uint256 rarity;
        uint256 attack;
        uint256 defense;
        uint256 durability;
        address currentOwner;
        bool exists;
    }

    mapping(uint256 => GameItem) public items;
    mapping(address => uint256[]) public playerItems;
    mapping(address => uint256) public playerItemCount;
    mapping(uint256 => bool) public itemExists;
    mapping(address => bool) public isPlayer;

    event ItemCreated(uint256 itemId, string name, address owner);
    event ItemTransferred(uint256 itemId, address from, address to);
    event ItemUpgraded(uint256 itemId, uint256 newAttack, uint256 newDefense);

    constructor() {
        owner = msg.sender;
        nextItemId = 1;
        totalItems = 0;
    }

    function createSword(string memory name, address player) external {
        if (msg.sender != owner) {
            revert("Only owner can create items");
        }
        if (player == address(0)) {
            revert("Invalid player address");
        }

        uint256 itemId = nextItemId;
        nextItemId++;
        totalItems++;

        items[itemId] = GameItem({
            id: itemId,
            name: name,
            rarity: 1,
            attack: 10,
            defense: 2,
            durability: 100,
            currentOwner: player,
            exists: true
        });

        playerItems[player].push(itemId);
        playerItemCount[player]++;
        itemExists[itemId] = true;
        isPlayer[player] = true;

        emit ItemCreated(itemId, name, player);
    }

    function createShield(string memory name, address player) external {
        if (msg.sender != owner) {
            revert("Only owner can create items");
        }
        if (player == address(0)) {
            revert("Invalid player address");
        }

        uint256 itemId = nextItemId;
        nextItemId++;
        totalItems++;

        items[itemId] = GameItem({
            id: itemId,
            name: name,
            rarity: 1,
            attack: 2,
            defense: 15,
            durability: 100,
            currentOwner: player,
            exists: true
        });

        playerItems[player].push(itemId);
        playerItemCount[player]++;
        itemExists[itemId] = true;
        isPlayer[player] = true;

        emit ItemCreated(itemId, name, player);
    }

    function createArmor(string memory name, address player) external {
        if (msg.sender != owner) {
            revert("Only owner can create items");
        }
        if (player == address(0)) {
            revert("Invalid player address");
        }

        uint256 itemId = nextItemId;
        nextItemId++;
        totalItems++;

        items[itemId] = GameItem({
            id: itemId,
            name: name,
            rarity: 2,
            attack: 0,
            defense: 25,
            durability: 100,
            currentOwner: player,
            exists: true
        });

        playerItems[player].push(itemId);
        playerItemCount[player]++;
        itemExists[itemId] = true;
        isPlayer[player] = true;

        emit ItemCreated(itemId, name, player);
    }

    function transferItem(uint256 itemId, address to) external {
        if (!itemExists[itemId]) {
            revert("Item does not exist");
        }
        if (items[itemId].currentOwner != msg.sender) {
            revert("Not item owner");
        }
        if (to == address(0)) {
            revert("Invalid recipient");
        }
        if (to == msg.sender) {
            revert("Cannot transfer to self");
        }

        address from = msg.sender;


        uint256[] storage senderItems = playerItems[from];
        for (uint256 i = 0; i < senderItems.length; i++) {
            if (senderItems[i] == itemId) {
                senderItems[i] = senderItems[senderItems.length - 1];
                senderItems.pop();
                break;
            }
        }
        playerItemCount[from]--;


        playerItems[to].push(itemId);
        playerItemCount[to]++;
        isPlayer[to] = true;

        items[itemId].currentOwner = to;

        emit ItemTransferred(itemId, from, to);
    }

    function upgradeItemAttack(uint256 itemId) external {
        if (!itemExists[itemId]) {
            revert("Item does not exist");
        }
        if (items[itemId].currentOwner != msg.sender) {
            revert("Not item owner");
        }
        if (items[itemId].durability < 10) {
            revert("Item too damaged to upgrade");
        }

        items[itemId].attack += 5;
        items[itemId].durability -= 10;

        emit ItemUpgraded(itemId, items[itemId].attack, items[itemId].defense);
    }

    function upgradeItemDefense(uint256 itemId) external {
        if (!itemExists[itemId]) {
            revert("Item does not exist");
        }
        if (items[itemId].currentOwner != msg.sender) {
            revert("Not item owner");
        }
        if (items[itemId].durability < 10) {
            revert("Item too damaged to upgrade");
        }

        items[itemId].defense += 5;
        items[itemId].durability -= 10;

        emit ItemUpgraded(itemId, items[itemId].attack, items[itemId].defense);
    }

    function repairItem(uint256 itemId) external {
        if (!itemExists[itemId]) {
            revert("Item does not exist");
        }
        if (items[itemId].currentOwner != msg.sender) {
            revert("Not item owner");
        }
        if (items[itemId].durability >= 100) {
            revert("Item already at full durability");
        }

        items[itemId].durability = 100;
    }

    function useItem(uint256 itemId) external {
        if (!itemExists[itemId]) {
            revert("Item does not exist");
        }
        if (items[itemId].currentOwner != msg.sender) {
            revert("Not item owner");
        }
        if (items[itemId].durability == 0) {
            revert("Item is broken");
        }

        if (items[itemId].durability > 0) {
            items[itemId].durability--;
        }
    }

    function getPlayerItems(address player) external view returns (uint256[] memory) {
        if (!isPlayer[player]) {
            revert("Not a registered player");
        }

        return playerItems[player];
    }

    function getItemDetails(uint256 itemId) external view returns (
        uint256 id,
        string memory name,
        uint256 rarity,
        uint256 attack,
        uint256 defense,
        uint256 durability,
        address currentOwner
    ) {
        if (!itemExists[itemId]) {
            revert("Item does not exist");
        }

        GameItem memory item = items[itemId];
        return (
            item.id,
            item.name,
            item.rarity,
            item.attack,
            item.defense,
            item.durability,
            item.currentOwner
        );
    }

    function changeOwner(address newOwner) external {
        if (msg.sender != owner) {
            revert("Only current owner can change ownership");
        }
        if (newOwner == address(0)) {
            revert("Invalid new owner address");
        }

        owner = newOwner;
    }

    function getTotalItems() external view returns (uint256) {
        return totalItems;
    }

    function getPlayerItemCount(address player) external view returns (uint256) {
        return playerItemCount[player];
    }

    function isItemOwner(uint256 itemId, address user) external view returns (bool) {
        if (!itemExists[itemId]) {
            return false;
        }
        return items[itemId].currentOwner == user;
    }

    function bulkCreateSwords(string[] memory names, address[] memory players) external {
        if (msg.sender != owner) {
            revert("Only owner can create items");
        }
        if (names.length != players.length) {
            revert("Arrays length mismatch");
        }

        for (uint256 i = 0; i < names.length; i++) {
            if (players[i] == address(0)) {
                revert("Invalid player address");
            }

            uint256 itemId = nextItemId;
            nextItemId++;
            totalItems++;

            items[itemId] = GameItem({
                id: itemId,
                name: names[i],
                rarity: 1,
                attack: 10,
                defense: 2,
                durability: 100,
                currentOwner: players[i],
                exists: true
            });

            playerItems[players[i]].push(itemId);
            playerItemCount[players[i]]++;
            itemExists[itemId] = true;
            isPlayer[players[i]] = true;

            emit ItemCreated(itemId, names[i], players[i]);
        }
    }
}
