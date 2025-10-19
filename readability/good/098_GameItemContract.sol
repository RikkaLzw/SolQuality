
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
        CONSUMABLE,
        MATERIAL,
        SPECIAL
    }


    enum Rarity {
        COMMON,
        RARE,
        EPIC,
        LEGENDARY
    }


    struct GameItem {
        string name;
        string description;
        ItemType itemType;
        Rarity rarity;
        uint256 maxSupply;
        uint256 currentSupply;
        uint256 price;
        bool isActive;
        string imageUri;
    }


    mapping(uint256 => GameItem) public gameItems;
    mapping(address => bool) public authorizedMinters;
    mapping(uint256 => mapping(address => uint256)) public playerItemCounts;

    uint256 public nextItemId;
    uint256 public totalItemTypes;
    address public gameContract;
    uint256 public platformFeePercent;
    address public feeRecipient;


    event ItemCreated(
        uint256 indexed itemId,
        string name,
        ItemType itemType,
        Rarity rarity,
        uint256 maxSupply,
        uint256 price
    );

    event ItemMinted(
        uint256 indexed itemId,
        address indexed to,
        uint256 amount,
        uint256 totalPaid
    );

    event ItemBurned(
        uint256 indexed itemId,
        address indexed from,
        uint256 amount
    );

    event ItemTransferred(
        uint256 indexed itemId,
        address indexed from,
        address indexed to,
        uint256 amount
    );

    event AuthorizedMinterAdded(address indexed minter);
    event AuthorizedMinterRemoved(address indexed minter);
    event GameContractUpdated(address indexed oldContract, address indexed newContract);
    event PlatformFeeUpdated(uint256 oldFee, uint256 newFee);


    modifier onlyAuthorizedMinter() {
        require(
            authorizedMinters[msg.sender] || msg.sender == owner(),
            "GameItemContract: caller is not authorized minter"
        );
        _;
    }

    modifier onlyGameContract() {
        require(
            msg.sender == gameContract || msg.sender == owner(),
            "GameItemContract: caller is not game contract"
        );
        _;
    }

    modifier validItemId(uint256 itemId) {
        require(
            itemId < nextItemId && gameItems[itemId].isActive,
            "GameItemContract: invalid or inactive item ID"
        );
        _;
    }


    constructor(
        address initialOwner,
        string memory baseUri,
        address _feeRecipient
    ) ERC1155(baseUri) {
        require(initialOwner != address(0), "GameItemContract: invalid owner address");
        require(_feeRecipient != address(0), "GameItemContract: invalid fee recipient");

        _transferOwnership(initialOwner);
        feeRecipient = _feeRecipient;
        platformFeePercent = 250;
        nextItemId = 1;
    }


    function createGameItem(
        string memory name,
        string memory description,
        ItemType itemType,
        Rarity rarity,
        uint256 maxSupply,
        uint256 price,
        string memory imageUri
    ) external onlyOwner returns (uint256) {
        require(bytes(name).length > 0, "GameItemContract: name cannot be empty");
        require(maxSupply > 0, "GameItemContract: max supply must be greater than 0");

        uint256 itemId = nextItemId;

        gameItems[itemId] = GameItem({
            name: name,
            description: description,
            itemType: itemType,
            rarity: rarity,
            maxSupply: maxSupply,
            currentSupply: 0,
            price: price,
            isActive: true,
            imageUri: imageUri
        });

        nextItemId++;
        totalItemTypes++;

        emit ItemCreated(itemId, name, itemType, rarity, maxSupply, price);

        return itemId;
    }


    function mintGameItem(
        address to,
        uint256 itemId,
        uint256 amount
    ) external payable validItemId(itemId) whenNotPaused nonReentrant {
        require(to != address(0), "GameItemContract: cannot mint to zero address");
        require(amount > 0, "GameItemContract: amount must be greater than 0");

        GameItem storage item = gameItems[itemId];
        require(
            item.currentSupply + amount <= item.maxSupply,
            "GameItemContract: exceeds max supply"
        );

        uint256 totalCost = item.price * amount;
        require(msg.value >= totalCost, "GameItemContract: insufficient payment");


        uint256 platformFee = (totalCost * platformFeePercent) / 10000;
        uint256 remainingAmount = totalCost - platformFee;


        item.currentSupply += amount;
        playerItemCounts[itemId][to] += amount;


        _mint(to, itemId, amount, "");


        if (platformFee > 0) {
            payable(feeRecipient).transfer(platformFee);
        }


        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }

        emit ItemMinted(itemId, to, amount, totalCost);
    }


    function batchMintGameItems(
        address to,
        uint256[] memory itemIds,
        uint256[] memory amounts
    ) external payable whenNotPaused nonReentrant {
        require(to != address(0), "GameItemContract: cannot mint to zero address");
        require(
            itemIds.length == amounts.length,
            "GameItemContract: arrays length mismatch"
        );
        require(itemIds.length > 0, "GameItemContract: empty arrays");

        uint256 totalCost = 0;


        for (uint256 i = 0; i < itemIds.length; i++) {
            require(
                itemIds[i] < nextItemId && gameItems[itemIds[i]].isActive,
                "GameItemContract: invalid or inactive item ID"
            );
            require(amounts[i] > 0, "GameItemContract: amount must be greater than 0");

            GameItem storage item = gameItems[itemIds[i]];
            require(
                item.currentSupply + amounts[i] <= item.maxSupply,
                "GameItemContract: exceeds max supply"
            );

            totalCost += item.price * amounts[i];
        }

        require(msg.value >= totalCost, "GameItemContract: insufficient payment");


        for (uint256 i = 0; i < itemIds.length; i++) {
            gameItems[itemIds[i]].currentSupply += amounts[i];
            playerItemCounts[itemIds[i]][to] += amounts[i];
        }

        _mintBatch(to, itemIds, amounts, "");


        uint256 platformFee = (totalCost * platformFeePercent) / 10000;
        if (platformFee > 0) {
            payable(feeRecipient).transfer(platformFee);
        }


        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }

        emit ItemMinted(0, to, 0, totalCost);
    }


    function authorizedMint(
        address to,
        uint256 itemId,
        uint256 amount
    ) external onlyAuthorizedMinter validItemId(itemId) whenNotPaused {
        require(to != address(0), "GameItemContract: cannot mint to zero address");
        require(amount > 0, "GameItemContract: amount must be greater than 0");

        GameItem storage item = gameItems[itemId];
        require(
            item.currentSupply + amount <= item.maxSupply,
            "GameItemContract: exceeds max supply"
        );

        item.currentSupply += amount;
        playerItemCounts[itemId][to] += amount;

        _mint(to, itemId, amount, "");

        emit ItemMinted(itemId, to, amount, 0);
    }


    function burnGameItem(
        address from,
        uint256 itemId,
        uint256 amount
    ) external validItemId(itemId) {
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender),
            "GameItemContract: caller is not owner nor approved"
        );
        require(amount > 0, "GameItemContract: amount must be greater than 0");
        require(
            balanceOf(from, itemId) >= amount,
            "GameItemContract: insufficient balance"
        );

        gameItems[itemId].currentSupply -= amount;
        playerItemCounts[itemId][from] -= amount;

        _burn(from, itemId, amount);

        emit ItemBurned(itemId, from, amount);
    }


    function getGameItem(uint256 itemId) external view returns (GameItem memory) {
        require(itemId < nextItemId, "GameItemContract: invalid item ID");
        return gameItems[itemId];
    }


    function getPlayerItemCount(address player, uint256 itemId) external view returns (uint256) {
        return playerItemCounts[itemId][player];
    }


    function isValidItem(uint256 itemId) external view returns (bool) {
        return itemId < nextItemId && gameItems[itemId].isActive;
    }


    function updateItemPrice(uint256 itemId, uint256 newPrice) external onlyOwner validItemId(itemId) {
        gameItems[itemId].price = newPrice;
    }


    function updateItemStatus(uint256 itemId, bool isActive) external onlyOwner {
        require(itemId < nextItemId, "GameItemContract: invalid item ID");
        gameItems[itemId].isActive = isActive;
    }


    function addAuthorizedMinter(address minter) external onlyOwner {
        require(minter != address(0), "GameItemContract: invalid minter address");
        authorizedMinters[minter] = true;
        emit AuthorizedMinterAdded(minter);
    }


    function removeAuthorizedMinter(address minter) external onlyOwner {
        authorizedMinters[minter] = false;
        emit AuthorizedMinterRemoved(minter);
    }


    function setGameContract(address _gameContract) external onlyOwner {
        require(_gameContract != address(0), "GameItemContract: invalid game contract address");
        address oldContract = gameContract;
        gameContract = _gameContract;
        emit GameContractUpdated(oldContract, _gameContract);
    }


    function updatePlatformFee(uint256 newFeePercent) external onlyOwner {
        require(newFeePercent <= 1000, "GameItemContract: fee cannot exceed 10%");
        uint256 oldFee = platformFeePercent;
        platformFeePercent = newFeePercent;
        emit PlatformFeeUpdated(oldFee, newFeePercent);
    }


    function updateFeeRecipient(address newFeeRecipient) external onlyOwner {
        require(newFeeRecipient != address(0), "GameItemContract: invalid fee recipient");
        feeRecipient = newFeeRecipient;
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
    }


    function withdrawBalance() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "GameItemContract: no balance to withdraw");
        payable(owner()).transfer(balance);
    }


    function uri(uint256 itemId) public view override returns (string memory) {
        require(itemId < nextItemId, "GameItemContract: invalid item ID");

        if (bytes(gameItems[itemId].imageUri).length > 0) {
            return gameItems[itemId].imageUri;
        }

        return string(abi.encodePacked(super.uri(itemId), itemId.toString()));
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
                playerItemCounts[ids[i]][from] -= amounts[i];
                playerItemCounts[ids[i]][to] += amounts[i];
                emit ItemTransferred(ids[i], from, to, amounts[i]);
            }
        }
    }


    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
