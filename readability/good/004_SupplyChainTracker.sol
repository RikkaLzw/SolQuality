
pragma solidity ^0.8.0;


contract SupplyChainTracker {


    enum ProductStatus {
        Created,
        InTransit,
        Delivered,
        Received,
        Completed
    }


    enum ParticipantRole {
        Manufacturer,
        Supplier,
        Distributor,
        Retailer,
        Consumer
    }


    struct Participant {
        address participantAddress;
        string participantName;
        ParticipantRole role;
        bool isActive;
        uint256 registrationTime;
    }


    struct Product {
        uint256 productId;
        string productName;
        string productDescription;
        address manufacturer;
        uint256 manufacturingDate;
        ProductStatus currentStatus;
        bool exists;
    }


    struct TrackingRecord {
        uint256 recordId;
        uint256 productId;
        address participant;
        ProductStatus previousStatus;
        ProductStatus newStatus;
        string location;
        uint256 timestamp;
        string remarks;
    }


    address public contractOwner;


    mapping(address => Participant) public participants;


    mapping(uint256 => Product) public products;


    mapping(uint256 => TrackingRecord[]) public productTrackingHistory;


    address[] public participantAddresses;


    uint256[] public productIds;


    uint256 public nextProductId;


    uint256 public nextRecordId;


    event ParticipantRegistered(
        address indexed participantAddress,
        string participantName,
        ParticipantRole role,
        uint256 timestamp
    );

    event ProductCreated(
        uint256 indexed productId,
        string productName,
        address indexed manufacturer,
        uint256 timestamp
    );

    event ProductStatusUpdated(
        uint256 indexed productId,
        address indexed updatedBy,
        ProductStatus previousStatus,
        ProductStatus newStatus,
        string location,
        uint256 timestamp
    );

    event TrackingRecordAdded(
        uint256 indexed recordId,
        uint256 indexed productId,
        address indexed participant,
        uint256 timestamp
    );


    modifier onlyOwner() {
        require(msg.sender == contractOwner, "Only contract owner can perform this action");
        _;
    }


    modifier onlyRegisteredParticipant() {
        require(participants[msg.sender].isActive, "Only registered participants can perform this action");
        _;
    }


    modifier productExists(uint256 _productId) {
        require(products[_productId].exists, "Product does not exist");
        _;
    }


    modifier onlyAuthorizedForProduct(uint256 _productId) {
        require(
            products[_productId].manufacturer == msg.sender ||
            participants[msg.sender].isActive,
            "Not authorized to update this product"
        );
        _;
    }


    constructor() {
        contractOwner = msg.sender;
        nextProductId = 1;
        nextRecordId = 1;
    }


    function registerParticipant(
        address _participantAddress,
        string memory _participantName,
        ParticipantRole _role
    ) external onlyOwner {
        require(_participantAddress != address(0), "Invalid participant address");
        require(bytes(_participantName).length > 0, "Participant name cannot be empty");
        require(!participants[_participantAddress].isActive, "Participant already registered");

        participants[_participantAddress] = Participant({
            participantAddress: _participantAddress,
            participantName: _participantName,
            role: _role,
            isActive: true,
            registrationTime: block.timestamp
        });

        participantAddresses.push(_participantAddress);

        emit ParticipantRegistered(_participantAddress, _participantName, _role, block.timestamp);
    }


    function createProduct(
        string memory _productName,
        string memory _productDescription
    ) external onlyRegisteredParticipant {
        require(bytes(_productName).length > 0, "Product name cannot be empty");
        require(
            participants[msg.sender].role == ParticipantRole.Manufacturer,
            "Only manufacturers can create products"
        );

        uint256 productId = nextProductId;
        nextProductId++;

        products[productId] = Product({
            productId: productId,
            productName: _productName,
            productDescription: _productDescription,
            manufacturer: msg.sender,
            manufacturingDate: block.timestamp,
            currentStatus: ProductStatus.Created,
            exists: true
        });

        productIds.push(productId);


        _addTrackingRecord(
            productId,
            ProductStatus.Created,
            ProductStatus.Created,
            "Manufacturing Facility",
            "Product created by manufacturer"
        );

        emit ProductCreated(productId, _productName, msg.sender, block.timestamp);
    }


    function updateProductStatus(
        uint256 _productId,
        ProductStatus _newStatus,
        string memory _location,
        string memory _remarks
    ) external
      onlyRegisteredParticipant
      productExists(_productId)
      onlyAuthorizedForProduct(_productId) {

        require(bytes(_location).length > 0, "Location cannot be empty");
        require(_isValidStatusTransition(products[_productId].currentStatus, _newStatus), "Invalid status transition");

        ProductStatus previousStatus = products[_productId].currentStatus;
        products[_productId].currentStatus = _newStatus;


        _addTrackingRecord(_productId, previousStatus, _newStatus, _location, _remarks);

        emit ProductStatusUpdated(_productId, msg.sender, previousStatus, _newStatus, _location, block.timestamp);
    }


    function getProductInfo(uint256 _productId)
        external
        view
        productExists(_productId)
        returns (
            uint256 productId,
            string memory productName,
            string memory productDescription,
            address manufacturer,
            uint256 manufacturingDate,
            ProductStatus currentStatus
        ) {

        Product memory product = products[_productId];
        return (
            product.productId,
            product.productName,
            product.productDescription,
            product.manufacturer,
            product.manufacturingDate,
            product.currentStatus
        );
    }


    function getProductTrackingHistory(uint256 _productId)
        external
        view
        productExists(_productId)
        returns (TrackingRecord[] memory) {

        return productTrackingHistory[_productId];
    }


    function getParticipantInfo(address _participantAddress)
        external
        view
        returns (
            address participantAddress,
            string memory participantName,
            ParticipantRole role,
            bool isActive,
            uint256 registrationTime
        ) {

        require(participants[_participantAddress].isActive, "Participant not found or inactive");

        Participant memory participant = participants[_participantAddress];
        return (
            participant.participantAddress,
            participant.participantName,
            participant.role,
            participant.isActive,
            participant.registrationTime
        );
    }


    function getAllProductIds() external view returns (uint256[] memory) {
        return productIds;
    }


    function getAllParticipantAddresses() external view returns (address[] memory) {
        return participantAddresses;
    }


    function deactivateParticipant(address _participantAddress) external onlyOwner {
        require(participants[_participantAddress].isActive, "Participant not found or already inactive");
        participants[_participantAddress].isActive = false;
    }


    function _addTrackingRecord(
        uint256 _productId,
        ProductStatus _previousStatus,
        ProductStatus _newStatus,
        string memory _location,
        string memory _remarks
    ) internal {

        uint256 recordId = nextRecordId;
        nextRecordId++;

        TrackingRecord memory newRecord = TrackingRecord({
            recordId: recordId,
            productId: _productId,
            participant: msg.sender,
            previousStatus: _previousStatus,
            newStatus: _newStatus,
            location: _location,
            timestamp: block.timestamp,
            remarks: _remarks
        });

        productTrackingHistory[_productId].push(newRecord);

        emit TrackingRecordAdded(recordId, _productId, msg.sender, block.timestamp);
    }


    function _isValidStatusTransition(ProductStatus _currentStatus, ProductStatus _newStatus)
        internal
        pure
        returns (bool) {


        if (_currentStatus == ProductStatus.Created) {
            return _newStatus == ProductStatus.InTransit;
        } else if (_currentStatus == ProductStatus.InTransit) {
            return _newStatus == ProductStatus.Delivered || _newStatus == ProductStatus.InTransit;
        } else if (_currentStatus == ProductStatus.Delivered) {
            return _newStatus == ProductStatus.Received;
        } else if (_currentStatus == ProductStatus.Received) {
            return _newStatus == ProductStatus.Completed || _newStatus == ProductStatus.InTransit;
        } else if (_currentStatus == ProductStatus.Completed) {
            return false;
        }

        return false;
    }
}
