
pragma solidity ^0.8.0;

contract SupplyChainTracker {

    uint256 public constant MAX_STAGE = 5;
    uint256 public productCount;


    struct Product {
        string productId;
        string batchId;
        address manufacturer;
        address currentOwner;
        uint256 currentStage;
        uint256 timestamp;
        uint256 isActive;
        bytes metadata;
    }

    mapping(string => Product) public products;
    mapping(address => uint256) public authorizedUsers;


    uint256 public constant STAGE_MANUFACTURED = 1;
    uint256 public constant STAGE_SHIPPED = 2;
    uint256 public constant STAGE_IN_TRANSIT = 3;
    uint256 public constant STAGE_DELIVERED = 4;
    uint256 public constant STAGE_RECEIVED = 5;

    event ProductCreated(string indexed productId, address manufacturer);
    event ProductTransferred(string indexed productId, address from, address to);
    event StageUpdated(string indexed productId, uint256 newStage);

    modifier onlyAuthorized() {
        require(authorizedUsers[msg.sender] == 1, "Not authorized");
        _;
    }

    modifier validProduct(string memory _productId) {
        require(products[_productId].isActive == 1, "Product not found or inactive");
        _;
    }

    constructor() {
        authorizedUsers[msg.sender] = uint256(1);
        productCount = uint256(0);
    }

    function addAuthorizedUser(address _user) external onlyAuthorized {
        authorizedUsers[_user] = uint256(1);
    }

    function removeAuthorizedUser(address _user) external onlyAuthorized {
        authorizedUsers[_user] = uint256(0);
    }

    function createProduct(
        string memory _productId,
        string memory _batchId,
        bytes memory _metadata
    ) external onlyAuthorized {
        require(products[_productId].isActive == 0, "Product already exists");

        products[_productId] = Product({
            productId: _productId,
            batchId: _batchId,
            manufacturer: msg.sender,
            currentOwner: msg.sender,
            currentStage: uint256(STAGE_MANUFACTURED),
            timestamp: block.timestamp,
            isActive: uint256(1),
            metadata: _metadata
        });

        productCount = productCount + uint256(1);

        emit ProductCreated(_productId, msg.sender);
    }

    function transferProduct(
        string memory _productId,
        address _newOwner
    ) external onlyAuthorized validProduct(_productId) {
        require(_newOwner != address(0), "Invalid address");
        require(products[_productId].currentOwner == msg.sender, "Not current owner");

        address previousOwner = products[_productId].currentOwner;
        products[_productId].currentOwner = _newOwner;
        products[_productId].timestamp = block.timestamp;

        emit ProductTransferred(_productId, previousOwner, _newOwner);
    }

    function updateStage(
        string memory _productId,
        uint256 _newStage
    ) external onlyAuthorized validProduct(_productId) {
        require(_newStage >= uint256(1) && _newStage <= MAX_STAGE, "Invalid stage");
        require(products[_productId].currentOwner == msg.sender, "Not current owner");

        products[_productId].currentStage = _newStage;
        products[_productId].timestamp = block.timestamp;

        emit StageUpdated(_productId, _newStage);
    }

    function updateMetadata(
        string memory _productId,
        bytes memory _newMetadata
    ) external onlyAuthorized validProduct(_productId) {
        require(products[_productId].currentOwner == msg.sender, "Not current owner");

        products[_productId].metadata = _newMetadata;
        products[_productId].timestamp = block.timestamp;
    }

    function deactivateProduct(string memory _productId) external onlyAuthorized validProduct(_productId) {
        require(products[_productId].currentOwner == msg.sender, "Not current owner");

        products[_productId].isActive = uint256(0);
    }

    function getProduct(string memory _productId) external view returns (
        string memory productId,
        string memory batchId,
        address manufacturer,
        address currentOwner,
        uint256 currentStage,
        uint256 timestamp,
        uint256 isActive,
        bytes memory metadata
    ) {
        Product memory product = products[_productId];
        return (
            product.productId,
            product.batchId,
            product.manufacturer,
            product.currentOwner,
            product.currentStage,
            product.timestamp,
            product.isActive,
            product.metadata
        );
    }

    function isUserAuthorized(address _user) external view returns (uint256) {
        return authorizedUsers[_user];
    }

    function getProductStage(string memory _productId) external view returns (uint256) {
        require(products[_productId].isActive == 1, "Product not found or inactive");
        return products[_productId].currentStage;
    }

    function getTotalProducts() external view returns (uint256) {
        return productCount;
    }
}
