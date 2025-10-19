
pragma solidity ^0.8.0;

contract SupplyChainTracker {
    address public owner;
    uint256 private productCounter;

    enum ProductStatus { Created, InTransit, Delivered, Verified }

    struct Product {
        uint256 id;
        string name;
        address manufacturer;
        address currentHolder;
        ProductStatus status;
        uint256 timestamp;
        string location;
    }

    struct Participant {
        address participantAddress;
        string name;
        string role;
        bool isActive;
    }

    mapping(uint256 => Product) public products;
    mapping(address => Participant) public participants;
    mapping(uint256 => address[]) private productHistory;

    event ProductCreated(uint256 productId, string name, address manufacturer);
    event ProductTransferred(uint256 productId, address from, address to);
    event ProductStatusUpdated(uint256 productId, ProductStatus status);
    event ParticipantRegistered(address participant, string name);

    error InvalidProduct();
    error NotAuthorized();
    error InvalidStatus();
    error ParticipantExists();

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyParticipant() {
        require(participants[msg.sender].isActive);
        _;
    }

    modifier validProduct(uint256 _productId) {
        require(_productId > 0 && _productId <= productCounter);
        _;
    }

    constructor() {
        owner = msg.sender;
        productCounter = 0;
    }

    function registerParticipant(
        address _participant,
        string memory _name,
        string memory _role
    ) external onlyOwner {
        require(!participants[_participant].isActive);

        participants[_participant] = Participant({
            participantAddress: _participant,
            name: _name,
            role: _role,
            isActive: true
        });

        emit ParticipantRegistered(_participant, _name);
    }

    function createProduct(
        string memory _name,
        string memory _location
    ) external onlyParticipant returns (uint256) {
        productCounter++;

        products[productCounter] = Product({
            id: productCounter,
            name: _name,
            manufacturer: msg.sender,
            currentHolder: msg.sender,
            status: ProductStatus.Created,
            timestamp: block.timestamp,
            location: _location
        });

        productHistory[productCounter].push(msg.sender);

        emit ProductCreated(productCounter, _name, msg.sender);

        return productCounter;
    }

    function transferProduct(
        uint256 _productId,
        address _newHolder,
        string memory _newLocation
    ) external validProduct(_productId) onlyParticipant {
        Product storage product = products[_productId];

        require(product.currentHolder == msg.sender);
        require(participants[_newHolder].isActive);
        require(product.status != ProductStatus.Delivered);

        address previousHolder = product.currentHolder;
        product.currentHolder = _newHolder;
        product.location = _newLocation;
        product.timestamp = block.timestamp;

        if (product.status == ProductStatus.Created) {
            product.status = ProductStatus.InTransit;
        }

        productHistory[_productId].push(_newHolder);

        emit ProductTransferred(_productId, previousHolder, _newHolder);
    }

    function updateProductStatus(
        uint256 _productId,
        ProductStatus _newStatus
    ) external validProduct(_productId) onlyParticipant {
        Product storage product = products[_productId];

        require(product.currentHolder == msg.sender);

        if (_newStatus == ProductStatus.Delivered) {
            require(product.status == ProductStatus.InTransit);
        } else if (_newStatus == ProductStatus.Verified) {
            require(product.status == ProductStatus.Delivered);
        }

        product.status = _newStatus;
        product.timestamp = block.timestamp;

        emit ProductStatusUpdated(_productId, _newStatus);
    }

    function getProduct(uint256 _productId) external view validProduct(_productId) returns (
        uint256 id,
        string memory name,
        address manufacturer,
        address currentHolder,
        ProductStatus status,
        uint256 timestamp,
        string memory location
    ) {
        Product memory product = products[_productId];
        return (
            product.id,
            product.name,
            product.manufacturer,
            product.currentHolder,
            product.status,
            product.timestamp,
            product.location
        );
    }

    function getProductHistory(uint256 _productId) external view validProduct(_productId) returns (address[] memory) {
        return productHistory[_productId];
    }

    function getParticipant(address _participant) external view returns (
        string memory name,
        string memory role,
        bool isActive
    ) {
        Participant memory participant = participants[_participant];
        return (participant.name, participant.role, participant.isActive);
    }

    function deactivateParticipant(address _participant) external onlyOwner {
        require(participants[_participant].isActive);
        participants[_participant].isActive = false;
    }

    function getTotalProducts() external view returns (uint256) {
        return productCounter;
    }

    function verifyProductAuthenticity(uint256 _productId) external view validProduct(_productId) returns (bool) {
        Product memory product = products[_productId];
        return product.id != 0 && participants[product.manufacturer].isActive;
    }
}
