
pragma solidity ^0.8.0;

contract SupplyChainTrackingContract {


    address public owner;
    uint256 public totalProducts;
    uint256 public totalBatches;
    uint256 public totalShipments;


    struct Product {
        uint256 id;
        string name;
        string description;
        address manufacturer;
        uint256 timestamp;
        bool exists;
    }


    struct Batch {
        uint256 id;
        uint256 productId;
        uint256 quantity;
        string location;
        address handler;
        uint256 timestamp;
        bool exists;
    }


    struct Shipment {
        uint256 id;
        uint256 batchId;
        address from;
        address to;
        string fromLocation;
        string toLocation;
        uint256 timestamp;
        bool delivered;
        bool exists;
    }


    mapping(uint256 => Product) public products;
    mapping(uint256 => Batch) public batches;
    mapping(uint256 => Shipment) public shipments;
    mapping(address => bool) public authorizedManufacturers;
    mapping(address => bool) public authorizedHandlers;
    mapping(address => bool) public authorizedCarriers;


    event ProductCreated(uint256 indexed productId, string name, address manufacturer);
    event BatchCreated(uint256 indexed batchId, uint256 productId, uint256 quantity);
    event ShipmentCreated(uint256 indexed shipmentId, uint256 batchId, address from, address to);
    event ShipmentDelivered(uint256 indexed shipmentId);

    constructor() {
        owner = msg.sender;
        totalProducts = 0;
        totalBatches = 0;
        totalShipments = 0;
    }


    function createProduct(string memory _name, string memory _description) external {

        require(msg.sender == owner || authorizedManufacturers[msg.sender], "Not authorized");
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
            exists: true
        });

        emit ProductCreated(productId, _name, msg.sender);
    }


    function createBatch(uint256 _productId, uint256 _quantity, string memory _location) external {

        require(msg.sender == owner || authorizedManufacturers[msg.sender] || authorizedHandlers[msg.sender], "Not authorized");
        require(products[_productId].exists, "Product does not exist");
        require(_quantity > 0, "Quantity must be greater than 0");
        require(bytes(_location).length > 0, "Location cannot be empty");

        totalBatches++;
        uint256 batchId = totalBatches;

        batches[batchId] = Batch({
            id: batchId,
            productId: _productId,
            quantity: _quantity,
            location: _location,
            handler: msg.sender,
            timestamp: block.timestamp,
            exists: true
        });

        emit BatchCreated(batchId, _productId, _quantity);
    }


    function createShipment(uint256 _batchId, address _to, string memory _fromLocation, string memory _toLocation) external {

        require(msg.sender == owner || authorizedHandlers[msg.sender] || authorizedCarriers[msg.sender], "Not authorized");
        require(batches[_batchId].exists, "Batch does not exist");
        require(_to != address(0), "Invalid destination address");
        require(bytes(_fromLocation).length > 0, "From location cannot be empty");
        require(bytes(_toLocation).length > 0, "To location cannot be empty");

        totalShipments++;
        uint256 shipmentId = totalShipments;

        shipments[shipmentId] = Shipment({
            id: shipmentId,
            batchId: _batchId,
            from: msg.sender,
            to: _to,
            fromLocation: _fromLocation,
            toLocation: _toLocation,
            timestamp: block.timestamp,
            delivered: false,
            exists: true
        });

        emit ShipmentCreated(shipmentId, _batchId, msg.sender, _to);
    }


    function confirmDelivery(uint256 _shipmentId) external {

        require(msg.sender == owner || authorizedHandlers[msg.sender] || authorizedCarriers[msg.sender], "Not authorized");
        require(shipments[_shipmentId].exists, "Shipment does not exist");
        require(!shipments[_shipmentId].delivered, "Already delivered");
        require(shipments[_shipmentId].to == msg.sender || msg.sender == owner, "Not authorized to confirm");

        shipments[_shipmentId].delivered = true;
        emit ShipmentDelivered(_shipmentId);
    }


    function authorizeManufacturer(address _manufacturer) external {

        require(msg.sender == owner, "Only owner can authorize");
        require(_manufacturer != address(0), "Invalid address");
        authorizedManufacturers[_manufacturer] = true;
    }


    function authorizeHandler(address _handler) external {

        require(msg.sender == owner, "Only owner can authorize");
        require(_handler != address(0), "Invalid address");
        authorizedHandlers[_handler] = true;
    }


    function authorizeCarrier(address _carrier) external {

        require(msg.sender == owner, "Only owner can authorize");
        require(_carrier != address(0), "Invalid address");
        authorizedCarriers[_carrier] = true;
    }


    function revokeManufacturer(address _manufacturer) external {

        require(msg.sender == owner, "Only owner can revoke");
        require(_manufacturer != address(0), "Invalid address");
        authorizedManufacturers[_manufacturer] = false;
    }


    function revokeHandler(address _handler) external {

        require(msg.sender == owner, "Only owner can revoke");
        require(_handler != address(0), "Invalid address");
        authorizedHandlers[_handler] = false;
    }


    function revokeCarrier(address _carrier) external {

        require(msg.sender == owner, "Only owner can revoke");
        require(_carrier != address(0), "Invalid address");
        authorizedCarriers[_carrier] = false;
    }


    function getProduct(uint256 _productId) external view returns (Product memory) {

        require(products[_productId].exists, "Product does not exist");
        return products[_productId];
    }


    function getBatch(uint256 _batchId) external view returns (Batch memory) {

        require(batches[_batchId].exists, "Batch does not exist");
        return batches[_batchId];
    }


    function getShipment(uint256 _shipmentId) external view returns (Shipment memory) {

        require(shipments[_shipmentId].exists, "Shipment does not exist");
        return shipments[_shipmentId];
    }


    function traceProductHistory(uint256 _productId) external view returns (
        Product memory product,
        Batch[] memory productBatches,
        Shipment[] memory productShipments
    ) {

        require(products[_productId].exists, "Product does not exist");

        product = products[_productId];


        Batch[] memory tempBatches = new Batch[](100);
        Shipment[] memory tempShipments = new Shipment[](1000);

        uint256 batchCount = 0;
        uint256 shipmentCount = 0;


        for (uint256 i = 1; i <= totalBatches; i++) {
            if (batches[i].exists && batches[i].productId == _productId) {
                tempBatches[batchCount] = batches[i];
                batchCount++;


                for (uint256 j = 1; j <= totalShipments; j++) {
                    if (shipments[j].exists && shipments[j].batchId == i) {
                        tempShipments[shipmentCount] = shipments[j];
                        shipmentCount++;
                    }
                }
            }
        }


        productBatches = new Batch[](batchCount);
        productShipments = new Shipment[](shipmentCount);

        for (uint256 k = 0; k < batchCount; k++) {
            productBatches[k] = tempBatches[k];
        }

        for (uint256 l = 0; l < shipmentCount; l++) {
            productShipments[l] = tempShipments[l];
        }

        return (product, productBatches, productShipments);
    }


    function updateBatchLocation(uint256 _batchId, string memory _newLocation) external {

        require(msg.sender == owner || authorizedHandlers[msg.sender], "Not authorized");
        require(batches[_batchId].exists, "Batch does not exist");
        require(bytes(_newLocation).length > 0, "Location cannot be empty");

        batches[_batchId].location = _newLocation;
    }


    function verifyProductAuthenticity(uint256 _productId) external view returns (bool) {

        require(products[_productId].exists, "Product does not exist");


        if (products[_productId].manufacturer == address(0)) {
            return false;
        }

        if (bytes(products[_productId].name).length == 0) {
            return false;
        }

        if (products[_productId].timestamp == 0) {
            return false;
        }

        return true;
    }


    function getStatistics() external view returns (
        uint256 totalProductsCount,
        uint256 totalBatchesCount,
        uint256 totalShipmentsCount,
        uint256 deliveredShipmentsCount,
        uint256 pendingShipmentsCount
    ) {
        totalProductsCount = totalProducts;
        totalBatchesCount = totalBatches;
        totalShipmentsCount = totalShipments;

        uint256 delivered = 0;
        uint256 pending = 0;


        for (uint256 i = 1; i <= totalShipments; i++) {
            if (shipments[i].exists) {
                if (shipments[i].delivered) {
                    delivered++;
                } else {
                    pending++;
                }
            }
        }

        deliveredShipmentsCount = delivered;
        pendingShipmentsCount = pending;
    }


    function transferOwnership(address _newOwner) external {

        require(msg.sender == owner, "Only owner can transfer");
        require(_newOwner != address(0), "Invalid new owner address");
        require(_newOwner != owner, "New owner cannot be current owner");

        owner = _newOwner;
    }
}
