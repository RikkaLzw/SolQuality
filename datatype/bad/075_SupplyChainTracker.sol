
pragma solidity ^0.8.0;

contract SupplyChainTracker {

    uint256 public totalProducts;
    uint256 public constant MAX_STAGE = 5;

    struct Product {
        string productId;
        bytes manufacturer;
        bytes currentLocation;
        uint256 currentStage;
        uint256 isActive;
        uint256 timestamp;
        address owner;
    }

    struct StageInfo {
        bytes stageName;
        bytes location;
        uint256 timestamp;
        uint256 isCompleted;
    }

    mapping(string => Product) public products;
    mapping(string => mapping(uint256 => StageInfo)) public productStages;
    mapping(address => uint256) public userProductCount;

    string[] public productIds;

    event ProductCreated(string productId, bytes manufacturer, address owner);
    event ProductMoved(string productId, uint256 newStage, bytes newLocation);
    event ProductTransferred(string productId, address from, address to);

    modifier onlyProductOwner(string memory _productId) {
        require(products[_productId].owner == msg.sender, "Not product owner");
        require(uint256(products[_productId].isActive) == 1, "Product not active");
        _;
    }

    modifier validStage(uint256 _stage) {
        require(_stage <= MAX_STAGE, "Invalid stage");
        _;
    }

    function createProduct(
        string memory _productId,
        bytes memory _manufacturer,
        bytes memory _initialLocation
    ) public {
        require(products[_productId].owner == address(0), "Product already exists");
        require(bytes(_productId).length > 0, "Product ID cannot be empty");
        require(_manufacturer.length > 0, "Manufacturer cannot be empty");

        products[_productId] = Product({
            productId: _productId,
            manufacturer: _manufacturer,
            currentLocation: _initialLocation,
            currentStage: uint256(0),
            isActive: uint256(1),
            timestamp: block.timestamp,
            owner: msg.sender
        });

        productStages[_productId][0] = StageInfo({
            stageName: bytes("Created"),
            location: _initialLocation,
            timestamp: block.timestamp,
            isCompleted: uint256(1)
        });

        productIds.push(_productId);
        totalProducts = totalProducts + uint256(1);
        userProductCount[msg.sender] = userProductCount[msg.sender] + uint256(1);

        emit ProductCreated(_productId, _manufacturer, msg.sender);
    }

    function moveProduct(
        string memory _productId,
        uint256 _newStage,
        bytes memory _newLocation,
        bytes memory _stageName
    ) public onlyProductOwner(_productId) validStage(_newStage) {
        Product storage product = products[_productId];
        require(_newStage > product.currentStage, "Cannot move to previous stage");

        product.currentStage = _newStage;
        product.currentLocation = _newLocation;
        product.timestamp = block.timestamp;

        productStages[_productId][_newStage] = StageInfo({
            stageName: _stageName,
            location: _newLocation,
            timestamp: block.timestamp,
            isCompleted: uint256(1)
        });

        emit ProductMoved(_productId, _newStage, _newLocation);
    }

    function transferProduct(string memory _productId, address _newOwner) public onlyProductOwner(_productId) {
        require(_newOwner != address(0), "Invalid new owner");
        require(_newOwner != msg.sender, "Cannot transfer to self");

        address previousOwner = products[_productId].owner;
        products[_productId].owner = _newOwner;

        userProductCount[previousOwner] = userProductCount[previousOwner] - uint256(1);
        userProductCount[_newOwner] = userProductCount[_newOwner] + uint256(1);

        emit ProductTransferred(_productId, previousOwner, _newOwner);
    }

    function deactivateProduct(string memory _productId) public onlyProductOwner(_productId) {
        products[_productId].isActive = uint256(0);
    }

    function getProduct(string memory _productId) public view returns (
        string memory productId,
        bytes memory manufacturer,
        bytes memory currentLocation,
        uint256 currentStage,
        uint256 isActive,
        uint256 timestamp,
        address owner
    ) {
        Product memory product = products[_productId];
        return (
            product.productId,
            product.manufacturer,
            product.currentLocation,
            product.currentStage,
            product.isActive,
            product.timestamp,
            product.owner
        );
    }

    function getStageInfo(string memory _productId, uint256 _stage) public view returns (
        bytes memory stageName,
        bytes memory location,
        uint256 timestamp,
        uint256 isCompleted
    ) {
        StageInfo memory stage = productStages[_productId][_stage];
        return (
            stage.stageName,
            stage.location,
            stage.timestamp,
            stage.isCompleted
        );
    }

    function getAllProductIds() public view returns (string[] memory) {
        return productIds;
    }

    function isProductActive(string memory _productId) public view returns (bool) {
        return uint256(products[_productId].isActive) == uint256(1);
    }

    function getTotalProducts() public view returns (uint256) {
        return totalProducts;
    }

    function getUserProductCount(address _user) public view returns (uint256) {
        return userProductCount[_user];
    }
}
