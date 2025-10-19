
pragma solidity ^0.8.0;

contract SupplyChainTracker {
    struct Product {
        string productId;
        string name;
        uint256 status;
        uint256 timestamp;
        address manufacturer;
        address currentOwner;
        bytes location;
        uint256 price;
        uint256 quantity;
    }

    struct Shipment {
        string shipmentId;
        string productId;
        address sender;
        address receiver;
        uint256 isDelivered;
        uint256 shipDate;
        uint256 deliveryDate;
        bytes route;
    }

    mapping(string => Product) public products;
    mapping(string => Shipment) public shipments;
    mapping(address => uint256) public userRole;

    string[] public productIds;
    string[] public shipmentIds;

    uint256 public constant MANUFACTURER_ROLE = uint256(1);
    uint256 public constant DISTRIBUTOR_ROLE = uint256(2);
    uint256 public constant RETAILER_ROLE = uint256(3);

    uint256 public constant STATUS_MANUFACTURED = uint256(1);
    uint256 public constant STATUS_IN_TRANSIT = uint256(2);
    uint256 public constant STATUS_DELIVERED = uint256(3);

    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    modifier onlyAuthorized() {
        require(userRole[msg.sender] > uint256(0), "Not authorized");
        _;
    }

    constructor() {
        owner = msg.sender;
        userRole[msg.sender] = MANUFACTURER_ROLE;
    }

    function setUserRole(address user, uint256 role) external onlyOwner {
        require(role >= uint256(1) && role <= uint256(3), "Invalid role");
        userRole[user] = role;
    }

    function createProduct(
        string memory _productId,
        string memory _name,
        bytes memory _location,
        uint256 _price,
        uint256 _quantity
    ) external onlyAuthorized {
        require(bytes(products[_productId].productId).length == uint256(0), "Product already exists");

        products[_productId] = Product({
            productId: _productId,
            name: _name,
            status: STATUS_MANUFACTURED,
            timestamp: block.timestamp,
            manufacturer: msg.sender,
            currentOwner: msg.sender,
            location: _location,
            price: _price,
            quantity: _quantity
        });

        productIds.push(_productId);
    }

    function createShipment(
        string memory _shipmentId,
        string memory _productId,
        address _receiver,
        bytes memory _route
    ) external onlyAuthorized {
        require(bytes(products[_productId].productId).length > uint256(0), "Product does not exist");
        require(products[_productId].currentOwner == msg.sender, "Not the current owner");
        require(bytes(shipments[_shipmentId].shipmentId).length == uint256(0), "Shipment already exists");

        shipments[_shipmentId] = Shipment({
            shipmentId: _shipmentId,
            productId: _productId,
            sender: msg.sender,
            receiver: _receiver,
            isDelivered: uint256(0),
            shipDate: block.timestamp,
            deliveryDate: uint256(0),
            route: _route
        });

        products[_productId].status = STATUS_IN_TRANSIT;
        shipmentIds.push(_shipmentId);
    }

    function confirmDelivery(string memory _shipmentId) external {
        require(bytes(shipments[_shipmentId].shipmentId).length > uint256(0), "Shipment does not exist");
        require(shipments[_shipmentId].receiver == msg.sender, "Only receiver can confirm delivery");
        require(shipments[_shipmentId].isDelivered == uint256(0), "Already delivered");

        shipments[_shipmentId].isDelivered = uint256(1);
        shipments[_shipmentId].deliveryDate = block.timestamp;

        string memory productId = shipments[_shipmentId].productId;
        products[productId].status = STATUS_DELIVERED;
        products[productId].currentOwner = msg.sender;
    }

    function updateProductLocation(string memory _productId, bytes memory _newLocation) external {
        require(bytes(products[_productId].productId).length > uint256(0), "Product does not exist");
        require(products[_productId].currentOwner == msg.sender, "Not the current owner");

        products[_productId].location = _newLocation;
    }

    function getProduct(string memory _productId) external view returns (
        string memory productId,
        string memory name,
        uint256 status,
        uint256 timestamp,
        address manufacturer,
        address currentOwner,
        bytes memory location,
        uint256 price,
        uint256 quantity
    ) {
        Product memory product = products[_productId];
        return (
            product.productId,
            product.name,
            product.status,
            product.timestamp,
            product.manufacturer,
            product.currentOwner,
            product.location,
            product.price,
            product.quantity
        );
    }

    function getShipment(string memory _shipmentId) external view returns (
        string memory shipmentId,
        string memory productId,
        address sender,
        address receiver,
        uint256 isDelivered,
        uint256 shipDate,
        uint256 deliveryDate,
        bytes memory route
    ) {
        Shipment memory shipment = shipments[_shipmentId];
        return (
            shipment.shipmentId,
            shipment.productId,
            shipment.sender,
            shipment.receiver,
            shipment.isDelivered,
            shipment.shipDate,
            shipment.deliveryDate,
            shipment.route
        );
    }

    function getProductCount() external view returns (uint256) {
        return uint256(productIds.length);
    }

    function getShipmentCount() external view returns (uint256) {
        return uint256(shipmentIds.length);
    }

    function isProductDelivered(string memory _productId) external view returns (uint256) {
        if (products[_productId].status == STATUS_DELIVERED) {
            return uint256(1);
        }
        return uint256(0);
    }
}
