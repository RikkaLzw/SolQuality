
pragma solidity ^0.8.0;

contract SupplyChainTrackingContract {


    address public owner;
    uint256 public totalProducts;
    uint256 public totalBatches;
    uint256 public totalShipments;


    uint256 public maxProductsPerBatch;
    uint256 public maxBatchesPerShipment;
    string public defaultLocation;

    struct Product {
        uint256 id;
        string name;
        string description;
        address manufacturer;
        uint256 timestamp;
        string location;
        bool exists;
    }

    struct Batch {
        uint256 id;
        uint256[] productIds;
        address processor;
        uint256 timestamp;
        string location;
        bool processed;
        bool exists;
    }

    struct Shipment {
        uint256 id;
        uint256[] batchIds;
        address shipper;
        address receiver;
        uint256 timestamp;
        string fromLocation;
        string toLocation;
        bool delivered;
        bool exists;
    }

    mapping(uint256 => Product) public products;
    mapping(uint256 => Batch) public batches;
    mapping(uint256 => Shipment) public shipments;
    mapping(address => bool) public authorizedManufacturers;
    mapping(address => bool) public authorizedProcessors;
    mapping(address => bool) public authorizedShippers;

    event ProductCreated(uint256 indexed productId, string name, address manufacturer);
    event BatchCreated(uint256 indexed batchId, address processor);
    event ShipmentCreated(uint256 indexed shipmentId, address shipper, address receiver);
    event ProductLocationUpdated(uint256 indexed productId, string newLocation);
    event BatchProcessed(uint256 indexed batchId);
    event ShipmentDelivered(uint256 indexed shipmentId);

    constructor() {
        owner = msg.sender;
        totalProducts = 0;
        totalBatches = 0;
        totalShipments = 0;

        maxProductsPerBatch = 1000;
        maxBatchesPerShipment = 50;
        defaultLocation = "Warehouse";
        authorizedManufacturers[msg.sender] = true;
        authorizedProcessors[msg.sender] = true;
        authorizedShippers[msg.sender] = true;
    }


    function addManufacturer(address _manufacturer) public {

        require(msg.sender == owner, "Only owner can add manufacturers");
        require(_manufacturer != address(0), "Invalid address");
        authorizedManufacturers[_manufacturer] = true;
    }

    function addProcessor(address _processor) public {

        require(msg.sender == owner, "Only owner can add processors");
        require(_processor != address(0), "Invalid address");
        authorizedProcessors[_processor] = true;
    }

    function addShipper(address _shipper) public {

        require(msg.sender == owner, "Only owner can add shippers");
        require(_shipper != address(0), "Invalid address");
        authorizedShippers[_shipper] = true;
    }

    function createProduct(string memory _name, string memory _description) public returns (uint256) {

        require(authorizedManufacturers[msg.sender] == true, "Not authorized manufacturer");
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");

        totalProducts++;
        uint256 productId = totalProducts;

        products[productId] = Product({
            id: productId,
            name: _name,
            description: _description,
            manufacturer: msg.sender,
            timestamp: block.timestamp,
            location: defaultLocation,
            exists: true
        });

        emit ProductCreated(productId, _name, msg.sender);
        return productId;
    }

    function updateProductLocation(uint256 _productId, string memory _newLocation) public {

        require(products[_productId].exists == true, "Product does not exist");
        require(bytes(_newLocation).length > 0, "Location cannot be empty");

        require(authorizedManufacturers[msg.sender] == true || authorizedProcessors[msg.sender] == true || authorizedShippers[msg.sender] == true, "Not authorized");

        products[_productId].location = _newLocation;
        emit ProductLocationUpdated(_productId, _newLocation);
    }

    function createBatch(uint256[] memory _productIds) public returns (uint256) {

        require(authorizedProcessors[msg.sender] == true, "Not authorized processor");
        require(_productIds.length > 0, "Batch must contain products");
        require(_productIds.length <= 1000, "Too many products in batch");


        for (uint256 i = 0; i < _productIds.length; i++) {
            require(products[_productIds[i]].exists == true, "Product does not exist");
        }

        totalBatches++;
        uint256 batchId = totalBatches;

        batches[batchId] = Batch({
            id: batchId,
            productIds: _productIds,
            processor: msg.sender,
            timestamp: block.timestamp,
            location: defaultLocation,
            processed: false,
            exists: true
        });

        emit BatchCreated(batchId, msg.sender);
        return batchId;
    }

    function processBatch(uint256 _batchId) public {

        require(batches[_batchId].exists == true, "Batch does not exist");

        require(authorizedProcessors[msg.sender] == true, "Not authorized processor");
        require(batches[_batchId].processed == false, "Batch already processed");

        batches[_batchId].processed = true;


        for (uint256 i = 0; i < batches[_batchId].productIds.length; i++) {
            uint256 productId = batches[_batchId].productIds[i];
            products[productId].location = "Processed";
        }

        emit BatchProcessed(_batchId);
    }

    function createShipment(uint256[] memory _batchIds, address _receiver, string memory _toLocation) public returns (uint256) {

        require(authorizedShippers[msg.sender] == true, "Not authorized shipper");
        require(_batchIds.length > 0, "Shipment must contain batches");
        require(_batchIds.length <= 50, "Too many batches in shipment");
        require(_receiver != address(0), "Invalid receiver address");
        require(bytes(_toLocation).length > 0, "Destination cannot be empty");


        for (uint256 i = 0; i < _batchIds.length; i++) {
            require(batches[_batchIds[i]].exists == true, "Batch does not exist");
            require(batches[_batchIds[i]].processed == true, "Batch not processed");
        }

        totalShipments++;
        uint256 shipmentId = totalShipments;

        shipments[shipmentId] = Shipment({
            id: shipmentId,
            batchIds: _batchIds,
            shipper: msg.sender,
            receiver: _receiver,
            timestamp: block.timestamp,
            fromLocation: defaultLocation,
            toLocation: _toLocation,
            delivered: false,
            exists: true
        });

        emit ShipmentCreated(shipmentId, msg.sender, _receiver);
        return shipmentId;
    }

    function deliverShipment(uint256 _shipmentId) public {

        require(shipments[_shipmentId].exists == true, "Shipment does not exist");
        require(msg.sender == shipments[_shipmentId].receiver, "Only receiver can confirm delivery");
        require(shipments[_shipmentId].delivered == false, "Shipment already delivered");

        shipments[_shipmentId].delivered = true;


        for (uint256 i = 0; i < shipments[_shipmentId].batchIds.length; i++) {
            uint256 batchId = shipments[_shipmentId].batchIds[i];
            for (uint256 j = 0; j < batches[batchId].productIds.length; j++) {
                uint256 productId = batches[batchId].productIds[j];
                products[productId].location = shipments[_shipmentId].toLocation;
            }
        }

        emit ShipmentDelivered(_shipmentId);
    }

    function getProductHistory(uint256 _productId) public view returns (
        string memory name,
        string memory description,
        address manufacturer,
        uint256 timestamp,
        string memory currentLocation
    ) {

        require(products[_productId].exists == true, "Product does not exist");

        Product memory product = products[_productId];
        return (
            product.name,
            product.description,
            product.manufacturer,
            product.timestamp,
            product.location
        );
    }

    function getBatchInfo(uint256 _batchId) public view returns (
        uint256[] memory productIds,
        address processor,
        uint256 timestamp,
        string memory location,
        bool processed
    ) {

        require(batches[_batchId].exists == true, "Batch does not exist");

        Batch memory batch = batches[_batchId];
        return (
            batch.productIds,
            batch.processor,
            batch.timestamp,
            batch.location,
            batch.processed
        );
    }

    function getShipmentInfo(uint256 _shipmentId) public view returns (
        uint256[] memory batchIds,
        address shipper,
        address receiver,
        uint256 timestamp,
        string memory fromLocation,
        string memory toLocation,
        bool delivered
    ) {

        require(shipments[_shipmentId].exists == true, "Shipment does not exist");

        Shipment memory shipment = shipments[_shipmentId];
        return (
            shipment.batchIds,
            shipment.shipper,
            shipment.receiver,
            shipment.timestamp,
            shipment.fromLocation,
            shipment.toLocation,
            shipment.delivered
        );
    }


    function removeManufacturer(address _manufacturer) public {

        require(msg.sender == owner, "Only owner can remove manufacturers");
        require(_manufacturer != address(0), "Invalid address");
        authorizedManufacturers[_manufacturer] = false;
    }

    function removeProcessor(address _processor) public {

        require(msg.sender == owner, "Only owner can remove processors");
        require(_processor != address(0), "Invalid address");
        authorizedProcessors[_processor] = false;
    }

    function removeShipper(address _shipper) public {

        require(msg.sender == owner, "Only owner can remove shippers");
        require(_shipper != address(0), "Invalid address");
        authorizedShippers[_shipper] = false;
    }

    function updateMaxProductsPerBatch(uint256 _newMax) public {

        require(msg.sender == owner, "Only owner can update limits");
        require(_newMax > 0, "Max must be greater than 0");
        maxProductsPerBatch = _newMax;
    }

    function updateMaxBatchesPerShipment(uint256 _newMax) public {

        require(msg.sender == owner, "Only owner can update limits");
        require(_newMax > 0, "Max must be greater than 0");
        maxBatchesPerShipment = _newMax;
    }

    function updateDefaultLocation(string memory _newLocation) public {

        require(msg.sender == owner, "Only owner can update default location");
        require(bytes(_newLocation).length > 0, "Location cannot be empty");
        defaultLocation = _newLocation;
    }
}
