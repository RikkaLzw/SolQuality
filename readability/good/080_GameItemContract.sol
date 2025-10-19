
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
        bool isTradeable;
    }


    mapping(uint256 => ItemInfo) public itemInfos;
    mapping(address => bool) public authorizedMinters;
    mapping(uint256 => mapping(address => bool)) public itemApprovals;

    uint256 public nextItemId;
    uint256 public totalItemTypes;
    address public treasuryWallet;


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
    event TreasuryWalletUpdated(address indexed oldWallet, address indexed newWallet);
    event ItemInfoUpdated(uint256 indexed itemId);


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


    constructor(
        string memory baseURI,
        address _treasuryWallet
    ) ERC1155(baseURI) {
        require(_treasuryWallet != address(0), "GameItemContract: treasury wallet cannot be zero address");

        treasuryWallet = _treasuryWallet;
        nextItemId = 1;


        authorizedMinters[msg.sender] = true;
        emit MinterAuthorized(msg.sender, true);
    }


    function createItem(
        string memory name,
        string memory description,
        ItemType itemType,
        Rarity rarity,
        uint256 maxSupply,
        uint256 mintPrice,
        bool isTradeable
    ) external onlyOwner {
        require(bytes(name).length > 0, "GameItemContract: name cannot be empty");
        require(bytes(description).length > 0, "GameItemContract: description cannot be empty");

        uint256 itemId = nextItemId;
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
            isActive: true,
            isTradeable: isTradeable
        });

        emit ItemCreated(itemId, name, itemType, rarity, maxSupply, mintPrice);
    }


    function mintItem(
        address to,
        uint256 itemId,
        uint256 amount
    ) external payable nonReentrant whenNotPaused validItemId(itemId) onlyAuthorizedMinter {
        require(to != address(0), "GameItemContract: mint to zero address");
        require(amount > 0, "GameItemContract: amount must be greater than zero");

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


        if (totalPrice > 0) {
            (bool success, ) = treasuryWallet.call{value: totalPrice}("");
            require(success, "GameItemContract: treasury transfer failed");
        }


        if (msg.value > totalPrice) {
            (bool refundSuccess, ) = msg.sender.call{value: msg.value - totalPrice}("");
            require(refundSuccess, "GameItemContract: refund failed");
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
            require(amount > 0, "GameItemContract: amount must be greater than zero");
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
        }

        require(msg.value >= totalPrice, "GameItemContract: insufficient payment");


        _mintBatch(to, itemIds, amounts, "");


        if (totalPrice > 0) {
            (bool success, ) = treasuryWallet.call{value: totalPrice}("");
            require(success, "GameItemContract: treasury transfer failed");
        }


        if (msg.value > totalPrice) {
            (bool refundSuccess, ) = msg.sender.call{value: msg.value - totalPrice}("");
            require(refundSuccess, "GameItemContract: refund failed");
        }


        for (uint256 i = 0; i < itemIds.length; i++) {
            emit ItemMinted(to, itemIds[i], amounts[i], itemInfos[itemIds[i]].mintPrice * amounts[i]);
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
        require(amount > 0, "GameItemContract: amount must be greater than zero");


        itemInfos[itemId].currentSupply -= amount;


        _burn(from, itemId, amount);

        emit ItemBurned(from, itemId, amount);
    }


    function updateItemInfo(
        uint256 itemId,
        string memory name,
        string memory description,
        uint256 mintPrice,
        bool isTradeable
    ) external onlyOwner validItemId(itemId) {
        require(bytes(name).length > 0, "GameItemContract: name cannot be empty");
        require(bytes(description).length > 0, "GameItemContract: description cannot be empty");

        ItemInfo storage item = itemInfos[itemId];
        item.name = name;
        item.description = description;
        item.mintPrice = mintPrice;
        item.isTradeable = isTradeable;

        emit ItemInfoUpdated(itemId);
    }


    function setItemActive(uint256 itemId, bool isActive) external onlyOwner {
        require(itemId < nextItemId, "GameItemContract: invalid item ID");
        itemInfos[itemId].isActive = isActive;
        emit ItemInfoUpdated(itemId);
    }


    function setAuthorizedMinter(address minter, bool authorized) external onlyOwner {
        require(minter != address(0), "GameItemContract: minter cannot be zero address");
        authorizedMinters[minter] = authorized;
        emit MinterAuthorized(minter, authorized);
    }


    function updateTreasuryWallet(address newTreasuryWallet) external onlyOwner {
        require(newTreasuryWallet != address(0), "GameItemContract: treasury wallet cannot be zero address");
        address oldWallet = treasuryWallet;
        treasuryWallet = newTreasuryWallet;
        emit TreasuryWalletUpdated(oldWallet, newTreasuryWallet);
    }


    function setBaseURI(string memory newBaseURI) external onlyOwner {
        _setURI(newBaseURI);
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


        if (from != address(0) && to != address(0)) {
            for (uint256 i = 0; i < ids.length; i++) {
                require(
                    itemInfos[ids[i]].isTradeable,
                    "GameItemContract: item is not tradeable"
                );
            }
        }
    }


    function uri(uint256 itemId) public view override returns (string memory) {
        require(itemId < nextItemId, "GameItemContract: URI query for nonexistent token");
        return string(abi.encodePacked(super.uri(itemId), itemId.toString()));
    }


    function getItemInfo(uint256 itemId) external view returns (ItemInfo memory) {
        require(itemId < nextItemId, "GameItemContract: invalid item ID");
        return itemInfos[itemId];
    }


    function balanceOfBatch(
        address account,
        uint256[] memory itemIds
    ) public view override returns (uint256[] memory) {
        return super.balanceOfBatch(_asSingletonArray(account), itemIds);
    }


    function _asSingletonArray(address element) private pure returns (address[] memory) {
        address[] memory array = new address[](1);
        array[0] = element;
        return array;
    }


    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "GameItemContract: no balance to withdraw");

        (bool success, ) = owner().call{value: balance}("");
        require(success, "GameItemContract: withdrawal failed");
    }


    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
