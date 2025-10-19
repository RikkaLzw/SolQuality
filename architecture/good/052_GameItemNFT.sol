
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract GameItemNFT is ERC721, ERC721Enumerable, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;


    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant MAX_DURABILITY = 100;
    uint256 public constant REPAIR_COST_BASE = 0.001 ether;


    enum ItemType { WEAPON, ARMOR, ACCESSORY, CONSUMABLE }
    enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }


    struct GameItem {
        string name;
        ItemType itemType;
        Rarity rarity;
        uint256 attack;
        uint256 defense;
        uint256 durability;
        uint256 maxDurability;
        bool isEquipped;
        uint256 createdAt;
    }


    Counters.Counter private _tokenIdCounter;
    mapping(uint256 => GameItem) private _gameItems;
    mapping(address => mapping(ItemType => uint256[])) private _playerItems;
    mapping(address => uint256[]) private _equippedItems;
    mapping(Rarity => uint256) public mintPrices;

    bool public mintingEnabled;
    uint256 public repairFeePercentage = 10;


    event ItemMinted(address indexed to, uint256 indexed tokenId, ItemType itemType, Rarity rarity);
    event ItemEquipped(address indexed player, uint256 indexed tokenId);
    event ItemUnequipped(address indexed player, uint256 indexed tokenId);
    event ItemRepaired(uint256 indexed tokenId, uint256 newDurability);
    event ItemUpgraded(uint256 indexed tokenId, uint256 newAttack, uint256 newDefense);


    modifier onlyTokenOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        _;
    }

    modifier itemExists(uint256 tokenId) {
        require(_exists(tokenId), "Item does not exist");
        _;
    }

    modifier mintingActive() {
        require(mintingEnabled, "Minting is not active");
        _;
    }

    modifier validDurability(uint256 tokenId) {
        require(_gameItems[tokenId].durability > 0, "Item is broken");
        _;
    }

    constructor() ERC721("Game Items", "GITM") {
        _initializeMintPrices();
        mintingEnabled = true;
    }


    function mintItem(
        string memory name,
        ItemType itemType,
        Rarity rarity
    ) external payable mintingActive nonReentrant {
        require(totalSupply() < MAX_SUPPLY, "Max supply reached");
        require(msg.value >= mintPrices[rarity], "Insufficient payment");
        require(bytes(name).length > 0, "Name cannot be empty");

        uint256 tokenId = _getNextTokenId();
        GameItem memory newItem = _createGameItem(name, itemType, rarity);

        _gameItems[tokenId] = newItem;
        _playerItems[msg.sender][itemType].push(tokenId);

        _safeMint(msg.sender, tokenId);

        emit ItemMinted(msg.sender, tokenId, itemType, rarity);
    }

    function equipItem(uint256 tokenId)
        external
        onlyTokenOwner(tokenId)
        itemExists(tokenId)
        validDurability(tokenId)
    {
        require(!_gameItems[tokenId].isEquipped, "Item already equipped");

        _gameItems[tokenId].isEquipped = true;
        _equippedItems[msg.sender].push(tokenId);

        emit ItemEquipped(msg.sender, tokenId);
    }

    function unequipItem(uint256 tokenId)
        external
        onlyTokenOwner(tokenId)
        itemExists(tokenId)
    {
        require(_gameItems[tokenId].isEquipped, "Item not equipped");

        _gameItems[tokenId].isEquipped = false;
        _removeFromEquippedItems(msg.sender, tokenId);

        emit ItemUnequipped(msg.sender, tokenId);
    }

    function repairItem(uint256 tokenId)
        external
        payable
        onlyTokenOwner(tokenId)
        itemExists(tokenId)
        nonReentrant
    {
        GameItem storage item = _gameItems[tokenId];
        require(item.durability < item.maxDurability, "Item at full durability");

        uint256 repairCost = _calculateRepairCost(tokenId);
        require(msg.value >= repairCost, "Insufficient repair fee");

        item.durability = item.maxDurability;

        emit ItemRepaired(tokenId, item.durability);
    }

    function upgradeItem(uint256 tokenId)
        external
        payable
        onlyTokenOwner(tokenId)
        itemExists(tokenId)
        nonReentrant
    {
        GameItem storage item = _gameItems[tokenId];
        uint256 upgradeCost = _calculateUpgradeCost(item.rarity);
        require(msg.value >= upgradeCost, "Insufficient upgrade fee");

        uint256 attackBonus = _getUpgradeBonus(item.rarity, true);
        uint256 defenseBonus = _getUpgradeBonus(item.rarity, false);

        item.attack += attackBonus;
        item.defense += defenseBonus;

        emit ItemUpgraded(tokenId, item.attack, item.defense);
    }

    function useItem(uint256 tokenId)
        external
        onlyTokenOwner(tokenId)
        itemExists(tokenId)
        validDurability(tokenId)
    {
        GameItem storage item = _gameItems[tokenId];

        if (item.itemType == ItemType.CONSUMABLE) {
            _burn(tokenId);
            _removeFromPlayerItems(msg.sender, tokenId, item.itemType);
        } else {
            require(item.durability > 0, "Item is broken");
            item.durability -= 1;

            if (item.durability == 0 && item.isEquipped) {
                item.isEquipped = false;
                _removeFromEquippedItems(msg.sender, tokenId);
                emit ItemUnequipped(msg.sender, tokenId);
            }
        }
    }


    function getGameItem(uint256 tokenId)
        external
        view
        itemExists(tokenId)
        returns (GameItem memory)
    {
        return _gameItems[tokenId];
    }

    function getPlayerItems(address player, ItemType itemType)
        external
        view
        returns (uint256[] memory)
    {
        return _playerItems[player][itemType];
    }

    function getEquippedItems(address player)
        external
        view
        returns (uint256[] memory)
    {
        return _equippedItems[player];
    }

    function getPlayerStats(address player)
        external
        view
        returns (uint256 totalAttack, uint256 totalDefense)
    {
        uint256[] memory equipped = _equippedItems[player];

        for (uint256 i = 0; i < equipped.length; i++) {
            GameItem memory item = _gameItems[equipped[i]];
            if (item.durability > 0) {
                totalAttack += item.attack;
                totalDefense += item.defense;
            }
        }
    }


    function setMintingEnabled(bool enabled) external onlyOwner {
        mintingEnabled = enabled;
    }

    function setMintPrice(Rarity rarity, uint256 price) external onlyOwner {
        mintPrices[rarity] = price;
    }

    function setRepairFeePercentage(uint256 percentage) external onlyOwner {
        require(percentage <= 50, "Fee too high");
        repairFeePercentage = percentage;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }


    function _initializeMintPrices() private {
        mintPrices[Rarity.COMMON] = 0.01 ether;
        mintPrices[Rarity.UNCOMMON] = 0.025 ether;
        mintPrices[Rarity.RARE] = 0.05 ether;
        mintPrices[Rarity.EPIC] = 0.1 ether;
        mintPrices[Rarity.LEGENDARY] = 0.25 ether;
    }

    function _getNextTokenId() private returns (uint256) {
        _tokenIdCounter.increment();
        return _tokenIdCounter.current();
    }

    function _createGameItem(
        string memory name,
        ItemType itemType,
        Rarity rarity
    ) private view returns (GameItem memory) {
        (uint256 attack, uint256 defense) = _generateStats(itemType, rarity);
        uint256 durability = _generateDurability(rarity);

        return GameItem({
            name: name,
            itemType: itemType,
            rarity: rarity,
            attack: attack,
            defense: defense,
            durability: durability,
            maxDurability: durability,
            isEquipped: false,
            createdAt: block.timestamp
        });
    }

    function _generateStats(ItemType itemType, Rarity rarity)
        private
        pure
        returns (uint256 attack, uint256 defense)
    {
        uint256 baseMultiplier = uint256(rarity) + 1;

        if (itemType == ItemType.WEAPON) {
            attack = 10 * baseMultiplier;
            defense = 2 * baseMultiplier;
        } else if (itemType == ItemType.ARMOR) {
            attack = 2 * baseMultiplier;
            defense = 10 * baseMultiplier;
        } else if (itemType == ItemType.ACCESSORY) {
            attack = 5 * baseMultiplier;
            defense = 5 * baseMultiplier;
        } else {
            attack = 0;
            defense = 0;
        }
    }

    function _generateDurability(Rarity rarity) private pure returns (uint256) {
        return MAX_DURABILITY + (uint256(rarity) * 20);
    }

    function _calculateRepairCost(uint256 tokenId) private view returns (uint256) {
        GameItem memory item = _gameItems[tokenId];
        uint256 damagePercentage = ((item.maxDurability - item.durability) * 100) / item.maxDurability;
        return (REPAIR_COST_BASE * damagePercentage * (uint256(item.rarity) + 1)) / 100;
    }

    function _calculateUpgradeCost(Rarity rarity) private pure returns (uint256) {
        return 0.05 ether * (uint256(rarity) + 1);
    }

    function _getUpgradeBonus(Rarity rarity, bool isAttack) private pure returns (uint256) {
        uint256 baseBonus = isAttack ? 5 : 3;
        return baseBonus * (uint256(rarity) + 1);
    }

    function _removeFromEquippedItems(address player, uint256 tokenId) private {
        uint256[] storage equipped = _equippedItems[player];
        for (uint256 i = 0; i < equipped.length; i++) {
            if (equipped[i] == tokenId) {
                equipped[i] = equipped[equipped.length - 1];
                equipped.pop();
                break;
            }
        }
    }

    function _removeFromPlayerItems(address player, uint256 tokenId, ItemType itemType) private {
        uint256[] storage items = _playerItems[player][itemType];
        for (uint256 i = 0; i < items.length; i++) {
            if (items[i] == tokenId) {
                items[i] = items[items.length - 1];
                items.pop();
                break;
            }
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);

        if (from != address(0) && to != address(0)) {
            GameItem storage item = _gameItems[tokenId];
            if (item.isEquipped) {
                item.isEquipped = false;
                _removeFromEquippedItems(from, tokenId);
                emit ItemUnequipped(from, tokenId);
            }

            _removeFromPlayerItems(from, tokenId, item.itemType);
            _playerItems[to][item.itemType].push(tokenId);
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
