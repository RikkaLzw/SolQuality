
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract GameItemContract is ERC1155, AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant GAME_ADMIN_ROLE = keccak256("GAME_ADMIN_ROLE");


    enum ItemType { WEAPON, ARMOR, CONSUMABLE, MATERIAL, RARE }


    struct ItemInfo {
        ItemType itemType;
        uint8 rarity;
        uint16 level;
        uint32 attack;
        uint32 defense;
        uint32 durability;
        uint32 maxDurability;
        bool tradeable;
        uint128 price;
    }


    mapping(uint256 => ItemInfo) public itemInfos;
    mapping(uint256 => string) private _itemURIs;
    mapping(address => mapping(uint256 => uint256)) private _userItemCounts;


    mapping(uint256 => uint256) public itemSupply;
    mapping(uint256 => uint256) public maxSupply;


    mapping(uint256 => mapping(address => uint256)) public marketListings;


    event ItemCreated(uint256 indexed itemId, ItemType itemType, uint8 rarity);
    event ItemUpgraded(uint256 indexed itemId, address indexed owner, uint16 newLevel);
    event ItemListed(uint256 indexed itemId, address indexed seller, uint256 price);
    event ItemSold(uint256 indexed itemId, address indexed seller, address indexed buyer, uint256 price);

    constructor(string memory uri) ERC1155(uri) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(GAME_ADMIN_ROLE, msg.sender);
    }


    function createItem(
        uint256 itemId,
        ItemType itemType,
        uint8 rarity,
        uint32 attack,
        uint32 defense,
        uint32 durability,
        uint128 price,
        uint256 _maxSupply,
        string memory itemURI
    ) external onlyRole(GAME_ADMIN_ROLE) {
        require(itemInfos[itemId].maxDurability == 0, "Item already exists");
        require(rarity >= 1 && rarity <= 5, "Invalid rarity");

        itemInfos[itemId] = ItemInfo({
            itemType: itemType,
            rarity: rarity,
            level: 1,
            attack: attack,
            defense: defense,
            durability: durability,
            maxDurability: durability,
            tradeable: true,
            price: price
        });

        maxSupply[itemId] = _maxSupply;
        _itemURIs[itemId] = itemURI;

        emit ItemCreated(itemId, itemType, rarity);
    }


    function mintItem(
        address to,
        uint256 itemId,
        uint256 amount
    ) external onlyRole(MINTER_ROLE) whenNotPaused {
        uint256 currentSupply = itemSupply[itemId];
        require(currentSupply + amount <= maxSupply[itemId], "Exceeds max supply");


        itemSupply[itemId] = currentSupply + amount;
        _userItemCounts[to][itemId] += amount;

        _mint(to, itemId, amount, "");
    }


    function mintBatch(
        address to,
        uint256[] memory itemIds,
        uint256[] memory amounts
    ) external onlyRole(MINTER_ROLE) whenNotPaused {
        require(itemIds.length == amounts.length, "Arrays length mismatch");


        uint256 length = itemIds.length;
        for (uint256 i = 0; i < length;) {
            uint256 itemId = itemIds[i];
            uint256 amount = amounts[i];
            uint256 currentSupply = itemSupply[itemId];

            require(currentSupply + amount <= maxSupply[itemId], "Exceeds max supply");

            itemSupply[itemId] = currentSupply + amount;
            _userItemCounts[to][itemId] += amount;

            unchecked { ++i; }
        }

        _mintBatch(to, itemIds, amounts, "");
    }


    function upgradeItem(uint256 itemId) external whenNotPaused {
        require(balanceOf(msg.sender, itemId) > 0, "Not item owner");

        ItemInfo storage item = itemInfos[itemId];
        require(item.level < 100, "Max level reached");
        require(item.durability > 0, "Item broken");


        uint256 upgradeCost = _calculateUpgradeCost(item.level, item.rarity);
        require(address(this).balance >= upgradeCost, "Insufficient upgrade fee");


        uint16 newLevel = item.level + 1;
        item.level = newLevel;
        item.attack += item.attack * 5 / 100;
        item.defense += item.defense * 5 / 100;

        emit ItemUpgraded(itemId, msg.sender, newLevel);
    }


    function listItem(uint256 itemId, uint256 price) external whenNotPaused {
        require(balanceOf(msg.sender, itemId) > 0, "Not item owner");
        require(itemInfos[itemId].tradeable, "Item not tradeable");
        require(price > 0, "Invalid price");

        marketListings[itemId][msg.sender] = price;
        emit ItemListed(itemId, msg.sender, price);
    }

    function buyItem(uint256 itemId, address seller) external payable nonReentrant whenNotPaused {
        uint256 price = marketListings[itemId][seller];
        require(price > 0, "Item not listed");
        require(msg.value >= price, "Insufficient payment");
        require(balanceOf(seller, itemId) > 0, "Seller no longer owns item");


        delete marketListings[itemId][seller];


        _safeTransferFrom(seller, msg.sender, itemId, 1, "");


        uint256 fee = price * 25 / 1000;
        uint256 sellerAmount = price - fee;

        (bool success,) = payable(seller).call{value: sellerAmount}("");
        require(success, "Transfer to seller failed");


        if (msg.value > price) {
            (bool refundSuccess,) = payable(msg.sender).call{value: msg.value - price}("");
            require(refundSuccess, "Refund failed");
        }

        emit ItemSold(itemId, seller, msg.sender, price);
    }


    function repairItem(uint256 itemId) external payable whenNotPaused {
        require(balanceOf(msg.sender, itemId) > 0, "Not item owner");

        ItemInfo storage item = itemInfos[itemId];
        require(item.durability < item.maxDurability, "Item already at max durability");

        uint256 repairCost = _calculateRepairCost(item.maxDurability - item.durability, item.rarity);
        require(msg.value >= repairCost, "Insufficient repair fee");

        item.durability = item.maxDurability;


        if (msg.value > repairCost) {
            (bool success,) = payable(msg.sender).call{value: msg.value - repairCost}("");
            require(success, "Refund failed");
        }
    }


    function getUserItemCount(address user, uint256 itemId) external view returns (uint256) {
        return _userItemCounts[user][itemId];
    }


    function getUserItemsBatch(address user, uint256[] memory itemIds)
        external view returns (uint256[] memory balances) {
        balances = new uint256[](itemIds.length);
        uint256 length = itemIds.length;

        for (uint256 i = 0; i < length;) {
            balances[i] = _userItemCounts[user][itemIds[i]];
            unchecked { ++i; }
        }
    }


    function _calculateUpgradeCost(uint16 level, uint8 rarity) private pure returns (uint256) {
        return uint256(level) * uint256(rarity) * 0.001 ether;
    }


    function _calculateRepairCost(uint32 durabilityToRepair, uint8 rarity) private pure returns (uint256) {
        return uint256(durabilityToRepair) * uint256(rarity) * 0.0001 ether;
    }


    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        if (from != address(0) && to != address(0)) {
            uint256 length = ids.length;
            for (uint256 i = 0; i < length;) {
                uint256 itemId = ids[i];
                uint256 amount = amounts[i];

                _userItemCounts[from][itemId] -= amount;
                _userItemCounts[to][itemId] += amount;

                unchecked { ++i; }
            }
        }
    }


    function uri(uint256 itemId) public view override returns (string memory) {
        string memory itemURI = _itemURIs[itemId];
        return bytes(itemURI).length > 0 ? itemURI : super.uri(itemId);
    }

    function setItemURI(uint256 itemId, string memory itemURI)
        external onlyRole(GAME_ADMIN_ROLE) {
        _itemURIs[itemId] = itemURI;
    }


    function pause() external onlyRole(GAME_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(GAME_ADMIN_ROLE) {
        _unpause();
    }

    function withdrawFees() external onlyRole(DEFAULT_ADMIN_ROLE) {
        (bool success,) = payable(msg.sender).call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }


    function supportsInterface(bytes4 interfaceId)
        public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
