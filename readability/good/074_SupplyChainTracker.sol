
pragma solidity ^0.8.0;


contract SupplyChainTracker {


    enum ProductStatus {
        Created,
        InProduction,
        Manufactured,
        InTransit,
        Delivered,
        Sold
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
        string contactInfo;
        ParticipantRole role;
        bool isActive;
        uint256 registrationTime;
    }


    struct Product {
        uint256 productId;
        string productName;
        string description;
        address manufacturer;
        uint256 manufacturingDate;
        uint256 expiryDate;
        ProductStatus currentStatus;
        string currentLocation;
        bool exists;
    }


    struct Transaction {
        uint256 transactionId;
        uint256 productId;
        address fromParticipant;
        address toParticipant;
        uint256 timestamp;
        string location;
        string notes;
        ProductStatus newStatus;
    }


    address public contractOwner;
    uint256 public nextProductId;
    uint256 public nextTransactionId;


    mapping(address => Participant) public participants;
    mapping(uint256 => Product) public products;
    mapping(uint256 => Transaction[]) public productTransactions;
    mapping(address => uint256[]) public participantProducts;


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
        ProductStatus oldStatus,
        ProductStatus newStatus,
        address indexed updatedBy,
        uint256 timestamp
    );

    event ProductTransferred(
        uint256 indexed productId,
        address indexed fromParticipant,
        address indexed toParticipant,
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

    modifier onlyManufacturer(uint256 _productId) {
        require(products[_productId].manufacturer == msg.sender, "Only manufacturer can perform this action");
        _;
    }


    constructor() {
        contractOwner = msg.sender;
        nextProductId = 1;
        nextTransactionId = 1;
    }


    function registerParticipant(
        address _participantAddress,
        string memory _participantName,
        string memory _contactInfo,
        ParticipantRole _role
    ) external onlyOwner {
        require(_participantAddress != address(0), "Invalid participant address");
        require(bytes(_participantName).length > 0, "Participant name cannot be empty");
        require(!participants[_participantAddress].isActive, "Participant already registered");

        participants[_participantAddress] = Participant({
            participantAddress: _participantAddress,
            participantName: _participantName,
            contactInfo: _contactInfo,
            role: _role,
            isActive: true,
            registrationTime: block.timestamp
        });

        emit ParticipantRegistered(_participantAddress, _participantName, _role, block.timestamp);
    }


    function createProduct(
        string memory _productName,
        string memory _description,
        uint256 _expiryDate,
        string memory _initialLocation
    ) external onlyRegisteredParticipant {
        require(participants[msg.sender].role == ParticipantRole.Manufacturer, "Only manufacturers can create products");
        require(bytes(_productName).length > 0, "Product name cannot be empty");
        require(_expiryDate > block.timestamp, "Expiry date must be in the future");

        uint256 productId = nextProductId;
        nextProductId++;

        products[productId] = Product({
            productId: productId,
            productName: _productName,
            description: _description,
            manufacturer: msg.sender,
            manufacturingDate: block.timestamp,
            expiryDate: _expiryDate,
            currentStatus: ProductStatus.Created,
            currentLocation: _initialLocation,
            exists: true
        });

        participantProducts[msg.sender].push(productId);


        _createTransaction(
            productId,
            address(0),
            msg.sender,
            _initialLocation,
            "Product created",
            ProductStatus.Created
        );

        emit ProductCreated(productId, _productName, msg.sender, block.timestamp);
    }


    function updateProductStatus(
        uint256 _productId,
        ProductStatus _newStatus,
        string memory _location,
        string memory _notes
    ) external onlyRegisteredParticipant productExists(_productId) {
        Product storage product = products[_productId];
        ProductStatus oldStatus = product.currentStatus;

        require(_isValidStatusTransition(oldStatus, _newStatus), "Invalid status transition");

        product.currentStatus = _newStatus;
        product.currentLocation = _location;

        _createTransaction(
            _productId,
            msg.sender,
            msg.sender,
            _location,
            _notes,
            _newStatus
        );

        emit ProductStatusUpdated(_productId, oldStatus, _newStatus, msg.sender, block.timestamp);
    }


    function transferProduct(
        uint256 _productId,
        address _toParticipant,
        string memory _location,
        string memory _notes
    ) external onlyRegisteredParticipant productExists(_productId) {
        require(participants[_toParticipant].isActive, "Recipient is not a registered participant");
        require(_toParticipant != msg.sender, "Cannot transfer to yourself");

        Product storage product = products[_productId];
        product.currentLocation = _location;


        participantProducts[_toParticipant].push(_productId);

        _createTransaction(
            _productId,
            msg.sender,
            _toParticipant,
            _location,
            _notes,
            product.currentStatus
        );

        emit ProductTransferred(_productId, msg.sender, _toParticipant, block.timestamp);
    }


    function getProduct(uint256 _productId) external view productExists(_productId) returns (Product memory) {
        return products[_productId];
    }


    function getProductHistory(uint256 _productId) external view productExists(_productId) returns (Transaction[] memory) {
        return productTransactions[_productId];
    }


    function getParticipant(address _participantAddress) external view returns (Participant memory) {
        return participants[_participantAddress];
    }


    function getParticipantProducts(address _participantAddress) external view returns (uint256[] memory) {
        return participantProducts[_participantAddress];
    }


    function verifyProduct(uint256 _productId) external view returns (bool) {
        return products[_productId].exists && products[_productId].expiryDate > block.timestamp;
    }


    function deactivateParticipant(address _participantAddress) external onlyOwner {
        require(participants[_participantAddress].isActive, "Participant is not active");
        participants[_participantAddress].isActive = false;
    }


    function _createTransaction(
        uint256 _productId,
        address _from,
        address _to,
        string memory _location,
        string memory _notes,
        ProductStatus _newStatus
    ) internal {
        uint256 transactionId = nextTransactionId;
        nextTransactionId++;

        Transaction memory newTransaction = Transaction({
            transactionId: transactionId,
            productId: _productId,
            fromParticipant: _from,
            toParticipant: _to,
            timestamp: block.timestamp,
            location: _location,
            notes: _notes,
            newStatus: _newStatus
        });

        productTransactions[_productId].push(newTransaction);
    }


    function _isValidStatusTransition(ProductStatus _currentStatus, ProductStatus _newStatus) internal pure returns (bool) {
        if (_currentStatus == ProductStatus.Created) {
            return _newStatus == ProductStatus.InProduction;
        } else if (_currentStatus == ProductStatus.InProduction) {
            return _newStatus == ProductStatus.Manufactured;
        } else if (_currentStatus == ProductStatus.Manufactured) {
            return _newStatus == ProductStatus.InTransit;
        } else if (_currentStatus == ProductStatus.InTransit) {
            return _newStatus == ProductStatus.Delivered;
        } else if (_currentStatus == ProductStatus.Delivered) {
            return _newStatus == ProductStatus.Sold;
        }
        return false;
    }
}
