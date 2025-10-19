
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract GameItemContract is ERC1155, AccessControl, Pausable, ReentrancyGuard {
    using Counters for Counters.Counter;


    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");


    uint256 public constant MAX_SUPPLY_PER_ITEM = 1000000;
    uint256 public constant MAX_MINT_PER_TX = 100;
    uint256 public constant LEGENDARY_RARITY = 1;
    uint256 public constant EPIC_RARITY = 2;
    uint256 public constant RARE_RARITY = 3;
    uint256 public constant COMMON_RARITY = 4;


    Counters.Counter private _itemIdCounter;
    mapping(uint256 => ItemInfo) private _itemInfo;
    mapping(uint256 => uint256) private _totalSupply;
    mapping(address => mapping(uint256 => uint256)) private _mintedByUser;
    mapping(uint256 => uint256) private _maxUserMint;

    struct ItemInfo {
        string name;
        uint256 rarity;
        uint256 maxSupply;
        bool mintable;
        uint256 mintPrice;
    }


    event ItemCreated(uint256 indexed itemId, string name, uint256 rarity, uint256 maxSupply);
    event ItemMinted(address indexed to, uint256 indexed itemId, uint256 amount);
    event ItemBurned(address indexed from, uint256 indexed itemId, uint256 amount);
    event ItemInfoUpdated(uint256 indexed itemId, string name, uint256 rarity);


    modifier validItemId(uint256 itemId) {
        require(_exists(itemId), "GameItemContract: Item does not exist");
        _;
    }

    modifier validAmount(uint256 amount) {
        require(amount > 0, "GameItemContract: Amount must be greater than 0");
        require(amount <= MAX_MINT_PER_TX, "GameItemContract: Amount exceeds max per transaction");
        _;
    }

    modifier mintableItem(uint256 itemId) {
        require(_itemInfo[itemId].mintable, "GameItemContract: Item is not mintable");
        _;
    }

    modifier sufficientSupply(uint256 itemId, uint256 amount) {
        require(
            _totalSupply[itemId] + amount <= _itemInfo[itemId].maxSupply,
            "GameItemContract: Insufficient supply"
        );
        _;
    }

    modifier userMintLimit(address user, uint256 itemId, uint256 amount) {
        uint256 maxMint = _maxUserMint[itemId];
        if (maxMint > 0) {
            require(
                _mintedByUser[user][itemId] + amount <= maxMint,
                "GameItemContract: User mint limit exceeded"
            );
        }
        _;
    }

    constructor(string memory uri) ERC1155(uri) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(URI_SETTER_ROLE, msg.sender);
    }


    function createItem(
        string memory name,
        uint256 rarity,
        uint256 maxSupply,
        uint256 mintPrice,
        uint256 maxUserMint
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (uint256) {
        require(bytes(name).length > 0, "GameItemContract: Name cannot be empty");
        require(rarity >= LEGENDARY_RARITY && rarity <= COMMON_RARITY, "GameItemContract: Invalid rarity");
        require(maxSupply > 0 && maxSupply <= MAX_SUPPLY_PER_ITEM, "GameItemContract: Invalid max supply");

        _itemIdCounter.increment();
        uint256 itemId = _itemIdCounter.current();

        _itemInfo[itemId] = ItemInfo({
            name: name,
            rarity: rarity,
            maxSupply: maxSupply,
            mintable: true,
            mintPrice: mintPrice
        });

        if (maxUserMint > 0) {
            _maxUserMint[itemId] = maxUserMint;
        }

        emit ItemCreated(itemId, name, rarity, maxSupply);
        return itemId;
    }


    function mint(
        address to,
        uint256 itemId,
        uint256 amount
    )
        external
        payable
        onlyRole(MINTER_ROLE)
        whenNotPaused
        nonReentrant
        validItemId(itemId)
        validAmount(amount)
        mintableItem(itemId)
        sufficientSupply(itemId, amount)
        userMintLimit(to, itemId, amount)
    {
        _validatePayment(itemId, amount);
        _executeMint(to, itemId, amount);
    }


    function publicMint(
        uint256 itemId,
        uint256 amount
    )
        external
        payable
        whenNotPaused
        nonReentrant
        validItemId(itemId)
        validAmount(amount)
        mintableItem(itemId)
        sufficientSupply(itemId, amount)
        userMintLimit(msg.sender, itemId, amount)
    {
        _validatePayment(itemId, amount);
        _executeMint(msg.sender, itemId, amount);
    }


    function mintBatch(
        address to,
        uint256[] memory itemIds,
        uint256[] memory amounts
    ) external payable onlyRole(MINTER_ROLE) whenNotPaused nonReentrant {
        require(itemIds.length == amounts.length, "GameItemContract: Arrays length mismatch");
        require(itemIds.length > 0, "GameItemContract: Empty arrays");

        uint256 totalPayment = 0;
        for (uint256 i = 0; i < itemIds.length; i++) {
            require(_exists(itemIds[i]), "GameItemContract: Item does not exist");
            require(amounts[i] > 0, "GameItemContract: Amount must be greater than 0");
            require(_itemInfo[itemIds[i]].mintable, "GameItemContract: Item is not mintable");
            require(
                _totalSupply[itemIds[i]] + amounts[i] <= _itemInfo[itemIds[i]].maxSupply,
                "GameItemContract: Insufficient supply"
            );

            uint256 maxMint = _maxUserMint[itemIds[i]];
            if (maxMint > 0) {
                require(
                    _mintedByUser[to][itemIds[i]] + amounts[i] <= maxMint,
                    "GameItemContract: User mint limit exceeded"
                );
            }

            totalPayment += _itemInfo[itemIds[i]].mintPrice * amounts[i];
            _mintedByUser[to][itemIds[i]] += amounts[i];
            _totalSupply[itemIds[i]] += amounts[i];
        }

        require(msg.value >= totalPayment, "GameItemContract: Insufficient payment");

        _mintBatch(to, itemIds, amounts, "");

        for (uint256 i = 0; i < itemIds.length; i++) {
            emit ItemMinted(to, itemIds[i], amounts[i]);
        }

        if (msg.value > totalPayment) {
            payable(msg.sender).transfer(msg.value - totalPayment);
        }
    }


    function burn(
        address from,
        uint256 itemId,
        uint256 amount
    ) external onlyRole(BURNER_ROLE) validItemId(itemId) validAmount(amount) {
        require(balanceOf(from, itemId) >= amount, "GameItemContract: Insufficient balance");

        _burn(from, itemId, amount);
        _totalSupply[itemId] -= amount;

        emit ItemBurned(from, itemId, amount);
    }


    function updateItemInfo(
        uint256 itemId,
        string memory name,
        uint256 rarity
    ) external onlyRole(DEFAULT_ADMIN_ROLE) validItemId(itemId) {
        require(bytes(name).length > 0, "GameItemContract: Name cannot be empty");
        require(rarity >= LEGENDARY_RARITY && rarity <= COMMON_RARITY, "GameItemContract: Invalid rarity");

        _itemInfo[itemId].name = name;
        _itemInfo[itemId].rarity = rarity;

        emit ItemInfoUpdated(itemId, name, rarity);
    }


    function setItemMintable(uint256 itemId, bool mintable)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        validItemId(itemId)
    {
        _itemInfo[itemId].mintable = mintable;
    }


    function setItemMintPrice(uint256 itemId, uint256 price)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        validItemId(itemId)
    {
        _itemInfo[itemId].mintPrice = price;
    }


    function setUserMintLimit(uint256 itemId, uint256 limit)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        validItemId(itemId)
    {
        _maxUserMint[itemId] = limit;
    }


    function setURI(string memory newuri) external onlyRole(URI_SETTER_ROLE) {
        _setURI(newuri);
    }


    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }


    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }


    function withdraw() external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "GameItemContract: No funds to withdraw");

        payable(msg.sender).transfer(balance);
    }


    function _validatePayment(uint256 itemId, uint256 amount) internal view {
        uint256 totalPrice = _itemInfo[itemId].mintPrice * amount;
        require(msg.value >= totalPrice, "GameItemContract: Insufficient payment");
    }

    function _executeMint(address to, uint256 itemId, uint256 amount) internal {
        _mint(to, itemId, amount, "");
        _totalSupply[itemId] += amount;
        _mintedByUser[to][itemId] += amount;

        emit ItemMinted(to, itemId, amount);

        uint256 totalPrice = _itemInfo[itemId].mintPrice * amount;
        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }
    }

    function _exists(uint256 itemId) internal view returns (bool) {
        return itemId > 0 && itemId <= _itemIdCounter.current();
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


    function getItemInfo(uint256 itemId)
        external
        view
        validItemId(itemId)
        returns (ItemInfo memory)
    {
        return _itemInfo[itemId];
    }

    function totalSupply(uint256 itemId) external view validItemId(itemId) returns (uint256) {
        return _totalSupply[itemId];
    }

    function getUserMintedAmount(address user, uint256 itemId)
        external
        view
        validItemId(itemId)
        returns (uint256)
    {
        return _mintedByUser[user][itemId];
    }

    function getUserMintLimit(uint256 itemId)
        external
        view
        validItemId(itemId)
        returns (uint256)
    {
        return _maxUserMint[itemId];
    }

    function getCurrentItemId() external view returns (uint256) {
        return _itemIdCounter.current();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
