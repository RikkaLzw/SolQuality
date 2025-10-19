
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract GameItemContract is ERC1155, Ownable, ReentrancyGuard, Pausable {

    struct ItemInfo {
        uint128 maxSupply;
        uint128 currentSupply;
        uint64 price;
        uint32 rarity;
        bool tradeable;
        bool mintable;
    }


    mapping(uint256 => ItemInfo) public items;
    mapping(address => mapping(uint256 => uint256)) private userItemCounts;
    mapping(uint256 => string) private itemURIs;


    uint256[] private itemIds;
    mapping(uint256 => uint256) private itemIdToIndex;


    event ItemCreated(uint256 indexed itemId, uint128 maxSupply, uint64 price, uint32 rarity);
    event ItemMinted(address indexed to, uint256 indexed itemId, uint256 amount);
    event ItemBurned(address indexed from, uint256 indexed itemId, uint256 amount);
    event ItemTraded(address indexed from, address indexed to, uint256 indexed itemId, uint256 amount);

    constructor(string memory baseURI) ERC1155(baseURI) {}


    function createItem(
        uint256 itemId,
        uint128 maxSupply,
        uint64 price,
        uint32 rarity,
        bool tradeable,
        string memory itemURI
    ) external onlyOwner {
        require(items[itemId].maxSupply == 0, "Item already exists");
        require(maxSupply > 0, "Max supply must be positive");

        items[itemId] = ItemInfo({
            maxSupply: maxSupply,
            currentSupply: 0,
            price: price,
            rarity: rarity,
            tradeable: tradeable,
            mintable: true
        });

        itemIds.push(itemId);
        itemIdToIndex[itemId] = itemIds.length - 1;
        itemURIs[itemId] = itemURI;

        emit ItemCreated(itemId, maxSupply, price, rarity);
    }


    function mintItem(address to, uint256 itemId, uint256 amount)
        external
        onlyOwner
        whenNotPaused
        nonReentrant
    {
        ItemInfo storage item = items[itemId];
        require(item.mintable, "Item not mintable");
        require(item.currentSupply + amount <= item.maxSupply, "Exceeds max supply");


        uint128 newSupply = item.currentSupply + uint128(amount);
        item.currentSupply = newSupply;


        userItemCounts[to][itemId] += amount;

        _mint(to, itemId, amount, "");
        emit ItemMinted(to, itemId, amount);
    }


    function batchMintItems(
        address to,
        uint256[] memory itemIds_,
        uint256[] memory amounts
    ) external onlyOwner whenNotPaused nonReentrant {
        require(itemIds_.length == amounts.length, "Arrays length mismatch");


        for (uint256 i = 0; i < itemIds_.length;) {
            ItemInfo storage item = items[itemIds_[i]];
            require(item.mintable, "Item not mintable");
            require(item.currentSupply + amounts[i] <= item.maxSupply, "Exceeds max supply");
            unchecked { ++i; }
        }


        for (uint256 i = 0; i < itemIds_.length;) {
            uint256 itemId = itemIds_[i];
            uint256 amount = amounts[i];

            items[itemId].currentSupply += uint128(amount);
            userItemCounts[to][itemId] += amount;

            emit ItemMinted(to, itemId, amount);
            unchecked { ++i; }
        }

        _mintBatch(to, itemIds_, amounts, "");
    }


    function burnItem(uint256 itemId, uint256 amount)
        external
        whenNotPaused
        nonReentrant
    {
        require(balanceOf(msg.sender, itemId) >= amount, "Insufficient balance");


        items[itemId].currentSupply -= uint128(amount);
        userItemCounts[msg.sender][itemId] -= amount;

        _burn(msg.sender, itemId, amount);
        emit ItemBurned(msg.sender, itemId, amount);
    }


    function tradeItem(
        address from,
        address to,
        uint256 itemId,
        uint256 amount
    ) external whenNotPaused nonReentrant {
        require(items[itemId].tradeable, "Item not tradeable");
        require(
            msg.sender == from || isApprovedForAll(from, msg.sender),
            "Not authorized"
        );
        require(balanceOf(from, itemId) >= amount, "Insufficient balance");


        userItemCounts[from][itemId] -= amount;
        userItemCounts[to][itemId] += amount;

        _safeTransferFrom(from, to, itemId, amount, "");
        emit ItemTraded(from, to, itemId, amount);
    }


    function getItemInfo(uint256 itemId)
        external
        view
        returns (
            uint128 maxSupply,
            uint128 currentSupply,
            uint64 price,
            uint32 rarity,
            bool tradeable,
            bool mintable
        )
    {
        ItemInfo memory item = items[itemId];
        return (
            item.maxSupply,
            item.currentSupply,
            item.price,
            item.rarity,
            item.tradeable,
            item.mintable
        );
    }


    function getUserItemCount(address user, uint256 itemId)
        external
        view
        returns (uint256)
    {
        return userItemCounts[user][itemId];
    }


    function getAllItemIds() external view returns (uint256[] memory) {
        return itemIds;
    }


    function updateItemProperties(
        uint256 itemId,
        uint64 newPrice,
        bool tradeable,
        bool mintable
    ) external onlyOwner {
        require(items[itemId].maxSupply > 0, "Item does not exist");

        ItemInfo storage item = items[itemId];
        item.price = newPrice;
        item.tradeable = tradeable;
        item.mintable = mintable;
    }


    function uri(uint256 itemId) public view override returns (string memory) {
        string memory itemURI = itemURIs[itemId];
        return bytes(itemURI).length > 0 ? itemURI : super.uri(itemId);
    }


    function setItemURI(uint256 itemId, string memory newURI) external onlyOwner {
        require(items[itemId].maxSupply > 0, "Item does not exist");
        itemURIs[itemId] = newURI;
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


        if (from != address(0) && to != address(0)) {
            for (uint256 i = 0; i < ids.length;) {
                userItemCounts[from][ids[i]] -= amounts[i];
                userItemCounts[to][ids[i]] += amounts[i];
                unchecked { ++i; }
            }
        }
    }


    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        override
        returns (uint256[] memory)
    {
        require(accounts.length == ids.length, "Arrays length mismatch");

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length;) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
            unchecked { ++i; }
        }

        return batchBalances;
    }
}
