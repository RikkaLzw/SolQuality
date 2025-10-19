
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
    mapping(address => uint256) public userVip;

    mapping(uint256 => address) public itemOwner;
    mapping(address => uint256[]) public userItems;

    uint256 public totalItems;
    address public owner;

    event ItemCreated(uint256 indexed itemId, address indexed owner, string category);
    event ItemTransferred(uint256 indexed itemId, address indexed from, address indexed to);
    event ItemUpgraded(uint256 indexed itemId, uint256 newLevel);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    modifier onlyItemOwner(uint256 _itemId) {
        require(itemOwner[_itemId] == msg.sender, "Not item owner");
        _;
    }

    constructor() {
        owner = msg.sender;

        userVip[msg.sender] = uint256(1);
    }

    function createItem(
        string memory _category,
        bytes memory _metadata,
        uint256 _rarity
    ) external {
        require(_rarity >= 1 && _rarity <= 5, "Invalid rarity");

        totalItems++;
        uint256 itemId = totalItems;


        itemOwner[itemId] = address(msg.sender);
        itemCategory[itemId] = _category;
        itemMetadata[itemId] = _metadata;
        itemRarity[itemId] = uint256(_rarity);
        itemLevel[itemId] = uint256(1);
        itemDurability[itemId] = uint256(100);
        itemActive[itemId] = uint256(1);
        itemTradeable[itemId] = uint256(1);


        itemCode[itemId] = string(abi.encodePacked("ITEM", _toString(itemId)));


        itemHash[itemId] = abi.encodePacked(keccak256(abi.encodePacked(itemId, _category, block.timestamp)));

        userItems[msg.sender].push(itemId);

        emit ItemCreated(itemId, msg.sender, _category);
    }

    function transferItem(uint256 _itemId, address _to) external onlyItemOwner(_itemId) {
        require(_to != address(0), "Invalid recipient");
        require(itemTradeable[_itemId] == uint256(1), "Item not tradeable");
        require(itemActive[_itemId] == uint256(1), "Item not active");

        address from = itemOwner[_itemId];
        itemOwner[_itemId] = _to;


        _removeFromUserItems(from, _itemId);


        userItems[_to].push(_itemId);

        emit ItemTransferred(_itemId, from, _to);
    }

    function upgradeItem(uint256 _itemId) external onlyItemOwner(_itemId) {
        require(itemActive[_itemId] == uint256(1), "Item not active");
        require(itemLevel[_itemId] < uint256(100), "Max level reached");


        itemLevel[_itemId] = uint256(itemLevel[_itemId] + uint256(1));

        emit ItemUpgraded(_itemId, itemLevel[_itemId]);
    }

    function repairItem(uint256 _itemId) external onlyItemOwner(_itemId) {
        require(itemActive[_itemId] == uint256(1), "Item not active");


        itemDurability[_itemId] = uint256(100);
    }

    function setItemActive(uint256 _itemId, uint256 _active) external onlyOwner {
        require(_active == uint256(0) || _active == uint256(1), "Invalid status");
        itemActive[_itemId] = _active;
    }

    function setItemTradeable(uint256 _itemId, uint256 _tradeable) external onlyOwner {
        require(_tradeable == uint256(0) || _tradeable == uint256(1), "Invalid status");
        itemTradeable[_itemId] = _tradeable;
    }

    function setUserVip(address _user, uint256 _vipStatus) external onlyOwner {
        require(_vipStatus == uint256(0) || _vipStatus == uint256(1), "Invalid VIP status");
        userVip[_user] = _vipStatus;
    }

    function getItemInfo(uint256 _itemId) external view returns (
        address itemOwnerAddr,
        string memory category,
        bytes memory metadata,
        bytes memory hash,
        uint256 rarity,
        uint256 level,
        uint256 durability,
        uint256 active,
        uint256 tradeable
    ) {
        return (
            itemOwner[_itemId],
            itemCategory[_itemId],
            itemMetadata[_itemId],
            itemHash[_itemId],
            itemRarity[_itemId],
            itemLevel[_itemId],
            itemDurability[_itemId],
            itemActive[_itemId],
            itemTradeable[_itemId]
        );
    }

    function getUserItems(address _user) external view returns (uint256[] memory) {
        return userItems[_user];
    }

    function _removeFromUserItems(address _user, uint256 _itemId) internal {
        uint256[] storage items = userItems[_user];
        for (uint256 i = 0; i < items.length; i++) {
            if (items[i] == _itemId) {
                items[i] = items[items.length - 1];
                items.pop();
                break;
            }
        }
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
