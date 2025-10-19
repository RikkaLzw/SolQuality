
pragma solidity ^0.8.0;

contract SupplyChainTracker {

    uint256 public constant MAX_STAGE = 5;
    uint256 public totalProducts;


    struct Product {
        string productId;
        string batchNumber;
        address manufacturer;
        address currentOwner;
        uint256 currentStage;
        uint256 timestamp;
        uint256 isActive;
        bytes metadata;
    }

    struct StageInfo {
        string stageName;
        address handler;
        uint256 timestamp;
        bytes data;
        uint256 isCompleted;
    }

    mapping(string => Product) public products;
    mapping(string => mapping(uint256 => StageInfo)) public productStages;
    mapping(address => uint256) public userProductCount;

    string[] public productIds;

    event ProductCreated(string indexed productId, address indexed manufacturer);
    event StageUpdated(string indexed productId, uint256 stage, address indexed handler);
    event OwnershipTransferred(string indexed productId, address indexed from, address indexed to);

    modifier onlyProductOwner(string memory _productId) {
        require(products[_productId].currentOwner == msg.sender, "Not product owner");
        _;
    }

    modifier productExists(string memory _productId) {
        require(products[_productId].isActive == uint256(1), "Product does not exist");
        _;
    }

    function createProduct(
        string memory _productId,
        string memory _batchNumber,
        bytes memory _metadata
    ) external {
        require(products[_productId].isActive == uint256(0), "Product already exists");


        uint256 convertedStage = uint256(0);
        uint256 convertedActive = uint256(1);
        uint256 convertedTimestamp = uint256(block.timestamp);

        products[_productId] = Product({
            productId: _productId,
            batchNumber: _batchNumber,
            manufacturer: msg.sender,
            currentOwner: msg.sender,
            currentStage: convertedStage,
            timestamp: convertedTimestamp,
            isActive: convertedActive,
            metadata: _metadata
        });

        productIds.push(_productId);
        totalProducts = totalProducts + uint256(1);
        userProductCount[msg.sender] = userProductCount[msg.sender] + uint256(1);

        emit ProductCreated(_productId, msg.sender);
    }

    function updateStage(
        string memory _productId,
        string memory _stageName,
        bytes memory _data
    ) external productExists(_productId) onlyProductOwner(_productId) {
        uint256 currentStage = products[_productId].currentStage;
        require(currentStage < MAX_STAGE, "Product already at final stage");


        uint256 newStage = uint256(currentStage + uint256(1));
        uint256 completedFlag = uint256(1);
        uint256 currentTime = uint256(block.timestamp);

        productStages[_productId][newStage] = StageInfo({
            stageName: _stageName,
            handler: msg.sender,
            timestamp: currentTime,
            data: _data,
            isCompleted: completedFlag
        });

        products[_productId].currentStage = newStage;
        products[_productId].timestamp = currentTime;

        emit StageUpdated(_productId, newStage, msg.sender);
    }

    function transferOwnership(
        string memory _productId,
        address _newOwner
    ) external productExists(_productId) onlyProductOwner(_productId) {
        require(_newOwner != address(0), "Invalid address");
        require(_newOwner != msg.sender, "Cannot transfer to self");

        address previousOwner = products[_productId].currentOwner;
        products[_productId].currentOwner = _newOwner;


        userProductCount[previousOwner] = userProductCount[previousOwner] - uint256(1);
        userProductCount[_newOwner] = userProductCount[_newOwner] + uint256(1);

        emit OwnershipTransferred(_productId, previousOwner, _newOwner);
    }

    function getProductInfo(string memory _productId) external view returns (
        string memory productId,
        string memory batchNumber,
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
            product.batchNumber,
            product.manufacturer,
            product.currentOwner,
            product.currentStage,
            product.timestamp,
            product.isActive,
            product.metadata
        );
    }

    function getStageInfo(
        string memory _productId,
        uint256 _stage
    ) external view returns (
        string memory stageName,
        address handler,
        uint256 timestamp,
        bytes memory data,
        uint256 isCompleted
    ) {
        StageInfo memory stageInfo = productStages[_productId][_stage];
        return (
            stageInfo.stageName,
            stageInfo.handler,
            stageInfo.timestamp,
            stageInfo.data,
            stageInfo.isCompleted
        );
    }

    function isProductActive(string memory _productId) external view returns (uint256) {
        return products[_productId].isActive;
    }

    function getTotalProducts() external view returns (uint256) {
        return totalProducts;
    }

    function getAllProductIds() external view returns (string[] memory) {
        return productIds;
    }

    function getUserProductCount(address _user) external view returns (uint256) {
        return userProductCount[_user];
    }
}
