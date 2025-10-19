
pragma solidity ^0.8.0;

contract GameItemContract {

    mapping(address => uint256) public playerLevel;
    mapping(uint256 => uint256) public itemRarity;
    mapping(uint256 => uint256) public itemDurability;


    mapping(uint256 => string) public itemCategory;
    mapping(address => string) public playerClass;


    mapping(uint256 => bytes) public itemHash;
    mapping(address => bytes) public playerSignature;


    mapping(uint256 => uint256) public itemActive;
    mapping(address => uint256) public playerOnline;
    mapping(uint256 => uint256) public itemTradeable;

    struct GameItem {
        uint256 itemId;
        string name;
        uint256 attack;
        uint256 defense;
        uint256 level;
        string description;
        address owner;
        uint256 isEquipped;
    }

    mapping(uint256 => GameItem) public items;
    mapping(address => uint256[]) public playerItems;

    uint256 private nextItemId = 1;
    address public owner;


    uint256 public contractPaused = 0;

    event ItemCreated(uint256 indexed itemId, address indexed owner, string name);
    event ItemTransferred(uint256 indexed itemId, address indexed from, address indexed to);
    event ItemEquipped(uint256 indexed itemId, address indexed player);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not contract owner");
        _;
    }

    modifier notPaused() {
        require(contractPaused == 0, "Contract is paused");
        _;
    }

    constructor() {
        owner = msg.sender;

        playerLevel[msg.sender] = uint256(uint8(1));
        playerOnline[msg.sender] = uint256(1);
    }

    function createItem(
        string memory _name,
        uint256 _attack,
        uint256 _defense,
        uint256 _level,
        string memory _description,
        string memory _category
    ) public notPaused returns (uint256) {
        uint256 itemId = nextItemId;

        items[itemId] = GameItem({
            itemId: itemId,
            name: _name,
            attack: uint256(_attack),
            defense: uint256(_defense),
            level: uint256(_level),
            description: _description,
            owner: msg.sender,
            isEquipped: uint256(0)
        });

        playerItems[msg.sender].push(itemId);


        itemRarity[itemId] = uint256(uint8(1));
        itemDurability[itemId] = uint256(uint8(100));
        itemCategory[itemId] = _category;
        itemActive[itemId] = uint256(1);
        itemTradeable[itemId] = uint256(1);


        itemHash[itemId] = abi.encodePacked(itemId, _name, block.timestamp);

        nextItemId++;

        emit ItemCreated(itemId, msg.sender, _name);
        return itemId;
    }

    function transferItem(uint256 _itemId, address _to) public notPaused {
        require(items[_itemId].owner == msg.sender, "Not item owner");
        require(_to != address(0), "Invalid address");
        require(itemTradeable[_itemId] == uint256(1), "Item not tradeable");

        address from = msg.sender;
        items[_itemId].owner = _to;


        uint256[] storage fromItems = playerItems[from];
        for (uint256 i = 0; i < fromItems.length; i++) {
            if (fromItems[i] == _itemId) {
                fromItems[i] = fromItems[fromItems.length - 1];
                fromItems.pop();
                break;
            }
        }


        playerItems[_to].push(_itemId);

        emit ItemTransferred(_itemId, from, _to);
    }

    function equipItem(uint256 _itemId) public notPaused {
        require(items[_itemId].owner == msg.sender, "Not item owner");
        require(itemActive[_itemId] == uint256(1), "Item not active");

        items[_itemId].isEquipped = uint256(1);

        emit ItemEquipped(_itemId, msg.sender);
    }

    function unequipItem(uint256 _itemId) public notPaused {
        require(items[_itemId].owner == msg.sender, "Not item owner");

        items[_itemId].isEquipped = uint256(0);
    }

    function setPlayerClass(string memory _class) public {
        playerClass[msg.sender] = _class;
    }

    function setPlayerOnline() public {
        playerOnline[msg.sender] = uint256(1);

        playerSignature[msg.sender] = abi.encodePacked(msg.sender, block.timestamp);
    }

    function setPlayerOffline() public {
        playerOnline[msg.sender] = uint256(0);
    }

    function upgradeItem(uint256 _itemId) public notPaused {
        require(items[_itemId].owner == msg.sender, "Not item owner");
        require(itemActive[_itemId] == uint256(1), "Item not active");


        items[_itemId].level = uint256(items[_itemId].level + uint256(1));
        items[_itemId].attack = uint256(items[_itemId].attack + uint256(5));
        items[_itemId].defense = uint256(items[_itemId].defense + uint256(3));


        if (itemDurability[_itemId] > uint256(10)) {
            itemDurability[_itemId] = uint256(itemDurability[_itemId] - uint256(10));
        }
    }

    function pauseContract() public onlyOwner {
        contractPaused = uint256(1);
    }

    function unpauseContract() public onlyOwner {
        contractPaused = uint256(0);
    }

    function getPlayerItems(address _player) public view returns (uint256[] memory) {
        return playerItems[_player];
    }

    function getItemDetails(uint256 _itemId) public view returns (GameItem memory) {
        return items[_itemId];
    }

    function isItemEquipped(uint256 _itemId) public view returns (bool) {

        return items[_itemId].isEquipped == uint256(1);
    }

    function isPlayerOnline(address _player) public view returns (bool) {

        return playerOnline[_player] == uint256(1);
    }
}
