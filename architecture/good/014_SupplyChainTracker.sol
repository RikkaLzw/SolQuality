
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract SupplyChainTracker is AccessControl, ReentrancyGuard, Pausable {

    bytes32 public constant MANUFACTURER_ROLE = keccak256("MANUFACTURER_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    bytes32 public constant RETAILER_ROLE = keccak256("RETAILER_ROLE");
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");


    uint256 public constant MAX_BATCH_SIZE = 10000;
    uint256 public constant MIN_TEMPERATURE = -50;
    uint256 public constant MAX_TEMPERATURE = 100;


    enum ProductState {
        Created,
        InTransit,
        Delivered,
        Sold,
        Recalled
    }

    enum ParticipantType {
        Manufacturer,
        Distributor,
        Retailer,
        Consumer
    }


    struct Product {
        uint256 id;
        string name;
        string batchNumber;
        address manufacturer;
        uint256 manufacturingDate;
        uint256 expiryDate;
        ProductState state;
        address currentOwner;
        bool exists;
    }

    struct Participant {
        address participantAddress;
        string name;
        string location;
        ParticipantType participantType;
        bool isActive;
        uint256 registrationDate;
    }

    struct TransactionRecord {
        uint256 productId;
        address from;
        address to;
        uint256 timestamp;
        string location;
        int256 temperature;
        string notes;
    }

    struct QualityCheck {
        uint256 productId;
        address auditor;
        uint256 timestamp;
        bool passed;
        string remarks;
    }


    mapping(uint256 => Product) private products;
    mapping(address => Participant) private participants;
    mapping(uint256 => TransactionRecord[]) private productTransactions;
    mapping(uint256 => QualityCheck[]) private productQualityChecks;

    uint256 private nextProductId;
    uint256 private totalProducts;


    event ProductCreated(
        uint256 indexed productId,
        string name,
        string batchNumber,
        address indexed manufacturer
    );

    event ProductTransferred(
        uint256 indexed productId,
        address indexed from,
        address indexed to,
        uint256 timestamp
    );

    event ParticipantRegistered(
        address indexed participant,
        string name,
        ParticipantType participantType
    );

    event QualityCheckPerformed(
        uint256 indexed productId,
        address indexed auditor,
        bool passed
    );

    event ProductStateChanged(
        uint256 indexed productId,
        ProductState oldState,
        ProductState newState
    );


    modifier validProduct(uint256 _productId) {
        require(products[_productId].exists, "Product does not exist");
        _;
    }

    modifier onlyProductOwner(uint256 _productId) {
        require(
            products[_productId].currentOwner == msg.sender,
            "Not the product owner"
        );
        _;
    }

    modifier onlyActiveParticipant() {
        require(
            participants[msg.sender].isActive,
            "Participant not active"
        );
        _;
    }

    modifier validTemperature(int256 _temperature) {
        require(
            _temperature >= MIN_TEMPERATURE && _temperature <= MAX_TEMPERATURE,
            "Invalid temperature range"
        );
        _;
    }

    modifier validBatchSize(uint256 _quantity) {
        require(_quantity > 0 && _quantity <= MAX_BATCH_SIZE, "Invalid batch size");
        _;
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        nextProductId = 1;
    }


    function registerParticipant(
        address _participant,
        string memory _name,
        string memory _location,
        ParticipantType _type
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_participant != address(0), "Invalid participant address");
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(!participants[_participant].isActive, "Participant already registered");

        participants[_participant] = Participant({
            participantAddress: _participant,
            name: _name,
            location: _location,
            participantType: _type,
            isActive: true,
            registrationDate: block.timestamp
        });


        _grantParticipantRole(_participant, _type);

        emit ParticipantRegistered(_participant, _name, _type);
    }


    function createProduct(
        string memory _name,
        string memory _batchNumber,
        uint256 _expiryDate,
        uint256 _quantity
    )
        external
        onlyRole(MANUFACTURER_ROLE)
        onlyActiveParticipant
        validBatchSize(_quantity)
        whenNotPaused
    {
        require(bytes(_name).length > 0, "Product name cannot be empty");
        require(bytes(_batchNumber).length > 0, "Batch number cannot be empty");
        require(_expiryDate > block.timestamp, "Expiry date must be in future");

        for (uint256 i = 0; i < _quantity; i++) {
            uint256 productId = nextProductId++;

            products[productId] = Product({
                id: productId,
                name: _name,
                batchNumber: _batchNumber,
                manufacturer: msg.sender,
                manufacturingDate: block.timestamp,
                expiryDate: _expiryDate,
                state: ProductState.Created,
                currentOwner: msg.sender,
                exists: true
            });

            totalProducts++;

            emit ProductCreated(productId, _name, _batchNumber, msg.sender);
        }
    }


    function transferProduct(
        uint256 _productId,
        address _to,
        string memory _location,
        int256 _temperature,
        string memory _notes
    )
        external
        validProduct(_productId)
        onlyProductOwner(_productId)
        onlyActiveParticipant
        validTemperature(_temperature)
        whenNotPaused
        nonReentrant
    {
        require(_to != address(0), "Invalid recipient address");
        require(participants[_to].isActive, "Recipient not active participant");
        require(_to != msg.sender, "Cannot transfer to self");

        Product storage product = products[_productId];
        address previousOwner = product.currentOwner;


        product.currentOwner = _to;


        _updateProductState(_productId, participants[_to].participantType);


        productTransactions[_productId].push(TransactionRecord({
            productId: _productId,
            from: previousOwner,
            to: _to,
            timestamp: block.timestamp,
            location: _location,
            temperature: _temperature,
            notes: _notes
        }));

        emit ProductTransferred(_productId, previousOwner, _to, block.timestamp);
    }


    function performQualityCheck(
        uint256 _productId,
        bool _passed,
        string memory _remarks
    )
        external
        onlyRole(AUDITOR_ROLE)
        validProduct(_productId)
        onlyActiveParticipant
        whenNotPaused
    {
        productQualityChecks[_productId].push(QualityCheck({
            productId: _productId,
            auditor: msg.sender,
            timestamp: block.timestamp,
            passed: _passed,
            remarks: _remarks
        }));

        emit QualityCheckPerformed(_productId, msg.sender, _passed);
    }


    function recallProduct(uint256 _productId)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        validProduct(_productId)
        whenNotPaused
    {
        Product storage product = products[_productId];
        ProductState oldState = product.state;
        product.state = ProductState.Recalled;

        emit ProductStateChanged(_productId, oldState, ProductState.Recalled);
    }


    function getProduct(uint256 _productId)
        external
        view
        validProduct(_productId)
        returns (Product memory)
    {
        return products[_productId];
    }


    function getProductTransactions(uint256 _productId)
        external
        view
        validProduct(_productId)
        returns (TransactionRecord[] memory)
    {
        return productTransactions[_productId];
    }


    function getProductQualityChecks(uint256 _productId)
        external
        view
        validProduct(_productId)
        returns (QualityCheck[] memory)
    {
        return productQualityChecks[_productId];
    }


    function getParticipant(address _participant)
        external
        view
        returns (Participant memory)
    {
        return participants[_participant];
    }


    function getTotalProducts() external view returns (uint256) {
        return totalProducts;
    }


    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }


    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }


    function deactivateParticipant(address _participant)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(participants[_participant].isActive, "Participant not active");
        participants[_participant].isActive = false;
    }


    function _grantParticipantRole(address _participant, ParticipantType _type) internal {
        if (_type == ParticipantType.Manufacturer) {
            _grantRole(MANUFACTURER_ROLE, _participant);
        } else if (_type == ParticipantType.Distributor) {
            _grantRole(DISTRIBUTOR_ROLE, _participant);
        } else if (_type == ParticipantType.Retailer) {
            _grantRole(RETAILER_ROLE, _participant);
        }
    }

    function _updateProductState(uint256 _productId, ParticipantType _recipientType) internal {
        Product storage product = products[_productId];
        ProductState oldState = product.state;
        ProductState newState = oldState;

        if (_recipientType == ParticipantType.Distributor || _recipientType == ParticipantType.Retailer) {
            newState = ProductState.InTransit;
        } else if (_recipientType == ParticipantType.Consumer) {
            newState = ProductState.Sold;
        }

        if (newState != oldState) {
            product.state = newState;
            emit ProductStateChanged(_productId, oldState, newState);
        }
    }
}
