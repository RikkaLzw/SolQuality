
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
    }


    mapping(uint256 => ItemInfo) public itemInfos;
    mapping(address => bool) public authorizedMinters;
    mapping(uint256 => string) private tokenURIs;

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

    event MinterAuthorized(address indexed minter);
    event MinterRevoked(address indexed minter);
    event BaseURIUpdated(string newBaseURI);


    modifier onlyAuthorizedMinter() {
        require(
            authorizedMinters[msg.sender] || msg.sender == owner(),
            "GameItemContract: caller is not authorized minter"
        );
        _;
    }

    modifier validItemId(uint256 itemId) {
        require(itemId < nextItemId, "GameItemContract: invalid item ID");
        require(itemInfos[itemId].isActive, "GameItemContract: item is not active");
        _;
    }


    constructor(string memory initialBaseURI) ERC1155(initialBaseURI) {
        baseTokenURI = initialBaseURI;
        nextItemId = 1;
    }


    function createItem(
        string memory name,
        string memory description,
        ItemType itemType,
        Rarity rarity,
        uint256 maxSupply,
        uint256 mintPrice
    ) external onlyOwner returns (uint256 itemId) {
        require(bytes(name).length > 0, "GameItemContract: name cannot be empty");

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
            isActive: true
        });

        emit ItemCreated(itemId, name, itemType, rarity, maxSupply, mintPrice);
    }


    function mintItem(
        address to,
        uint256 itemId,
        uint256 amount
    ) external payable nonReentrant whenNotPaused validItemId(itemId) onlyAuthorizedMinter {
        require(to != address(0), "GameItemContract: mint to zero address");
        require(amount > 0, "GameItemContract: amount must be greater than 0");

        ItemInfo storage item = itemInfos[itemId];


        if (item.maxSupply > 0) {
            require(
                item.currentSupply + amount <= item.maxSupply,
                "GameItemContract: exceeds max supply"
            );
        }


        uint256 totalPrice = item.mintPrice * amount;
        if (msg.sender != owner()) {
            require(msg.value >= totalPrice, "GameItemContract: insufficient payment");
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
        require(to != address(0), "GameItemContract: mint to zero address");
        require(itemIds.length == amounts.length, "GameItemContract: arrays length mismatch");
        require(itemIds.length > 0, "GameItemContract: empty arrays");

        uint256 totalPrice = 0;

        for (uint256 i = 0; i < itemIds.length; i++) {
            uint256 itemId = itemIds[i];
            uint256 amount = amounts[i];

            require(itemId < nextItemId, "GameItemContract: invalid item ID");
            require(amount > 0, "GameItemContract: amount must be greater than 0");

            ItemInfo storage item = itemInfos[itemId];
            require(item.isActive, "GameItemContract: item is not active");


            if (item.maxSupply > 0) {
                require(
                    item.currentSupply + amount <= item.maxSupply,
                    "GameItemContract: exceeds max supply"
                );
            }


            totalPrice += item.mintPrice * amount;


            item.currentSupply += amount;
        }


        if (msg.sender != owner()) {
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

        ItemInfo storage item = itemInfos[itemId];
        item.currentSupply -= amount;

        _burn(from, itemId, amount);

        emit ItemBurned(from, itemId, amount);
    }


    function authorizeMinter(address minter) external onlyOwner {
        require(minter != address(0), "GameItemContract: invalid minter address");
        authorizedMinters[minter] = true;
        emit MinterAuthorized(minter);
    }


    function revokeMinter(address minter) external onlyOwner {
        authorizedMinters[minter] = false;
        emit MinterRevoked(minter);
    }


    function setItemActive(uint256 itemId, bool isActive) external onlyOwner {
        require(itemId < nextItemId, "GameItemContract: invalid item ID");
        itemInfos[itemId].isActive = isActive;
    }


    function updateItemPrice(uint256 itemId, uint256 newPrice) external onlyOwner validItemId(itemId) {
        itemInfos[itemId].mintPrice = newPrice;
    }


    function setBaseURI(string memory newBaseURI) external onlyOwner {
        baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }


    function setTokenURI(uint256 itemId, string memory tokenURI) external onlyOwner {
        require(itemId < nextItemId, "GameItemContract: invalid item ID");
        tokenURIs[itemId] = tokenURI;
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


    function uri(uint256 itemId) public view override returns (string memory) {
        require(itemId < nextItemId, "GameItemContract: invalid item ID");

        string memory tokenURI = tokenURIs[itemId];
        if (bytes(tokenURI).length > 0) {
            return tokenURI;
        }

        return string(abi.encodePacked(baseTokenURI, itemId.toString()));
    }


    function getItemInfo(uint256 itemId) external view returns (ItemInfo memory) {
        require(itemId < nextItemId, "GameItemContract: invalid item ID");
        return itemInfos[itemId];
    }


    function isAuthorizedMinter(address account) external view returns (bool) {
        return authorizedMinters[account] || account == owner();
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
    }


    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
