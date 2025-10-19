
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract GameItemContract is ERC1155, Ownable, ReentrancyGuard, Pausable {

    enum ItemType { WEAPON, ARMOR, CONSUMABLE, MATERIAL, RARE }


    struct ItemInfo {
        string name;
        ItemType itemType;
        uint256 maxSupply;
        uint256 currentSupply;
        uint256 mintPrice;
        bool tradeable;
        uint8 rarity;
    }


    struct GameConfig {
        uint128 nextItemId;
        uint128 totalItems;
    }

    GameConfig public gameConfig;


    mapping(uint256 => ItemInfo) public items;


    mapping(address => mapping(uint256 => uint256)) private _userItemCache;


    mapping(ItemType => uint256[]) public itemsByType;


    mapping(uint8 => uint256[]) public itemsByRarity;


    event ItemCreated(uint256 indexed itemId, string name, ItemType itemType, uint8 rarity);
    event ItemMinted(address indexed to, uint256 indexed itemId, uint256 amount);
    event ItemBurned(address indexed from, uint256 indexed itemId, uint256 amount);
    event ItemTraded(address indexed from, address indexed to, uint256 indexed itemId, uint256 amount);

    constructor() ERC1155("https://api.gameitem.com/metadata/{id}.json") {
        gameConfig.nextItemId = 1;
        gameConfig.totalItems = 0;
    }


    function createItem(
        string calldata name,
        ItemType itemType,
        uint256 maxSupply,
        uint256 mintPrice,
        bool tradeable,
        uint8 rarity
    ) external onlyOwner {
        require(rarity >= 1 && rarity <= 5, "Invalid rarity");
        require(maxSupply > 0, "Max supply must be positive");

        uint256 itemId = gameConfig.nextItemId;


        items[itemId] = ItemInfo({
            name: name,
            itemType: itemType,
            maxSupply: maxSupply,
            currentSupply: 0,
            mintPrice: mintPrice,
            tradeable: tradeable,
            rarity: rarity
        });


        itemsByType[itemType].push(itemId);
        itemsByRarity[rarity].push(itemId);


        unchecked {
            gameConfig.nextItemId = uint128(itemId + 1);
            gameConfig.totalItems++;
        }

        emit ItemCreated(itemId, name, itemType, rarity);
    }


    function mintItem(uint256 itemId, uint256 amount) external payable nonReentrant whenNotPaused {
        ItemInfo storage item = items[itemId];
        require(bytes(item.name).length > 0, "Item does not exist");
        require(item.currentSupply + amount <= item.maxSupply, "Exceeds max supply");
        require(msg.value >= item.mintPrice * amount, "Insufficient payment");


        uint256 newSupply = item.currentSupply + amount;
        item.currentSupply = newSupply;


        _userItemCache[msg.sender][itemId] += amount;

        _mint(msg.sender, itemId, amount, "");

        emit ItemMinted(msg.sender, itemId, amount);


        if (msg.value > item.mintPrice * amount) {
            payable(msg.sender).transfer(msg.value - item.mintPrice * amount);
        }
    }


    function batchMintItems(
        uint256[] calldata itemIds,
        uint256[] calldata amounts
    ) external payable nonReentrant whenNotPaused {
        require(itemIds.length == amounts.length, "Arrays length mismatch");
        require(itemIds.length <= 10, "Too many items at once");

        uint256 totalCost = 0;
        uint256 length = itemIds.length;


        for (uint256 i = 0; i < length;) {
            uint256 itemId = itemIds[i];
            uint256 amount = amounts[i];

            ItemInfo storage item = items[itemId];
            require(bytes(item.name).length > 0, "Item does not exist");
            require(item.currentSupply + amount <= item.maxSupply, "Exceeds max supply");

            totalCost += item.mintPrice * amount;

            unchecked { ++i; }
        }

        require(msg.value >= totalCost, "Insufficient payment");


        for (uint256 i = 0; i < length;) {
            uint256 itemId = itemIds[i];
            uint256 amount = amounts[i];

            items[itemId].currentSupply += amount;
            _userItemCache[msg.sender][itemId] += amount;

            unchecked { ++i; }
        }

        _mintBatch(msg.sender, itemIds, amounts, "");


        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }
    }


    function burnItem(uint256 itemId, uint256 amount) external {
        require(balanceOf(msg.sender, itemId) >= amount, "Insufficient balance");


        _userItemCache[msg.sender][itemId] -= amount;
        items[itemId].currentSupply -= amount;

        _burn(msg.sender, itemId, amount);

        emit ItemBurned(msg.sender, itemId, amount);
    }


    function tradeItem(
        address to,
        uint256 itemId,
        uint256 amount
    ) external whenNotPaused {
        require(items[itemId].tradeable, "Item not tradeable");
        require(balanceOf(msg.sender, itemId) >= amount, "Insufficient balance");
        require(to != address(0) && to != msg.sender, "Invalid recipient");


        _userItemCache[msg.sender][itemId] -= amount;
        _userItemCache[to][itemId] += amount;

        safeTransferFrom(msg.sender, to, itemId, amount, "");

        emit ItemTraded(msg.sender, to, itemId, amount);
    }


    function getUserItemBalance(address user, uint256 itemId) external view returns (uint256) {
        return _userItemCache[user][itemId];
    }


    function getItemsByType(ItemType itemType) external view returns (uint256[] memory) {
        return itemsByType[itemType];
    }


    function getItemsByRarity(uint8 rarity) external view returns (uint256[] memory) {
        return itemsByRarity[rarity];
    }


    function getItemsInfo(uint256[] calldata itemIds) external view returns (ItemInfo[] memory) {
        ItemInfo[] memory result = new ItemInfo[](itemIds.length);

        for (uint256 i = 0; i < itemIds.length;) {
            result[i] = items[itemIds[i]];
            unchecked { ++i; }
        }

        return result;
    }


    function getUserItems(
        address user,
        uint256 offset,
        uint256 limit
    ) external view returns (uint256[] memory itemIds, uint256[] memory balances) {
        require(limit <= 50, "Limit too high");

        uint256 totalItems = gameConfig.totalItems;
        uint256 end = offset + limit;
        if (end > totalItems) {
            end = totalItems;
        }

        uint256[] memory tempIds = new uint256[](limit);
        uint256[] memory tempBalances = new uint256[](limit);
        uint256 count = 0;

        for (uint256 i = offset + 1; i <= end;) {
            uint256 balance = balanceOf(user, i);
            if (balance > 0) {
                tempIds[count] = i;
                tempBalances[count] = balance;
                count++;
            }
            unchecked { ++i; }
        }


        itemIds = new uint256[](count);
        balances = new uint256[](count);

        for (uint256 i = 0; i < count;) {
            itemIds[i] = tempIds[i];
            balances[i] = tempBalances[i];
            unchecked { ++i; }
        }
    }


    function setURI(string calldata newuri) external onlyOwner {
        _setURI(newuri);
    }


    function setItemTradeable(uint256 itemId, bool tradeable) external onlyOwner {
        require(bytes(items[itemId].name).length > 0, "Item does not exist");
        items[itemId].tradeable = tradeable;
    }


    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }


    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        payable(owner()).transfer(balance);
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
            for (uint256 i = 0; i < ids.length;) {
                _userItemCache[from][ids[i]] -= amounts[i];
                _userItemCache[to][ids[i]] += amounts[i];
                unchecked { ++i; }
            }
        }
    }


    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
