
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract GameItemContract is ERC1155, Ownable, Pausable, ReentrancyGuard {
    struct ItemInfo {
        string name;
        uint256 maxSupply;
        uint256 currentSupply;
        uint256 price;
        bool tradeable;
    }

    mapping(uint256 => ItemInfo) public items;
    mapping(address => mapping(uint256 => bool)) public playerItems;
    mapping(address => bool) public gameOperators;

    uint256 private _itemIdCounter;

    event ItemCreated(uint256 indexed itemId, string name, uint256 maxSupply, uint256 price);
    event ItemMinted(address indexed to, uint256 indexed itemId, uint256 amount);
    event ItemBurned(address indexed from, uint256 indexed itemId, uint256 amount);
    event GameOperatorSet(address indexed operator, bool status);

    modifier onlyGameOperator() {
        require(gameOperators[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }

    constructor(string memory uri) ERC1155(uri) {}

    function createItem(
        string memory name,
        uint256 maxSupply,
        uint256 price,
        bool tradeable
    ) external onlyOwner returns (uint256) {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(maxSupply > 0, "Max supply must be positive");

        uint256 itemId = _itemIdCounter++;

        items[itemId] = ItemInfo({
            name: name,
            maxSupply: maxSupply,
            currentSupply: 0,
            price: price,
            tradeable: tradeable
        });

        emit ItemCreated(itemId, name, maxSupply, price);
        return itemId;
    }

    function mintItem(
        address to,
        uint256 itemId,
        uint256 amount
    ) external onlyGameOperator whenNotPaused {
        require(to != address(0), "Invalid recipient");
        require(_itemExists(itemId), "Item does not exist");

        ItemInfo storage item = items[itemId];
        require(item.currentSupply + amount <= item.maxSupply, "Exceeds max supply");

        item.currentSupply += amount;
        playerItems[to][itemId] = true;

        _mint(to, itemId, amount, "");
        emit ItemMinted(to, itemId, amount);
    }

    function burnItem(
        address from,
        uint256 itemId,
        uint256 amount
    ) external onlyGameOperator {
        require(from != address(0), "Invalid address");
        require(_itemExists(itemId), "Item does not exist");
        require(balanceOf(from, itemId) >= amount, "Insufficient balance");

        items[itemId].currentSupply -= amount;
        _burn(from, itemId, amount);

        emit ItemBurned(from, itemId, amount);
    }

    function purchaseItem(uint256 itemId, uint256 amount)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        require(_itemExists(itemId), "Item does not exist");

        ItemInfo storage item = items[itemId];
        require(item.currentSupply + amount <= item.maxSupply, "Exceeds max supply");
        require(msg.value >= item.price * amount, "Insufficient payment");

        item.currentSupply += amount;
        playerItems[msg.sender][itemId] = true;

        _mint(msg.sender, itemId, amount, "");
        emit ItemMinted(msg.sender, itemId, amount);
    }

    function setGameOperator(address operator, bool status) external onlyOwner {
        require(operator != address(0), "Invalid operator address");
        gameOperators[operator] = status;
        emit GameOperatorSet(operator, status);
    }

    function updateItemPrice(uint256 itemId, uint256 newPrice) external onlyOwner {
        require(_itemExists(itemId), "Item does not exist");
        items[itemId].price = newPrice;
    }

    function setItemTradeable(uint256 itemId, bool tradeable) external onlyOwner {
        require(_itemExists(itemId), "Item does not exist");
        items[itemId].tradeable = tradeable;
    }

    function getItemInfo(uint256 itemId) external view returns (ItemInfo memory) {
        require(_itemExists(itemId), "Item does not exist");
        return items[itemId];
    }

    function hasPlayerItem(address player, uint256 itemId) external view returns (bool) {
        return playerItems[player][itemId];
    }

    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner()).transfer(balance);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override {
        require(_itemExists(id), "Item does not exist");
        require(items[id].tradeable, "Item not tradeable");
        super.safeTransferFrom(from, to, id, amount, data);
        playerItems[to][id] = true;
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public override {
        for (uint256 i = 0; i < ids.length; i++) {
            require(_itemExists(ids[i]), "Item does not exist");
            require(items[ids[i]].tradeable, "Item not tradeable");
        }
        super.safeBatchTransferFrom(from, to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; i++) {
            playerItems[to][ids[i]] = true;
        }
    }

    function _itemExists(uint256 itemId) internal view returns (bool) {
        return itemId < _itemIdCounter;
    }
}
