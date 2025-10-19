
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

library SupplyChainUtils {
    function validateProductId(bytes32 productId) internal pure {
        require(productId != bytes32(0), "Invalid product ID");
    }

    function validateAddress(address addr) internal pure {
        require(addr != address(0), "Invalid address");
    }

    function validateTimestamp(uint256 timestamp) internal view {
        require(timestamp <= block.timestamp, "Future timestamp not allowed");
    }
}

abstract contract SupplyChainBase is AccessControl, ReentrancyGuard, Pausable {
    using SupplyChainUtils for bytes32;
    using SupplyChainUtils for address;
    using SupplyChainUtils for uint256;


    bytes32 public constant MANUFACTURER_ROLE = keccak256("MANUFACTURER_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    bytes32 public constant RETAILER_ROLE = keccak256("RETAILER_ROLE");
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");


    uint256 public constant MAX_BATCH_SIZE = 1000;
    uint256 public constant MIN_PRODUCT_LIFETIME = 1 days;
    uint256 public constant MAX_PRODUCT_LIFETIME = 365 days;

    enum ProductStatus {
        Created,
        InTransit,
        Delivered,
        Sold,
        Recalled
    }

    struct Product {
        bytes32 id;
        string name;
        address manufacturer;
        uint256 manufactureDate;
        uint256 expiryDate;
        ProductStatus status;
        bytes32 batchId;
        string metadataHash;
        bool exists;
    }

    struct TransferRecord {
        address from;
        address to;
        uint256 timestamp;
        string location;
        string notes;
    }

    mapping(bytes32 => Product) internal products;
    mapping(bytes32 => TransferRecord[]) internal transferHistory;
    mapping(address => uint256) internal participantProductCount;

    event ProductCreated(
        bytes32 indexed productId,
        string name,
        address indexed manufacturer,
        bytes32 indexed batchId
    );

    event ProductTransferred(
        bytes32 indexed productId,
        address indexed from,
        address indexed to,
        string location
    );

    event ProductStatusChanged(
        bytes32 indexed productId,
        ProductStatus oldStatus,
        ProductStatus newStatus
    );

    modifier validProductId(bytes32 productId) {
        productId.validateProductId();
        _;
    }

    modifier productExists(bytes32 productId) {
        require(products[productId].exists, "Product does not exist");
        _;
    }

    modifier onlyProductOwner(bytes32 productId) {
        require(_isProductOwner(productId, msg.sender), "Not product owner");
        _;
    }

    modifier validTransferParticipants(address from, address to) {
        from.validateAddress();
        to.validateAddress();
        require(from != to, "Cannot transfer to same address");
        _;
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(AUDITOR_ROLE, msg.sender);
    }

    function _isProductOwner(bytes32 productId, address account) internal view virtual returns (bool);

    function _updateProductStatus(bytes32 productId, ProductStatus newStatus) internal {
        ProductStatus oldStatus = products[productId].status;
        products[productId].status = newStatus;
        emit ProductStatusChanged(productId, oldStatus, newStatus);
    }

    function _addTransferRecord(
        bytes32 productId,
        address from,
        address to,
        string memory location,
        string memory notes
    ) internal {
        transferHistory[productId].push(TransferRecord({
            from: from,
            to: to,
            timestamp: block.timestamp,
            location: location,
            notes: notes
        }));
    }
}

contract SupplyChainTracker is SupplyChainBase {
    mapping(bytes32 => address) private productOwners;
    mapping(bytes32 => bool) private batchExists;

    function createProduct(
        bytes32 productId,
        string memory name,
        uint256 expiryDate,
        bytes32 batchId,
        string memory metadataHash
    )
        external
        onlyRole(MANUFACTURER_ROLE)
        whenNotPaused
        nonReentrant
        validProductId(productId)
    {
        require(!products[productId].exists, "Product already exists");
        require(bytes(name).length > 0, "Product name cannot be empty");
        require(expiryDate > block.timestamp + MIN_PRODUCT_LIFETIME, "Invalid expiry date");
        require(expiryDate <= block.timestamp + MAX_PRODUCT_LIFETIME, "Expiry date too far");
        batchId.validateProductId();

        products[productId] = Product({
            id: productId,
            name: name,
            manufacturer: msg.sender,
            manufactureDate: block.timestamp,
            expiryDate: expiryDate,
            status: ProductStatus.Created,
            batchId: batchId,
            metadataHash: metadataHash,
            exists: true
        });

        productOwners[productId] = msg.sender;
        batchExists[batchId] = true;
        participantProductCount[msg.sender]++;

        _addTransferRecord(productId, address(0), msg.sender, "Manufacturing facility", "Product created");

        emit ProductCreated(productId, name, msg.sender, batchId);
    }

    function transferProduct(
        bytes32 productId,
        address to,
        string memory location,
        string memory notes
    )
        external
        whenNotPaused
        nonReentrant
        productExists(productId)
        onlyProductOwner(productId)
        validTransferParticipants(msg.sender, to)
    {
        require(
            hasRole(DISTRIBUTOR_ROLE, to) || hasRole(RETAILER_ROLE, to),
            "Invalid recipient role"
        );
        require(products[productId].status != ProductStatus.Recalled, "Cannot transfer recalled product");
        require(block.timestamp < products[productId].expiryDate, "Product expired");

        productOwners[productId] = to;
        participantProductCount[msg.sender]--;
        participantProductCount[to]++;

        _updateProductStatus(productId, ProductStatus.InTransit);
        _addTransferRecord(productId, msg.sender, to, location, notes);

        emit ProductTransferred(productId, msg.sender, to, location);
    }

    function confirmDelivery(bytes32 productId)
        external
        whenNotPaused
        productExists(productId)
        onlyProductOwner(productId)
    {
        require(products[productId].status == ProductStatus.InTransit, "Product not in transit");

        _updateProductStatus(productId, ProductStatus.Delivered);
    }

    function markAsSold(bytes32 productId, address customer)
        external
        whenNotPaused
        productExists(productId)
        onlyProductOwner(productId)
    {
        require(hasRole(RETAILER_ROLE, msg.sender), "Only retailers can mark as sold");
        require(products[productId].status == ProductStatus.Delivered, "Product not delivered");
        customer.validateAddress();

        _updateProductStatus(productId, ProductStatus.Sold);
        _addTransferRecord(productId, msg.sender, customer, "Point of sale", "Sold to consumer");
    }

    function recallProduct(bytes32 productId, string memory reason)
        external
        onlyRole(AUDITOR_ROLE)
        whenNotPaused
        productExists(productId)
    {
        require(bytes(reason).length > 0, "Recall reason required");

        _updateProductStatus(productId, ProductStatus.Recalled);
        _addTransferRecord(productId, productOwners[productId], msg.sender, "Recall center", reason);
    }

    function batchRecallByBatch(bytes32 batchId, string memory reason)
        external
        onlyRole(AUDITOR_ROLE)
        whenNotPaused
    {
        require(batchExists[batchId], "Batch does not exist");
        require(bytes(reason).length > 0, "Recall reason required");



        emit ProductStatusChanged(batchId, ProductStatus.Created, ProductStatus.Recalled);
    }

    function getProduct(bytes32 productId)
        external
        view
        productExists(productId)
        returns (Product memory)
    {
        return products[productId];
    }

    function getProductOwner(bytes32 productId)
        external
        view
        productExists(productId)
        returns (address)
    {
        return productOwners[productId];
    }

    function getTransferHistory(bytes32 productId)
        external
        view
        productExists(productId)
        returns (TransferRecord[] memory)
    {
        return transferHistory[productId];
    }

    function getParticipantProductCount(address participant)
        external
        view
        returns (uint256)
    {
        return participantProductCount[participant];
    }

    function isProductExpired(bytes32 productId)
        external
        view
        productExists(productId)
        returns (bool)
    {
        return block.timestamp >= products[productId].expiryDate;
    }

    function _isProductOwner(bytes32 productId, address account)
        internal
        view
        override
        returns (bool)
    {
        return productOwners[productId] == account;
    }


    function grantManufacturerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(MANUFACTURER_ROLE, account);
    }

    function grantDistributorRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(DISTRIBUTOR_ROLE, account);
    }

    function grantRetailerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(RETAILER_ROLE, account);
    }

    function grantAuditorRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(AUDITOR_ROLE, account);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
