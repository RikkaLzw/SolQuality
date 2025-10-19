
pragma solidity ^0.8.0;

contract SupplyChainTracker {

    event ProductCreated(uint256 indexed productId, address indexed manufacturer, string productName);
    event ProductTransferred(uint256 indexed productId, address indexed from, address indexed to, uint256 timestamp);
    event ProductStatusUpdated(uint256 indexed productId, ProductStatus status);
    event QualityCheckAdded(uint256 indexed productId, address indexed inspector, bool passed);


    enum ProductStatus { Created, InTransit, Delivered, Recalled }
    enum UserRole { None, Manufacturer, Distributor, Retailer, Inspector }


    struct Product {
        uint256 id;
        string name;
        address manufacturer;
        address currentOwner;
        ProductStatus status;
        uint256 createdAt;
        uint256 lastUpdated;
        uint32 transferCount;
    }

    struct TransferRecord {
        address from;
        address to;
        uint256 timestamp;
        string location;
    }

    struct QualityCheck {
        address inspector;
        bool passed;
        string notes;
        uint256 timestamp;
    }


    uint256 private _productIdCounter;


    mapping(uint256 => Product) public products;


    mapping(uint256 => mapping(uint256 => TransferRecord)) public transferHistory;
    mapping(uint256 => uint256) public transferCounts;


    mapping(uint256 => mapping(uint256 => QualityCheck)) public qualityChecks;
    mapping(uint256 => uint256) public qualityCheckCounts;


    mapping(address => UserRole) public userRoles;


    mapping(address => uint256[]) private ownerProducts;
    mapping(uint256 => uint256) private productIndexInOwnerArray;


    address public admin;
    mapping(address => bool) public authorizedInspectors;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier onlyManufacturer() {
        require(userRoles[msg.sender] == UserRole.Manufacturer, "Only manufacturer");
        _;
    }

    modifier onlyAuthorizedUser() {
        require(userRoles[msg.sender] != UserRole.None, "Not authorized");
        _;
    }

    modifier onlyProductOwner(uint256 productId) {
        require(products[productId].currentOwner == msg.sender, "Not product owner");
        _;
    }

    modifier onlyInspector() {
        require(authorizedInspectors[msg.sender], "Not authorized inspector");
        _;
    }

    modifier productExists(uint256 productId) {
        require(products[productId].id != 0, "Product does not exist");
        _;
    }

    constructor() {
        admin = msg.sender;
        userRoles[msg.sender] = UserRole.Manufacturer;
    }


    function setUserRole(address user, UserRole role) external onlyAdmin {
        userRoles[user] = role;
    }

    function authorizeInspector(address inspector, bool authorized) external onlyAdmin {
        authorizedInspectors[inspector] = authorized;
    }


    function createProduct(string calldata productName) external onlyManufacturer returns (uint256) {
        uint256 productId = ++_productIdCounter;
        uint256 currentTime = block.timestamp;


        Product storage newProduct = products[productId];
        newProduct.id = productId;
        newProduct.name = productName;
        newProduct.manufacturer = msg.sender;
        newProduct.currentOwner = msg.sender;
        newProduct.status = ProductStatus.Created;
        newProduct.createdAt = currentTime;
        newProduct.lastUpdated = currentTime;
        newProduct.transferCount = 0;


        ownerProducts[msg.sender].push(productId);
        productIndexInOwnerArray[productId] = ownerProducts[msg.sender].length - 1;

        emit ProductCreated(productId, msg.sender, productName);
        return productId;
    }

    function transferProduct(uint256 productId, address to, string calldata location)
        external
        onlyProductOwner(productId)
        productExists(productId)
    {
        require(to != address(0), "Invalid recipient");
        require(userRoles[to] != UserRole.None, "Recipient not authorized");
        require(to != msg.sender, "Cannot transfer to self");

        Product storage product = products[productId];
        require(product.status != ProductStatus.Recalled, "Product is recalled");

        address from = msg.sender;
        uint256 currentTime = block.timestamp;


        product.currentOwner = to;
        product.lastUpdated = currentTime;
        product.transferCount++;


        if (userRoles[to] == UserRole.Distributor || userRoles[to] == UserRole.Retailer) {
            product.status = ProductStatus.InTransit;
        }


        uint256 transferIndex = transferCounts[productId];
        transferHistory[productId][transferIndex] = TransferRecord({
            from: from,
            to: to,
            timestamp: currentTime,
            location: location
        });
        transferCounts[productId]++;


        _removeFromOwnerArray(from, productId);
        ownerProducts[to].push(productId);
        productIndexInOwnerArray[productId] = ownerProducts[to].length - 1;

        emit ProductTransferred(productId, from, to, currentTime);
    }

    function updateProductStatus(uint256 productId, ProductStatus newStatus)
        external
        onlyProductOwner(productId)
        productExists(productId)
    {
        Product storage product = products[productId];
        require(product.status != newStatus, "Status unchanged");

        product.status = newStatus;
        product.lastUpdated = block.timestamp;

        emit ProductStatusUpdated(productId, newStatus);
    }

    function addQualityCheck(uint256 productId, bool passed, string calldata notes)
        external
        onlyInspector
        productExists(productId)
    {
        uint256 checkIndex = qualityCheckCounts[productId];
        qualityChecks[productId][checkIndex] = QualityCheck({
            inspector: msg.sender,
            passed: passed,
            notes: notes,
            timestamp: block.timestamp
        });
        qualityCheckCounts[productId]++;


        products[productId].lastUpdated = block.timestamp;

        emit QualityCheckAdded(productId, msg.sender, passed);
    }

    function recallProduct(uint256 productId) external productExists(productId) {
        Product storage product = products[productId];
        require(
            msg.sender == product.manufacturer || msg.sender == admin,
            "Only manufacturer or admin can recall"
        );

        product.status = ProductStatus.Recalled;
        product.lastUpdated = block.timestamp;

        emit ProductStatusUpdated(productId, ProductStatus.Recalled);
    }


    function getProduct(uint256 productId) external view productExists(productId) returns (
        uint256 id,
        string memory name,
        address manufacturer,
        address currentOwner,
        ProductStatus status,
        uint256 createdAt,
        uint256 lastUpdated,
        uint32 transferCount
    ) {
        Product memory product = products[productId];
        return (
            product.id,
            product.name,
            product.manufacturer,
            product.currentOwner,
            product.status,
            product.createdAt,
            product.lastUpdated,
            product.transferCount
        );
    }

    function getTransferHistory(uint256 productId) external view productExists(productId) returns (
        address[] memory froms,
        address[] memory tos,
        uint256[] memory timestamps,
        string[] memory locations
    ) {
        uint256 count = transferCounts[productId];
        froms = new address[](count);
        tos = new address[](count);
        timestamps = new uint256[](count);
        locations = new string[](count);

        for (uint256 i = 0; i < count; i++) {
            TransferRecord memory record = transferHistory[productId][i];
            froms[i] = record.from;
            tos[i] = record.to;
            timestamps[i] = record.timestamp;
            locations[i] = record.location;
        }
    }

    function getQualityChecks(uint256 productId) external view productExists(productId) returns (
        address[] memory inspectors,
        bool[] memory results,
        string[] memory notes,
        uint256[] memory timestamps
    ) {
        uint256 count = qualityCheckCounts[productId];
        inspectors = new address[](count);
        results = new bool[](count);
        notes = new string[](count);
        timestamps = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            QualityCheck memory check = qualityChecks[productId][i];
            inspectors[i] = check.inspector;
            results[i] = check.passed;
            notes[i] = check.notes;
            timestamps[i] = check.timestamp;
        }
    }

    function getOwnerProducts(address owner) external view returns (uint256[] memory) {
        return ownerProducts[owner];
    }

    function getProductCount() external view returns (uint256) {
        return _productIdCounter;
    }

    function isProductRecalled(uint256 productId) external view productExists(productId) returns (bool) {
        return products[productId].status == ProductStatus.Recalled;
    }


    function _removeFromOwnerArray(address owner, uint256 productId) private {
        uint256[] storage ownerProductArray = ownerProducts[owner];
        uint256 productIndex = productIndexInOwnerArray[productId];
        uint256 lastIndex = ownerProductArray.length - 1;

        if (productIndex != lastIndex) {
            uint256 lastProductId = ownerProductArray[lastIndex];
            ownerProductArray[productIndex] = lastProductId;
            productIndexInOwnerArray[lastProductId] = productIndex;
        }

        ownerProductArray.pop();
        delete productIndexInOwnerArray[productId];
    }
}
