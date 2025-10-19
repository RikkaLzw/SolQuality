
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract GameItemContract is ERC1155, Ownable, Pausable, ReentrancyGuard {

    struct GameItem {
        string name;
        string description;
        uint256 rarity;
        uint256 maxSupply;
        uint256 currentSupply;
        uint256 price;
        bool tradeable;
        bool craftable;
    }


    mapping(uint256 => GameItem) public gameItems;
    mapping(uint256 => bool) public itemExists;
    mapping(address => mapping(uint256 => bool)) public playerCraftedItem;
    mapping(uint256 => uint256[]) public craftingRecipe;
    mapping(uint256 => uint256[]) public craftingAmounts;

    uint256 public nextItemId = 1;
    uint256 public craftingFee = 0.001 ether;


    event ItemCreated(
        uint256 indexed itemId,
        string name,
        uint256 indexed rarity,
        uint256 maxSupply,
        uint256 price
    );

    event ItemMinted(
        address indexed to,
        uint256 indexed itemId,
        uint256 amount,
        uint256 totalPaid
    );

    event ItemCrafted(
        address indexed crafter,
        uint256 indexed craftedItemId,
        uint256[] requiredItems,
        uint256[] requiredAmounts
    );

    event ItemTradeStatusChanged(
        uint256 indexed itemId,
        bool tradeable
    );

    event CraftingRecipeSet(
        uint256 indexed itemId,
        uint256[] requiredItems,
        uint256[] requiredAmounts
    );

    event CraftingFeeUpdated(
        uint256 oldFee,
        uint256 newFee
    );

    constructor() ERC1155("https://api.gameitem.com/metadata/{id}.json") {}


    function createItem(
        string memory _name,
        string memory _description,
        uint256 _rarity,
        uint256 _maxSupply,
        uint256 _price,
        bool _tradeable,
        bool _craftable
    ) external onlyOwner {
        require(bytes(_name).length > 0, "GameItemContract: Item name cannot be empty");
        require(_rarity >= 1 && _rarity <= 5, "GameItemContract: Rarity must be between 1 and 5");
        require(_maxSupply > 0, "GameItemContract: Max supply must be greater than 0");

        uint256 itemId = nextItemId++;

        gameItems[itemId] = GameItem({
            name: _name,
            description: _description,
            rarity: _rarity,
            maxSupply: _maxSupply,
            currentSupply: 0,
            price: _price,
            tradeable: _tradeable,
            craftable: _craftable
        });

        itemExists[itemId] = true;

        emit ItemCreated(itemId, _name, _rarity, _maxSupply, _price);
    }


    function mintItem(uint256 _itemId, uint256 _amount) external payable whenNotPaused nonReentrant {
        require(itemExists[_itemId], "GameItemContract: Item does not exist");
        require(_amount > 0, "GameItemContract: Amount must be greater than 0");

        GameItem storage item = gameItems[_itemId];
        require(item.currentSupply + _amount <= item.maxSupply, "GameItemContract: Exceeds max supply");

        uint256 totalCost = item.price * _amount;
        require(msg.value >= totalCost, "GameItemContract: Insufficient payment");

        item.currentSupply += _amount;
        _mint(msg.sender, _itemId, _amount, "");


        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }

        emit ItemMinted(msg.sender, _itemId, _amount, totalCost);
    }


    function setCraftingRecipe(
        uint256 _itemId,
        uint256[] memory _requiredItems,
        uint256[] memory _requiredAmounts
    ) external onlyOwner {
        require(itemExists[_itemId], "GameItemContract: Item does not exist");
        require(_requiredItems.length > 0, "GameItemContract: Recipe cannot be empty");
        require(_requiredItems.length == _requiredAmounts.length, "GameItemContract: Arrays length mismatch");
        require(gameItems[_itemId].craftable, "GameItemContract: Item is not craftable");


        for (uint256 i = 0; i < _requiredItems.length; i++) {
            require(itemExists[_requiredItems[i]], "GameItemContract: Required item does not exist");
            require(_requiredAmounts[i] > 0, "GameItemContract: Required amount must be greater than 0");
        }

        craftingRecipe[_itemId] = _requiredItems;
        craftingAmounts[_itemId] = _requiredAmounts;

        emit CraftingRecipeSet(_itemId, _requiredItems, _requiredAmounts);
    }


    function craftItem(uint256 _itemId) external payable whenNotPaused nonReentrant {
        require(itemExists[_itemId], "GameItemContract: Item does not exist");
        require(gameItems[_itemId].craftable, "GameItemContract: Item is not craftable");
        require(craftingRecipe[_itemId].length > 0, "GameItemContract: No crafting recipe set");
        require(msg.value >= craftingFee, "GameItemContract: Insufficient crafting fee");
        require(gameItems[_itemId].currentSupply < gameItems[_itemId].maxSupply, "GameItemContract: Max supply reached");

        uint256[] memory requiredItems = craftingRecipe[_itemId];
        uint256[] memory requiredAmounts = craftingAmounts[_itemId];


        for (uint256 i = 0; i < requiredItems.length; i++) {
            require(
                balanceOf(msg.sender, requiredItems[i]) >= requiredAmounts[i],
                "GameItemContract: Insufficient required items for crafting"
            );
        }


        for (uint256 i = 0; i < requiredItems.length; i++) {
            _burn(msg.sender, requiredItems[i], requiredAmounts[i]);
        }


        gameItems[_itemId].currentSupply += 1;
        _mint(msg.sender, _itemId, 1, "");
        playerCraftedItem[msg.sender][_itemId] = true;


        if (msg.value > craftingFee) {
            payable(msg.sender).transfer(msg.value - craftingFee);
        }

        emit ItemCrafted(msg.sender, _itemId, requiredItems, requiredAmounts);
    }


    function setItemTradeable(uint256 _itemId, bool _tradeable) external onlyOwner {
        require(itemExists[_itemId], "GameItemContract: Item does not exist");

        gameItems[_itemId].tradeable = _tradeable;

        emit ItemTradeStatusChanged(_itemId, _tradeable);
    }


    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override {
        require(gameItems[id].tradeable || from == address(0), "GameItemContract: Item is not tradeable");
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
            require(gameItems[ids[i]].tradeable || from == address(0), "GameItemContract: Item is not tradeable");
        }
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }


    function setCraftingFee(uint256 _newFee) external onlyOwner {
        uint256 oldFee = craftingFee;
        craftingFee = _newFee;

        emit CraftingFeeUpdated(oldFee, _newFee);
    }


    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }


    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "GameItemContract: No funds to withdraw");

        payable(owner()).transfer(balance);
    }


    function getItem(uint256 _itemId) external view returns (GameItem memory) {
        require(itemExists[_itemId], "GameItemContract: Item does not exist");
        return gameItems[_itemId];
    }

    function getCraftingRecipe(uint256 _itemId) external view returns (uint256[] memory, uint256[] memory) {
        require(itemExists[_itemId], "GameItemContract: Item does not exist");
        return (craftingRecipe[_itemId], craftingAmounts[_itemId]);
    }

    function hasPlayerCraftedItem(address _player, uint256 _itemId) external view returns (bool) {
        return playerCraftedItem[_player][_itemId];
    }


    function setURI(string memory _newURI) external onlyOwner {
        _setURI(_newURI);
    }
}
