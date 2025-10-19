
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract GameItemContract is ERC1155, Ownable, Pausable, ReentrancyGuard {

    struct ItemInfo {
        bytes32 name;
        uint16 rarity;
        uint32 maxSupply;
        uint32 currentSupply;
        uint64 price;
        bool tradeable;
        bool craftable;
    }

    mapping(uint16 => ItemInfo) public items;
    mapping(address => mapping(uint16 => uint32)) public playerItemCounts;
    mapping(uint16 => bool) public itemExists;

    uint16 private _currentItemId;
    uint64 public constant MAX_ITEMS_PER_MINT = 100;

    event ItemCreated(uint16 indexed itemId, bytes32 name, uint16 rarity, uint32 maxSupply, uint64 price);
    event ItemMinted(address indexed to, uint16 indexed itemId, uint32 amount);
    event ItemBurned(address indexed from, uint16 indexed itemId, uint32 amount);
    event ItemTraded(address indexed from, address indexed to, uint16 indexed itemId, uint32 amount);

    constructor(string memory uri) ERC1155(uri) {}

    function createItem(
        bytes32 _name,
        uint16 _rarity,
        uint32 _maxSupply,
        uint64 _price,
        bool _tradeable,
        bool _craftable
    ) external onlyOwner {
        require(_maxSupply > 0, "Max supply must be greater than 0");
        require(_rarity > 0 && _rarity <= 5, "Rarity must be between 1 and 5");

        uint16 itemId = ++_currentItemId;

        items[itemId] = ItemInfo({
            name: _name,
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

    function mintItem(
        address _to,
        uint16 _itemId,
        uint32 _amount
    ) external onlyOwner nonReentrant whenNotPaused {
        require(itemExists[_itemId], "Item does not exist");
        require(_amount > 0 && _amount <= MAX_ITEMS_PER_MINT, "Invalid amount");
        require(_to != address(0), "Cannot mint to zero address");

        ItemInfo storage item = items[_itemId];
        require(item.currentSupply + _amount <= item.maxSupply, "Exceeds max supply");

        item.currentSupply += _amount;
        playerItemCounts[_to][_itemId] += _amount;

        _mint(_to, _itemId, _amount, "");

        emit ItemMinted(_to, _itemId, _amount);
    }

    function burnItem(
        uint16 _itemId,
        uint32 _amount
    ) external nonReentrant whenNotPaused {
        require(itemExists[_itemId], "Item does not exist");
        require(_amount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender, _itemId) >= _amount, "Insufficient balance");

        ItemInfo storage item = items[_itemId];
        item.currentSupply -= _amount;
        playerItemCounts[msg.sender][_itemId] -= _amount;

        _burn(msg.sender, _itemId, _amount);

        emit ItemBurned(msg.sender, _itemId, _amount);
    }

    function tradeItem(
        address _to,
        uint16 _itemId,
        uint32 _amount
    ) external nonReentrant whenNotPaused {
        require(itemExists[_itemId], "Item does not exist");
        require(_amount > 0, "Amount must be greater than 0");
        require(_to != address(0), "Cannot trade to zero address");
        require(_to != msg.sender, "Cannot trade to yourself");
        require(balanceOf(msg.sender, _itemId) >= _amount, "Insufficient balance");
        require(items[_itemId].tradeable, "Item is not tradeable");

        playerItemCounts[msg.sender][_itemId] -= _amount;
        playerItemCounts[_to][_itemId] += _amount;

        _safeTransferFrom(msg.sender, _to, _itemId, _amount, "");

        emit ItemTraded(msg.sender, _to, _itemId, _amount);
    }

    function getItemInfo(uint16 _itemId) external view returns (ItemInfo memory) {
        require(itemExists[_itemId], "Item does not exist");
        return items[_itemId];
    }

    function getPlayerItemCount(address _player, uint16 _itemId) external view returns (uint32) {
        return playerItemCounts[_player][_itemId];
    }

    function getCurrentItemId() external view returns (uint16) {
        return _currentItemId;
    }

    function updateItemPrice(uint16 _itemId, uint64 _newPrice) external onlyOwner {
        require(itemExists[_itemId], "Item does not exist");
        items[_itemId].price = _newPrice;
    }

    function updateItemTradeable(uint16 _itemId, bool _tradeable) external onlyOwner {
        require(itemExists[_itemId], "Item does not exist");
        items[_itemId].tradeable = _tradeable;
    }

    function setURI(string memory _newURI) external onlyOwner {
        _setURI(_newURI);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
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
