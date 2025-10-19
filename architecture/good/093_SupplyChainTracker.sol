
pragma solidity ^0.8.0;

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


    enum ProductStatus { Created, InTransit, Delivered, Sold, Recalled }
    enum ParticipantType { Manufacturer, Distributor, Retailer, Consumer }


    struct Product {
        uint256 id;
        string name;
        string description;
        uint256 batchId;
        address manufacturer;
        uint256 createdAt;
        ProductStatus status;
        string currentLocation;
        bool exists;
    }

    struct Batch {
        uint256 id;
        string batchNumber;
        uint256 quantity;
        uint256 createdAt;
        address manufacturer;
        bool exists;
    }

    struct Participant {
        address participantAddress;
        string name;
        string contactInfo;
        ParticipantType participantType;
        bool isActive;
        uint256 registeredAt;
    }

    struct TransferRecord {
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
        string report;
        uint256 score;
    }


    mapping(uint256 => Product) private products;
    mapping(uint256 => Batch) private batches;
    mapping(address => Participant) private participants;
    mapping(uint256 => TransferRecord[]) private productTransfers;
    mapping(uint256 => QualityCheck[]) private productQualityChecks;
    mapping(string => uint256) private batchNumberToId;

    uint256 private nextProductId = 1;
    uint256 private nextBatchId = 1;
    uint256 public totalProducts;
    uint256 public totalBatches;


    event ProductCreated(uint256 indexed productId, uint256 indexed batchId, address indexed manufacturer);
    event BatchCreated(uint256 indexed batchId, string batchNumber, address indexed manufacturer);
    event ProductTransferred(uint256 indexed productId, address indexed from, address indexed to, string location);
    event ProductStatusUpdated(uint256 indexed productId, ProductStatus newStatus);
    event ParticipantRegistered(address indexed participant, ParticipantType participantType);
    event QualityCheckPerformed(uint256 indexed productId, address indexed auditor, bool passed, uint256 score);
    event ProductRecalled(uint256 indexed productId, address indexed initiator);


    modifier onlyExistingProduct(uint256 _productId) {
        require(products[_productId].exists, "Product does not exist");
        _;
    }

    modifier onlyExistingBatch(uint256 _batchId) {
        require(batches[_batchId].exists, "Batch does not exist");
        _;
    }

    modifier onlyRegisteredParticipant() {
        require(participants[msg.sender].isActive, "Participant not registered or inactive");
        _;
    }

    modifier onlyProductOwner(uint256 _productId) {
        require(_isAuthorizedForProduct(_productId), "Not authorized for this product");
        _;
    }

    modifier validTemperature(int256 _temperature) {
        require(_temperature >= MIN_TEMPERATURE && _temperature <= MAX_TEMPERATURE, "Invalid temperature range");
        _;
    }

    modifier validScore(uint256 _score) {
        require(_score <= 100, "Score must be between 0 and 100");
        _;
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(AUDITOR_ROLE, msg.sender);


        _registerParticipant(msg.sender, "Contract Deployer", "admin@supplychain.com", ParticipantType.Manufacturer);
    }


    function registerParticipant(
        address _participant,
        string memory _name,
        string memory _contactInfo,
        ParticipantType _participantType
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _registerParticipant(_participant, _name, _contactInfo, _participantType);
        _assignRoleByType(_participant, _participantType);
    }

    function deactivateParticipant(address _participant) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(participants[_participant].isActive, "Participant not active");
        participants[_participant].isActive = false;
    }


    function createBatch(
        string memory _batchNumber,
        uint256 _quantity
    ) external onlyRole(MANUFACTURER_ROLE) onlyRegisteredParticipant whenNotPaused returns (uint256) {
        require(bytes(_batchNumber).length > 0, "Batch number cannot be empty");
        require(_quantity > 0 && _quantity <= MAX_BATCH_SIZE, "Invalid quantity");
        require(batchNumberToId[_batchNumber] == 0, "Batch number already exists");

        uint256 batchId = nextBatchId++;

        batches[batchId] = Batch({
            id: batchId,
            batchNumber: _batchNumber,
            quantity: _quantity,
            createdAt: block.timestamp,
            manufacturer: msg.sender,
            exists: true
        });

        batchNumberToId[_batchNumber] = batchId;
        totalBatches++;

        emit BatchCreated(batchId, _batchNumber, msg.sender);
        return batchId;
    }


    function createProduct(
        string memory _name,
        string memory _description,
        uint256 _batchId,
        string memory _location
    ) external onlyRole(MANUFACTURER_ROLE) onlyRegisteredParticipant onlyExistingBatch(_batchId) whenNotPaused returns (uint256) {
        require(bytes(_name).length > 0, "Product name cannot be empty");
        require(batches[_batchId].manufacturer == msg.sender, "Not authorized for this batch");

        uint256 productId = nextProductId++;

        products[productId] = Product({
            id: productId,
            name: _name,
            description: _description,
            batchId: _batchId,
            manufacturer: msg.sender,
            createdAt: block.timestamp,
            status: ProductStatus.Created,
            currentLocation: _location,
            exists: true
        });

        totalProducts++;


        _recordTransfer(productId, address(0), msg.sender, _location, 0, "Product created");

        emit ProductCreated(productId, _batchId, msg.sender);
        return productId;
    }

    function transferProduct(
        uint256 _productId,
        address _to,
        string memory _location,
        int256 _temperature,
        string memory _notes
    ) external
        onlyExistingProduct(_productId)
        onlyProductOwner(_productId)
        onlyRegisteredParticipant
        validTemperature(_temperature)
        whenNotPaused
    {
        require(participants[_to].isActive, "Recipient not registered or inactive");
        require(products[_productId].status != ProductStatus.Sold, "Cannot transfer sold product");
        require(products[_productId].status != ProductStatus.Recalled, "Cannot transfer recalled product");

        products[_productId].currentLocation = _location;
        products[_productId].status = ProductStatus.InTransit;

        _recordTransfer(_productId, msg.sender, _to, _location, _temperature, _notes);

        emit ProductTransferred(_productId, msg.sender, _to, _location);
        emit ProductStatusUpdated(_productId, ProductStatus.InTransit);
    }

    function confirmDelivery(uint256 _productId)
        external
        onlyExistingProduct(_productId)
        onlyRegisteredParticipant
        whenNotPaused
    {
        require(products[_productId].status == ProductStatus.InTransit, "Product not in transit");
        require(_wasTransferredTo(_productId, msg.sender), "Not authorized to confirm delivery");

        products[_productId].status = ProductStatus.Delivered;
        emit ProductStatusUpdated(_productId, ProductStatus.Delivered);
    }

    function markAsSold(uint256 _productId)
        external
        onlyExistingProduct(_productId)
        onlyRole(RETAILER_ROLE)
        onlyRegisteredParticipant
        whenNotPaused
    {
        require(products[_productId].status == ProductStatus.Delivered, "Product not delivered");
        require(_wasTransferredTo(_productId, msg.sender), "Not authorized to mark as sold");

        products[_productId].status = ProductStatus.Sold;
        emit ProductStatusUpdated(_productId, ProductStatus.Sold);
    }

    function recallProduct(uint256 _productId, string memory _reason)
        external
        onlyExistingProduct(_productId)
        whenNotPaused
    {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender) ||
            products[_productId].manufacturer == msg.sender,
            "Not authorized to recall product"
        );
        require(products[_productId].status != ProductStatus.Recalled, "Product already recalled");

        products[_productId].status = ProductStatus.Recalled;

        emit ProductRecalled(_productId, msg.sender);
        emit ProductStatusUpdated(_productId, ProductStatus.Recalled);
    }


    function performQualityCheck(
        uint256 _productId,
        bool _passed,
        string memory _report,
        uint256 _score
    ) external
        onlyExistingProduct(_productId)
        onlyRole(AUDITOR_ROLE)
        validScore(_score)
        whenNotPaused
    {
        QualityCheck memory check = QualityCheck({
            productId: _productId,
            auditor: msg.sender,
            timestamp: block.timestamp,
            passed: _passed,
            report: _report,
            score: _score
        });

        productQualityChecks[_productId].push(check);

        emit QualityCheckPerformed(_productId, msg.sender, _passed, _score);
    }


    function getProduct(uint256 _productId)
        external
        view
        onlyExistingProduct(_productId)
        returns (Product memory)
    {
        return products[_productId];
    }

    function getBatch(uint256 _batchId)
        external
        view
        onlyExistingBatch(_batchId)
        returns (Batch memory)
    {
        return batches[_batchId];
    }

    function getParticipant(address _participant)
        external
        view
        returns (Participant memory)
    {
        return participants[_participant];
    }

    function getProductTransfers(uint256 _productId)
        external
        view
        onlyExistingProduct(_productId)
        returns (TransferRecord[] memory)
    {
        return productTransfers[_productId];
    }

    function getProductQualityChecks(uint256 _productId)
        external
        view
        onlyExistingProduct(_productId)
        returns (QualityCheck[] memory)
    {
        return productQualityChecks[_productId];
    }

    function getBatchIdByNumber(string memory _batchNumber)
        external
        view
        returns (uint256)
    {
        return batchNumberToId[_batchNumber];
    }

    function getProductsByBatch(uint256 _batchId)
        external
        view
        onlyExistingBatch(_batchId)
        returns (uint256[] memory)
    {
        uint256[] memory batchProducts = new uint256[](totalProducts);
        uint256 count = 0;

        for (uint256 i = 1; i < nextProductId; i++) {
            if (products[i].exists && products[i].batchId == _batchId) {
                batchProducts[count] = i;
                count++;
            }
        }


        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = batchProducts[i];
        }

        return result;
    }


    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }


    function _registerParticipant(
        address _participant,
        string memory _name,
        string memory _contactInfo,
        ParticipantType _participantType
    ) internal {
        require(_participant != address(0), "Invalid participant address");
        require(bytes(_name).length > 0, "Name cannot be empty");

        participants[_participant] = Participant({
            participantAddress: _participant,
            name: _name,
            contactInfo: _contactInfo,
            participantType: _participantType,
            isActive: true,
            registeredAt: block.timestamp
        });

        emit ParticipantRegistered(_participant, _participantType);
    }

    function _assignRoleByType(address _participant, ParticipantType _participantType) internal {
        if (_participantType == ParticipantType.Manufacturer) {
            _grantRole(MANUFACTURER_ROLE, _participant);
        } else if (_participantType == ParticipantType.Distributor) {
            _grantRole(DISTRIBUTOR_ROLE, _participant);
        } else if (_participantType == ParticipantType.Retailer) {
            _grantRole(RETAILER_ROLE, _participant);
        }
    }

    function _recordTransfer(
        uint256 _productId,
        address _from,
        address _to,
        string memory _location,
        int256 _temperature,
        string memory _notes
    ) internal {
        TransferRecord memory transfer = TransferRecord({
            productId: _productId,
            from: _from,
            to: _to,
            timestamp: block.timestamp,
            location: _location,
            temperature: _temperature,
            notes: _notes
        });

        productTransfers[_productId].push(transfer);
    }

    function _isAuthorizedForProduct(uint256 _productId) internal view returns (bool) {
        if (hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            return true;
        }


        if (products[_productId].manufacturer == msg.sender) {
            return true;
        }


        return _wasTransferredTo(_productId, msg.sender);
    }

    function _wasTransferredTo(uint256 _productId, address _participant) internal view returns (bool) {
        TransferRecord[] memory transfers = productTransfers[_productId];
        if (transfers.length == 0) {
            return false;
        }


        return transfers[transfers.length - 1].to == _participant;
    }
}
