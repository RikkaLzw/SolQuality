
pragma solidity ^0.8.19;

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
        string imageUri;
    }


    mapping(uint256 => ItemInfo) public itemInfos;
    mapping(address => bool) public authorizedMinters;
    mapping(uint256 => mapping(address => uint256)) public playerItemCounts;

    uint256 public nextItemId;
    uint256 public totalItemTypes;
    string private baseTokenUri;


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
    event ItemInfoUpdated(uint256 indexed itemId);
    event BaseUriUpdated(string newBaseUri);


    modifier onlyAuthorizedMinter() {
        require(
            authorizedMinters[msg.sender] || msg.sender == owner(),
            "GameItemContract: caller is not authorized minter"
        );
        _;
    }

    modifier validItemId(uint256 itemId) {
        require(itemId < nextItemId, "GameItemContract: invalid item ID");
        _;
    }

    modifier itemActive(uint256 itemId) {
        require(itemInfos[itemId].isActive, "GameItemContract: item is not active");
        _;
    }


    constructor(
        address initialOwner,
        string memory baseUri
    ) ERC1155(baseUri) {
        _transferOwnership(initialOwner);
        baseTokenUri = baseUri;
        nextItemId = 1;
    }


    function createItem(
        string memory name,
        string memory description,
        ItemType itemType,
        Rarity rarity,
        uint256 maxSupply,
        uint256 mintPrice,
        string memory imageUri
    ) external onlyOwner returns (uint256 itemId) {
        require(bytes(name).length > 0, "GameItemContract: name cannot be empty");
        require(bytes(description).length > 0, "GameItemContract: description cannot be empty");

        itemId = nextItemId;
        nextItemId++;

        itemInfos[itemId] = ItemInfo({
            name: name,
            description: description,
            itemType: itemType,
            rarity: rarity,
            maxSupply: maxSupply,
            currentSupply: 0,
            mintPrice: mintPrice,
            isActive: true,
            imageUri: imageUri
        });

        totalItemTypes++;

        emit ItemCreated(itemId, name, itemType, rarity, maxSupply, mintPrice);
    }


    function mintItem(
        address to,
        uint256 itemId,
        uint256 amount
    ) external payable nonReentrant validItemId(itemId) itemActive(itemId) onlyAuthorizedMinter {
        require(to != address(0), "GameItemContract: mint to zero address");
        require(amount > 0, "GameItemContract: amount must be greater than 0");

        ItemInfo storage item = itemInfos[itemId];


        if (item.maxSupply > 0) {
            require(
                item.currentSupply + amount <= item.maxSupply,
                "GameItemContract: exceeds maximum supply"
            );
        }


        uint256 totalPrice = item.mintPrice * amount;
        if (totalPrice > 0) {
            require(msg.value >= totalPrice, "GameItemContract: insufficient payment");
        }


        item.currentSupply += amount;
        playerItemCounts[itemId][to] += amount;


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
    ) external payable nonReentrant onlyAuthorizedMinter {
        require(to != address(0), "GameItemContract: mint to zero address");
        require(itemIds.length == amounts.length, "GameItemContract: arrays length mismatch");
        require(itemIds.length > 0, "GameItemContract: empty arrays");

        uint256 totalPrice = 0;


        for (uint256 i = 0; i < itemIds.length; i++) {
            uint256 itemId = itemIds[i];
            uint256 amount = amounts[i];

            require(itemId < nextItemId, "GameItemContract: invalid item ID");
            require(amount > 0, "GameItemContract: amount must be greater than 0");
            require(itemInfos[itemId].isActive, "GameItemContract: item is not active");

            ItemInfo storage item = itemInfos[itemId];


            if (item.maxSupply > 0) {
                require(
                    item.currentSupply + amount <= item.maxSupply,
                    "GameItemContract: exceeds maximum supply"
                );
            }

            totalPrice += item.mintPrice * amount;
            item.currentSupply += amount;
            playerItemCounts[itemId][to] += amount;
        }


        if (totalPrice > 0) {
            require(msg.value >= totalPrice, "GameItemContract: insufficient payment");
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
            "GameItemContract: caller is not owner nor approved"
        );
        require(amount > 0, "GameItemContract: amount must be greater than 0");


        itemInfos[itemId].currentSupply -= amount;
        playerItemCounts[itemId][from] -= amount;

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
            "GameItemContract: caller is not owner nor approved"
        );
        require(itemIds.length == amounts.length, "GameItemContract: arrays length mismatch");

        for (uint256 i = 0; i < itemIds.length; i++) {
            uint256 itemId = itemIds[i];
            uint256 amount = amounts[i];

            require(itemId < nextItemId, "GameItemContract: invalid item ID");
            require(amount > 0, "GameItemContract: amount must be greater than 0");

            itemInfos[itemId].currentSupply -= amount;
            playerItemCounts[itemId][from] -= amount;
        }

        _burnBatch(from, itemIds, amounts);
    }


    function setAuthorizedMinter(address minter, bool authorized) external onlyOwner {
        require(minter != address(0), "GameItemContract: invalid minter address");
        authorizedMinters[minter] = authorized;
        emit MinterAuthorized(minter, authorized);
    }


    function updateItemInfo(
        uint256 itemId,
        string memory name,
        string memory description,
        uint256 mintPrice,
        bool isActive,
        string memory imageUri
    ) external onlyOwner validItemId(itemId) {
        require(bytes(name).length > 0, "GameItemContract: name cannot be empty");
        require(bytes(description).length > 0, "GameItemContract: description cannot be empty");

        ItemInfo storage item = itemInfos[itemId];
        item.name = name;
        item.description = description;
        item.mintPrice = mintPrice;
        item.isActive = isActive;
        item.imageUri = imageUri;

        emit ItemInfoUpdated(itemId);
    }


    function setBaseUri(string memory newBaseUri) external onlyOwner {
        baseTokenUri = newBaseUri;
        _setURI(newBaseUri);
        emit BaseUriUpdated(newBaseUri);
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
    }


    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "GameItemContract: no balance to withdraw");
        payable(owner()).transfer(balance);
    }


    function uri(uint256 itemId) public view override validItemId(itemId) returns (string memory) {
        ItemInfo memory item = itemInfos[itemId];
        if (bytes(item.imageUri).length > 0) {
            return item.imageUri;
        }
        return string(abi.encodePacked(baseTokenUri, itemId.toString()));
    }


    function getPlayerItemCount(address player, uint256 itemId) external view validItemId(itemId) returns (uint256) {
        return playerItemCounts[itemId][player];
    }


    function getItemInfo(uint256 itemId) external view validItemId(itemId) returns (ItemInfo memory) {
        return itemInfos[itemId];
    }


    function itemExists(uint256 itemId) external view returns (bool) {
        return itemId < nextItemId;
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


    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
