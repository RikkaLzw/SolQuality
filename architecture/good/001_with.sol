
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


contract GameItemContract is ERC1155, Ownable, Pausable, ReentrancyGuard {
    using Strings for uint256;


    uint256 public constant WEAPON = 1;
    uint256 public constant ARMOR = 2;
    uint256 public constant POTION = 3;
    uint256 public constant MATERIAL = 4;
    uint256 public constant RARE_ITEM = 5;

    uint256 public constant MAX_SUPPLY_PER_ITEM = 10000;
    uint256 public constant MAX_MINT_PER_TX = 50;
    uint256 public constant RARE_ITEM_LIMIT = 100;


    mapping(uint256 => ItemInfo) public itemInfo;
    mapping(uint256 => uint256) public totalSupply;
    mapping(address => bool) public authorizedMinters;
    mapping(uint256 => bool) public itemExists;

    uint256 private _currentItemId;
    string private _baseTokenURI;

    struct ItemInfo {
        string name;
        string description;
        uint256 itemType;
        uint256 rarity;
        uint256 maxSupply;
        bool tradeable;
        uint256 price;
    }


    event ItemCreated(uint256 indexed itemId, string name, uint256 itemType, uint256 maxSupply);
    event ItemMinted(address indexed to, uint256 indexed itemId, uint256 amount);
    event ItemBurned(address indexed from, uint256 indexed itemId, uint256 amount);
    event MinterAuthorized(address indexed minter);
    event MinterRevoked(address indexed minter);
    event ItemTradeabilityChanged(uint256 indexed itemId, bool tradeable);


    modifier onlyAuthorizedMinter() {
        require(authorizedMinters[msg.sender] || msg.sender == owner(), "Not authorized minter");
        _;
    }

    modifier itemMustExist(uint256 itemId) {
        require(itemExists[itemId], "Item does not exist");
        _;
    }

    modifier validAmount(uint256 amount) {
        require(amount > 0 && amount <= MAX_MINT_PER_TX, "Invalid amount");
        _;
    }

    modifier supplyCheck(uint256 itemId, uint256 amount) {
        require(
            totalSupply[itemId] + amount <= itemInfo[itemId].maxSupply,
            "Exceeds max supply"
        );
        _;
    }

    constructor(
        string memory baseURI,
        address initialOwner
    ) ERC1155(baseURI) {
        _baseTokenURI = baseURI;
        _transferOwnership(initialOwner);
        _currentItemId = 1;
    }


    function createItem(
        string memory name,
        string memory description,
        uint256 itemType,
        uint256 rarity,
        uint256 maxSupply,
        bool tradeable,
        uint256 price
    ) external onlyOwner returns (uint256) {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(maxSupply > 0 && maxSupply <= MAX_SUPPLY_PER_ITEM, "Invalid max supply");
        require(itemType >= WEAPON && itemType <= RARE_ITEM, "Invalid item type");

        if (itemType == RARE_ITEM) {
            require(maxSupply <= RARE_ITEM_LIMIT, "Rare item supply too high");
        }

        uint256 newItemId = _currentItemId++;

        itemInfo[newItemId] = ItemInfo({
            name: name,
            description: description,
            itemType: itemType,
            rarity: rarity,
            maxSupply: maxSupply,
            tradeable: tradeable,
            price: price
        });

        itemExists[newItemId] = true;

        emit ItemCreated(newItemId, name, itemType, maxSupply);
        return newItemId;
    }


    function mintItem(
        address to,
        uint256 itemId,
        uint256 amount
    )
        external
        onlyAuthorizedMinter
        whenNotPaused
        nonReentrant
        itemMustExist(itemId)
        validAmount(amount)
        supplyCheck(itemId, amount)
    {
        require(to != address(0), "Cannot mint to zero address");

        totalSupply[itemId] += amount;
        _mint(to, itemId, amount, "");

        emit ItemMinted(to, itemId, amount);
    }


    function mintBatch(
        address to,
        uint256[] memory itemIds,
        uint256[] memory amounts
    )
        external
        onlyAuthorizedMinter
        whenNotPaused
        nonReentrant
    {
        require(to != address(0), "Cannot mint to zero address");
        require(itemIds.length == amounts.length, "Arrays length mismatch");
        require(itemIds.length <= 10, "Too many items in batch");

        for (uint256 i = 0; i < itemIds.length; i++) {
            require(itemExists[itemIds[i]], "Item does not exist");
            require(amounts[i] > 0 && amounts[i] <= MAX_MINT_PER_TX, "Invalid amount");
            require(
                totalSupply[itemIds[i]] + amounts[i] <= itemInfo[itemIds[i]].maxSupply,
                "Exceeds max supply"
            );

            totalSupply[itemIds[i]] += amounts[i];
        }

        _mintBatch(to, itemIds, amounts, "");

        for (uint256 i = 0; i < itemIds.length; i++) {
            emit ItemMinted(to, itemIds[i], amounts[i]);
        }
    }


    function burnItem(
        uint256 itemId,
        uint256 amount
    )
        external
        whenNotPaused
        itemMustExist(itemId)
        validAmount(amount)
    {
        require(balanceOf(msg.sender, itemId) >= amount, "Insufficient balance");

        totalSupply[itemId] -= amount;
        _burn(msg.sender, itemId, amount);

        emit ItemBurned(msg.sender, itemId, amount);
    }


    function authorizeMinter(address minter) external onlyOwner {
        require(minter != address(0), "Invalid minter address");
        require(!authorizedMinters[minter], "Already authorized");

        authorizedMinters[minter] = true;
        emit MinterAuthorized(minter);
    }


    function revokeMinter(address minter) external onlyOwner {
        require(authorizedMinters[minter], "Not authorized");

        authorizedMinters[minter] = false;
        emit MinterRevoked(minter);
    }


    function setItemTradeability(uint256 itemId, bool tradeable)
        external
        onlyOwner
        itemMustExist(itemId)
    {
        itemInfo[itemId].tradeable = tradeable;
        emit ItemTradeabilityChanged(itemId, tradeable);
    }


    function setBaseURI(string memory newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
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


        if (from == address(0) || to == address(0)) {
            return;
        }


        for (uint256 i = 0; i < ids.length; i++) {
            require(itemInfo[ids[i]].tradeable, "Item not tradeable");
        }
    }


    function uri(uint256 tokenId) public view override returns (string memory) {
        require(itemExists[tokenId], "Item does not exist");
        return string(abi.encodePacked(_baseTokenURI, tokenId.toString()));
    }


    function getItemInfo(uint256 itemId)
        external
        view
        itemMustExist(itemId)
        returns (ItemInfo memory)
    {
        return itemInfo[itemId];
    }


    function getCurrentItemId() external view returns (uint256) {
        return _currentItemId;
    }


    function exists(uint256 itemId) external view returns (bool) {
        return itemExists[itemId];
    }


    function getTotalSupply(uint256 itemId) external view returns (uint256) {
        return totalSupply[itemId];
    }
}
