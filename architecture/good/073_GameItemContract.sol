
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract GameItemContract is ERC1155, Ownable, Pausable, ReentrancyGuard {
    using Strings for uint256;


    uint256 public constant WEAPON = 1;
    uint256 public constant ARMOR = 2;
    uint256 public constant POTION = 3;
    uint256 public constant ACCESSORY = 4;
    uint256 public constant MATERIAL = 5;


    uint256 public constant COMMON = 1;
    uint256 public constant RARE = 2;
    uint256 public constant EPIC = 3;
    uint256 public constant LEGENDARY = 4;


    uint256 public constant MAX_SUPPLY_PER_ITEM = 10000;
    uint256 public constant MAX_MINT_PER_TX = 50;
    uint256 public constant CRAFTING_COOLDOWN = 1 hours;


    struct Item {
        string name;
        uint256 itemType;
        uint256 rarity;
        uint256 maxSupply;
        uint256 currentSupply;
        uint256 mintPrice;
        bool mintable;
        bool tradeable;
    }


    mapping(uint256 => Item) public items;
    mapping(address => mapping(uint256 => uint256)) public lastCraftTime;
    mapping(uint256 => string) private _tokenURIs;

    uint256 private _currentItemId;
    address public treasuryWallet;


    event ItemCreated(uint256 indexed itemId, string name, uint256 itemType, uint256 rarity);
    event ItemMinted(address indexed to, uint256 indexed itemId, uint256 amount);
    event ItemCrafted(address indexed crafter, uint256 indexed resultItemId, uint256[] materialIds, uint256[] materialAmounts);
    event ItemUpgraded(address indexed player, uint256 indexed itemId, uint256 newRarity);


    modifier validItemId(uint256 itemId) {
        require(itemId > 0 && itemId <= _currentItemId, "Invalid item ID");
        _;
    }

    modifier canMint(uint256 itemId, uint256 amount) {
        require(items[itemId].mintable, "Item not mintable");
        require(amount > 0 && amount <= MAX_MINT_PER_TX, "Invalid mint amount");
        require(items[itemId].currentSupply + amount <= items[itemId].maxSupply, "Exceeds max supply");
        _;
    }

    modifier canCraft(address player, uint256 itemId) {
        require(block.timestamp >= lastCraftTime[player][itemId] + CRAFTING_COOLDOWN, "Crafting cooldown active");
        _;
    }

    modifier onlyTradeable(uint256 itemId) {
        require(items[itemId].tradeable, "Item not tradeable");
        _;
    }

    constructor(
        string memory uri,
        address _treasuryWallet
    ) ERC1155(uri) {
        treasuryWallet = _treasuryWallet;
        _initializeDefaultItems();
    }


    function _initializeDefaultItems() internal {
        _createItem("Iron Sword", WEAPON, COMMON, 5000, 0.01 ether, true, true);
        _createItem("Steel Armor", ARMOR, RARE, 3000, 0.05 ether, true, true);
        _createItem("Health Potion", POTION, COMMON, 10000, 0.001 ether, true, false);
        _createItem("Magic Ring", ACCESSORY, EPIC, 1000, 0.1 ether, true, true);
        _createItem("Iron Ore", MATERIAL, COMMON, 8000, 0.005 ether, true, true);
    }


    function createItem(
        string memory name,
        uint256 itemType,
        uint256 rarity,
        uint256 maxSupply,
        uint256 mintPrice,
        bool mintable,
        bool tradeable
    ) external onlyOwner returns (uint256) {
        return _createItem(name, itemType, rarity, maxSupply, mintPrice, mintable, tradeable);
    }

    function mintItem(
        uint256 itemId,
        uint256 amount
    ) external payable nonReentrant whenNotPaused validItemId(itemId) canMint(itemId, amount) {
        Item storage item = items[itemId];
        uint256 totalCost = item.mintPrice * amount;

        require(msg.value >= totalCost, "Insufficient payment");

        item.currentSupply += amount;
        _mint(msg.sender, itemId, amount, "");


        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }


        if (totalCost > 0) {
            payable(treasuryWallet).transfer(totalCost);
        }

        emit ItemMinted(msg.sender, itemId, amount);
    }

    function craftItem(
        uint256 resultItemId,
        uint256[] memory materialIds,
        uint256[] memory materialAmounts
    ) external nonReentrant whenNotPaused validItemId(resultItemId) canCraft(msg.sender, resultItemId) {
        require(materialIds.length == materialAmounts.length, "Arrays length mismatch");
        require(materialIds.length > 0, "No materials provided");


        _burnBatch(msg.sender, materialIds, materialAmounts);


        lastCraftTime[msg.sender][resultItemId] = block.timestamp;


        items[resultItemId].currentSupply += 1;
        _mint(msg.sender, resultItemId, 1, "");

        emit ItemCrafted(msg.sender, resultItemId, materialIds, materialAmounts);
    }

    function upgradeItem(
        uint256 itemId,
        uint256 upgradeAmount
    ) external nonReentrant whenNotPaused validItemId(itemId) {
        require(balanceOf(msg.sender, itemId) >= upgradeAmount, "Insufficient items");

        Item storage item = items[itemId];
        require(item.rarity < LEGENDARY, "Already max rarity");


        _burn(msg.sender, itemId, upgradeAmount);


        uint256 newRarity = item.rarity + 1;
        uint256 upgradedItemId = _findOrCreateUpgradedItem(itemId, newRarity);

        items[upgradedItemId].currentSupply += 1;
        _mint(msg.sender, upgradedItemId, 1, "");

        emit ItemUpgraded(msg.sender, upgradedItemId, newRarity);
    }

    function batchTransfer(
        address to,
        uint256[] memory itemIds,
        uint256[] memory amounts
    ) external whenNotPaused {
        require(itemIds.length == amounts.length, "Arrays length mismatch");

        for (uint256 i = 0; i < itemIds.length; i++) {
            require(items[itemIds[i]].tradeable, "Item not tradeable");
        }

        safeBatchTransferFrom(msg.sender, to, itemIds, amounts, "");
    }


    function getItem(uint256 itemId) external view validItemId(itemId) returns (Item memory) {
        return items[itemId];
    }

    function getItemsByType(uint256 itemType) external view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](_currentItemId);
        uint256 count = 0;

        for (uint256 i = 1; i <= _currentItemId; i++) {
            if (items[i].itemType == itemType) {
                result[count] = i;
                count++;
            }
        }


        uint256[] memory filteredResult = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            filteredResult[i] = result[i];
        }

        return filteredResult;
    }

    function getUserItems(address user) external view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory itemIds = new uint256[](_currentItemId);
        uint256[] memory amounts = new uint256[](_currentItemId);
        uint256 count = 0;

        for (uint256 i = 1; i <= _currentItemId; i++) {
            uint256 balance = balanceOf(user, i);
            if (balance > 0) {
                itemIds[count] = i;
                amounts[count] = balance;
                count++;
            }
        }


        uint256[] memory userItemIds = new uint256[](count);
        uint256[] memory userAmounts = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            userItemIds[i] = itemIds[i];
            userAmounts[i] = amounts[i];
        }

        return (userItemIds, userAmounts);
    }

    function uri(uint256 itemId) public view override returns (string memory) {
        require(itemId > 0 && itemId <= _currentItemId, "Invalid item ID");

        string memory tokenURI = _tokenURIs[itemId];
        if (bytes(tokenURI).length > 0) {
            return tokenURI;
        }

        return string(abi.encodePacked(super.uri(itemId), itemId.toString()));
    }


    function setItemURI(uint256 itemId, string memory tokenURI) external onlyOwner validItemId(itemId) {
        _tokenURIs[itemId] = tokenURI;
    }

    function setURI(string memory newURI) external onlyOwner {
        _setURI(newURI);
    }

    function updateItemConfig(
        uint256 itemId,
        uint256 mintPrice,
        bool mintable,
        bool tradeable
    ) external onlyOwner validItemId(itemId) {
        Item storage item = items[itemId];
        item.mintPrice = mintPrice;
        item.mintable = mintable;
        item.tradeable = tradeable;
    }

    function setTreasuryWallet(address _treasuryWallet) external onlyOwner {
        require(_treasuryWallet != address(0), "Invalid treasury wallet");
        treasuryWallet = _treasuryWallet;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(treasuryWallet).transfer(balance);
    }


    function _createItem(
        string memory name,
        uint256 itemType,
        uint256 rarity,
        uint256 maxSupply,
        uint256 mintPrice,
        bool mintable,
        bool tradeable
    ) internal returns (uint256) {
        require(bytes(name).length > 0, "Item name cannot be empty");
        require(itemType >= WEAPON && itemType <= MATERIAL, "Invalid item type");
        require(rarity >= COMMON && rarity <= LEGENDARY, "Invalid rarity");
        require(maxSupply > 0 && maxSupply <= MAX_SUPPLY_PER_ITEM, "Invalid max supply");

        _currentItemId++;
        uint256 itemId = _currentItemId;

        items[itemId] = Item({
            name: name,
            itemType: itemType,
            rarity: rarity,
            maxSupply: maxSupply,
            currentSupply: 0,
            mintPrice: mintPrice,
            mintable: mintable,
            tradeable: tradeable
        });

        emit ItemCreated(itemId, name, itemType, rarity);
        return itemId;
    }

    function _findOrCreateUpgradedItem(uint256 originalItemId, uint256 newRarity) internal returns (uint256) {
        Item memory originalItem = items[originalItemId];


        for (uint256 i = 1; i <= _currentItemId; i++) {
            Item memory item = items[i];
            if (keccak256(bytes(item.name)) == keccak256(bytes(originalItem.name)) &&
                item.itemType == originalItem.itemType &&
                item.rarity == newRarity) {
                return i;
            }
        }


        string memory upgradedName = string(abi.encodePacked(originalItem.name, " +"));
        return _createItem(
            upgradedName,
            originalItem.itemType,
            newRarity,
            originalItem.maxSupply / 2,
            originalItem.mintPrice * 2,
            false,
            originalItem.tradeable
        );
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

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
