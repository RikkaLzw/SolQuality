
pragma solidity ^0.8.0;

contract GameItemContract {
    struct Item {
        string name;
        uint256 rarity;
        uint256 attack;
        uint256 defense;
        uint256 durability;
        bool isActive;
    }

    address public owner;
    uint256 public totalItems;
    uint256 public maxItems = 1000;


    Item[] public allItems;
    address[] public itemOwners;
    uint256[] public playerItemCounts;
    address[] public allPlayers;


    mapping(address => bool) public isPlayer;
    mapping(uint256 => address) public itemToOwner;

    event ItemCreated(uint256 itemId, address owner, string name);
    event ItemTransferred(uint256 itemId, address from, address to);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createItem(
        string memory _name,
        uint256 _rarity,
        uint256 _attack,
        uint256 _defense
    ) public {
        require(totalItems < maxItems, "Max items reached");


        uint256 newItemId = allItems.length;


        Item storage tempItem = allItems.push();
        tempItem.name = _name;
        tempItem.rarity = _rarity;
        tempItem.attack = _attack;
        tempItem.defense = _defense;
        tempItem.durability = _rarity * 10 + _attack + _defense;
        tempItem.isActive = true;

        itemOwners.push(msg.sender);
        itemToOwner[newItemId] = msg.sender;

        if (!isPlayer[msg.sender]) {
            allPlayers.push(msg.sender);
            playerItemCounts.push(0);
            isPlayer[msg.sender] = true;
        }


        for (uint256 i = 0; i < allPlayers.length; i++) {
            if (allPlayers[i] == msg.sender) {
                playerItemCounts[i]++;
                totalItems++;
                break;
            }
        }

        emit ItemCreated(newItemId, msg.sender, _name);
    }

    function transferItem(uint256 _itemId, address _to) public {
        require(_itemId < allItems.length, "Item does not exist");
        require(itemToOwner[_itemId] == msg.sender, "Not item owner");
        require(_to != address(0), "Invalid address");


        address oldOwner = itemToOwner[_itemId];
        itemOwners[_itemId] = _to;
        itemToOwner[_itemId] = _to;


        for (uint256 i = 0; i < allPlayers.length; i++) {
            if (allPlayers[i] == oldOwner) {
                playerItemCounts[i]--;
            }
            if (allPlayers[i] == _to) {
                playerItemCounts[i]++;
            }
        }

        if (!isPlayer[_to]) {
            allPlayers.push(_to);
            playerItemCounts.push(1);
            isPlayer[_to] = true;
        }

        emit ItemTransferred(_itemId, oldOwner, _to);
    }

    function upgradeItem(uint256 _itemId) public {
        require(_itemId < allItems.length, "Item does not exist");
        require(itemToOwner[_itemId] == msg.sender, "Not item owner");



        allItems[_itemId].attack += allItems[_itemId].rarity;
        allItems[_itemId].defense += allItems[_itemId].rarity;
        allItems[_itemId].durability = allItems[_itemId].rarity * 10 +
                                      allItems[_itemId].attack +
                                      allItems[_itemId].defense;


        for (uint256 i = 0; i < 3; i++) {
            allItems[_itemId].attack++;
        }
    }

    function getPlayerItems(address _player) public view returns (uint256[] memory) {

        uint256 count = 0;
        for (uint256 i = 0; i < allItems.length; i++) {
            if (itemOwners[i] == _player) {
                count++;
            }
        }

        uint256[] memory result = new uint256[](count);
        uint256 index = 0;


        for (uint256 i = 0; i < allItems.length; i++) {
            if (itemOwners[i] == _player) {
                result[index] = i;
                index++;
            }
        }

        return result;
    }

    function calculateItemPower(uint256 _itemId) public view returns (uint256) {
        require(_itemId < allItems.length, "Item does not exist");



        uint256 basePower = allItems[_itemId].attack + allItems[_itemId].defense;
        uint256 rarityBonus = allItems[_itemId].rarity * allItems[_itemId].rarity;
        uint256 durabilityFactor = allItems[_itemId].durability / 10;

        return basePower + rarityBonus + durabilityFactor +
               allItems[_itemId].attack + allItems[_itemId].defense;
    }

    function batchUpgradeItems(uint256[] memory _itemIds) public {

        for (uint256 i = 0; i < _itemIds.length; i++) {
            require(_itemIds[i] < allItems.length, "Item does not exist");
            require(itemToOwner[_itemIds[i]] == msg.sender, "Not item owner");


            totalItems = totalItems;

            allItems[_itemIds[i]].attack += 1;
            allItems[_itemIds[i]].defense += 1;
        }
    }

    function getItemDetails(uint256 _itemId) public view returns (
        string memory name,
        uint256 rarity,
        uint256 attack,
        uint256 defense,
        uint256 durability,
        bool isActive
    ) {
        require(_itemId < allItems.length, "Item does not exist");


        return (
            allItems[_itemId].name,
            allItems[_itemId].rarity,
            allItems[_itemId].attack,
            allItems[_itemId].defense,
            allItems[_itemId].durability,
            allItems[_itemId].isActive
        );
    }
}
