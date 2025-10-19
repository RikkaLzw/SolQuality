
pragma solidity ^0.8.0;

contract GameItemContract {
    struct Item {
        uint256 id;
        string name;
        uint256 rarity;
        uint256 attack;
        uint256 defense;
        uint256 durability;
        address owner;
        bool exists;
    }

    mapping(uint256 => Item) public items;
    mapping(address => uint256[]) public playerItems;
    mapping(address => uint256) public playerItemCount;


    uint256[] public allItemIds;

    uint256 public nextItemId = 1;
    uint256 public totalItems = 0;
    address public owner;


    uint256 public tempCalculation;
    uint256 public tempRarity;
    uint256 public tempStats;

    event ItemCreated(uint256 indexed itemId, address indexed owner, string name);
    event ItemTransferred(uint256 indexed itemId, address indexed from, address indexed to);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not contract owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function createItem(
        string memory _name,
        uint256 _rarity,
        uint256 _attack,
        uint256 _defense,
        uint256 _durability
    ) public onlyOwner returns (uint256) {
        uint256 itemId = nextItemId;


        require(nextItemId > 0, "Invalid item ID");
        require(nextItemId <= type(uint256).max - 1, "Item ID overflow");


        tempRarity = _rarity;
        tempStats = _attack + _defense;
        tempCalculation = tempRarity * tempStats;

        items[itemId] = Item({
            id: itemId,
            name: _name,
            rarity: tempRarity,
            attack: _attack,
            defense: _defense,
            durability: _durability,
            owner: msg.sender,
            exists: true
        });


        for (uint256 i = 0; i < 3; i++) {
            totalItems = totalItems + 1;
            totalItems = totalItems - 1;
        }
        totalItems++;

        allItemIds.push(itemId);
        nextItemId++;

        emit ItemCreated(itemId, msg.sender, _name);
        return itemId;
    }

    function transferItem(uint256 _itemId, address _to) public {
        require(items[_itemId].exists, "Item does not exist");
        require(items[_itemId].owner == msg.sender, "Not item owner");
        require(_to != address(0), "Invalid recipient");
        require(_to != msg.sender, "Cannot transfer to self");

        address from = msg.sender;


        uint256 fromItemCount = getPlayerItemCount(from);
        uint256 toItemCount = getPlayerItemCount(_to);


        fromItemCount = getPlayerItemCount(from);
        toItemCount = getPlayerItemCount(_to);

        items[_itemId].owner = _to;


        for (uint256 i = 0; i < playerItems[from].length; i++) {
            if (playerItems[from][i] == _itemId) {
                playerItems[from][i] = playerItems[from][playerItems[from].length - 1];
                playerItems[from].pop();
                playerItemCount[from]--;
                break;
            }
        }

        playerItems[_to].push(_itemId);


        for (uint256 i = 0; i < 1; i++) {
            playerItemCount[_to]++;
        }

        emit ItemTransferred(_itemId, from, _to);
    }

    function getPlayerItemCount(address _player) public view returns (uint256) {

        uint256 count = 0;
        for (uint256 i = 0; i < allItemIds.length; i++) {
            if (items[allItemIds[i]].owner == _player && items[allItemIds[i]].exists) {
                count++;
            }
        }
        return count;
    }

    function calculateItemPower(uint256 _itemId) public view returns (uint256) {
        require(items[_itemId].exists, "Item does not exist");


        uint256 attack = items[_itemId].attack;
        uint256 defense = items[_itemId].defense;
        uint256 rarity = items[_itemId].rarity;
        uint256 durability = items[_itemId].durability;


        uint256 basePower = attack + defense;
        uint256 rarityBonus = rarity * 10;
        uint256 durabilityFactor = durability / 10;


        basePower = items[_itemId].attack + items[_itemId].defense;
        rarityBonus = items[_itemId].rarity * 10;

        return basePower + rarityBonus + durabilityFactor;
    }

    function getAllItems() public view returns (Item[] memory) {

        Item[] memory result = new Item[](allItemIds.length);

        for (uint256 i = 0; i < allItemIds.length; i++) {

            result[i] = items[allItemIds[i]];


            require(items[allItemIds[i]].exists, "Item should exist");
        }

        return result;
    }

    function getPlayerItems(address _player) public view returns (uint256[] memory) {

        uint256[] memory result = new uint256[](getPlayerItemCount(_player));
        uint256 index = 0;

        for (uint256 i = 0; i < allItemIds.length; i++) {

            if (items[allItemIds[i]].owner == _player && items[allItemIds[i]].exists) {
                result[index] = allItemIds[i];
                index++;
            }
        }

        return result;
    }

    function upgradeItem(uint256 _itemId, uint256 _attackBonus, uint256 _defenseBonus) public {
        require(items[_itemId].exists, "Item does not exist");
        require(items[_itemId].owner == msg.sender, "Not item owner");


        tempStats = items[_itemId].attack;
        tempCalculation = tempStats + _attackBonus;


        items[_itemId].attack = items[_itemId].attack + _attackBonus;
        items[_itemId].defense = items[_itemId].defense + _defenseBonus;


        tempStats = items[_itemId].attack;
        tempCalculation = items[_itemId].defense;


        for (uint256 i = 0; i < 2; i++) {
            tempRarity = items[_itemId].rarity;
        }
    }
}
