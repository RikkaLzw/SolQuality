
pragma solidity ^0.8.0;

contract SupplyChainTracker {
    address public owner;
    uint256 private nextProductId;
    uint256 private nextBatchId;

    enum ProductStatus { Created, InTransit, Delivered, Verified }
    enum UserRole { None, Manufacturer, Distributor, Retailer, Consumer }

    struct Product {
        uint256 id;
        string name;
        string description;
        address manufacturer;
        uint256 timestamp;
        ProductStatus status;
        bool exists;
    }

    struct Batch {
        uint256 id;
        uint256 productId;
        uint256 quantity;
        address currentOwner;
        uint256 createdAt;
        ProductStatus status;
        bool exists;
    }

    struct TransferRecord {
        address from;
        address to;
        uint256 timestamp;
        string location;
    }

    mapping(address => UserRole) public userRoles;
    mapping(uint256 => Product) public products;
    mapping(uint256 => Batch) public batches;
    mapping(uint256 => TransferRecord[]) public batchHistory;
    mapping(address => uint256[]) public userBatches;

    event ProductCreated(uint256 indexed productId, string name, address manufacturer);
    event BatchCreated(uint256 indexed batchId, uint256 indexed productId, uint256 quantity);
    event BatchTransferred(uint256 indexed batchId, address from, address to, string location);
    event StatusUpdated(uint256 indexed batchId, ProductStatus status);
    event RoleAssigned(address indexed user, UserRole role);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    modifier onlyAuthorized(UserRole requiredRole) {
        require(userRoles[msg.sender] >= requiredRole, "Insufficient permissions");
        _;
    }

    modifier batchExists(uint256 batchId) {
        require(batches[batchId].exists, "Batch does not exist");
        _;
    }

    modifier productExists(uint256 productId) {
        require(products[productId].exists, "Product does not exist");
        _;
    }

    constructor() {
        owner = msg.sender;
        nextProductId = 1;
        nextBatchId = 1;
        userRoles[msg.sender] = UserRole.Manufacturer;
    }

    function assignRole(address user, UserRole role) external onlyOwner {
        require(user != address(0), "Invalid address");
        userRoles[user] = role;
        emit RoleAssigned(user, role);
    }

    function createProduct(string memory name, string memory description)
        external
        onlyAuthorized(UserRole.Manufacturer)
        returns (uint256)
    {
        require(bytes(name).length > 0, "Product name required");

        uint256 productId = nextProductId++;
        products[productId] = Product({
            id: productId,
            name: name,
            description: description,
            manufacturer: msg.sender,
            timestamp: block.timestamp,
            status: ProductStatus.Created,
            exists: true
        });

        emit ProductCreated(productId, name, msg.sender);
        return productId;
    }

    function createBatch(uint256 productId, uint256 quantity)
        external
        onlyAuthorized(UserRole.Manufacturer)
        productExists(productId)
        returns (uint256)
    {
        require(quantity > 0, "Quantity must be greater than zero");
        require(products[productId].manufacturer == msg.sender, "Only product manufacturer can create batch");

        uint256 batchId = nextBatchId++;
        batches[batchId] = Batch({
            id: batchId,
            productId: productId,
            quantity: quantity,
            currentOwner: msg.sender,
            createdAt: block.timestamp,
            status: ProductStatus.Created,
            exists: true
        });

        userBatches[msg.sender].push(batchId);
        batchHistory[batchId].push(TransferRecord({
            from: address(0),
            to: msg.sender,
            timestamp: block.timestamp,
            location: "Manufacturing Facility"
        }));

        emit BatchCreated(batchId, productId, quantity);
        return batchId;
    }

    function transferBatch(uint256 batchId, address to, string memory location)
        external
        batchExists(batchId)
    {
        require(to != address(0), "Invalid recipient address");
        require(batches[batchId].currentOwner == msg.sender, "Only current owner can transfer");
        require(userRoles[to] != UserRole.None, "Recipient must have assigned role");

        _updateBatchOwner(batchId, to);
        _recordTransfer(batchId, msg.sender, to, location);

        emit BatchTransferred(batchId, msg.sender, to, location);
    }

    function updateBatchStatus(uint256 batchId, ProductStatus status)
        external
        batchExists(batchId)
        onlyAuthorized(UserRole.Distributor)
    {
        require(batches[batchId].currentOwner == msg.sender, "Only current owner can update status");
        batches[batchId].status = status;
        emit StatusUpdated(batchId, status);
    }

    function getBatchHistory(uint256 batchId)
        external
        view
        batchExists(batchId)
        returns (TransferRecord[] memory)
    {
        return batchHistory[batchId];
    }

    function getUserBatches(address user)
        external
        view
        returns (uint256[] memory)
    {
        return userBatches[user];
    }

    function getProductDetails(uint256 productId)
        external
        view
        productExists(productId)
        returns (Product memory)
    {
        return products[productId];
    }

    function getBatchDetails(uint256 batchId)
        external
        view
        batchExists(batchId)
        returns (Batch memory)
    {
        return batches[batchId];
    }

    function _updateBatchOwner(uint256 batchId, address newOwner) internal {
        address currentOwner = batches[batchId].currentOwner;
        batches[batchId].currentOwner = newOwner;
        userBatches[newOwner].push(batchId);
        _removeBatchFromUser(currentOwner, batchId);
    }

    function _recordTransfer(uint256 batchId, address from, address to, string memory location) internal {
        batchHistory[batchId].push(TransferRecord({
            from: from,
            to: to,
            timestamp: block.timestamp,
            location: location
        }));
    }

    function _removeBatchFromUser(address user, uint256 batchId) internal {
        uint256[] storage userBatchList = userBatches[user];
        for (uint256 i = 0; i < userBatchList.length; i++) {
            if (userBatchList[i] == batchId) {
                userBatchList[i] = userBatchList[userBatchList.length - 1];
                userBatchList.pop();
                break;
            }
        }
    }
}
