
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract GameItemContract is ERC1155, Ownable, Pausable, ReentrancyGuard {

    struct ItemInfo {
        bytes32 name;
        uint16 rarity;
        uint32 durability;
        uint32 maxDurability;
        bool tradeable;
        bool consumable;
        uint64 cooldown;
        uint128 basePrice;
    }

    mapping(uint256 => ItemInfo) public itemInfo;
    mapping(uint256 => bool) public itemExists;
    mapping(address => mapping(uint256 => uint64)) public lastUsed;
    mapping(uint256 => uint256) public totalSupply;
    mapping(uint256 => uint256) public maxSupply;

    uint256 private _currentItemId;
    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    event ItemCreated(uint256 indexed itemId, bytes32 name, uint16 rarity);
    event ItemUsed(address indexed user, uint256 indexed itemId, uint32 newDurability);
    event ItemRepaired(uint256 indexed itemId, uint32 newDurability);
    event ItemDestroyed(uint256 indexed itemId, address indexed owner);

    constructor(string memory uri) ERC1155(uri) {
        _currentItemId = 1;
    }

    function createItem(
        bytes32 _name,
        uint16 _rarity,
        uint32 _maxDurability,
        bool _tradeable,
        bool _consumable,
        uint64 _cooldown,
        uint128 _basePrice,
        uint256 _maxSupply
    ) external onlyOwner returns (uint256) {
        uint256 itemId = _currentItemId++;

        itemInfo[itemId] = ItemInfo({
            name: _name,
            rarity: _rarity,
            durability: _maxDurability,
            maxDurability: _maxDurability,
            tradeable: _tradeable,
            consumable: _consumable,
            cooldown: _cooldown,
            basePrice: _basePrice
        });

        itemExists[itemId] = true;
        maxSupply[itemId] = _maxSupply;

        emit ItemCreated(itemId, _name, _rarity);
        return itemId;
    }

    function mintItem(
        address to,
        uint256 itemId,
        uint256 amount
    ) external onlyOwner {
        require(itemExists[itemId], "Item does not exist");
        require(totalSupply[itemId] + amount <= maxSupply[itemId], "Exceeds max supply");

        totalSupply[itemId] += amount;
        _mint(to, itemId, amount, "");
    }

    function useItem(uint256 itemId) external nonReentrant whenNotPaused {
        require(balanceOf(msg.sender, itemId) > 0, "Item not owned");
        require(itemExists[itemId], "Item does not exist");

        ItemInfo storage item = itemInfo[itemId];
        require(block.timestamp >= lastUsed[msg.sender][itemId] + item.cooldown, "Item on cooldown");

        lastUsed[msg.sender][itemId] = uint64(block.timestamp);

        if (item.consumable) {
            _burn(msg.sender, itemId, 1);
            totalSupply[itemId] -= 1;
        } else {
            require(item.durability > 0, "Item is broken");
            item.durability -= 1;

            if (item.durability == 0) {
                _burn(msg.sender, itemId, 1);
                totalSupply[itemId] -= 1;
                emit ItemDestroyed(itemId, msg.sender);
            }
        }

        emit ItemUsed(msg.sender, itemId, item.durability);
    }

    function repairItem(uint256 itemId, uint32 repairAmount) external payable nonReentrant {
        require(balanceOf(msg.sender, itemId) > 0, "Item not owned");
        require(itemExists[itemId], "Item does not exist");

        ItemInfo storage item = itemInfo[itemId];
        require(!item.consumable, "Cannot repair consumable items");
        require(item.durability < item.maxDurability, "Item already at max durability");

        uint128 repairCost = (item.basePrice * repairAmount) / 100;
        require(msg.value >= repairCost, "Insufficient payment for repair");

        uint32 newDurability = item.durability + repairAmount;
        if (newDurability > item.maxDurability) {
            newDurability = item.maxDurability;
        }

        item.durability = newDurability;

        if (msg.value > repairCost) {
            payable(msg.sender).transfer(msg.value - repairCost);
        }

        emit ItemRepaired(itemId, newDurability);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override {
        require(itemExists[id], "Item does not exist");
        require(itemInfo[id].tradeable, "Item is not tradeable");
        super.safeTransferFrom(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public override {
        for (uint256 i = 0; i < ids.length; i++) {
            require(itemExists[ids[i]], "Item does not exist");
            require(itemInfo[ids[i]].tradeable, "Item is not tradeable");
        }
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function getItemInfo(uint256 itemId) external view returns (ItemInfo memory) {
        require(itemExists[itemId], "Item does not exist");
        return itemInfo[itemId];
    }

    function getRemainingCooldown(address user, uint256 itemId) external view returns (uint64) {
        if (!itemExists[itemId]) return 0;

        uint64 lastUsedTime = lastUsed[user][itemId];
        uint64 cooldownPeriod = itemInfo[itemId].cooldown;

        if (block.timestamp >= lastUsedTime + cooldownPeriod) {
            return 0;
        }

        return uint64(lastUsedTime + cooldownPeriod - block.timestamp);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner()).transfer(balance);
    }

    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
