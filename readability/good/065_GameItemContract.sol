
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
        POTION,
        MATERIAL,
        ACCESSORY
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
        require(itemId < nextItemId, "GameItemContract: item does not exist");
        require(itemInfos[itemId].isActive, "GameItemContract: item is not active");
        _;
    }


    constructor(string memory initialBaseURI) ERC1155(initialBaseURI) {
        baseTokenURI = initialBaseURI;
        nextItemId = 0;
        totalItemTypes = 0;
    }


    function createItem(
        string memory name,
        string memory description,
        ItemType itemType,
        Rarity rarity,
        uint256 maxSupply,
        uint256 mintPrice,
        string memory tokenURI
    ) external onlyOwner {
        require(bytes(name).length > 0, "GameItemContract: name cannot be empty");
        require(bytes(description).length > 0, "GameItemContract: description cannot be empty");

        uint256 itemId = nextItemId;

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

        if (bytes(tokenURI).length > 0) {
            tokenURIs[itemId] = tokenURI;
        }

        nextItemId++;
        totalItemTypes++;

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
                "GameItemContract: exceeds maximum supply"
            );
        }


        uint256 totalPrice = item.mintPrice * amount;
        require(msg.value >= totalPrice, "GameItemContract: insufficient payment");


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

            require(itemId < nextItemId, "GameItemContract: item does not exist");
            require(amount > 0, "GameItemContract: amount must be greater than 0");

            ItemInfo storage item = itemInfos[itemId];
            require(item.isActive, "GameItemContract: item is not active");


            if (item.maxSupply > 0) {
                require(
                    item.currentSupply + amount <= item.maxSupply,
                    "GameItemContract: exceeds maximum supply"
                );
            }

            totalPrice += item.mintPrice * amount;
            item.currentSupply += amount;
        }

        require(msg.value >= totalPrice, "GameItemContract: insufficient payment");


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

        _burn(from, itemId, amount);
        itemInfos[itemId].currentSupply -= amount;

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

        for (uint256 i = 0; i < itemIds.length; i++) {
            require(itemIds[i] < nextItemId, "GameItemContract: item does not exist");
            require(itemInfos[itemIds[i]].isActive, "GameItemContract: item is not active");
            itemInfos[itemIds[i]].currentSupply -= amounts[i];
        }

        _burnBatch(from, itemIds, amounts);
    }


    function authorizeMinter(address minter) external onlyOwner {
        require(minter != address(0), "GameItemContract: minter cannot be zero address");
        authorizedMinters[minter] = true;
        emit MinterAuthorized(minter);
    }


    function revokeMinter(address minter) external onlyOwner {
        authorizedMinters[minter] = false;
        emit MinterRevoked(minter);
    }


    function setItemActive(uint256 itemId, bool isActive) external onlyOwner {
        require(itemId < nextItemId, "GameItemContract: item does not exist");
        itemInfos[itemId].isActive = isActive;
    }


    function updateItemPrice(uint256 itemId, uint256 newPrice) external onlyOwner validItemId(itemId) {
        itemInfos[itemId].mintPrice = newPrice;
    }


    function setBaseURI(string memory newBaseURI) external onlyOwner {
        baseTokenURI = newBaseURI;
        _setURI(newBaseURI);
        emit BaseURIUpdated(newBaseURI);
    }


    function setTokenURI(uint256 itemId, string memory tokenURI) external onlyOwner {
        require(itemId < nextItemId, "GameItemContract: item does not exist");
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
        require(balance > 0, "GameItemContract: no funds to withdraw");
        payable(owner()).transfer(balance);
    }


    function uri(uint256 itemId) public view override returns (string memory) {
        require(itemId < nextItemId, "GameItemContract: item does not exist");

        string memory tokenURI = tokenURIs[itemId];
        if (bytes(tokenURI).length > 0) {
            return tokenURI;
        }

        return string(abi.encodePacked(baseTokenURI, itemId.toString()));
    }


    function getItemInfo(uint256 itemId) external view returns (ItemInfo memory) {
        require(itemId < nextItemId, "GameItemContract: item does not exist");
        return itemInfos[itemId];
    }


    function hasItem(address user, uint256 itemId) external view returns (bool) {
        return balanceOf(user, itemId) > 0;
    }


    function getUserItems(address user, uint256[] memory itemIds) external view returns (uint256[] memory) {
        return balanceOfBatch(_asSingletonArray(user, itemIds.length), itemIds);
    }


    function _asSingletonArray(address element, uint256 length) private pure returns (address[] memory) {
        address[] memory array = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            array[i] = element;
        }
        return array;
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
