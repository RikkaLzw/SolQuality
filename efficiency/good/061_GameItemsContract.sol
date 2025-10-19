
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract GameItemsContract is ERC1155, Ownable, Pausable, ReentrancyGuard {

    struct ItemInfo {
        uint128 price;
        uint64 maxSupply;
        uint32 rarity;
        uint16 itemType;
        uint8 level;
        bool tradeable;
    }


    mapping(uint256 => ItemInfo) public items;
    mapping(uint256 => uint256) public totalSupply;
    mapping(address => mapping(uint256 => uint256)) public playerCooldowns;
    mapping(uint256 => string) private _tokenURIs;

    uint256 public nextItemId = 1;
    uint256 public constant MAX_BATCH_SIZE = 50;
    uint256 public constant COOLDOWN_PERIOD = 1 hours;


    event ItemCreated(uint256 indexed itemId, uint128 price, uint64 maxSupply, uint16 itemType);
    event ItemMinted(address indexed to, uint256 indexed itemId, uint256 amount);
    event ItemBurned(address indexed from, uint256 indexed itemId, uint256 amount);

    constructor(string memory uri) ERC1155(uri) {}


    function createItem(
        uint128 _price,
        uint64 _maxSupply,
        uint32 _rarity,
        uint16 _itemType,
        uint8 _level,
        bool _tradeable,
        string memory _uri
    ) external onlyOwner {
        uint256 itemId = nextItemId++;

        items[itemId] = ItemInfo({
            price: _price,
            maxSupply: _maxSupply,
            rarity: _rarity,
            itemType: _itemType,
            level: _level,
            tradeable: _tradeable
        });

        _tokenURIs[itemId] = _uri;

        emit ItemCreated(itemId, _price, _maxSupply, _itemType);
    }


    function purchaseItem(uint256 itemId, uint256 amount)
        external
        payable
        whenNotPaused
        nonReentrant
    {

        ItemInfo memory item = items[itemId];
        require(item.price > 0, "Item does not exist");

        uint256 currentSupply = totalSupply[itemId];
        require(currentSupply + amount <= item.maxSupply, "Exceeds max supply");


        require(
            block.timestamp >= playerCooldowns[msg.sender][itemId] + COOLDOWN_PERIOD,
            "Cooldown period not met"
        );

        uint256 totalCost = item.price * amount;
        require(msg.value >= totalCost, "Insufficient payment");


        totalSupply[itemId] = currentSupply + amount;
        playerCooldowns[msg.sender][itemId] = block.timestamp;


        _mint(msg.sender, itemId, amount, "");


        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }

        emit ItemMinted(msg.sender, itemId, amount);
    }


    function batchPurchaseItems(
        uint256[] calldata itemIds,
        uint256[] calldata amounts
    ) external payable whenNotPaused nonReentrant {
        require(itemIds.length == amounts.length, "Arrays length mismatch");
        require(itemIds.length <= MAX_BATCH_SIZE, "Batch size too large");

        uint256 totalCost = 0;
        uint256 currentTime = block.timestamp;


        for (uint256 i = 0; i < itemIds.length; ) {
            uint256 itemId = itemIds[i];
            uint256 amount = amounts[i];

            ItemInfo memory item = items[itemId];
            require(item.price > 0, "Item does not exist");
            require(
                totalSupply[itemId] + amount <= item.maxSupply,
                "Exceeds max supply"
            );
            require(
                currentTime >= playerCooldowns[msg.sender][itemId] + COOLDOWN_PERIOD,
                "Cooldown period not met"
            );

            totalCost += item.price * amount;

            unchecked { ++i; }
        }

        require(msg.value >= totalCost, "Insufficient payment");


        for (uint256 i = 0; i < itemIds.length; ) {
            uint256 itemId = itemIds[i];
            uint256 amount = amounts[i];

            totalSupply[itemId] += amount;
            playerCooldowns[msg.sender][itemId] = currentTime;

            unchecked { ++i; }
        }

        _mintBatch(msg.sender, itemIds, amounts, "");


        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }
    }


    function adminMint(
        address to,
        uint256 itemId,
        uint256 amount
    ) external onlyOwner {
        ItemInfo memory item = items[itemId];
        require(item.price > 0, "Item does not exist");
        require(totalSupply[itemId] + amount <= item.maxSupply, "Exceeds max supply");

        totalSupply[itemId] += amount;
        _mint(to, itemId, amount, "");

        emit ItemMinted(to, itemId, amount);
    }


    function burnItem(uint256 itemId, uint256 amount) external {
        require(balanceOf(msg.sender, itemId) >= amount, "Insufficient balance");

        totalSupply[itemId] -= amount;
        _burn(msg.sender, itemId, amount);

        emit ItemBurned(msg.sender, itemId, amount);
    }


    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override {
        require(items[id].tradeable, "Item is not tradeable");
        super.safeTransferFrom(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public override {

        for (uint256 i = 0; i < ids.length; ) {
            require(items[ids[i]].tradeable, "Item is not tradeable");
            unchecked { ++i; }
        }
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }


    function uri(uint256 tokenId) public view override returns (string memory) {
        string memory tokenURI = _tokenURIs[tokenId];
        return bytes(tokenURI).length > 0 ? tokenURI : super.uri(tokenId);
    }


    function setTokenURI(uint256 tokenId, string memory newURI) external onlyOwner {
        _tokenURIs[tokenId] = newURI;
    }


    function updateItemPrice(uint256 itemId, uint128 newPrice) external onlyOwner {
        require(items[itemId].price > 0, "Item does not exist");
        items[itemId].price = newPrice;
    }

    function updateItemTradeable(uint256 itemId, bool tradeable) external onlyOwner {
        require(items[itemId].price > 0, "Item does not exist");
        items[itemId].tradeable = tradeable;
    }


    function getItemInfo(uint256 itemId)
        external
        view
        returns (
            uint128 price,
            uint64 maxSupply,
            uint32 rarity,
            uint16 itemType,
            uint8 level,
            bool tradeable,
            uint256 currentSupply
        )
    {
        ItemInfo memory item = items[itemId];
        return (
            item.price,
            item.maxSupply,
            item.rarity,
            item.itemType,
            item.level,
            item.tradeable,
            totalSupply[itemId]
        );
    }


    function getBalances(address account, uint256[] calldata itemIds)
        external
        view
        returns (uint256[] memory balances)
    {
        balances = new uint256[](itemIds.length);
        for (uint256 i = 0; i < itemIds.length; ) {
            balances[i] = balanceOf(account, itemIds[i]);
            unchecked { ++i; }
        }
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


    function setURI(string memory newURI) external onlyOwner {
        _setURI(newURI);
    }
}
