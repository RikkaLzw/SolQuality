
pragma solidity ^0.8.0;

contract SupplyChainTracker {
    address public owner;
    uint32 private productCounter;

    struct Product {
        bytes32 productId;
        bytes32 name;
        bytes32 origin;
        address manufacturer;
        uint64 timestamp;
        bool isActive;
    }

    struct TrackingRecord {
        bytes32 productId;
        bytes32 location;
        bytes32 status;
        address handler;
        uint64 timestamp;
        bool isVerified;
    }

    mapping(bytes32 => Product) public products;
    mapping(bytes32 => TrackingRecord[]) public trackingHistory;
    mapping(address => bool) public authorizedHandlers;
    mapping(bytes32 => bool) public productExists;

    event ProductCreated(bytes32 indexed productId, bytes32 name, address manufacturer);
    event ProductTracked(bytes32 indexed productId, bytes32 location, bytes32 status, address handler);
    event HandlerAuthorized(address indexed handler);
    event HandlerRevoked(address indexed handler);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    modifier onlyAuthorized() {
        require(authorizedHandlers[msg.sender] || msg.sender == owner, "Not authorized");
        _;
    }

    modifier productMustExist(bytes32 _productId) {
        require(productExists[_productId], "Product does not exist");
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedHandlers[msg.sender] = true;
    }

    function createProduct(
        bytes32 _name,
        bytes32 _origin
    ) external onlyAuthorized returns (bytes32) {
        productCounter++;
        bytes32 productId = keccak256(abi.encodePacked(msg.sender, block.timestamp, productCounter));

        products[productId] = Product({
            productId: productId,
            name: _name,
            origin: _origin,
            manufacturer: msg.sender,
            timestamp: uint64(block.timestamp),
            isActive: true
        });

        productExists[productId] = true;

        emit ProductCreated(productId, _name, msg.sender);
        return productId;
    }

    function trackProduct(
        bytes32 _productId,
        bytes32 _location,
        bytes32 _status
    ) external onlyAuthorized productMustExist(_productId) {
        require(products[_productId].isActive, "Product is not active");

        TrackingRecord memory newRecord = TrackingRecord({
            productId: _productId,
            location: _location,
            status: _status,
            handler: msg.sender,
            timestamp: uint64(block.timestamp),
            isVerified: true
        });

        trackingHistory[_productId].push(newRecord);

        emit ProductTracked(_productId, _location, _status, msg.sender);
    }

    function getProduct(bytes32 _productId) external view productMustExist(_productId) returns (
        bytes32 name,
        bytes32 origin,
        address manufacturer,
        uint64 timestamp,
        bool isActive
    ) {
        Product memory product = products[_productId];
        return (
            product.name,
            product.origin,
            product.manufacturer,
            product.timestamp,
            product.isActive
        );
    }

    function getTrackingHistory(bytes32 _productId) external view productMustExist(_productId) returns (
        TrackingRecord[] memory
    ) {
        return trackingHistory[_productId];
    }

    function getTrackingCount(bytes32 _productId) external view productMustExist(_productId) returns (uint256) {
        return trackingHistory[_productId].length;
    }

    function authorizeHandler(address _handler) external onlyOwner {
        require(_handler != address(0), "Invalid handler address");
        authorizedHandlers[_handler] = true;
        emit HandlerAuthorized(_handler);
    }

    function revokeHandler(address _handler) external onlyOwner {
        require(_handler != owner, "Cannot revoke owner");
        authorizedHandlers[_handler] = false;
        emit HandlerRevoked(_handler);
    }

    function deactivateProduct(bytes32 _productId) external onlyOwner productMustExist(_productId) {
        products[_productId].isActive = false;
    }

    function isHandlerAuthorized(address _handler) external view returns (bool) {
        return authorizedHandlers[_handler];
    }

    function getTotalProducts() external view returns (uint32) {
        return productCounter;
    }
}
