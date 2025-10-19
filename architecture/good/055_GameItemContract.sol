
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract GameItemContract is ERC1155, AccessControl, Pausable, ReentrancyGuard {
    using Counters for Counters.Counter;


    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");


    uint256 public constant MAX_SUPPLY_PER_ITEM = 1000000;
    uint256 public constant MAX_MINT_PER_TX = 100;
    uint256 public constant PLATFORM_FEE_RATE = 250;
    uint256 public constant FEE_DENOMINATOR = 10000;


    Counters.Counter private _itemIdTracker;
    address private _feeRecipient;


    struct ItemInfo {
        string name;
        string description;
        uint256 rarity;
        uint256 maxSupply;
        uint256 currentSupply;
        uint256 mintPrice;
        bool mintable;
        address creator;
    }


    mapping(uint256 => ItemInfo) private _itemInfos;
    mapping(uint256 => string) private _itemURIs;
    mapping(address => mapping(uint256 => uint256)) private _creatorRoyalties;


    event ItemCreated(
        uint256 indexed itemId,
        string name,
        uint256 rarity,
        uint256 maxSupply,
        uint256 mintPrice,
        address indexed creator
    );

    event ItemMinted(
        uint256 indexed itemId,
        address indexed to,
        uint256 amount,
        uint256 totalPrice
    );

    event ItemTraded(
        uint256 indexed itemId,
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 price
    );


    modifier validItemId(uint256 itemId) {
        require(_exists(itemId), "GameItemContract: Item does not exist");
        _;
    }

    modifier onlyItemCreator(uint256 itemId) {
        require(
            _itemInfos[itemId].creator == msg.sender || hasRole(ADMIN_ROLE, msg.sender),
            "GameItemContract: Not item creator or admin"
        );
        _;
    }

    modifier mintableItem(uint256 itemId) {
        require(_itemInfos[itemId].mintable, "GameItemContract: Item not mintable");
        _;
    }

    modifier validAmount(uint256 amount) {
        require(amount > 0 && amount <= MAX_MINT_PER_TX, "GameItemContract: Invalid amount");
        _;
    }

    constructor(
        string memory baseURI,
        address feeRecipient
    ) ERC1155(baseURI) {
        require(feeRecipient != address(0), "GameItemContract: Invalid fee recipient");

        _feeRecipient = feeRecipient;


        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);


        _itemIdTracker.increment();
    }


    function createItem(
        string memory name,
        string memory description,
        string memory itemURI,
        uint256 rarity,
        uint256 maxSupply,
        uint256 mintPrice,
        uint256 royaltyRate
    ) external whenNotPaused returns (uint256) {
        require(bytes(name).length > 0, "GameItemContract: Empty name");
        require(rarity >= 1 && rarity <= 4, "GameItemContract: Invalid rarity");
        require(maxSupply > 0 && maxSupply <= MAX_SUPPLY_PER_ITEM, "GameItemContract: Invalid max supply");
        require(royaltyRate <= 1000, "GameItemContract: Royalty rate too high");

        uint256 itemId = _itemIdTracker.current();
        _itemIdTracker.increment();

        _itemInfos[itemId] = ItemInfo({
            name: name,
            description: description,
            rarity: rarity,
            maxSupply: maxSupply,
            currentSupply: 0,
            mintPrice: mintPrice,
            mintable: true,
            creator: msg.sender
        });

        _itemURIs[itemId] = itemURI;
        _creatorRoyalties[msg.sender][itemId] = royaltyRate;

        emit ItemCreated(itemId, name, rarity, maxSupply, mintPrice, msg.sender);

        return itemId;
    }


    function mintItem(
        uint256 itemId,
        uint256 amount
    ) external payable nonReentrant whenNotPaused validItemId(itemId) mintableItem(itemId) validAmount(amount) {
        ItemInfo storage item = _itemInfos[itemId];

        require(
            item.currentSupply + amount <= item.maxSupply,
            "GameItemContract: Exceeds max supply"
        );

        uint256 totalPrice = item.mintPrice * amount;
        require(msg.value >= totalPrice, "GameItemContract: Insufficient payment");


        item.currentSupply += amount;


        _mint(msg.sender, itemId, amount, "");


        _handlePayment(itemId, totalPrice);


        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }

        emit ItemMinted(itemId, msg.sender, amount, totalPrice);
    }


    function batchMintItem(
        address to,
        uint256 itemId,
        uint256 amount
    ) external onlyRole(MINTER_ROLE) whenNotPaused validItemId(itemId) validAmount(amount) {
        ItemInfo storage item = _itemInfos[itemId];

        require(
            item.currentSupply + amount <= item.maxSupply,
            "GameItemContract: Exceeds max supply"
        );

        item.currentSupply += amount;
        _mint(to, itemId, amount, "");

        emit ItemMinted(itemId, to, amount, 0);
    }


    function tradeItem(
        uint256 itemId,
        address to,
        uint256 amount,
        uint256 price
    ) external payable nonReentrant whenNotPaused validItemId(itemId) {
        require(to != address(0), "GameItemContract: Invalid recipient");
        require(amount > 0, "GameItemContract: Invalid amount");
        require(balanceOf(msg.sender, itemId) >= amount, "GameItemContract: Insufficient balance");
        require(msg.value >= price, "GameItemContract: Insufficient payment");


        safeTransferFrom(msg.sender, to, itemId, amount, "");


        if (price > 0) {
            _handleTradePayment(itemId, msg.sender, price);
        }


        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }

        emit ItemTraded(itemId, msg.sender, to, amount, price);
    }


    function setItemURI(
        uint256 itemId,
        string memory newURI
    ) external validItemId(itemId) onlyItemCreator(itemId) {
        _itemURIs[itemId] = newURI;
    }


    function toggleItemMintable(
        uint256 itemId
    ) external validItemId(itemId) onlyItemCreator(itemId) {
        _itemInfos[itemId].mintable = !_itemInfos[itemId].mintable;
    }


    function updateItemPrice(
        uint256 itemId,
        uint256 newPrice
    ) external validItemId(itemId) onlyItemCreator(itemId) {
        _itemInfos[itemId].mintPrice = newPrice;
    }


    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }


    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }


    function setFeeRecipient(address newFeeRecipient) external onlyRole(ADMIN_ROLE) {
        require(newFeeRecipient != address(0), "GameItemContract: Invalid address");
        _feeRecipient = newFeeRecipient;
    }


    function emergencyWithdraw() external onlyRole(ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        require(balance > 0, "GameItemContract: No funds to withdraw");
        payable(_feeRecipient).transfer(balance);
    }


    function getItemInfo(uint256 itemId) external view validItemId(itemId) returns (ItemInfo memory) {
        return _itemInfos[itemId];
    }

    function uri(uint256 itemId) public view override validItemId(itemId) returns (string memory) {
        return _itemURIs[itemId];
    }

    function getCurrentItemId() external view returns (uint256) {
        return _itemIdTracker.current();
    }

    function getCreatorRoyalty(address creator, uint256 itemId) external view returns (uint256) {
        return _creatorRoyalties[creator][itemId];
    }


    function _exists(uint256 itemId) internal view returns (bool) {
        return itemId > 0 && itemId < _itemIdTracker.current();
    }

    function _handlePayment(uint256 itemId, uint256 totalPrice) internal {
        if (totalPrice == 0) return;

        address creator = _itemInfos[itemId].creator;
        uint256 royaltyRate = _creatorRoyalties[creator][itemId];

        uint256 platformFee = (totalPrice * PLATFORM_FEE_RATE) / FEE_DENOMINATOR;
        uint256 royaltyAmount = (totalPrice * royaltyRate) / FEE_DENOMINATOR;
        uint256 creatorAmount = totalPrice - platformFee - royaltyAmount;


        if (platformFee > 0) {
            payable(_feeRecipient).transfer(platformFee);
        }


        if (creatorAmount > 0) {
            payable(creator).transfer(creatorAmount);
        }
    }

    function _handleTradePayment(uint256 itemId, address seller, uint256 price) internal {
        if (price == 0) return;

        address creator = _itemInfos[itemId].creator;
        uint256 royaltyRate = _creatorRoyalties[creator][itemId];

        uint256 platformFee = (price * PLATFORM_FEE_RATE) / FEE_DENOMINATOR;
        uint256 royaltyAmount = (price * royaltyRate) / FEE_DENOMINATOR;
        uint256 sellerAmount = price - platformFee - royaltyAmount;


        if (platformFee > 0) {
            payable(_feeRecipient).transfer(platformFee);
        }


        if (royaltyAmount > 0 && creator != seller) {
            payable(creator).transfer(royaltyAmount);
        } else if (creator == seller) {
            sellerAmount += royaltyAmount;
        }


        if (sellerAmount > 0) {
            payable(seller).transfer(sellerAmount);
        }
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

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
