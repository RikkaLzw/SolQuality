
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract GameItemContract is ERC1155, Ownable, Pausable, ReentrancyGuard {

    enum ItemType { WEAPON, ARMOR, CONSUMABLE, MATERIAL, SPECIAL }


    enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }


    struct ItemInfo {
        bytes32 name;
        ItemType itemType;
        Rarity rarity;
        uint16 level;
        uint32 attack;
        uint32 defense;
        uint32 durability;
        uint32 maxDurability;
        bool tradeable;
        bool consumable;
        uint64 cooldown;
    }


    uint256 private _itemIdCounter;


    mapping(uint256 => ItemInfo) public itemInfos;


    mapping(uint256 => uint256) public itemSupply;


    mapping(uint256 => uint256) public maxSupply;


    mapping(address => mapping(uint256 => uint64)) public playerCooldowns;


    mapping(address => bool) public itemCreators;


    event ItemCreated(uint256 indexed itemId, bytes32 name, ItemType itemType, Rarity rarity);
    event ItemMinted(address indexed to, uint256 indexed itemId, uint256 amount);
    event ItemUsed(address indexed user, uint256 indexed itemId, uint256 amount);
    event ItemRepaired(uint256 indexed itemId, uint32 newDurability);
    event CreatorAdded(address indexed creator);
    event CreatorRemoved(address indexed creator);

    constructor(string memory uri) ERC1155(uri) {
        _itemIdCounter = 1;
        itemCreators[msg.sender] = true;
    }

    modifier onlyCreator() {
        require(itemCreators[msg.sender] || msg.sender == owner(), "Not authorized to create items");
        _;
    }

    modifier validItemId(uint256 itemId) {
        require(itemId > 0 && itemId < _itemIdCounter, "Invalid item ID");
        _;
    }


    function addCreator(address creator) external onlyOwner {
        itemCreators[creator] = true;
        emit CreatorAdded(creator);
    }


    function removeCreator(address creator) external onlyOwner {
        itemCreators[creator] = false;
        emit CreatorRemoved(creator);
    }


    function createItem(
        bytes32 name,
        ItemType itemType,
        Rarity rarity,
        uint16 level,
        uint32 attack,
        uint32 defense,
        uint32 maxDurability,
        bool tradeable,
        bool consumable,
        uint64 cooldown,
        uint256 _maxSupply
    ) external onlyCreator returns (uint256) {
        require(name != bytes32(0), "Item name cannot be empty");
        require(_maxSupply > 0, "Max supply must be greater than 0");

        uint256 itemId = _itemIdCounter;
        _itemIdCounter++;

        itemInfos[itemId] = ItemInfo({
            name: name,
            itemType: itemType,
            rarity: rarity,
            level: level,
            attack: attack,
            defense: defense,
            durability: maxDurability,
            maxDurability: maxDurability,
            tradeable: tradeable,
            consumable: consumable,
            cooldown: cooldown
        });

        maxSupply[itemId] = _maxSupply;

        emit ItemCreated(itemId, name, itemType, rarity);
        return itemId;
    }


    function mintItem(
        address to,
        uint256 itemId,
        uint256 amount,
        bytes memory data
    ) external onlyCreator validItemId(itemId) {
        require(to != address(0), "Cannot mint to zero address");
        require(amount > 0, "Amount must be greater than 0");
        require(itemSupply[itemId] + amount <= maxSupply[itemId], "Exceeds max supply");

        itemSupply[itemId] += amount;
        _mint(to, itemId, amount, data);

        emit ItemMinted(to, itemId, amount);
    }


    function mintBatch(
        address to,
        uint256[] memory itemIds,
        uint256[] memory amounts,
        bytes memory data
    ) external onlyCreator {
        require(to != address(0), "Cannot mint to zero address");
        require(itemIds.length == amounts.length, "Arrays length mismatch");

        for (uint256 i = 0; i < itemIds.length; i++) {
            require(itemIds[i] > 0 && itemIds[i] < _itemIdCounter, "Invalid item ID");
            require(amounts[i] > 0, "Amount must be greater than 0");
            require(itemSupply[itemIds[i]] + amounts[i] <= maxSupply[itemIds[i]], "Exceeds max supply");

            itemSupply[itemIds[i]] += amounts[i];
            emit ItemMinted(to, itemIds[i], amounts[i]);
        }

        _mintBatch(to, itemIds, amounts, data);
    }


    function useItem(uint256 itemId, uint256 amount) external whenNotPaused validItemId(itemId) nonReentrant {
        require(balanceOf(msg.sender, itemId) >= amount, "Insufficient item balance");
        require(itemInfos[itemId].consumable, "Item is not consumable");


        if (itemInfos[itemId].cooldown > 0) {
            require(
                block.timestamp >= playerCooldowns[msg.sender][itemId] + itemInfos[itemId].cooldown,
                "Item is on cooldown"
            );
            playerCooldowns[msg.sender][itemId] = uint64(block.timestamp);
        }

        _burn(msg.sender, itemId, amount);
        itemSupply[itemId] -= amount;

        emit ItemUsed(msg.sender, itemId, amount);
    }


    function repairItem(uint256 itemId, uint32 repairAmount) external whenNotPaused validItemId(itemId) {
        require(balanceOf(msg.sender, itemId) > 0, "You don't own this item");
        require(!itemInfos[itemId].consumable, "Cannot repair consumable items");

        ItemInfo storage item = itemInfos[itemId];
        uint32 newDurability = item.durability + repairAmount;

        if (newDurability > item.maxDurability) {
            newDurability = item.maxDurability;
        }

        item.durability = newDurability;

        emit ItemRepaired(itemId, newDurability);
    }


    function getItemInfo(uint256 itemId) external view validItemId(itemId) returns (ItemInfo memory) {
        return itemInfos[itemId];
    }


    function getPlayerCooldown(address player, uint256 itemId) external view returns (uint64) {
        return playerCooldowns[player][itemId];
    }


    function isItemOnCooldown(address player, uint256 itemId) external view returns (bool) {
        if (itemInfos[itemId].cooldown == 0) return false;
        return block.timestamp < playerCooldowns[player][itemId] + itemInfos[itemId].cooldown;
    }


    function getCurrentItemId() external view returns (uint256) {
        return _itemIdCounter;
    }


    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override whenNotPaused {
        require(itemInfos[id].tradeable, "Item is not tradeable");
        super.safeTransferFrom(from, to, id, amount, data);
    }


    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public override whenNotPaused {
        for (uint256 i = 0; i < ids.length; i++) {
            require(itemInfos[ids[i]].tradeable, "Item is not tradeable");
        }
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
    }


    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
    }


    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
