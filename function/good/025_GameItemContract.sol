
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract GameItemContract is ERC1155, Ownable, Pausable, ReentrancyGuard {
    struct ItemInfo {
        string name;
        uint256 maxSupply;
        uint256 currentSupply;
        bool mintable;
    }

    mapping(uint256 => ItemInfo) public items;
    mapping(address => bool) public authorizedMinters;

    uint256 private _currentItemId;

    event ItemCreated(uint256 indexed itemId, string name, uint256 maxSupply);
    event ItemMinted(address indexed to, uint256 indexed itemId, uint256 amount);
    event ItemBurned(address indexed from, uint256 indexed itemId, uint256 amount);
    event MinterAuthorized(address indexed minter);
    event MinterRevoked(address indexed minter);

    modifier onlyAuthorizedMinter() {
        require(authorizedMinters[msg.sender] || msg.sender == owner(), "Not authorized minter");
        _;
    }

    modifier validItemId(uint256 itemId) {
        require(itemId < _currentItemId, "Item does not exist");
        _;
    }

    constructor(string memory uri) ERC1155(uri) {}

    function createItem(string memory name, uint256 maxSupply) external onlyOwner returns (uint256) {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(maxSupply > 0, "Max supply must be greater than 0");

        uint256 itemId = _currentItemId++;
        items[itemId] = ItemInfo({
            name: name,
            maxSupply: maxSupply,
            currentSupply: 0,
            mintable: true
        });

        emit ItemCreated(itemId, name, maxSupply);
        return itemId;
    }

    function mintItem(address to, uint256 itemId, uint256 amount)
        external
        onlyAuthorizedMinter
        validItemId(itemId)
        whenNotPaused
    {
        require(to != address(0), "Cannot mint to zero address");
        require(amount > 0, "Amount must be greater than 0");
        require(items[itemId].mintable, "Item is not mintable");

        ItemInfo storage item = items[itemId];
        require(item.currentSupply + amount <= item.maxSupply, "Exceeds max supply");

        item.currentSupply += amount;
        _mint(to, itemId, amount, "");

        emit ItemMinted(to, itemId, amount);
    }

    function burnItem(address from, uint256 itemId, uint256 amount)
        external
        validItemId(itemId)
        whenNotPaused
    {
        require(from != address(0), "Cannot burn from zero address");
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(from, itemId) >= amount, "Insufficient balance");
        require(msg.sender == from || isApprovedForAll(from, msg.sender), "Not authorized to burn");

        items[itemId].currentSupply -= amount;
        _burn(from, itemId, amount);

        emit ItemBurned(from, itemId, amount);
    }

    function batchMintItems(address to, uint256[] memory itemIds, uint256[] memory amounts)
        external
        onlyAuthorizedMinter
        whenNotPaused
    {
        require(to != address(0), "Cannot mint to zero address");
        require(itemIds.length == amounts.length, "Arrays length mismatch");
        require(itemIds.length <= 10, "Too many items in batch");

        for (uint256 i = 0; i < itemIds.length; i++) {
            uint256 itemId = itemIds[i];
            uint256 amount = amounts[i];

            require(itemId < _currentItemId, "Item does not exist");
            require(amount > 0, "Amount must be greater than 0");
            require(items[itemId].mintable, "Item is not mintable");

            ItemInfo storage item = items[itemId];
            require(item.currentSupply + amount <= item.maxSupply, "Exceeds max supply");

            item.currentSupply += amount;
            emit ItemMinted(to, itemId, amount);
        }

        _mintBatch(to, itemIds, amounts, "");
    }

    function toggleItemMintable(uint256 itemId) external onlyOwner validItemId(itemId) {
        items[itemId].mintable = !items[itemId].mintable;
    }

    function authorizeMinter(address minter) external onlyOwner {
        require(minter != address(0), "Cannot authorize zero address");
        require(!authorizedMinters[minter], "Already authorized");

        authorizedMinters[minter] = true;
        emit MinterAuthorized(minter);
    }

    function revokeMinter(address minter) external onlyOwner {
        require(authorizedMinters[minter], "Not authorized");

        authorizedMinters[minter] = false;
        emit MinterRevoked(minter);
    }

    function getItemInfo(uint256 itemId) external view validItemId(itemId) returns (ItemInfo memory) {
        return items[itemId];
    }

    function getCurrentItemId() external view returns (uint256) {
        return _currentItemId;
    }

    function setURI(string memory newUri) external onlyOwner {
        _setURI(newUri);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
