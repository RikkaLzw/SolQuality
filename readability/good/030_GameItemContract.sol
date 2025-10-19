
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


contract GameItemContract is ERC1155, Ownable, Pausable, ReentrancyGuard {
    using Strings for uint256;


    enum ItemType {
        WEAPON,
        ARMOR,
        CONSUMABLE,
        MATERIAL,
        SPECIAL
    }


    enum Rarity {
        COMMON,
        UNCOMMON,
        RARE,
        EPIC,
        LEGENDARY
    }


    struct ItemInfo {
        string name;
        string description;
        ItemType itemType;
        Rarity rarity;
        uint256 maxSupply;
        uint256 currentSupply;
        uint256 mintPrice;
        bool isActive;
        bool isTradeable;
    }


    mapping(uint256 => ItemInfo) public itemInfos;
    mapping(address => bool) public authorizedMinters;
    mapping(uint256 => mapping(address => bool)) public itemBlacklist;

    uint256 public nextItemId;
    uint256 public totalItemTypes;
    string private baseTokenURI;


    event ItemCreated(
        uint256 indexed itemId,
        string name,
        ItemType itemType,
        Rarity rarity,
        uint256 maxSupply,
        uint256 mintPrice
    );

    event ItemMinted(
        address indexed to,
        uint256 indexed itemId,
        uint256 amount,
        uint256 totalPrice
    );

    event ItemBurned(
        address indexed from,
        uint256 indexed itemId,
        uint256 amount
    );

    event MinterAuthorized(address indexed minter, bool authorized);
    event ItemStatusUpdated(uint256 indexed itemId, bool isActive, bool isTradeable);
    event ItemBlacklistUpdated(uint256 indexed itemId, address indexed user, bool blacklisted);


    modifier onlyAuthorizedMinter() {
        require(authorizedMinters[msg.sender] || msg.sender == owner(), "GameItemContract: Not authorized minter");
        _;
    }

    modifier validItemId(uint256 itemId) {
        require(itemId < nextItemId, "GameItemContract: Invalid item ID");
        _;
    }

    modifier itemActive(uint256 itemId) {
        require(itemInfos[itemId].isActive, "GameItemContract: Item not active");
        _;
    }

    modifier notBlacklisted(uint256 itemId, address user) {
        require(!itemBlacklist[itemId][user], "GameItemContract: User blacklisted for this item");
        _;
    }


    constructor(
        address initialOwner,
        string memory baseURI
    ) ERC1155(baseURI) {
        _transferOwnership(initialOwner);
        baseTokenURI = baseURI;
        nextItemId = 1;
    }


    function createItem(
        string memory name,
        string memory description,
        ItemType itemType,
        Rarity rarity,
        uint256 maxSupply,
        uint256 mintPrice,
        bool isActive,
        bool isTradeable
    ) external onlyOwner returns (uint256 itemId) {
        require(bytes(name).length > 0, "GameItemContract: Name cannot be empty");

        itemId = nextItemId;
        nextItemId++;
        totalItemTypes++;

        itemInfos[itemId] = ItemInfo({
            name: name,
            description: description,
            itemType: itemType,
            rarity: rarity,
            maxSupply: maxSupply,
            currentSupply: 0,
            mintPrice: mintPrice,
            isActive: isActive,
            isTradeable: isTradeable
        });

        emit ItemCreated(itemId, name, itemType, rarity, maxSupply, mintPrice);
    }


    function mintItem(
        address to,
        uint256 itemId,
        uint256 amount
    ) external payable nonReentrant whenNotPaused validItemId(itemId) itemActive(itemId) notBlacklisted(itemId, to) {
        require(to != address(0), "GameItemContract: Cannot mint to zero address");
        require(amount > 0, "GameItemContract: Amount must be greater than 0");

        ItemInfo storage item = itemInfos[itemId];


        if (item.maxSupply > 0) {
            require(
                item.currentSupply + amount <= item.maxSupply,
                "GameItemContract: Exceeds maximum supply"
            );
        }


        uint256 totalPrice = item.mintPrice * amount;


        if (totalPrice > 0) {
            require(msg.value >= totalPrice, "GameItemContract: Insufficient payment");
        }


        item.currentSupply += amount;


        _mint(to, itemId, amount, "");


        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }

        emit ItemMinted(to, itemId, amount, totalPrice);
    }


    function mintBatch(
        address to,
        uint256[] memory itemIds,
        uint256[] memory amounts
    ) external payable nonReentrant whenNotPaused onlyAuthorizedMinter {
        require(to != address(0), "GameItemContract: Cannot mint to zero address");
        require(itemIds.length == amounts.length, "GameItemContract: Arrays length mismatch");
        require(itemIds.length > 0, "GameItemContract: Empty arrays");

        uint256 totalPrice = 0;


        for (uint256 i = 0; i < itemIds.length; i++) {
            uint256 itemId = itemIds[i];
            uint256 amount = amounts[i];

            require(itemId < nextItemId, "GameItemContract: Invalid item ID");
            require(amount > 0, "GameItemContract: Amount must be greater than 0");
            require(itemInfos[itemId].isActive, "GameItemContract: Item not active");
            require(!itemBlacklist[itemId][to], "GameItemContract: User blacklisted for this item");

            ItemInfo storage item = itemInfos[itemId];


            if (item.maxSupply > 0) {
                require(
                    item.currentSupply + amount <= item.maxSupply,
                    "GameItemContract: Exceeds maximum supply"
                );
            }


            item.currentSupply += amount;
            totalPrice += item.mintPrice * amount;
        }


        if (totalPrice > 0) {
            require(msg.value >= totalPrice, "GameItemContract: Insufficient payment");
        }


        _mintBatch(to, itemIds, amounts, "");


        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }
    }


    function burnItem(
        address from,
        uint256 itemId,
        uint256 amount
    ) external validItemId(itemId) {
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender),
            "GameItemContract: Caller is not owner nor approved"
        );
        require(amount > 0, "GameItemContract: Amount must be greater than 0");


        itemInfos[itemId].currentSupply -= amount;


        _burn(from, itemId, amount);

        emit ItemBurned(from, itemId, amount);
    }


    function burnBatch(
        address from,
        uint256[] memory itemIds,
        uint256[] memory amounts
    ) external {
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender),
            "GameItemContract: Caller is not owner nor approved"
        );
        require(itemIds.length == amounts.length, "GameItemContract: Arrays length mismatch");


        for (uint256 i = 0; i < itemIds.length; i++) {
            require(itemIds[i] < nextItemId, "GameItemContract: Invalid item ID");
            require(amounts[i] > 0, "GameItemContract: Amount must be greater than 0");
            itemInfos[itemIds[i]].currentSupply -= amounts[i];
        }


        _burnBatch(from, itemIds, amounts);
    }


    function setAuthorizedMinter(address minter, bool authorized) external onlyOwner {
        require(minter != address(0), "GameItemContract: Invalid minter address");
        authorizedMinters[minter] = authorized;
        emit MinterAuthorized(minter, authorized);
    }


    function updateItemStatus(
        uint256 itemId,
        bool isActive,
        bool isTradeable
    ) external onlyOwner validItemId(itemId) {
        itemInfos[itemId].isActive = isActive;
        itemInfos[itemId].isTradeable = isTradeable;
        emit ItemStatusUpdated(itemId, isActive, isTradeable);
    }


    function updateItemPrice(uint256 itemId, uint256 newPrice) external onlyOwner validItemId(itemId) {
        itemInfos[itemId].mintPrice = newPrice;
    }


    function setItemBlacklist(
        uint256 itemId,
        address user,
        bool blacklisted
    ) external onlyOwner validItemId(itemId) {
        require(user != address(0), "GameItemContract: Invalid user address");
        itemBlacklist[itemId][user] = blacklisted;
        emit ItemBlacklistUpdated(itemId, user, blacklisted);
    }


    function setBaseURI(string memory newBaseURI) external onlyOwner {
        baseTokenURI = newBaseURI;
        _setURI(newBaseURI);
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


    function uri(uint256 itemId) public view override validItemId(itemId) returns (string memory) {
        return string(abi.encodePacked(baseTokenURI, itemId.toString(), ".json"));
    }


    function getItemInfo(uint256 itemId) external view validItemId(itemId) returns (ItemInfo memory) {
        return itemInfos[itemId];
    }


    function isItemTradeable(uint256 itemId) external view validItemId(itemId) returns (bool) {
        return itemInfos[itemId].isTradeable;
    }


    function getRemainingSupply(uint256 itemId) external view validItemId(itemId) returns (uint256) {
        ItemInfo memory item = itemInfos[itemId];
        if (item.maxSupply == 0) {
            return type(uint256).max;
        }
        return item.maxSupply - item.currentSupply;
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
            for (uint256 i = 0; i < ids.length; i++) {
                require(
                    itemInfos[ids[i]].isTradeable,
                    "GameItemContract: Item is not tradeable"
                );
                require(
                    !itemBlacklist[ids[i]][to],
                    "GameItemContract: Recipient is blacklisted for this item"
                );
            }
        }
    }


    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
