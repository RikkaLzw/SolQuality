
pragma solidity ^0.8.0;

contract SupplyChainTracker {

    struct Product {
        uint256 id;
        string name;
        address manufacturer;
        uint256 timestamp;
        string location;
        ProductStatus status;
        address currentOwner;
    }

    enum ProductStatus { Created, InTransit, Delivered, Verified }

    mapping(uint256 => Product) public products;
    mapping(address => bool) public authorizedParties;
    mapping(uint256 => address[]) public productHistory;

    uint256 public nextProductId;
    address public admin;


    event ProductCreated(uint256 productId, string name, address manufacturer);
    event ProductTransferred(uint256 productId, address from, address to);
    event StatusUpdated(uint256 productId, ProductStatus status);


    error InvalidInput();
    error NotAuthorized();
    error ProductNotFound();

    modifier onlyAdmin() {

        require(msg.sender == admin);
        _;
    }

    modifier onlyAuthorized() {

        require(authorizedParties[msg.sender] || msg.sender == admin);
        _;
    }

    modifier productExists(uint256 _productId) {

        require(_productId < nextProductId);
        _;
    }

    constructor() {
        admin = msg.sender;
        authorizedParties[msg.sender] = true;
        nextProductId = 1;
    }

    function addAuthorizedParty(address _party) external onlyAdmin {

        require(_party != address(0));
        authorizedParties[_party] = true;

    }

    function removeAuthorizedParty(address _party) external onlyAdmin {

        require(_party != admin);
        authorizedParties[_party] = false;

    }

    function createProduct(string memory _name, string memory _location) external onlyAuthorized {

        require(bytes(_name).length > 0);
        require(bytes(_location).length > 0);

        uint256 productId = nextProductId;

        products[productId] = Product({
            id: productId,
            name: _name,
            manufacturer: msg.sender,
            timestamp: block.timestamp,
            location: _location,
            status: ProductStatus.Created,
            currentOwner: msg.sender
        });

        productHistory[productId].push(msg.sender);
        nextProductId++;

        emit ProductCreated(productId, _name, msg.sender);
    }

    function transferProduct(uint256 _productId, address _to) external productExists(_productId) {
        Product storage product = products[_productId];


        require(product.currentOwner == msg.sender);
        require(_to != address(0));
        require(authorizedParties[_to]);

        address previousOwner = product.currentOwner;
        product.currentOwner = _to;
        product.timestamp = block.timestamp;


        if (product.status == ProductStatus.Created) {
            product.status = ProductStatus.InTransit;
        }

        productHistory[_productId].push(_to);

        emit ProductTransferred(_productId, previousOwner, _to);
    }

    function updateProductLocation(uint256 _productId, string memory _location) external productExists(_productId) onlyAuthorized {
        Product storage product = products[_productId];


        require(bytes(_location).length > 0);

        product.location = _location;
        product.timestamp = block.timestamp;

    }

    function updateProductStatus(uint256 _productId, ProductStatus _status) external productExists(_productId) {
        Product storage product = products[_productId];


        require(product.currentOwner == msg.sender);

        ProductStatus oldStatus = product.status;
        product.status = _status;
        product.timestamp = block.timestamp;


        if (_status == ProductStatus.Delivered && oldStatus != ProductStatus.InTransit) {

            require(false);
        }

        emit StatusUpdated(_productId, _status);
    }

    function verifyProduct(uint256 _productId) external productExists(_productId) onlyAuthorized {
        Product storage product = products[_productId];


        require(product.status == ProductStatus.Delivered);

        product.status = ProductStatus.Verified;
        product.timestamp = block.timestamp;

    }

    function getProduct(uint256 _productId) external view productExists(_productId) returns (Product memory) {
        return products[_productId];
    }

    function getProductHistory(uint256 _productId) external view productExists(_productId) returns (address[] memory) {
        return productHistory[_productId];
    }

    function isProductAuthentic(uint256 _productId) external view productExists(_productId) returns (bool) {
        Product memory product = products[_productId];
        return product.status == ProductStatus.Verified && productHistory[_productId].length > 0;
    }

    function changeAdmin(address _newAdmin) external onlyAdmin {

        require(_newAdmin != address(0));
        require(_newAdmin != admin);

        address oldAdmin = admin;
        admin = _newAdmin;
        authorizedParties[_newAdmin] = true;

    }
}
