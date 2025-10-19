
pragma solidity ^0.8.0;

contract GameItemContract {

    mapping(uint256 => uint256) public itemRarity;
    mapping(uint256 => uint256) public itemLevel;
    mapping(uint256 => uint256) public itemDurability;


    mapping(uint256 => string) public itemCategory;
    mapping(uint256 => string) public itemCode;


    mapping(uint256 => bytes) public itemMetadata;
    mapping(uint256 => bytes) public itemHash;


    mapping(uint256 => uint256) public itemActive;
    mapping(uint256 => uint256) public itemTradeable;
    mapping(uint256 => uint256) public itemUpgradeable;

    mapping(uint256 => address) public itemOwner;
    mapping(uint256 => string) public itemName;
    mapping(address => uint256[]) public ownerItems;

    uint256 public nextItemId;
    address public admin;

    event ItemCreated(uint256 indexed itemId, address indexed owner, string name);
    event ItemTransferred(uint256 indexed itemId, address indexed from, address indexed to);
    event ItemUpgraded(uint256 indexed itemId, uint256 newLevel);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    modifier onlyOwner(uint256 itemId) {
        require(itemOwner[itemId] == msg.sender, "Only item owner can call this function");
        _;
    }

    constructor() {
        admin = msg.sender;
        nextItemId = 1;
    }

    function createItem(
        string memory name,
        string memory category,
        string memory code,
        bytes memory metadata,
        uint256 rarity,
        uint256 initialLevel
    ) public onlyAdmin returns (uint256) {
        uint256 itemId = nextItemId;
        nextItemId++;

        itemOwner[itemId] = admin;
        itemName[itemId] = name;


        itemCategory[itemId] = category;
        itemCode[itemId] = code;


        itemMetadata[itemId] = metadata;
        itemHash[itemId] = abi.encodePacked(itemId, block.timestamp);


        itemRarity[itemId] = rarity;
        itemLevel[itemId] = initialLevel;
        itemDurability[itemId] = uint256(100);


        itemActive[itemId] = uint256(1);
        itemTradeable[itemId] = 1;
        itemUpgradeable[itemId] = 1;

        ownerItems[admin].push(itemId);

        emit ItemCreated(itemId, admin, name);
        return itemId;
    }

    function transferItem(uint256 itemId, address to) public onlyOwner(itemId) {
        require(to != address(0), "Cannot transfer to zero address");
        require(itemActive[itemId] == 1, "Item is not active");
        require(itemTradeable[itemId] == 1, "Item is not tradeable");

        address from = itemOwner[itemId];
        itemOwner[itemId] = to;


        uint256[] storage fromItems = ownerItems[from];
        for (uint256 i = 0; i < fromItems.length; i++) {
            if (fromItems[i] == itemId) {
                fromItems[i] = fromItems[fromItems.length - 1];
                fromItems.pop();
                break;
            }
        }


        ownerItems[to].push(itemId);

        emit ItemTransferred(itemId, from, to);
    }

    function upgradeItem(uint256 itemId) public onlyOwner(itemId) {
        require(itemActive[itemId] == 1, "Item is not active");
        require(itemUpgradeable[itemId] == 1, "Item is not upgradeable");
        require(itemLevel[itemId] < uint256(100), "Item already at max level");


        itemLevel[itemId] = itemLevel[itemId] + uint256(1);


        if (itemDurability[itemId] > uint256(10)) {
            itemDurability[itemId] = itemDurability[itemId] - uint256(10);
        }

        emit ItemUpgraded(itemId, itemLevel[itemId]);
    }

    function repairItem(uint256 itemId) public onlyOwner(itemId) {
        require(itemActive[itemId] == 1, "Item is not active");


        itemDurability[itemId] = uint256(100);
    }

    function deactivateItem(uint256 itemId) public onlyAdmin {
        itemActive[itemId] = uint256(0);
    }

    function activateItem(uint256 itemId) public onlyAdmin {
        itemActive[itemId] = uint256(1);
    }

    function setTradeable(uint256 itemId, uint256 tradeable) public onlyAdmin {

        require(tradeable == 0 || tradeable == 1, "Invalid tradeable value");
        itemTradeable[itemId] = tradeable;
    }

    function getItemInfo(uint256 itemId) public view returns (
        string memory name,
        string memory category,
        string memory code,
        uint256 rarity,
        uint256 level,
        uint256 durability,
        uint256 active,
        uint256 tradeable,
        address owner
    ) {
        return (
            itemName[itemId],
            itemCategory[itemId],
            itemCode[itemId],
            itemRarity[itemId],
            itemLevel[itemId],
            itemDurability[itemId],
            itemActive[itemId],
            itemTradeable[itemId],
            itemOwner[itemId]
        );
    }

    function getOwnerItems(address owner) public view returns (uint256[] memory) {
        return ownerItems[owner];
    }

    function updateItemMetadata(uint256 itemId, bytes memory newMetadata) public onlyAdmin {

        itemMetadata[itemId] = newMetadata;
        itemHash[itemId] = abi.encodePacked(itemId, block.timestamp, newMetadata);
    }
}
