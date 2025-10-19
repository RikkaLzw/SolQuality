
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

    uint16 private nextItemId = 1;

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
        require(_rarity >= 1 && _rarity <= 5, "Rarity must be between 1 and 5");

        uint16 itemId = nextItemId;
        nextItemId++;

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

    function mintItem(address _to, uint16 _itemId, uint32 _amount) external onlyOwner nonReentrant {
        require(itemExists[_itemId], "Item does not exist");
        require(_amount > 0, "Amount must be greater than 0");

        ItemInfo storage item = items[_itemId];
        require(item.currentSupply + _amount <= item.maxSupply, "Exceeds max supply");

        item.currentSupply += _amount;
        playerItemCounts[_to][_itemId] += _amount;

        _mint(_to, _itemId, _amount, "");

        emit ItemMinted(_to, _itemId, _amount);
    }

    function burnItem(uint16 _itemId, uint32 _amount) external nonReentrant {
        require(itemExists[_itemId], "Item does not exist");
        require(_amount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender, _itemId) >= _amount, "Insufficient balance");

        ItemInfo storage item = items[_itemId];
        item.currentSupply -= _amount;
        playerItemCounts[msg.sender][_itemId] -= _amount;

        _burn(msg.sender, _itemId, _amount);

        emit ItemBurned(msg.sender, _itemId, _amount);
    }

    function tradeItem(address _to, uint16 _itemId, uint32 _amount) external nonReentrant whenNotPaused {
        require(itemExists[_itemId], "Item does not exist");
        require(_amount > 0, "Amount must be greater than 0");
        require(_to != address(0), "Invalid recipient address");
        require(_to != msg.sender, "Cannot trade to yourself");
        require(balanceOf(msg.sender, _itemId) >= _amount, "Insufficient balance");
        require(items[_itemId].tradeable, "Item is not tradeable");

        playerItemCounts[msg.sender][_itemId] -= _amount;
        playerItemCounts[_to][_itemId] += _amount;

        safeTransferFrom(msg.sender, _to, _itemId, _amount, "");

        emit ItemTraded(msg.sender, _to, _itemId, _amount);
    }

    function craftItem(uint16 _targetItemId, uint16[] calldata _materialIds, uint32[] calldata _materialAmounts) external nonReentrant whenNotPaused {
        require(itemExists[_targetItemId], "Target item does not exist");
        require(items[_targetItemId].craftable, "Item is not craftable");
        require(_materialIds.length == _materialAmounts.length, "Arrays length mismatch");
        require(_materialIds.length > 0, "No materials provided");

        for (uint8 i = 0; i < _materialIds.length; i++) {
            require(itemExists[_materialIds[i]], "Material item does not exist");
            require(_materialAmounts[i] > 0, "Material amount must be greater than 0");
            require(balanceOf(msg.sender, _materialIds[i]) >= _materialAmounts[i], "Insufficient material balance");
        }

        for (uint8 i = 0; i < _materialIds.length; i++) {
            _burn(msg.sender, _materialIds[i], _materialAmounts[i]);
            items[_materialIds[i]].currentSupply -= _materialAmounts[i];
            playerItemCounts[msg.sender][_materialIds[i]] -= _materialAmounts[i];
        }

        ItemInfo storage targetItem = items[_targetItemId];
        require(targetItem.currentSupply + 1 <= targetItem.maxSupply, "Exceeds max supply");

        targetItem.currentSupply += 1;
        playerItemCounts[msg.sender][_targetItemId] += 1;

        _mint(msg.sender, _targetItemId, 1, "");

        emit ItemMinted(msg.sender, _targetItemId, 1);
    }

    function getItemInfo(uint16 _itemId) external view returns (ItemInfo memory) {
        require(itemExists[_itemId], "Item does not exist");
        return items[_itemId];
    }

    function getPlayerItemCount(address _player, uint16 _itemId) external view returns (uint32) {
        return playerItemCounts[_player][_itemId];
    }

    function setItemTradeable(uint16 _itemId, bool _tradeable) external onlyOwner {
        require(itemExists[_itemId], "Item does not exist");
        items[_itemId].tradeable = _tradeable;
    }

    function setItemCraftable(uint16 _itemId, bool _craftable) external onlyOwner {
        require(itemExists[_itemId], "Item does not exist");
        items[_itemId].craftable = _craftable;
    }

    function setItemPrice(uint16 _itemId, uint64 _price) external onlyOwner {
        require(itemExists[_itemId], "Item does not exist");
        items[_itemId].price = _price;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setURI(string memory _newURI) external onlyOwner {
        _setURI(_newURI);
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
