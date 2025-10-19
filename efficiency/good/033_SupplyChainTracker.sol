
pragma solidity ^0.8.19;

contract SupplyChainTracker {

    address public immutable owner;
    uint256 private _productCounter;


    enum ProductStatus {
        Created,
        InTransit,
        Delivered,
        Verified,
        Recalled
    }


    struct Product {
        uint256 id;
        bytes32 name;
        address manufacturer;
        uint64 timestamp;
        uint32 batchNumber;
        ProductStatus status;
        bytes32 location;
    }

    struct TrackingEvent {
        uint64 timestamp;
        bytes32 location;
        ProductStatus status;
        address updatedBy;
    }


    mapping(uint256 => Product) private _products;
    mapping(uint256 => TrackingEvent[]) private _productHistory;
    mapping(address => bool) public authorizedUpdaters;
    mapping(bytes32 => uint256[]) private _locationProducts;


    event ProductCreated(uint256 indexed productId, bytes32 name, address manufacturer);
    event ProductUpdated(uint256 indexed productId, ProductStatus status, bytes32 location);
    event UpdaterAuthorized(address indexed updater);
    event UpdaterRevoked(address indexed updater);


    error Unauthorized();
    error ProductNotFound();
    error InvalidStatus();
    error ZeroAddress();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyAuthorized() {
        if (!authorizedUpdaters[msg.sender] && msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier productExists(uint256 productId) {
        if (_products[productId].id == 0) revert ProductNotFound();
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedUpdaters[msg.sender] = true;
    }


    function createProduct(
        bytes32 name,
        address manufacturer,
        uint32 batchNumber,
        bytes32 initialLocation
    ) external onlyAuthorized returns (uint256) {
        if (manufacturer == address(0)) revert ZeroAddress();


        uint256 productId = ++_productCounter;
        uint64 currentTime = uint64(block.timestamp);


        _products[productId] = Product({
            id: productId,
            name: name,
            manufacturer: manufacturer,
            timestamp: currentTime,
            batchNumber: batchNumber,
            status: ProductStatus.Created,
            location: initialLocation
        });


        _productHistory[productId].push(TrackingEvent({
            timestamp: currentTime,
            location: initialLocation,
            status: ProductStatus.Created,
            updatedBy: msg.sender
        }));


        _locationProducts[initialLocation].push(productId);

        emit ProductCreated(productId, name, manufacturer);
        return productId;
    }


    function updateProductStatus(
        uint256 productId,
        ProductStatus newStatus,
        bytes32 newLocation
    ) external onlyAuthorized productExists(productId) {

        Product storage product = _products[productId];
        bytes32 oldLocation = product.location;


        if (uint8(newStatus) <= uint8(product.status) && newStatus != ProductStatus.Recalled) {
            revert InvalidStatus();
        }


        product.status = newStatus;
        product.location = newLocation;

        uint64 currentTime = uint64(block.timestamp);


        _productHistory[productId].push(TrackingEvent({
            timestamp: currentTime,
            location: newLocation,
            status: newStatus,
            updatedBy: msg.sender
        }));


        if (oldLocation != newLocation) {
            _removeProductFromLocation(productId, oldLocation);
            _locationProducts[newLocation].push(productId);
        }

        emit ProductUpdated(productId, newStatus, newLocation);
    }


    function batchUpdateProducts(
        uint256[] calldata productIds,
        ProductStatus[] calldata statuses,
        bytes32[] calldata locations
    ) external onlyAuthorized {
        uint256 length = productIds.length;
        if (length != statuses.length || length != locations.length) revert InvalidStatus();

        for (uint256 i = 0; i < length;) {
            updateProductStatus(productIds[i], statuses[i], locations[i]);
            unchecked {
                ++i;
            }
        }
    }


    function getProduct(uint256 productId)
        external
        view
        productExists(productId)
        returns (Product memory)
    {
        return _products[productId];
    }

    function getProductHistory(uint256 productId)
        external
        view
        productExists(productId)
        returns (TrackingEvent[] memory)
    {
        return _productHistory[productId];
    }

    function getProductsAtLocation(bytes32 location)
        external
        view
        returns (uint256[] memory)
    {
        return _locationProducts[location];
    }

    function getProductsByManufacturer(address manufacturer)
        external
        view
        returns (uint256[] memory productIds)
    {

        uint256[] memory tempIds = new uint256[](_productCounter);
        uint256 count = 0;

        for (uint256 i = 1; i <= _productCounter;) {
            if (_products[i].manufacturer == manufacturer) {
                tempIds[count] = i;
                unchecked {
                    ++count;
                }
            }
            unchecked {
                ++i;
            }
        }


        productIds = new uint256[](count);
        for (uint256 j = 0; j < count;) {
            productIds[j] = tempIds[j];
            unchecked {
                ++j;
            }
        }
    }

    function getTotalProducts() external view returns (uint256) {
        return _productCounter;
    }


    function authorizeUpdater(address updater) external onlyOwner {
        if (updater == address(0)) revert ZeroAddress();
        authorizedUpdaters[updater] = true;
        emit UpdaterAuthorized(updater);
    }

    function revokeUpdater(address updater) external onlyOwner {
        authorizedUpdaters[updater] = false;
        emit UpdaterRevoked(updater);
    }


    function _removeProductFromLocation(uint256 productId, bytes32 location) private {
        uint256[] storage locationProductIds = _locationProducts[location];
        uint256 length = locationProductIds.length;

        for (uint256 i = 0; i < length;) {
            if (locationProductIds[i] == productId) {

                locationProductIds[i] = locationProductIds[length - 1];
                locationProductIds.pop();
                break;
            }
            unchecked {
                ++i;
            }
        }
    }


    function emergencyRecall(uint256 productId)
        external
        onlyOwner
        productExists(productId)
    {
        Product storage product = _products[productId];
        product.status = ProductStatus.Recalled;

        _productHistory[productId].push(TrackingEvent({
            timestamp: uint64(block.timestamp),
            location: product.location,
            status: ProductStatus.Recalled,
            updatedBy: msg.sender
        }));

        emit ProductUpdated(productId, ProductStatus.Recalled, product.location);
    }
}
