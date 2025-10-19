
pragma solidity ^0.8.0;

contract SupplyChainTracker {
    address public owner;
    uint32 private nextProductId;

    struct Product {
        bytes32 productHash;
        bytes32 batchId;
        address manufacturer;
        uint64 manufactureTimestamp;
        uint64 expiryTimestamp;
        bytes32 origin;
        bool isActive;
    }

    struct TrackingEvent {
        bytes32 eventHash;
        address actor;
        bytes32 location;
        uint64 timestamp;
        uint8 eventType;
        bytes32 description;
    }

    mapping(uint32 => Product) public products;
    mapping(uint32 => TrackingEvent[]) public productHistory;
    mapping(address => bool) public authorizedActors;
    mapping(bytes32 => uint32) public batchToProductId;

    event ProductRegistered(uint32 indexed productId, bytes32 indexed batchId, address indexed manufacturer);
    event TrackingEventAdded(uint32 indexed productId, address indexed actor, uint8 eventType);
    event ActorAuthorized(address indexed actor);
    event ActorRevoked(address indexed actor);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    modifier onlyAuthorized() {
        require(authorizedActors[msg.sender] || msg.sender == owner, "Not authorized");
        _;
    }

    modifier productExists(uint32 _productId) {
        require(_productId < nextProductId && products[_productId].isActive, "Product does not exist");
        _;
    }

    constructor() {
        owner = msg.sender;
        nextProductId = 1;
        authorizedActors[msg.sender] = true;
    }

    function authorizeActor(address _actor) external onlyOwner {
        require(_actor != address(0), "Invalid actor address");
        authorizedActors[_actor] = true;
        emit ActorAuthorized(_actor);
    }

    function revokeActor(address _actor) external onlyOwner {
        require(_actor != owner, "Cannot revoke owner");
        authorizedActors[_actor] = false;
        emit ActorRevoked(_actor);
    }

    function registerProduct(
        bytes32 _productHash,
        bytes32 _batchId,
        uint64 _expiryTimestamp,
        bytes32 _origin
    ) external onlyAuthorized returns (uint32) {
        require(_productHash != bytes32(0), "Invalid product hash");
        require(_batchId != bytes32(0), "Invalid batch ID");
        require(_expiryTimestamp > block.timestamp, "Expiry must be in future");
        require(batchToProductId[_batchId] == 0, "Batch ID already exists");

        uint32 productId = nextProductId++;

        products[productId] = Product({
            productHash: _productHash,
            batchId: _batchId,
            manufacturer: msg.sender,
            manufactureTimestamp: uint64(block.timestamp),
            expiryTimestamp: _expiryTimestamp,
            origin: _origin,
            isActive: true
        });

        batchToProductId[_batchId] = productId;


        _addTrackingEvent(
            productId,
            keccak256(abi.encodePacked("MANUFACTURED", block.timestamp)),
            _origin,
            0,
            "Product manufactured"
        );

        emit ProductRegistered(productId, _batchId, msg.sender);
        return productId;
    }

    function addTrackingEvent(
        uint32 _productId,
        bytes32 _location,
        uint8 _eventType,
        bytes32 _description
    ) external onlyAuthorized productExists(_productId) {
        require(_eventType <= 3, "Invalid event type");
        require(_location != bytes32(0), "Invalid location");

        bytes32 eventHash = keccak256(abi.encodePacked(
            _productId,
            msg.sender,
            _location,
            block.timestamp,
            _eventType,
            _description
        ));

        _addTrackingEvent(_productId, eventHash, _location, _eventType, _description);
        emit TrackingEventAdded(_productId, msg.sender, _eventType);
    }

    function _addTrackingEvent(
        uint32 _productId,
        bytes32 _eventHash,
        bytes32 _location,
        uint8 _eventType,
        bytes32 _description
    ) private {
        productHistory[_productId].push(TrackingEvent({
            eventHash: _eventHash,
            actor: msg.sender,
            location: _location,
            timestamp: uint64(block.timestamp),
            eventType: _eventType,
            description: _description
        }));
    }

    function getProduct(uint32 _productId) external view productExists(_productId)
        returns (
            bytes32 productHash,
            bytes32 batchId,
            address manufacturer,
            uint64 manufactureTimestamp,
            uint64 expiryTimestamp,
            bytes32 origin,
            bool isActive
        ) {
        Product storage product = products[_productId];
        return (
            product.productHash,
            product.batchId,
            product.manufacturer,
            product.manufactureTimestamp,
            product.expiryTimestamp,
            product.origin,
            product.isActive
        );
    }

    function getProductHistory(uint32 _productId) external view productExists(_productId)
        returns (TrackingEvent[] memory) {
        return productHistory[_productId];
    }

    function getProductHistoryLength(uint32 _productId) external view productExists(_productId)
        returns (uint256) {
        return productHistory[_productId].length;
    }

    function getTrackingEvent(uint32 _productId, uint256 _eventIndex) external view productExists(_productId)
        returns (
            bytes32 eventHash,
            address actor,
            bytes32 location,
            uint64 timestamp,
            uint8 eventType,
            bytes32 description
        ) {
        require(_eventIndex < productHistory[_productId].length, "Event index out of bounds");
        TrackingEvent storage trackingEvent = productHistory[_productId][_eventIndex];
        return (
            trackingEvent.eventHash,
            trackingEvent.actor,
            trackingEvent.location,
            trackingEvent.timestamp,
            trackingEvent.eventType,
            trackingEvent.description
        );
    }

    function getProductByBatch(bytes32 _batchId) external view returns (uint32) {
        uint32 productId = batchToProductId[_batchId];
        require(productId != 0, "Batch ID not found");
        return productId;
    }

    function isProductExpired(uint32 _productId) external view productExists(_productId) returns (bool) {
        return block.timestamp > products[_productId].expiryTimestamp;
    }

    function deactivateProduct(uint32 _productId) external onlyAuthorized productExists(_productId) {
        products[_productId].isActive = false;

        _addTrackingEvent(
            _productId,
            keccak256(abi.encodePacked("DEACTIVATED", block.timestamp)),
            "SYSTEM",
            3,
            "Product deactivated"
        );
    }

    function getTotalProducts() external view returns (uint32) {
        return nextProductId - 1;
    }

    function verifyProductIntegrity(uint32 _productId, bytes32 _expectedHash) external view productExists(_productId) returns (bool) {
        return products[_productId].productHash == _expectedHash;
    }
}
