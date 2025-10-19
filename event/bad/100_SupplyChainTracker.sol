
pragma solidity ^0.8.0;

contract SupplyChainTracker {

    struct Product {
        uint256 id;
        string name;
        address manufacturer;
        uint256 timestamp;
        ProductStatus status;
        address currentOwner;
        string location;
    }

    enum ProductStatus { Created, InTransit, Delivered, Verified }

    mapping(uint256 => Product) public products;
    mapping(address => bool) public authorizedParties;
    mapping(uint256 => address[]) public productHistory;

    uint256 public productCounter;
    address public admin;

    error InvalidId();
    error NotAuth();
    error BadStatus();

    event ProductCreated(uint256 productId, string name, address manufacturer);
    event StatusUpdated(uint256 productId, ProductStatus status);
    event OwnershipTransferred(uint256 productId, address newOwner);

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    modifier onlyAuthorized() {
        require(authorizedParties[msg.sender] || msg.sender == admin);
        _;
    }

    modifier validProduct(uint256 _productId) {
        require(_productId > 0 && _productId <= productCounter);
        _;
    }

    constructor() {
        admin = msg.sender;
        authorizedParties[msg.sender] = true;
    }

    function addAuthorizedParty(address _party) external onlyAdmin {
        require(_party != address(0));
        authorizedParties[_party] = true;
    }

    function removeAuthorizedParty(address _party) external onlyAdmin {
        require(_party != address(0));
        require(_party != admin);
        authorizedParties[_party] = false;
    }

    function createProduct(
        string memory _name,
        address _manufacturer,
        string memory _location
    ) external onlyAuthorized returns (uint256) {
        require(bytes(_name).length > 0);
        require(_manufacturer != address(0));

        productCounter++;

        products[productCounter] = Product({
            id: productCounter,
            name: _name,
            manufacturer: _manufacturer,
            timestamp: block.timestamp,
            status: ProductStatus.Created,
            currentOwner: _manufacturer,
            location: _location
        });

        productHistory[productCounter].push(_manufacturer);

        emit ProductCreated(productCounter, _name, _manufacturer);

        return productCounter;
    }

    function updateProductStatus(
        uint256 _productId,
        ProductStatus _status
    ) external onlyAuthorized validProduct(_productId) {
        Product storage product = products[_productId];

        require(uint8(_status) > uint8(product.status));

        product.status = _status;
        product.timestamp = block.timestamp;

        emit StatusUpdated(_productId, _status);
    }

    function transferOwnership(
        uint256 _productId,
        address _newOwner,
        string memory _newLocation
    ) external onlyAuthorized validProduct(_productId) {
        require(_newOwner != address(0));

        Product storage product = products[_productId];
        require(product.status != ProductStatus.Delivered);

        product.currentOwner = _newOwner;
        product.location = _newLocation;
        product.timestamp = block.timestamp;

        productHistory[_productId].push(_newOwner);

        emit OwnershipTransferred(_productId, _newOwner);
    }

    function updateLocation(
        uint256 _productId,
        string memory _location
    ) external onlyAuthorized validProduct(_productId) {
        require(bytes(_location).length > 0);

        products[_productId].location = _location;
        products[_productId].timestamp = block.timestamp;
    }

    function verifyProduct(uint256 _productId) external onlyAuthorized validProduct(_productId) {
        Product storage product = products[_productId];
        require(product.status == ProductStatus.Delivered);

        product.status = ProductStatus.Verified;
        product.timestamp = block.timestamp;
    }

    function getProduct(uint256 _productId) external view validProduct(_productId) returns (
        uint256 id,
        string memory name,
        address manufacturer,
        uint256 timestamp,
        ProductStatus status,
        address currentOwner,
        string memory location
    ) {
        Product memory product = products[_productId];
        return (
            product.id,
            product.name,
            product.manufacturer,
            product.timestamp,
            product.status,
            product.currentOwner,
            product.location
        );
    }

    function getProductHistory(uint256 _productId) external view validProduct(_productId) returns (address[] memory) {
        return productHistory[_productId];
    }

    function isAuthorized(address _party) external view returns (bool) {
        return authorizedParties[_party];
    }

    function getTotalProducts() external view returns (uint256) {
        return productCounter;
    }
}
