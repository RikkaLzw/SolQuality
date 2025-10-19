
pragma solidity ^0.8.0;

contract SupplyChainTracker {

    uint256 public totalProducts;
    uint256 public totalManufacturers;
    uint256 public totalDistributors;
    uint256 public totalRetailers;


    struct Product {
        string productId;
        string batchNumber;
        string manufacturerId;
        uint256 productionDate;
        uint256 expiryDate;
        uint256 currentStatus;
        uint256 isAuthentic;
        bytes location;
        bytes additionalData;
    }

    struct Manufacturer {
        string manufacturerId;
        string name;
        bytes licenseInfo;
        uint256 isActive;
        uint256 registrationDate;
    }

    struct Distributor {
        string distributorId;
        string name;
        bytes certificationData;
        uint256 isVerified;
        uint256 registrationDate;
    }

    struct Retailer {
        string retailerId;
        string name;
        bytes businessLicense;
        uint256 isAuthorized;
        uint256 registrationDate;
    }

    struct TrackingRecord {
        string productId;
        string entityId;
        uint256 entityType;
        uint256 timestamp;
        bytes locationData;
        bytes transactionHash;
        uint256 isValid;
    }

    mapping(string => Product) public products;
    mapping(string => Manufacturer) public manufacturers;
    mapping(string => Distributor) public distributors;
    mapping(string => Retailer) public retailers;
    mapping(string => TrackingRecord[]) public productTrackingHistory;

    address public owner;
    uint256 public contractCreationTime;

    event ProductRegistered(string productId, string manufacturerId);
    event ManufacturerRegistered(string manufacturerId, string name);
    event DistributorRegistered(string distributorId, string name);
    event RetailerRegistered(string retailerId, string name);
    event ProductTransferred(string productId, string fromEntity, string toEntity);
    event ProductStatusUpdated(string productId, uint256 newStatus);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    modifier validProduct(string memory _productId) {
        require(uint256(products[_productId].isAuthentic) == uint256(1), "Product does not exist or is not authentic");
        _;
    }

    constructor() {
        owner = msg.sender;
        contractCreationTime = block.timestamp;

        totalProducts = uint256(0);
        totalManufacturers = uint256(0);
        totalDistributors = uint256(0);
        totalRetailers = uint256(0);
    }

    function registerManufacturer(
        string memory _manufacturerId,
        string memory _name,
        bytes memory _licenseInfo
    ) public onlyOwner {
        require(manufacturers[_manufacturerId].isActive != uint256(1), "Manufacturer already exists");

        manufacturers[_manufacturerId] = Manufacturer({
            manufacturerId: _manufacturerId,
            name: _name,
            licenseInfo: _licenseInfo,
            isActive: uint256(1),
            registrationDate: block.timestamp
        });

        totalManufacturers = uint256(totalManufacturers + uint256(1));

        emit ManufacturerRegistered(_manufacturerId, _name);
    }

    function registerDistributor(
        string memory _distributorId,
        string memory _name,
        bytes memory _certificationData
    ) public onlyOwner {
        require(distributors[_distributorId].isVerified != uint256(1), "Distributor already exists");

        distributors[_distributorId] = Distributor({
            distributorId: _distributorId,
            name: _name,
            certificationData: _certificationData,
            isVerified: uint256(1),
            registrationDate: block.timestamp
        });

        totalDistributors = uint256(totalDistributors + uint256(1));

        emit DistributorRegistered(_distributorId, _name);
    }

    function registerRetailer(
        string memory _retailerId,
        string memory _name,
        bytes memory _businessLicense
    ) public onlyOwner {
        require(retailers[_retailerId].isAuthorized != uint256(1), "Retailer already exists");

        retailers[_retailerId] = Retailer({
            retailerId: _retailerId,
            name: _name,
            businessLicense: _businessLicense,
            isAuthorized: uint256(1),
            registrationDate: block.timestamp
        });

        totalRetailers = uint256(totalRetailers + uint256(1));

        emit RetailerRegistered(_retailerId, _name);
    }

    function registerProduct(
        string memory _productId,
        string memory _batchNumber,
        string memory _manufacturerId,
        uint256 _expiryDate,
        bytes memory _location,
        bytes memory _additionalData
    ) public {
        require(manufacturers[_manufacturerId].isActive == uint256(1), "Manufacturer not registered or inactive");
        require(products[_productId].isAuthentic != uint256(1), "Product already exists");

        products[_productId] = Product({
            productId: _productId,
            batchNumber: _batchNumber,
            manufacturerId: _manufacturerId,
            productionDate: block.timestamp,
            expiryDate: _expiryDate,
            currentStatus: uint256(1),
            isAuthentic: uint256(1),
            location: _location,
            additionalData: _additionalData
        });


        productTrackingHistory[_productId].push(TrackingRecord({
            productId: _productId,
            entityId: _manufacturerId,
            entityType: uint256(0),
            timestamp: block.timestamp,
            locationData: _location,
            transactionHash: abi.encodePacked(blockhash(block.number - 1)),
            isValid: uint256(1)
        }));

        totalProducts = uint256(totalProducts + uint256(1));

        emit ProductRegistered(_productId, _manufacturerId);
    }

    function transferProduct(
        string memory _productId,
        string memory _fromEntityId,
        string memory _toEntityId,
        uint256 _toEntityType,
        bytes memory _newLocation
    ) public validProduct(_productId) {
        require(products[_productId].currentStatus == uint256(1), "Product is not active");


        if (_toEntityType == uint256(1)) {
            require(distributors[_toEntityId].isVerified == uint256(1), "Distributor not verified");
        } else if (_toEntityType == uint256(2)) {
            require(retailers[_toEntityId].isAuthorized == uint256(1), "Retailer not authorized");
        }


        products[_productId].location = _newLocation;


        productTrackingHistory[_productId].push(TrackingRecord({
            productId: _productId,
            entityId: _toEntityId,
            entityType: _toEntityType,
            timestamp: block.timestamp,
            locationData: _newLocation,
            transactionHash: abi.encodePacked(blockhash(block.number - 1)),
            isValid: uint256(1)
        }));

        emit ProductTransferred(_productId, _fromEntityId, _toEntityId);
    }

    function updateProductStatus(
        string memory _productId,
        uint256 _newStatus
    ) public onlyOwner validProduct(_productId) {
        products[_productId].currentStatus = _newStatus;

        emit ProductStatusUpdated(_productId, _newStatus);
    }

    function getProductTrackingHistory(string memory _productId)
        public
        view
        validProduct(_productId)
        returns (TrackingRecord[] memory) {
        return productTrackingHistory[_productId];
    }

    function verifyProductAuthenticity(string memory _productId)
        public
        view
        returns (uint256) {
        return products[_productId].isAuthentic;
    }

    function getProductDetails(string memory _productId)
        public
        view
        validProduct(_productId)
        returns (
            string memory batchNumber,
            string memory manufacturerId,
            uint256 productionDate,
            uint256 expiryDate,
            uint256 currentStatus,
            bytes memory location
        ) {
        Product memory product = products[_productId];
        return (
            product.batchNumber,
            product.manufacturerId,
            product.productionDate,
            product.expiryDate,
            product.currentStatus,
            product.location
        );
    }

    function getTotalCounts() public view returns (uint256, uint256, uint256, uint256) {
        return (totalProducts, totalManufacturers, totalDistributors, totalRetailers);
    }
}
