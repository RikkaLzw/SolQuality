
pragma solidity ^0.8.0;

contract SupplyChainTracker {

    uint256 public constant CREATED = 1;
    uint256 public constant IN_TRANSIT = 2;
    uint256 public constant DELIVERED = 3;
    uint256 public constant VERIFIED = 4;

    struct Product {
        string productId;
        string name;
        string manufacturer;
        uint256 status;
        uint256 timestamp;
        bytes location;
        uint256 isActive;
        address owner;
    }

    struct Shipment {
        string shipmentId;
        string[] productIds;
        string carrier;
        bytes origin;
        bytes destination;
        uint256 departureTime;
        uint256 arrivalTime;
        uint256 isCompleted;
        address shipper;
    }

    mapping(string => Product) public products;
    mapping(string => Shipment) public shipments;
    mapping(address => uint256) public authorizedUsers;

    string[] public productList;
    string[] public shipmentList;

    address public owner;
    uint256 public totalProducts;
    uint256 public totalShipments;

    event ProductCreated(string productId, string name, address manufacturer);
    event ProductStatusUpdated(string productId, uint256 newStatus);
    event ShipmentCreated(string shipmentId, address shipper);
    event ShipmentCompleted(string shipmentId);
    event LocationUpdated(string productId, bytes newLocation);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyAuthorized() {
        require(
            msg.sender == owner || authorizedUsers[msg.sender] == uint256(1),
            "Not authorized"
        );
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedUsers[msg.sender] = uint256(1);
        totalProducts = uint256(0);
        totalShipments = uint256(0);
    }

    function authorizeUser(address user) external onlyOwner {
        authorizedUsers[user] = uint256(1);
    }

    function revokeUser(address user) external onlyOwner {
        authorizedUsers[user] = uint256(0);
    }

    function createProduct(
        string memory _productId,
        string memory _name,
        string memory _manufacturer,
        bytes memory _initialLocation
    ) external onlyAuthorized {
        require(products[_productId].isActive == uint256(0), "Product already exists");

        products[_productId] = Product({
            productId: _productId,
            name: _name,
            manufacturer: _manufacturer,
            status: uint256(CREATED),
            timestamp: block.timestamp,
            location: _initialLocation,
            isActive: uint256(1),
            owner: msg.sender
        });

        productList.push(_productId);
        totalProducts = totalProducts + uint256(1);

        emit ProductCreated(_productId, _name, msg.sender);
    }

    function updateProductStatus(
        string memory _productId,
        uint256 _newStatus
    ) external onlyAuthorized {
        require(products[_productId].isActive == uint256(1), "Product does not exist");
        require(_newStatus >= CREATED && _newStatus <= VERIFIED, "Invalid status");

        products[_productId].status = _newStatus;
        products[_productId].timestamp = block.timestamp;

        emit ProductStatusUpdated(_productId, _newStatus);
    }

    function updateProductLocation(
        string memory _productId,
        bytes memory _newLocation
    ) external onlyAuthorized {
        require(products[_productId].isActive == uint256(1), "Product does not exist");

        products[_productId].location = _newLocation;
        products[_productId].timestamp = block.timestamp;

        emit LocationUpdated(_productId, _newLocation);
    }

    function createShipment(
        string memory _shipmentId,
        string[] memory _productIds,
        string memory _carrier,
        bytes memory _origin,
        bytes memory _destination
    ) external onlyAuthorized {
        require(shipments[_shipmentId].isCompleted == uint256(0), "Shipment already exists");


        for (uint256 i = uint256(0); i < _productIds.length; i++) {
            require(products[_productIds[i]].isActive == uint256(1), "Product does not exist");
            require(products[_productIds[i]].owner == msg.sender, "Not product owner");
        }

        shipments[_shipmentId] = Shipment({
            shipmentId: _shipmentId,
            productIds: _productIds,
            carrier: _carrier,
            origin: _origin,
            destination: _destination,
            departureTime: block.timestamp,
            arrivalTime: uint256(0),
            isCompleted: uint256(0),
            shipper: msg.sender
        });


        for (uint256 i = uint256(0); i < _productIds.length; i++) {
            products[_productIds[i]].status = IN_TRANSIT;
            products[_productIds[i]].location = _origin;
        }

        shipmentList.push(_shipmentId);
        totalShipments = totalShipments + uint256(1);

        emit ShipmentCreated(_shipmentId, msg.sender);
    }

    function completeShipment(string memory _shipmentId) external onlyAuthorized {
        require(shipments[_shipmentId].isCompleted == uint256(0), "Shipment already completed");
        require(shipments[_shipmentId].shipper == msg.sender, "Not shipment owner");

        shipments[_shipmentId].isCompleted = uint256(1);
        shipments[_shipmentId].arrivalTime = block.timestamp;


        string[] memory productIds = shipments[_shipmentId].productIds;
        for (uint256 i = uint256(0); i < productIds.length; i++) {
            products[productIds[i]].status = DELIVERED;
            products[productIds[i]].location = shipments[_shipmentId].destination;
        }

        emit ShipmentCompleted(_shipmentId);
    }

    function transferProductOwnership(
        string memory _productId,
        address _newOwner
    ) external {
        require(products[_productId].isActive == uint256(1), "Product does not exist");
        require(products[_productId].owner == msg.sender, "Not product owner");
        require(_newOwner != address(0), "Invalid new owner");

        products[_productId].owner = _newOwner;
        products[_productId].timestamp = block.timestamp;
    }

    function getProduct(string memory _productId) external view returns (
        string memory productId,
        string memory name,
        string memory manufacturer,
        uint256 status,
        uint256 timestamp,
        bytes memory location,
        uint256 isActive,
        address productOwner
    ) {
        Product memory product = products[_productId];
        return (
            product.productId,
            product.name,
            product.manufacturer,
            product.status,
            product.timestamp,
            product.location,
            product.isActive,
            product.owner
        );
    }

    function getShipment(string memory _shipmentId) external view returns (
        string memory shipmentId,
        string[] memory productIds,
        string memory carrier,
        bytes memory origin,
        bytes memory destination,
        uint256 departureTime,
        uint256 arrivalTime,
        uint256 isCompleted,
        address shipper
    ) {
        Shipment memory shipment = shipments[_shipmentId];
        return (
            shipment.shipmentId,
            shipment.productIds,
            shipment.carrier,
            shipment.origin,
            shipment.destination,
            shipment.departureTime,
            shipment.arrivalTime,
            shipment.isCompleted,
            shipment.shipper
        );
    }

    function getAllProducts() external view returns (string[] memory) {
        return productList;
    }

    function getAllShipments() external view returns (string[] memory) {
        return shipmentList;
    }

    function isUserAuthorized(address user) external view returns (uint256) {
        return authorizedUsers[user];
    }
}
