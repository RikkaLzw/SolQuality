
pragma solidity ^0.8.0;

contract SupplyChainTracker {

    address public immutable owner;
    uint256 private _productCounter;
    uint256 private _participantCounter;


    struct Product {
        uint256 id;
        string name;
        address manufacturer;
        uint64 createdAt;
        uint64 lastUpdated;
        ProductStatus status;
        bool exists;
    }

    struct TrackingEvent {
        uint256 productId;
        address participant;
        string location;
        string description;
        uint64 timestamp;
        EventType eventType;
    }

    struct Participant {
        address participantAddress;
        string name;
        ParticipantRole role;
        bool isActive;
        uint64 registeredAt;
    }

    enum ProductStatus { Created, InTransit, Delivered, Completed }
    enum EventType { Manufactured, Shipped, Received, QualityCheck, Delivered }
    enum ParticipantRole { Manufacturer, Supplier, Distributor, Retailer, Consumer }


    mapping(uint256 => Product) private _products;
    mapping(address => Participant) private _participants;
    mapping(uint256 => TrackingEvent[]) private _productEvents;
    mapping(address => uint256[]) private _participantProducts;
    mapping(uint256 => mapping(address => bool)) private _productParticipants;


    event ProductCreated(uint256 indexed productId, address indexed manufacturer, string name);
    event ParticipantRegistered(address indexed participant, ParticipantRole role, string name);
    event TrackingEventAdded(uint256 indexed productId, address indexed participant, EventType eventType);
    event ProductStatusUpdated(uint256 indexed productId, ProductStatus status);


    error Unauthorized();
    error ProductNotFound();
    error ParticipantNotFound();
    error InvalidParticipant();
    error ProductAlreadyExists();
    error ParticipantAlreadyExists();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyRegisteredParticipant() {
        if (!_participants[msg.sender].isActive) revert InvalidParticipant();
        _;
    }

    modifier productExists(uint256 productId) {
        if (!_products[productId].exists) revert ProductNotFound();
        _;
    }

    modifier onlyProductParticipant(uint256 productId) {
        if (!_productParticipants[productId][msg.sender] && msg.sender != owner) {
            revert Unauthorized();
        }
        _;
    }

    constructor() {
        owner = msg.sender;
        _productCounter = 1;
        _participantCounter = 1;
    }

    function registerParticipant(
        address participantAddress,
        string calldata name,
        ParticipantRole role
    ) external onlyOwner {
        if (_participants[participantAddress].participantAddress != address(0)) {
            revert ParticipantAlreadyExists();
        }

        _participants[participantAddress] = Participant({
            participantAddress: participantAddress,
            name: name,
            role: role,
            isActive: true,
            registeredAt: uint64(block.timestamp)
        });

        emit ParticipantRegistered(participantAddress, role, name);
    }

    function createProduct(
        string calldata name,
        address manufacturer
    ) external onlyOwner returns (uint256) {
        if (!_participants[manufacturer].isActive) revert ParticipantNotFound();

        uint256 productId = _productCounter++;

        _products[productId] = Product({
            id: productId,
            name: name,
            manufacturer: manufacturer,
            createdAt: uint64(block.timestamp),
            lastUpdated: uint64(block.timestamp),
            status: ProductStatus.Created,
            exists: true
        });

        _productParticipants[productId][manufacturer] = true;
        _participantProducts[manufacturer].push(productId);

        emit ProductCreated(productId, manufacturer, name);
        return productId;
    }

    function addTrackingEvent(
        uint256 productId,
        string calldata location,
        string calldata description,
        EventType eventType
    ) external
      onlyRegisteredParticipant
      productExists(productId)
      onlyProductParticipant(productId)
    {
        TrackingEvent memory newEvent = TrackingEvent({
            productId: productId,
            participant: msg.sender,
            location: location,
            description: description,
            timestamp: uint64(block.timestamp),
            eventType: eventType
        });

        _productEvents[productId].push(newEvent);


        Product storage product = _products[productId];
        product.lastUpdated = uint64(block.timestamp);


        if (eventType == EventType.Shipped) {
            product.status = ProductStatus.InTransit;
        } else if (eventType == EventType.Delivered) {
            product.status = ProductStatus.Delivered;
        }

        emit TrackingEventAdded(productId, msg.sender, eventType);
        emit ProductStatusUpdated(productId, product.status);
    }

    function addParticipantToProduct(
        uint256 productId,
        address participant
    ) external
      onlyOwner
      productExists(productId)
    {
        if (!_participants[participant].isActive) revert ParticipantNotFound();

        if (!_productParticipants[productId][participant]) {
            _productParticipants[productId][participant] = true;
            _participantProducts[participant].push(productId);
        }
    }

    function updateProductStatus(
        uint256 productId,
        ProductStatus status
    ) external
      onlyOwner
      productExists(productId)
    {
        Product storage product = _products[productId];
        product.status = status;
        product.lastUpdated = uint64(block.timestamp);

        emit ProductStatusUpdated(productId, status);
    }


    function getProduct(uint256 productId)
        external
        view
        productExists(productId)
        returns (Product memory)
    {
        return _products[productId];
    }

    function getProductEvents(uint256 productId)
        external
        view
        productExists(productId)
        returns (TrackingEvent[] memory)
    {
        return _productEvents[productId];
    }

    function getParticipant(address participantAddress)
        external
        view
        returns (Participant memory)
    {
        if (_participants[participantAddress].participantAddress == address(0)) {
            revert ParticipantNotFound();
        }
        return _participants[participantAddress];
    }

    function getParticipantProducts(address participant)
        external
        view
        returns (uint256[] memory)
    {
        return _participantProducts[participant];
    }

    function isProductParticipant(uint256 productId, address participant)
        external
        view
        returns (bool)
    {
        return _productParticipants[productId][participant];
    }

    function getProductCount() external view returns (uint256) {
        return _productCounter - 1;
    }

    function getLatestProductEvents(uint256 productId, uint256 limit)
        external
        view
        productExists(productId)
        returns (TrackingEvent[] memory)
    {
        TrackingEvent[] storage events = _productEvents[productId];
        uint256 eventsLength = events.length;

        if (eventsLength == 0) {
            return new TrackingEvent[](0);
        }

        uint256 resultLength = limit > eventsLength ? eventsLength : limit;
        TrackingEvent[] memory result = new TrackingEvent[](resultLength);


        uint256 startIndex = eventsLength > limit ? eventsLength - limit : 0;
        for (uint256 i = 0; i < resultLength; i++) {
            result[i] = events[startIndex + i];
        }

        return result;
    }

    function deactivateParticipant(address participant)
        external
        onlyOwner
    {
        if (_participants[participant].participantAddress == address(0)) {
            revert ParticipantNotFound();
        }
        _participants[participant].isActive = false;
    }
}
