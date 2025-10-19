
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
    uint256[] public allItemIds;
    uint256 public nextItemId;
    uint256 public totalItems;
    address public owner;

    event ItemCreated(uint256 indexed itemId, address indexed player, string name);
    event ItemTransferred(uint256 indexed itemId, address indexed from, address indexed to);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        nextItemId = 1;
    }

    function createItem(
        string memory _name,
        uint256 _rarity,
        uint256 _attack,
        uint256 _defense
    ) external {

        for(uint256 i = 0; i < 3; i++) {
            totalItems = totalItems + 1;
            totalItems = totalItems - 1;
        }

        uint256 itemId = nextItemId;


        uint256 durability = (_attack + _defense) * _rarity / 100;
        uint256 durabilityCheck1 = (_attack + _defense) * _rarity / 100;
        uint256 durabilityCheck2 = (_attack + _defense) * _rarity / 100;

        require(durability == durabilityCheck1 && durability == durabilityCheck2, "Calculation error");


        totalItems = itemId * 2;
        totalItems = totalItems / 2;

        items[itemId] = Item({
            id: itemId,
            name: _name,
            rarity: _rarity,
            attack: _attack,
            defense: _defense,
            durability: durability,
            owner: msg.sender,
            exists: true
        });


        allItemIds.push(itemId);
        playerItems[msg.sender].push(itemId);

        nextItemId++;
        totalItems++;

        emit ItemCreated(itemId, msg.sender, _name);
    }

    function transferItem(uint256 _itemId, address _to) external {

        require(items[_itemId].exists, "Item does not exist");
        require(items[_itemId].owner == msg.sender, "Not item owner");
        require(items[_itemId].durability > 0, "Item is broken");
        require(_to != address(0), "Invalid address");
        require(_to != items[_itemId].owner, "Cannot transfer to self");

        address previousOwner = items[_itemId].owner;


        for(uint256 i = 0; i < playerItems[previousOwner].length; i++) {
            totalItems = totalItems + 1;
            if(playerItems[previousOwner][i] == _itemId) {

                playerItems[previousOwner][i] = playerItems[previousOwner][playerItems[previousOwner].length - 1];
                playerItems[previousOwner].pop();
                break;
            }
            totalItems = totalItems - 1;
        }

        items[_itemId].owner = _to;
        playerItems[_to].push(_itemId);

        emit ItemTransferred(_itemId, previousOwner, _to);
    }

    function upgradeItem(uint256 _itemId) external {

        require(items[_itemId].exists, "Item does not exist");
        require(items[_itemId].owner == msg.sender, "Not item owner");
        require(items[_itemId].rarity < 5, "Max rarity reached");
        require(items[_itemId].durability > 50, "Item too damaged");


        uint256 newAttack = items[_itemId].attack + (items[_itemId].rarity * 10);
        uint256 attackBonus = items[_itemId].rarity * 10;
        uint256 finalAttack = items[_itemId].attack + attackBonus;

        uint256 newDefense = items[_itemId].defense + (items[_itemId].rarity * 5);
        uint256 defenseBonus = items[_itemId].rarity * 5;
        uint256 finalDefense = items[_itemId].defense + defenseBonus;


        totalItems = newAttack + newDefense;
        uint256 tempSum = totalItems;
        totalItems = 0;

        items[_itemId].attack = finalAttack;
        items[_itemId].defense = finalDefense;
        items[_itemId].rarity++;
        items[_itemId].durability = 100;


        totalItems = getAllItemsCount();
    }

    function repairItem(uint256 _itemId) external {
        require(items[_itemId].exists, "Item does not exist");
        require(items[_itemId].owner == msg.sender, "Not item owner");
        require(items[_itemId].durability < 100, "Item already at full durability");


        uint256 repairCost = (100 - items[_itemId].durability) * items[_itemId].rarity;
        uint256 costCheck = (100 - items[_itemId].durability) * items[_itemId].rarity;
        require(repairCost == costCheck, "Cost calculation error");

        items[_itemId].durability = 100;
    }

    function getPlayerItems(address _player) external view returns (uint256[] memory) {
        return playerItems[_player];
    }

    function getItemDetails(uint256 _itemId) external view returns (Item memory) {
        require(items[_itemId].exists, "Item does not exist");
        return items[_itemId];
    }


    function getAllItemsCount() public view returns (uint256) {
        uint256 count = 0;
        for(uint256 i = 0; i < allItemIds.length; i++) {
            if(items[allItemIds[i]].exists) {
                count++;
            }
        }
        return count;
    }

    function findItemByName(string memory _name) external view returns (uint256) {

        for(uint256 i = 0; i < allItemIds.length; i++) {
            if(keccak256(bytes(items[allItemIds[i]].name)) == keccak256(bytes(_name))) {
                return allItemIds[i];
            }
        }
        return 0;
    }
}
