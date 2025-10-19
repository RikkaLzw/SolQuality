
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract GameItemContract is ERC1155, Ownable, ReentrancyGuard, Pausable {

    struct ItemInfo {
        uint128 maxSupply;
        uint128 currentSupply;
        uint64 price;
        bool mintable;
        bool tradeable;
    }


    mapping(uint256 => ItemInfo) public items;
    mapping(uint256 => string) private _itemURIs;
    mapping(address => mapping(uint256 => uint256)) private _userItemCounts;
    mapping(address => bool) public authorizedMinters;

    uint256 private _nextItemId = 1;
    uint256 public constant MAX_BATCH_SIZE = 50;


    event ItemCreated(uint256 indexed itemId, uint128 maxSupply, uint64 price);
    event ItemMinted(address indexed to, uint256 indexed itemId, uint256 amount);
    event ItemBurned(address indexed from, uint256 indexed itemId, uint256 amount);
    event MinterAuthorized(address indexed minter, bool authorized);

    constructor(string memory baseURI) ERC1155(baseURI) {}

    modifier onlyAuthorized() {
        require(authorizedMinters[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }


    function createItem(
        uint128 maxSupply,
        uint64 price,
        string memory itemURI,
        bool mintable,
        bool tradeable
    ) external onlyOwner returns (uint256) {
        uint256 itemId = _nextItemId++;

        items[itemId] = ItemInfo({
            maxSupply: maxSupply,
            currentSupply: 0,
            price: price,
            mintable: mintable,
            tradeable: tradeable
        });

        _itemURIs[itemId] = itemURI;

        emit ItemCreated(itemId, maxSupply, price);
        return itemId;
    }


    function mintBatch(
        address to,
        uint256[] memory itemIds,
        uint256[] memory amounts
    ) external onlyAuthorized nonReentrant whenNotPaused {
        require(itemIds.length == amounts.length, "Arrays length mismatch");
        require(itemIds.length <= MAX_BATCH_SIZE, "Batch size too large");


        uint256 length = itemIds.length;

        for (uint256 i = 0; i < length;) {
            uint256 itemId = itemIds[i];
            uint256 amount = amounts[i];


            ItemInfo storage item = items[itemId];

            require(item.mintable, "Item not mintable");
            require(item.currentSupply + amount <= item.maxSupply, "Exceeds max supply");


            item.currentSupply += uint128(amount);
            _userItemCounts[to][itemId] += amount;

            emit ItemMinted(to, itemId, amount);

            unchecked { ++i; }
        }

        _mintBatch(to, itemIds, amounts, "");
    }


    function mint(
        address to,
        uint256 itemId,
        uint256 amount
    ) external payable onlyAuthorized nonReentrant whenNotPaused {

        ItemInfo storage item = items[itemId];

        require(item.mintable, "Item not mintable");
        require(item.currentSupply + amount <= item.maxSupply, "Exceeds max supply");


        if (item.price > 0) {
            require(msg.value >= item.price * amount, "Insufficient payment");
        }


        item.currentSupply += uint128(amount);
        _userItemCounts[to][itemId] += amount;

        _mint(to, itemId, amount, "");
        emit ItemMinted(to, itemId, amount);
    }


    function burn(
        address from,
        uint256 itemId,
        uint256 amount
    ) external {
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender),
            "Not owner nor approved"
        );


        ItemInfo storage item = items[itemId];
        item.currentSupply -= uint128(amount);
        _userItemCounts[from][itemId] -= amount;

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
            "Not owner nor approved"
        );

        uint256 length = itemIds.length;
        for (uint256 i = 0; i < length;) {
            uint256 itemId = itemIds[i];
            uint256 amount = amounts[i];

            ItemInfo storage item = items[itemId];
            item.currentSupply -= uint128(amount);
            _userItemCounts[from][itemId] -= amount;

            emit ItemBurned(from, itemId, amount);

            unchecked { ++i; }
        }

        _burnBatch(from, itemIds, amounts);
    }


    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override {
        require(items[id].tradeable, "Item not tradeable");


        _userItemCounts[from][id] -= amount;
        _userItemCounts[to][id] += amount;

        super.safeTransferFrom(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public override {
        uint256 length = ids.length;
        for (uint256 i = 0; i < length;) {
            require(items[ids[i]].tradeable, "Item not tradeable");

            _userItemCounts[from][ids[i]] -= amounts[i];
            _userItemCounts[to][ids[i]] += amounts[i];

            unchecked { ++i; }
        }

        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }


    function setMinterAuthorization(address minter, bool authorized) external onlyOwner {
        authorizedMinters[minter] = authorized;
        emit MinterAuthorized(minter, authorized);
    }

    function updateItemInfo(
        uint256 itemId,
        uint128 maxSupply,
        uint64 price,
        bool mintable,
        bool tradeable
    ) external onlyOwner {
        ItemInfo storage item = items[itemId];
        require(maxSupply >= item.currentSupply, "Max supply too low");

        item.maxSupply = maxSupply;
        item.price = price;
        item.mintable = mintable;
        item.tradeable = tradeable;
    }

    function setItemURI(uint256 itemId, string memory newURI) external onlyOwner {
        _itemURIs[itemId] = newURI;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }


    function uri(uint256 itemId) public view override returns (string memory) {
        string memory itemURI = _itemURIs[itemId];
        return bytes(itemURI).length > 0 ? itemURI : super.uri(itemId);
    }

    function getUserItemCount(address user, uint256 itemId) external view returns (uint256) {
        return _userItemCounts[user][itemId];
    }

    function getItemInfo(uint256 itemId) external view returns (
        uint128 maxSupply,
        uint128 currentSupply,
        uint64 price,
        bool mintable,
        bool tradeable
    ) {
        ItemInfo memory item = items[itemId];
        return (
            item.maxSupply,
            item.currentSupply,
            item.price,
            item.mintable,
            item.tradeable
        );
    }

    function getUserItemsBatch(
        address user,
        uint256[] memory itemIds
    ) external view returns (uint256[] memory balances) {
        uint256 length = itemIds.length;
        balances = new uint256[](length);

        for (uint256 i = 0; i < length;) {
            balances[i] = _userItemCounts[user][itemIds[i]];
            unchecked { ++i; }
        }
    }


    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
