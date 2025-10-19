
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract GameItemNFT is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;


    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant MAX_LEVEL = 10;
    uint256 public constant UPGRADE_BASE_COST = 0.01 ether;
    uint256 public constant MINT_PRICE = 0.05 ether;


    enum Rarity { Common, Rare, Epic, Legendary }


    enum ItemType { Weapon, Armor, Accessory, Consumable }


    struct ItemAttributes {
        string name;
        ItemType itemType;
        Rarity rarity;
        uint256 level;
        uint256 attack;
        uint256 defense;
        uint256 durability;
        bool isActive;
        uint256 createdAt;
    }


    Counters.Counter private _tokenIds;
    mapping(uint256 => ItemAttributes) private _itemAttributes;
    mapping(address => bool) private _authorizedMinters;
    mapping(Rarity => uint256) private _rarityMultipliers;
    bool private _mintingEnabled;


    event ItemMinted(uint256 indexed tokenId, address indexed to, string name, ItemType itemType, Rarity rarity);
    event ItemUpgraded(uint256 indexed tokenId, uint256 newLevel, uint256 cost);
    event ItemRepaired(uint256 indexed tokenId, uint256 newDurability, uint256 cost);
    event MinterAuthorized(address indexed minter, bool authorized);
    event MintingStatusChanged(bool enabled);


    modifier onlyAuthorizedMinter() {
        require(_authorizedMinters[msg.sender] || msg.sender == owner(), "Not authorized to mint");
        _;
    }

    modifier tokenExists(uint256 tokenId) {
        require(_exists(tokenId), "Token does not exist");
        _;
    }

    modifier onlyTokenOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        _;
    }

    modifier mintingEnabled() {
        require(_mintingEnabled, "Minting is disabled");
        _;
    }

    modifier validLevel(uint256 level) {
        require(level > 0 && level <= MAX_LEVEL, "Invalid level");
        _;
    }

    constructor() ERC721("GameItemNFT", "GINFT") {
        _mintingEnabled = true;
        _initializeRarityMultipliers();
    }


    function _initializeRarityMultipliers() private {
        _rarityMultipliers[Rarity.Common] = 1;
        _rarityMultipliers[Rarity.Rare] = 2;
        _rarityMultipliers[Rarity.Epic] = 5;
        _rarityMultipliers[Rarity.Legendary] = 10;
    }


    function mintItem(
        address to,
        string memory name,
        string memory tokenURI,
        ItemType itemType,
        Rarity rarity
    ) external payable mintingEnabled onlyAuthorizedMinter nonReentrant returns (uint256) {
        require(totalSupply() < MAX_SUPPLY, "Max supply reached");
        require(bytes(name).length > 0, "Name cannot be empty");
        require(msg.value >= MINT_PRICE, "Insufficient payment");

        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        _safeMint(to, newTokenId);
        _setTokenURI(newTokenId, tokenURI);

        _itemAttributes[newTokenId] = ItemAttributes({
            name: name,
            itemType: itemType,
            rarity: rarity,
            level: 1,
            attack: _calculateBaseAttribute(rarity, true),
            defense: _calculateBaseAttribute(rarity, false),
            durability: 100,
            isActive: true,
            createdAt: block.timestamp
        });

        emit ItemMinted(newTokenId, to, name, itemType, rarity);
        return newTokenId;
    }


    function publicMint(
        string memory name,
        string memory tokenURI,
        ItemType itemType,
        Rarity rarity
    ) external payable mintingEnabled nonReentrant returns (uint256) {
        require(totalSupply() < MAX_SUPPLY, "Max supply reached");
        require(bytes(name).length > 0, "Name cannot be empty");
        require(msg.value >= MINT_PRICE, "Insufficient payment");

        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);

        _itemAttributes[newTokenId] = ItemAttributes({
            name: name,
            itemType: itemType,
            rarity: rarity,
            level: 1,
            attack: _calculateBaseAttribute(rarity, true),
            defense: _calculateBaseAttribute(rarity, false),
            durability: 100,
            isActive: true,
            createdAt: block.timestamp
        });

        emit ItemMinted(newTokenId, msg.sender, name, itemType, rarity);
        return newTokenId;
    }


    function upgradeItem(uint256 tokenId) external payable tokenExists(tokenId) onlyTokenOwner(tokenId) nonReentrant {
        ItemAttributes storage item = _itemAttributes[tokenId];
        require(item.isActive, "Item is not active");
        require(item.level < MAX_LEVEL, "Item already at max level");
        require(item.durability > 0, "Item is broken");

        uint256 upgradeCost = _calculateUpgradeCost(item.level, item.rarity);
        require(msg.value >= upgradeCost, "Insufficient payment for upgrade");

        item.level++;
        item.attack = _calculateUpgradedAttribute(item.attack, item.rarity);
        item.defense = _calculateUpgradedAttribute(item.defense, item.rarity);

        emit ItemUpgraded(tokenId, item.level, upgradeCost);
    }


    function repairItem(uint256 tokenId) external payable tokenExists(tokenId) onlyTokenOwner(tokenId) nonReentrant {
        ItemAttributes storage item = _itemAttributes[tokenId];
        require(item.durability < 100, "Item doesn't need repair");

        uint256 repairCost = _calculateRepairCost(item.durability, item.rarity);
        require(msg.value >= repairCost, "Insufficient payment for repair");

        item.durability = 100;

        emit ItemRepaired(tokenId, item.durability, repairCost);
    }


    function burnItem(uint256 tokenId) external tokenExists(tokenId) onlyTokenOwner(tokenId) {
        _itemAttributes[tokenId].isActive = false;
        _burn(tokenId);
    }


    function _calculateBaseAttribute(Rarity rarity, bool isAttack) private view returns (uint256) {
        uint256 baseValue = isAttack ? 10 : 8;
        return baseValue * _rarityMultipliers[rarity];
    }


    function _calculateUpgradedAttribute(uint256 currentValue, Rarity rarity) private view returns (uint256) {
        uint256 increment = 2 * _rarityMultipliers[rarity];
        return currentValue + increment;
    }


    function _calculateUpgradeCost(uint256 currentLevel, Rarity rarity) private view returns (uint256) {
        return UPGRADE_BASE_COST * currentLevel * _rarityMultipliers[rarity];
    }


    function _calculateRepairCost(uint256 currentDurability, Rarity rarity) private view returns (uint256) {
        uint256 damagePercent = 100 - currentDurability;
        return (UPGRADE_BASE_COST * damagePercent * _rarityMultipliers[rarity]) / 100;
    }


    function getItemAttributes(uint256 tokenId) external view tokenExists(tokenId) returns (ItemAttributes memory) {
        return _itemAttributes[tokenId];
    }


    function getOwnerItems(address owner) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(owner);
        uint256[] memory tokenIds = new uint256[](balance);

        for (uint256 i = 0; i < balance; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }

        return tokenIds;
    }


    function setAuthorizedMinter(address minter, bool authorized) external onlyOwner {
        _authorizedMinters[minter] = authorized;
        emit MinterAuthorized(minter, authorized);
    }


    function setMintingEnabled(bool enabled) external onlyOwner {
        _mintingEnabled = enabled;
        emit MintingStatusChanged(enabled);
    }


    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }


    function isAuthorizedMinter(address minter) external view returns (bool) {
        return _authorizedMinters[minter];
    }


    function isMintingEnabled() external view returns (bool) {
        return _mintingEnabled;
    }


    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
