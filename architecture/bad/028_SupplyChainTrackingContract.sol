
pragma solidity ^0.8.0;

contract SupplyChainTrackingContract {


    address public owner;
    uint256 public totalProducts;
    uint256 public totalBatches;
    uint256 public totalShipments;


    uint256 maxProductsPerBatch = 1000;
    uint256 maxBatchesPerShipment = 50;
    string defaultLocation = "Warehouse A";

    struct Product {
        uint256 id;
        string name;
        string description;
        address manufacturer;
        uint256 timestamp;
        string origin;
        bool isActive;
    }

    struct Batch {
        uint256 id;
        uint256[] productIds;
        address processor;
        uint256 timestamp;
        string location;
        string quality;
        bool isProcessed;
    }

    struct Shipment {
        uint256 id;
        uint256[] batchIds;
        address shipper;
        address receiver;
        uint256 timestamp;
        string destination;
        string status;
        bool isDelivered;
    }


    mapping(uint256 => Product) public products;
    mapping(uint256 => Batch) public batches;
    mapping(uint256 => Shipment) public shipments;
    mapping(address => bool) public authorizedUsers;
    mapping(uint256 => address[]) public productHistory;
    mapping(uint256 => address[]) public batchHistory;

    event ProductCreated(uint256 indexed productId, string name, address manufacturer);
    event BatchCreated(uint256 indexed batchId, uint256[] productIds, address processor);
    event ShipmentCreated(uint256 indexed shipmentId, uint256[] batchIds, address shipper);
    event ProductTransferred(uint256 indexed productId, address from, address to);
    event BatchProcessed(uint256 indexed batchId, address processor);
    event ShipmentDelivered(uint256 indexed shipmentId, address receiver);

    constructor() {
        owner = msg.sender;
        totalProducts = 0;
        totalBatches = 0;
        totalShipments = 0;
        authorizedUsers[msg.sender] = true;
    }


    function createProduct(string memory _name, string memory _description, string memory _origin) public {

        require(msg.sender == owner || authorizedUsers[msg.sender], "Not authorized");
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");

        totalProducts++;

        products[totalProducts] = Product({
            id: totalProducts,
            name: _name,
            description: _description,
            manufacturer: msg.sender,
            timestamp: block.timestamp,
            origin: _origin,
            isActive: true
        });

        productHistory[totalProducts].push(msg.sender);

        emit ProductCreated(totalProducts, _name, msg.sender);
    }

    function createBatch(uint256[] memory _productIds, string memory _location, string memory _quality) public {

        require(msg.sender == owner || authorizedUsers[msg.sender], "Not authorized");
        require(_productIds.length > 0, "Product IDs cannot be empty");
        require(_productIds.length <= maxProductsPerBatch, "Too many products in batch");


        for (uint256 i = 0; i < _productIds.length; i++) {
            require(_productIds[i] > 0 && _productIds[i] <= totalProducts, "Invalid product ID");
            require(products[_productIds[i]].isActive, "Product is not active");
        }

        totalBatches++;

        batches[totalBatches] = Batch({
            id: totalBatches,
            productIds: _productIds,
            processor: msg.sender,
            timestamp: block.timestamp,
            location: _location,
            quality: _quality,
            isProcessed: false
        });

        batchHistory[totalBatches].push(msg.sender);

        emit BatchCreated(totalBatches, _productIds, msg.sender);
    }

    function processBatch(uint256 _batchId, string memory _newLocation, string memory _newQuality) public {

        require(msg.sender == owner || authorizedUsers[msg.sender], "Not authorized");
        require(_batchId > 0 && _batchId <= totalBatches, "Invalid batch ID");
        require(!batches[_batchId].isProcessed, "Batch already processed");

        batches[_batchId].location = _newLocation;
        batches[_batchId].quality = _newQuality;
        batches[_batchId].isProcessed = true;

        batchHistory[_batchId].push(msg.sender);

        emit BatchProcessed(_batchId, msg.sender);
    }

    function createShipment(uint256[] memory _batchIds, address _receiver, string memory _destination) public {

        require(msg.sender == owner || authorizedUsers[msg.sender], "Not authorized");
        require(_batchIds.length > 0, "Batch IDs cannot be empty");
        require(_batchIds.length <= maxBatchesPerShipment, "Too many batches in shipment");
        require(_receiver != address(0), "Invalid receiver address");


        for (uint256 i = 0; i < _batchIds.length; i++) {
            require(_batchIds[i] > 0 && _batchIds[i] <= totalBatches, "Invalid batch ID");
            require(batches[_batchIds[i]].isProcessed, "Batch not processed");
        }

        totalShipments++;

        shipments[totalShipments] = Shipment({
            id: totalShipments,
            batchIds: _batchIds,
            shipper: msg.sender,
            receiver: _receiver,
            timestamp: block.timestamp,
            destination: _destination,
            status: "In Transit",
            isDelivered: false
        });

        emit ShipmentCreated(totalShipments, _batchIds, msg.sender);
    }

    function deliverShipment(uint256 _shipmentId) public {

        require(msg.sender == owner || authorizedUsers[msg.sender], "Not authorized");
        require(_shipmentId > 0 && _shipmentId <= totalShipments, "Invalid shipment ID");
        require(!shipments[_shipmentId].isDelivered, "Shipment already delivered");
        require(msg.sender == shipments[_shipmentId].receiver, "Only receiver can confirm delivery");

        shipments[_shipmentId].status = "Delivered";
        shipments[_shipmentId].isDelivered = true;

        emit ShipmentDelivered(_shipmentId, msg.sender);
    }

    function transferProduct(uint256 _productId, address _to) public {

        require(msg.sender == owner || authorizedUsers[msg.sender], "Not authorized");
        require(_productId > 0 && _productId <= totalProducts, "Invalid product ID");
        require(_to != address(0), "Invalid recipient address");
        require(products[_productId].isActive, "Product is not active");

        productHistory[_productId].push(_to);

        emit ProductTransferred(_productId, msg.sender, _to);
    }

    function addAuthorizedUser(address _user) public {

        require(msg.sender == owner, "Only owner can add authorized users");
        require(_user != address(0), "Invalid user address");

        authorizedUsers[_user] = true;
    }

    function removeAuthorizedUser(address _user) public {

        require(msg.sender == owner, "Only owner can remove authorized users");
        require(_user != address(0), "Invalid user address");
        require(_user != owner, "Cannot remove owner");

        authorizedUsers[_user] = false;
    }

    function updateProductStatus(uint256 _productId, bool _isActive) public {

        require(msg.sender == owner || authorizedUsers[msg.sender], "Not authorized");
        require(_productId > 0 && _productId <= totalProducts, "Invalid product ID");

        products[_productId].isActive = _isActive;
    }

    function getProductHistory(uint256 _productId) public view returns (address[] memory) {

        require(_productId > 0 && _productId <= totalProducts, "Invalid product ID");

        return productHistory[_productId];
    }

    function getBatchHistory(uint256 _batchId) public view returns (address[] memory) {

        require(_batchId > 0 && _batchId <= totalBatches, "Invalid batch ID");

        return batchHistory[_batchId];
    }

    function getProductsByBatch(uint256 _batchId) public view returns (uint256[] memory) {

        require(_batchId > 0 && _batchId <= totalBatches, "Invalid batch ID");

        return batches[_batchId].productIds;
    }

    function getBatchesByShipment(uint256 _shipmentId) public view returns (uint256[] memory) {

        require(_shipmentId > 0 && _shipmentId <= totalShipments, "Invalid shipment ID");

        return shipments[_shipmentId].batchIds;
    }

    function updateShipmentStatus(uint256 _shipmentId, string memory _status) public {

        require(msg.sender == owner || authorizedUsers[msg.sender], "Not authorized");
        require(_shipmentId > 0 && _shipmentId <= totalShipments, "Invalid shipment ID");
        require(!shipments[_shipmentId].isDelivered, "Cannot update delivered shipment");

        shipments[_shipmentId].status = _status;
    }

    function getProductDetails(uint256 _productId) public view returns (
        string memory name,
        string memory description,
        address manufacturer,
        uint256 timestamp,
        string memory origin,
        bool isActive
    ) {

        require(_productId > 0 && _productId <= totalProducts, "Invalid product ID");

        Product memory product = products[_productId];
        return (
            product.name,
            product.description,
            product.manufacturer,
            product.timestamp,
            product.origin,
            product.isActive
        );
    }

    function getBatchDetails(uint256 _batchId) public view returns (
        uint256[] memory productIds,
        address processor,
        uint256 timestamp,
        string memory location,
        string memory quality,
        bool isProcessed
    ) {

        require(_batchId > 0 && _batchId <= totalBatches, "Invalid batch ID");

        Batch memory batch = batches[_batchId];
        return (
            batch.productIds,
            batch.processor,
            batch.timestamp,
            batch.location,
            batch.quality,
            batch.isProcessed
        );
    }

    function getShipmentDetails(uint256 _shipmentId) public view returns (
        uint256[] memory batchIds,
        address shipper,
        address receiver,
        uint256 timestamp,
        string memory destination,
        string memory status,
        bool isDelivered
    ) {

        require(_shipmentId > 0 && _shipmentId <= totalShipments, "Invalid shipment ID");

        Shipment memory shipment = shipments[_shipmentId];
        return (
            shipment.batchIds,
            shipment.shipper,
            shipment.receiver,
            shipment.timestamp,
            shipment.destination,
            shipment.status,
            shipment.isDelivered
        );
    }
}
