
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


contract GameItemContract is ERC1155, Ownable, Pausable, ReentrancyGuard {
    using Strings for uint256;


    uint256 public constant WEAPON_TYPE = 1;
    uint256 public constant ARMOR_TYPE = 2;
    uint256 public constant CONSUMABLE_TYPE = 3;
    uint256 public constant MATERIAL_TYPE = 4;

    uint256 public constant MAX_SUPPLY_PER_ITEM = 10000;
    uint256 public constant MAX_LEVEL = 10;
    uint256 public constant CRAFT_COOLDOWN = 1 hours;


    struct Item {
        uint256 itemType;
        uint256 rarity;
        uint256 level;
        uint256 attack;
        uint256 defense;
        uint256 maxSupply;
        uint256 currentSupply;
        bool tradeable;
        bool craftable;
        string name;
    }


    struct Recipe {
        uint256[] requiredItems;
        uint256[] requiredAmounts;
        uint256 resultItem;
        uint256 resultAmount;
        bool active;
    }


    struct Player {
        uint256 lastCraftTime;
        uint256 totalItemsCrafted;
        mapping(uint256 => bool) unlockedRecipes;
    }


    mapping(uint256 => Item) public items;
    mapping(uint256 => Recipe) public recipes;
    mapping(address => Player) public players;
    mapping(uint256 => string) private _tokenURIs;

    uint256 public nextItemId = 1;
    uint256 public nextRecipeId = 1;
    uint256 public craftingFee = 0.001 ether;


    event ItemCreated(uint256 indexed itemId, string name, uint256 itemType, uint256 rarity);
    event ItemCrafted(address indexed player, uint256 indexed recipeId, uint256 indexed resultItem, uint256 amount);
    event ItemUpgraded(address indexed player, uint256 indexed itemId, uint256 newLevel);
    event RecipeAdded(uint256 indexed recipeId, uint256 indexed resultItem);
    event ItemTraded(address indexed from, address indexed to, uint256 indexed itemId, uint256 amount);


    modifier validItem(uint256 itemId) {
        require(itemId > 0 && itemId < nextItemId, "Invalid item ID");
        _;
    }

    modifier validRecipe(uint256 recipeId) {
        require(recipeId > 0 && recipeId < nextRecipeId, "Invalid recipe ID");
        require(recipes[recipeId].active, "Recipe not active");
        _;
    }

    modifier canCraft(address player) {
        require(
            block.timestamp >= players[player].lastCraftTime + CRAFT_COOLDOWN,
            "Crafting cooldown not finished"
        );
        _;
    }

    modifier onlyItemOwner(uint256 itemId, uint256 amount) {
        require(balanceOf(msg.sender, itemId) >= amount, "Insufficient item balance");
        _;
    }

    constructor(string memory baseURI) ERC1155(baseURI) {}


    function createItem(
        uint256 itemType,
        uint256 rarity,
        uint256 attack,
        uint256 defense,
        uint256 maxSupply,
        bool tradeable,
        bool craftable,
        string memory name,
        string memory tokenURI
    ) external onlyOwner {
        require(itemType >= 1 && itemType <= 4, "Invalid item type");
        require(rarity >= 1 && rarity <= 5, "Invalid rarity");
        require(maxSupply <= MAX_SUPPLY_PER_ITEM, "Max supply exceeded");
        require(bytes(name).length > 0, "Name cannot be empty");

        uint256 itemId = nextItemId++;

        items[itemId] = Item({
            itemType: itemType,
            rarity: rarity,
            level: 1,
            attack: attack,
            defense: defense,
            maxSupply: maxSupply,
            currentSupply: 0,
            tradeable: tradeable,
            craftable: craftable,
            name: name
        });

        _tokenURIs[itemId] = tokenURI;

        emit ItemCreated(itemId, name, itemType, rarity);
    }


    function mintItem(
        address to,
        uint256 itemId,
        uint256 amount
    ) external onlyOwner validItem(itemId) {
        Item storage item = items[itemId];
        require(item.currentSupply + amount <= item.maxSupply, "Exceeds max supply");

        item.currentSupply += amount;
        _mint(to, itemId, amount, "");
    }


    function addRecipe(
        uint256[] memory requiredItems,
        uint256[] memory requiredAmounts,
        uint256 resultItem,
        uint256 resultAmount
    ) external onlyOwner validItem(resultItem) {
        require(requiredItems.length == requiredAmounts.length, "Arrays length mismatch");
        require(requiredItems.length > 0, "No required items");
        require(items[resultItem].craftable, "Result item not craftable");

        for (uint256 i = 0; i < requiredItems.length; i++) {
            require(requiredItems[i] > 0 && requiredItems[i] < nextItemId, "Invalid required item");
            require(requiredAmounts[i] > 0, "Invalid required amount");
        }

        uint256 recipeId = nextRecipeId++;

        recipes[recipeId] = Recipe({
            requiredItems: requiredItems,
            requiredAmounts: requiredAmounts,
            resultItem: resultItem,
            resultAmount: resultAmount,
            active: true
        });

        emit RecipeAdded(recipeId, resultItem);
    }


    function craftItem(uint256 recipeId)
        external
        payable
        nonReentrant
        whenNotPaused
        validRecipe(recipeId)
        canCraft(msg.sender)
    {
        require(msg.value >= craftingFee, "Insufficient crafting fee");

        Recipe storage recipe = recipes[recipeId];
        Item storage resultItem = items[recipe.resultItem];

        require(
            resultItem.currentSupply + recipe.resultAmount <= resultItem.maxSupply,
            "Exceeds max supply for result item"
        );


        for (uint256 i = 0; i < recipe.requiredItems.length; i++) {
            require(
                balanceOf(msg.sender, recipe.requiredItems[i]) >= recipe.requiredAmounts[i],
                "Insufficient required items"
            );
            _burn(msg.sender, recipe.requiredItems[i], recipe.requiredAmounts[i]);
        }


        resultItem.currentSupply += recipe.resultAmount;
        _mint(msg.sender, recipe.resultItem, recipe.resultAmount, "");


        players[msg.sender].lastCraftTime = block.timestamp;
        players[msg.sender].totalItemsCrafted += recipe.resultAmount;

        emit ItemCrafted(msg.sender, recipeId, recipe.resultItem, recipe.resultAmount);
    }


    function upgradeItem(uint256 itemId, uint256 amount)
        external
        payable
        nonReentrant
        whenNotPaused
        validItem(itemId)
        onlyItemOwner(itemId, amount)
    {
        Item storage item = items[itemId];
        require(item.level < MAX_LEVEL, "Item already at max level");
        require(item.itemType == WEAPON_TYPE || item.itemType == ARMOR_TYPE, "Item not upgradeable");

        uint256 upgradeCost = _calculateUpgradeCost(item.level, item.rarity);
        require(msg.value >= upgradeCost, "Insufficient upgrade fee");


        _burn(msg.sender, itemId, amount);


        uint256 upgradedItemId = _createUpgradedItem(itemId);
        _mint(msg.sender, upgradedItemId, amount, "");

        emit ItemUpgraded(msg.sender, upgradedItemId, item.level + 1);
    }


    function tradeItem(
        address to,
        uint256 itemId,
        uint256 amount
    ) external nonReentrant whenNotPaused validItem(itemId) onlyItemOwner(itemId, amount) {
        require(items[itemId].tradeable, "Item not tradeable");
        require(to != address(0) && to != msg.sender, "Invalid recipient");

        safeTransferFrom(msg.sender, to, itemId, amount, "");

        emit ItemTraded(msg.sender, to, itemId, amount);
    }


    function getItem(uint256 itemId) external view validItem(itemId) returns (Item memory) {
        return items[itemId];
    }


    function getRecipe(uint256 recipeId) external view validRecipe(recipeId) returns (Recipe memory) {
        return recipes[recipeId];
    }


    function getPlayerInfo(address player) external view returns (uint256, uint256) {
        return (players[player].lastCraftTime, players[player].totalItemsCrafted);
    }


    function setTokenURI(uint256 tokenId, string memory tokenURI) external onlyOwner {
        _tokenURIs[tokenId] = tokenURI;
    }


    function uri(uint256 tokenId) public view override returns (string memory) {
        return bytes(_tokenURIs[tokenId]).length > 0 ? _tokenURIs[tokenId] : super.uri(tokenId);
    }


    function setCraftingFee(uint256 newFee) external onlyOwner {
        craftingFee = newFee;
    }


    function toggleRecipe(uint256 recipeId) external onlyOwner {
        require(recipeId > 0 && recipeId < nextRecipeId, "Invalid recipe ID");
        recipes[recipeId].active = !recipes[recipeId].active;
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

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }


    function _calculateUpgradeCost(uint256 currentLevel, uint256 rarity) internal pure returns (uint256) {
        return (currentLevel * rarity * 0.001 ether) + 0.001 ether;
    }


    function _createUpgradedItem(uint256 originalItemId) internal returns (uint256) {
        Item storage originalItem = items[originalItemId];
        uint256 upgradedItemId = nextItemId++;

        uint256 newAttack = originalItem.attack + (originalItem.attack * 10 / 100);
        uint256 newDefense = originalItem.defense + (originalItem.defense * 10 / 100);

        items[upgradedItemId] = Item({
            itemType: originalItem.itemType,
            rarity: originalItem.rarity,
            level: originalItem.level + 1,
            attack: newAttack,
            defense: newDefense,
            maxSupply: originalItem.maxSupply,
            currentSupply: 0,
            tradeable: originalItem.tradeable,
            craftable: false,
            name: string(abi.encodePacked(originalItem.name, " +", (originalItem.level + 1).toString()))
        });

        _tokenURIs[upgradedItemId] = _tokenURIs[originalItemId];

        return upgradedItemId;
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
