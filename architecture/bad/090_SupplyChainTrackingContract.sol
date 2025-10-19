
pragma solidity ^0.8.0;

contract SupplyChainTrackingContract {


    address public owner;
    uint256 public totalProducts;
    uint256 public totalBatches;


    uint256 maxProductsPerBatch = 1000;
    uint256 maxStagesPerProduct = 10;
    string defaultLocation = "Unknown Location";

    struct Product {
        uint256 id;
        string name;
        string description;
        address manufacturer;
        uint256 batchId;
        uint256 timestamp;
        string currentLocation;
        uint256 currentStage;
        bool isActive;
    }

    struct Batch {
        uint256 id;
        string name;
        address creator;
        uint256 productCount;
        uint256 timestamp;
        bool isActive;
    }

    struct TrackingRecord {
        uint256 productId;
        string location;
        string action;
        address operator;
        uint256 timestamp;
        string notes;
    }


    mapping(uint256 => Product) public products;
    mapping(uint256 => Batch) public batches;
    mapping(uint256 => TrackingRecord[]) public productTrackingHistory;
    mapping(address => bool) public authorizedOperators;
    mapping(uint256 => uint256[]) public batchProducts;

    event ProductCreated(uint256 indexed productId, string name, uint256 batchId);
    event ProductMoved(uint256 indexed productId, string location, address operator);
    event BatchCreated(uint256 indexed batchId, string name, address creator);
    event OperatorAuthorized(address indexed operator);
    event OperatorRevoked(address indexed operator);

    constructor() {
        owner = msg.sender;
        totalProducts = 0;
        totalBatches = 0;
        authorizedOperators[msg.sender] = true;
    }


    function createBatch(string memory _name) external returns (uint256) {

        require(msg.sender == owner || authorizedOperators[msg.sender], "Not authorized");
        require(bytes(_name).length > 0, "Batch name cannot be empty");

        totalBatches++;
        uint256 batchId = totalBatches;

        batches[batchId] = Batch({
            id: batchId,
            name: _name,
            creator: msg.sender,
            productCount: 0,
            timestamp: block.timestamp,
            isActive: true
        });

        emit BatchCreated(batchId, _name, msg.sender);
        return batchId;
    }


    function createProduct(
        string memory _name,
        string memory _description,
        uint256 _batchId,
        string memory _initialLocation
    ) external returns (uint256) {

        require(msg.sender == owner || authorizedOperators[msg.sender], "Not authorized");
        require(bytes(_name).length > 0, "Product name cannot be empty");
        require(batches[_batchId].isActive, "Batch does not exist or inactive");


        require(batches[_batchId].productCount < 1000, "Batch is full");

        totalProducts++;
        uint256 productId = totalProducts;

        products[productId] = Product({
            id: productId,
            name: _name,
            description: _description,
            manufacturer: msg.sender,
            batchId: _batchId,
            timestamp: block.timestamp,
            currentLocation: bytes(_initialLocation).length > 0 ? _initialLocation : "Unknown Location",
            currentStage: 0,
            isActive: true
        });

        batches[_batchId].productCount++;
        batchProducts[_batchId].push(productId);


        productTrackingHistory[productId].push(TrackingRecord({
            productId: productId,
            location: bytes(_initialLocation).length > 0 ? _initialLocation : "Unknown Location",
            action: "Created",
            operator: msg.sender,
            timestamp: block.timestamp,
            notes: "Product created"
        }));

        emit ProductCreated(productId, _name, _batchId);
        return productId;
    }


    function moveProduct(
        uint256 _productId,
        string memory _newLocation,
        string memory _notes
    ) external {

        require(msg.sender == owner || authorizedOperators[msg.sender], "Not authorized");
        require(products[_productId].isActive, "Product does not exist or inactive");
        require(bytes(_newLocation).length > 0, "Location cannot be empty");

        products[_productId].currentLocation = _newLocation;


        productTrackingHistory[_productId].push(TrackingRecord({
            productId: _productId,
            location: _newLocation,
            action: "Moved",
            operator: msg.sender,
            timestamp: block.timestamp,
            notes: _notes
        }));

        emit ProductMoved(_productId, _newLocation, msg.sender);
    }


    function updateProductStage(
        uint256 _productId,
        uint256 _newStage,
        string memory _notes
    ) external {

        require(msg.sender == owner || authorizedOperators[msg.sender], "Not authorized");
        require(products[_productId].isActive, "Product does not exist or inactive");

        require(_newStage <= 10, "Stage cannot exceed maximum");
        require(_newStage > products[_productId].currentStage, "Stage must be progressive");

        products[_productId].currentStage = _newStage;


        productTrackingHistory[_productId].push(TrackingRecord({
            productId: _productId,
            location: products[_productId].currentLocation,
            action: "Stage Updated",
            operator: msg.sender,
            timestamp: block.timestamp,
            notes: _notes
        }));
    }


    function authorizeOperator(address _operator) external {

        require(msg.sender == owner, "Only owner can authorize operators");
        require(_operator != address(0), "Invalid operator address");

        authorizedOperators[_operator] = true;
        emit OperatorAuthorized(_operator);
    }


    function revokeOperator(address _operator) external {

        require(msg.sender == owner, "Only owner can revoke operators");
        require(_operator != owner, "Cannot revoke owner");

        authorizedOperators[_operator] = false;
        emit OperatorRevoked(_operator);
    }


    function deactivateProduct(uint256 _productId) external {

        require(msg.sender == owner || authorizedOperators[msg.sender], "Not authorized");
        require(products[_productId].isActive, "Product does not exist or already inactive");

        products[_productId].isActive = false;


        productTrackingHistory[_productId].push(TrackingRecord({
            productId: _productId,
            location: products[_productId].currentLocation,
            action: "Deactivated",
            operator: msg.sender,
            timestamp: block.timestamp,
            notes: "Product deactivated"
        }));
    }


    function deactivateBatch(uint256 _batchId) external {

        require(msg.sender == owner || authorizedOperators[msg.sender], "Not authorized");
        require(batches[_batchId].isActive, "Batch does not exist or already inactive");

        batches[_batchId].isActive = false;


        uint256[] memory batchProductIds = batchProducts[_batchId];
        for (uint256 i = 0; i < batchProductIds.length; i++) {
            if (products[batchProductIds[i]].isActive) {
                products[batchProductIds[i]].isActive = false;


                productTrackingHistory[batchProductIds[i]].push(TrackingRecord({
                    productId: batchProductIds[i],
                    location: products[batchProductIds[i]].currentLocation,
                    action: "Batch Deactivated",
                    operator: msg.sender,
                    timestamp: block.timestamp,
                    notes: "Deactivated due to batch deactivation"
                }));
            }
        }
    }


    function getProductHistory(uint256 _productId) public view returns (TrackingRecord[] memory) {
        return productTrackingHistory[_productId];
    }

    function getBatchProducts(uint256 _batchId) public view returns (uint256[] memory) {
        return batchProducts[_batchId];
    }

    function getProductDetails(uint256 _productId) public view returns (
        string memory name,
        string memory description,
        address manufacturer,
        uint256 batchId,
        string memory currentLocation,
        uint256 currentStage,
        bool isActive
    ) {
        Product memory product = products[_productId];
        return (
            product.name,
            product.description,
            product.manufacturer,
            product.batchId,
            product.currentLocation,
            product.currentStage,
            product.isActive
        );
    }

    function getBatchDetails(uint256 _batchId) public view returns (
        string memory name,
        address creator,
        uint256 productCount,
        uint256 timestamp,
        bool isActive
    ) {
        Batch memory batch = batches[_batchId];
        return (
            batch.name,
            batch.creator,
            batch.productCount,
            batch.timestamp,
            batch.isActive
        );
    }


    function updateMaxProductsPerBatch(uint256 _newMax) external {

        require(msg.sender == owner, "Only owner can update configuration");
        require(_newMax > 0, "Max products must be greater than 0");

        maxProductsPerBatch = _newMax;
    }


    function updateMaxStagesPerProduct(uint256 _newMax) external {

        require(msg.sender == owner, "Only owner can update configuration");
        require(_newMax > 0, "Max stages must be greater than 0");

        maxStagesPerProduct = _newMax;
    }


    function updateDefaultLocation(string memory _newLocation) external {

        require(msg.sender == owner, "Only owner can update configuration");
        require(bytes(_newLocation).length > 0, "Location cannot be empty");

        defaultLocation = _newLocation;
    }

    function isOperatorAuthorized(address _operator) external view returns (bool) {
        return authorizedOperators[_operator];
    }

    function getTotalProducts() external view returns (uint256) {
        return totalProducts;
    }

    function getTotalBatches() external view returns (uint256) {
        return totalBatches;
    }
}
