
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract GameItemContract is ERC1155, Ownable, Pausable, ReentrancyGuard {
    using Counters for Counters.Counter;


    uint256 public constant MAX_SUPPLY_PER_ITEM = 10000;
    uint256 public constant MAX_MINT_PER_TX = 50;
    uint256 public constant ROYALTY_PERCENTAGE = 250;
    uint256 public constant PERCENTAGE_BASE = 10000;


    Counters.Counter private _itemIdCounter;
    mapping(uint256 => ItemInfo) public itemInfo;
    mapping(uint256 => uint256) public itemSupply;
    mapping(address => bool) public authorizedMinters;

    struct ItemInfo {
        string name;
        string description;
        uint256 rarity;
        uint256 maxSupply;
        uint256 mintPrice;
        bool mintable;
        address creator;
    }


    event ItemCreated(uint256 indexed itemId, string name, uint256 rarity, uint256 maxSupply);
    event ItemMinted(address indexed to, uint256 indexed itemId, uint256 amount);
    event MinterAuthorized(address indexed minter, bool authorized);
    event ItemInfoUpdated(uint256 indexed itemId, string name, string description);


    modifier onlyAuthorizedMinter() {
        require(authorizedMinters[msg.sender] || msg.sender == owner(), "Not authorized to mint");
        _;
    }

    modifier validItemId(uint256 itemId) {
        require(itemId < _itemIdCounter.current(), "Item does not exist");
        _;
    }

    modifier mintableItem(uint256 itemId) {
        require(itemInfo[itemId].mintable, "Item is not mintable");
        _;
    }

    modifier withinSupplyLimit(uint256 itemId, uint256 amount) {
        require(
            itemSupply[itemId] + amount <= itemInfo[itemId].maxSupply,
            "Exceeds maximum supply"
        );
        _;
    }

    modifier withinMintLimit(uint256 amount) {
        require(amount > 0 && amount <= MAX_MINT_PER_TX, "Invalid mint amount");
        _;
    }

    constructor(string memory uri) ERC1155(uri) {}


    function createItem(
        string memory name,
        string memory description,
        uint256 rarity,
        uint256 maxSupply,
        uint256 mintPrice
    ) external onlyOwner returns (uint256) {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(rarity >= 1 && rarity <= 5, "Invalid rarity level");
        require(maxSupply > 0 && maxSupply <= MAX_SUPPLY_PER_ITEM, "Invalid max supply");

        uint256 itemId = _itemIdCounter.current();
        _itemIdCounter.increment();

        itemInfo[itemId] = ItemInfo({
            name: name,
            description: description,
            rarity: rarity,
            maxSupply: maxSupply,
            mintPrice: mintPrice,
            mintable: true,
            creator: msg.sender
        });

        emit ItemCreated(itemId, name, rarity, maxSupply);
        return itemId;
    }


    function mintItem(
        address to,
        uint256 itemId,
        uint256 amount
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyAuthorizedMinter
        validItemId(itemId)
        mintableItem(itemId)
        withinSupplyLimit(itemId, amount)
        withinMintLimit(amount)
    {
        require(to != address(0), "Cannot mint to zero address");

        uint256 totalCost = itemInfo[itemId].mintPrice * amount;
        require(msg.value >= totalCost, "Insufficient payment");

        itemSupply[itemId] += amount;
        _mint(to, itemId, amount, "");


        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }

        emit ItemMinted(to, itemId, amount);
    }


    function mintBatch(
        address to,
        uint256[] memory itemIds,
        uint256[] memory amounts
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyAuthorizedMinter
    {
        require(to != address(0), "Cannot mint to zero address");
        require(itemIds.length == amounts.length, "Arrays length mismatch");
        require(itemIds.length > 0, "Empty arrays");

        uint256 totalCost = 0;

        for (uint256 i = 0; i < itemIds.length; i++) {
            uint256 itemId = itemIds[i];
            uint256 amount = amounts[i];

            require(itemId < _itemIdCounter.current(), "Item does not exist");
            require(itemInfo[itemId].mintable, "Item is not mintable");
            require(amount > 0 && amount <= MAX_MINT_PER_TX, "Invalid mint amount");
            require(
                itemSupply[itemId] + amount <= itemInfo[itemId].maxSupply,
                "Exceeds maximum supply"
            );

            itemSupply[itemId] += amount;
            totalCost += itemInfo[itemId].mintPrice * amount;
        }

        require(msg.value >= totalCost, "Insufficient payment");

        _mintBatch(to, itemIds, amounts, "");


        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }

        for (uint256 i = 0; i < itemIds.length; i++) {
            emit ItemMinted(to, itemIds[i], amounts[i]);
        }
    }


    function setAuthorizedMinter(address minter, bool authorized) external onlyOwner {
        require(minter != address(0), "Invalid minter address");
        authorizedMinters[minter] = authorized;
        emit MinterAuthorized(minter, authorized);
    }


    function updateItemInfo(
        uint256 itemId,
        string memory name,
        string memory description
    ) external onlyOwner validItemId(itemId) {
        require(bytes(name).length > 0, "Name cannot be empty");

        itemInfo[itemId].name = name;
        itemInfo[itemId].description = description;

        emit ItemInfoUpdated(itemId, name, description);
    }


    function setItemPrice(uint256 itemId, uint256 newPrice)
        external
        onlyOwner
        validItemId(itemId)
    {
        itemInfo[itemId].mintPrice = newPrice;
    }


    function toggleItemMintable(uint256 itemId)
        external
        onlyOwner
        validItemId(itemId)
    {
        itemInfo[itemId].mintable = !itemInfo[itemId].mintable;
    }


    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
    }


    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        payable(owner()).transfer(balance);
    }


    function getCurrentItemId() external view returns (uint256) {
        return _itemIdCounter.current();
    }


    function getRemainingSupply(uint256 itemId)
        external
        view
        validItemId(itemId)
        returns (uint256)
    {
        return itemInfo[itemId].maxSupply - itemSupply[itemId];
    }


    function getItemsInfo(uint256[] memory itemIds)
        external
        view
        returns (ItemInfo[] memory)
    {
        ItemInfo[] memory items = new ItemInfo[](itemIds.length);
        for (uint256 i = 0; i < itemIds.length; i++) {
            require(itemIds[i] < _itemIdCounter.current(), "Item does not exist");
            items[i] = itemInfo[itemIds[i]];
        }
        return items;
    }


    function hasItemOfRarity(address user, uint256 rarity)
        external
        view
        returns (bool)
    {
        require(rarity >= 1 && rarity <= 5, "Invalid rarity level");

        for (uint256 i = 0; i < _itemIdCounter.current(); i++) {
            if (itemInfo[i].rarity == rarity && balanceOf(user, i) > 0) {
                return true;
            }
        }
        return false;
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


    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
