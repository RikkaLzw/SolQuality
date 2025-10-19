
pragma solidity ^0.8.0;

contract GameItemContract {

    mapping(uint256 => uint256) public itemRarity;
    mapping(uint256 => uint256) public itemLevel;
    mapping(uint256 => uint256) public itemDurability;


    mapping(uint256 => string) public itemCategory;
    mapping(uint256 => string) public itemCode;


    mapping(uint256 => bytes) public itemHash;
    mapping(uint256 => bytes) public itemSignature;

    struct GameItem {
        string name;
        uint256 itemType;
        uint256 attack;
        uint256 defense;
        uint256 isEquipped;
        uint256 isTransferable;
        address owner;
        bytes metadata;
    }

    mapping(uint256 => GameItem) public items;
    mapping(address => uint256[]) public playerItems;

    uint256 public nextItemId;
    address public gameAdmin;
    uint256 public contractActive;

    event ItemCreated(uint256 indexed itemId, address indexed owner, string name);
    event ItemTransferred(uint256 indexed itemId, address indexed from, address indexed to);
    event ItemEquipped(uint256 indexed itemId, address indexed player);

    constructor() {
        gameAdmin = msg.sender;
        nextItemId = 1;
        contractActive = 1;
    }

    modifier onlyAdmin() {
        require(msg.sender == gameAdmin, "Only admin can call this function");
        _;
    }

    modifier contractIsActive() {
        require(contractActive == 1, "Contract is not active");
        _;
    }

    function createItem(
        address _owner,
        string memory _name,
        uint256 _itemType,
        uint256 _attack,
        uint256 _defense,
        string memory _category,
        string memory _code,
        bytes memory _metadata,
        bytes memory _hash
    ) external onlyAdmin contractIsActive {
        require(_owner != address(0), "Invalid owner address");
        require(bytes(_name).length > 0, "Item name cannot be empty");

        uint256 itemId = nextItemId;


        items[itemId] = GameItem({
            name: _name,
            itemType: uint256(_itemType),
            attack: uint256(_attack),
            defense: uint256(_defense),
            isEquipped: uint256(0),
            isTransferable: uint256(1),
            owner: _owner,
            metadata: _metadata
        });


        itemRarity[itemId] = uint256(1);
        itemLevel[itemId] = uint256(1);
        itemDurability[itemId] = uint256(100);
        itemCategory[itemId] = _category;
        itemCode[itemId] = _code;
        itemHash[itemId] = _hash;
        itemSignature[itemId] = bytes("");

        playerItems[_owner].push(itemId);

        nextItemId++;

        emit ItemCreated(itemId, _owner, _name);
    }

    function transferItem(uint256 _itemId, address _to) external contractIsActive {
        require(_to != address(0), "Invalid recipient address");
        require(items[_itemId].owner == msg.sender, "You don't own this item");
        require(items[_itemId].isTransferable == 1, "Item is not transferable");
        require(items[_itemId].isEquipped == 0, "Cannot transfer equipped item");

        address from = items[_itemId].owner;
        items[_itemId].owner = _to;


        _removeItemFromPlayer(from, _itemId);

        playerItems[_to].push(_itemId);

        emit ItemTransferred(_itemId, from, _to);
    }

    function equipItem(uint256 _itemId) external contractIsActive {
        require(items[_itemId].owner == msg.sender, "You don't own this item");
        require(items[_itemId].isEquipped == 0, "Item is already equipped");

        items[_itemId].isEquipped = uint256(1);

        emit ItemEquipped(_itemId, msg.sender);
    }

    function unequipItem(uint256 _itemId) external contractIsActive {
        require(items[_itemId].owner == msg.sender, "You don't own this item");
        require(items[_itemId].isEquipped == 1, "Item is not equipped");

        items[_itemId].isEquipped = uint256(0);
    }

    function upgradeItem(uint256 _itemId, uint256 _newLevel) external onlyAdmin contractIsActive {
        require(items[_itemId].owner != address(0), "Item does not exist");
        require(_newLevel > itemLevel[_itemId], "New level must be higher");
        require(_newLevel <= uint256(100), "Level cannot exceed 100");

        itemLevel[_itemId] = uint256(_newLevel);


        items[_itemId].attack = items[_itemId].attack + uint256(10);
        items[_itemId].defense = items[_itemId].defense + uint256(5);
    }

    function setItemTransferable(uint256 _itemId, uint256 _transferable) external onlyAdmin {
        require(items[_itemId].owner != address(0), "Item does not exist");
        require(_transferable == 0 || _transferable == 1, "Invalid transferable value");

        items[_itemId].isTransferable = _transferable;
    }

    function setContractActive(uint256 _active) external onlyAdmin {
        require(_active == 0 || _active == 1, "Invalid active value");
        contractActive = _active;
    }

    function updateItemMetadata(uint256 _itemId, bytes memory _newMetadata) external onlyAdmin {
        require(items[_itemId].owner != address(0), "Item does not exist");
        items[_itemId].metadata = _newMetadata;
    }

    function getPlayerItems(address _player) external view returns (uint256[] memory) {
        return playerItems[_player];
    }

    function getItemDetails(uint256 _itemId) external view returns (
        string memory name,
        uint256 itemType,
        uint256 attack,
        uint256 defense,
        uint256 isEquipped,
        uint256 isTransferable,
        address owner,
        uint256 level,
        uint256 rarity,
        uint256 durability,
        string memory category,
        string memory code
    ) {
        GameItem memory item = items[_itemId];
        return (
            item.name,
            item.itemType,
            item.attack,
            item.defense,
            item.isEquipped,
            item.isTransferable,
            item.owner,
            itemLevel[_itemId],
            itemRarity[_itemId],
            itemDurability[_itemId],
            itemCategory[_itemId],
            itemCode[_itemId]
        );
    }

    function _removeItemFromPlayer(address _player, uint256 _itemId) internal {
        uint256[] storage items_array = playerItems[_player];
        for (uint256 i = 0; i < items_array.length; i++) {
            if (items_array[i] == _itemId) {
                items_array[i] = items_array[items_array.length - 1];
                items_array.pop();
                break;
            }
        }
    }

    function transferOwnership(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0), "Invalid new admin address");
        gameAdmin = _newAdmin;
    }
}
