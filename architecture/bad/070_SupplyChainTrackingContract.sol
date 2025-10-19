
pragma solidity ^0.8.0;

contract SupplyChainTrackingContract {


    mapping(uint256 => Product) public products;
    mapping(uint256 => Shipment) public shipments;
    mapping(address => Manufacturer) public manufacturers;
    mapping(address => Distributor) public distributors;
    mapping(address => Retailer) public retailers;
    mapping(uint256 => ProductHistory[]) public productHistories;

    uint256 public productCounter;
    uint256 public shipmentCounter;
    address public owner;


    uint256 internal maxProductsPerBatch = 1000;
    uint256 internal maxShipmentWeight = 50000;
    string internal defaultProductStatus = "Created";

    struct Product {
        uint256 id;
        string name;
        string description;
        address manufacturer;
        uint256 timestamp;
        string status;
        uint256 batchNumber;
        bool exists;
    }

    struct Shipment {
        uint256 id;
        uint256[] productIds;
        address from;
        address to;
        uint256 timestamp;
        string status;
        uint256 weight;
        bool exists;
    }

    struct Manufacturer {
        address addr;
        string name;
        string location;
        bool authorized;
        bool exists;
    }

    struct Distributor {
        address addr;
        string name;
        string location;
        bool authorized;
        bool exists;
    }

    struct Retailer {
        address addr;
        string name;
        string location;
        bool authorized;
        bool exists;
    }

    struct ProductHistory {
        uint256 timestamp;
        string action;
        address actor;
        string details;
    }

    event ProductCreated(uint256 indexed productId, string name, address manufacturer);
    event ShipmentCreated(uint256 indexed shipmentId, address from, address to);
    event ProductStatusUpdated(uint256 indexed productId, string status);
    event ShipmentStatusUpdated(uint256 indexed shipmentId, string status);

    constructor() {
        owner = msg.sender;
        productCounter = 0;
        shipmentCounter = 0;
    }


    function registerManufacturer(address _addr, string memory _name, string memory _location) public {

        require(msg.sender == owner, "Only owner can register manufacturers");
        require(_addr != address(0), "Invalid address");
        require(!manufacturers[_addr].exists, "Manufacturer already exists");

        manufacturers[_addr] = Manufacturer({
            addr: _addr,
            name: _name,
            location: _location,
            authorized: true,
            exists: true
        });
    }

    function registerDistributor(address _addr, string memory _name, string memory _location) public {

        require(msg.sender == owner, "Only owner can register distributors");
        require(_addr != address(0), "Invalid address");
        require(!distributors[_addr].exists, "Distributor already exists");

        distributors[_addr] = Distributor({
            addr: _addr,
            name: _name,
            location: _location,
            authorized: true,
            exists: true
        });
    }

    function registerRetailer(address _addr, string memory _name, string memory _location) public {

        require(msg.sender == owner, "Only owner can register retailers");
        require(_addr != address(0), "Invalid address");
        require(!retailers[_addr].exists, "Retailer already exists");

        retailers[_addr] = Retailer({
            addr: _addr,
            name: _name,
            location: _location,
            authorized: true,
            exists: true
        });
    }

    function createProduct(string memory _name, string memory _description, uint256 _batchNumber) public {

        require(manufacturers[msg.sender].exists, "Only registered manufacturers can create products");
        require(manufacturers[msg.sender].authorized, "Manufacturer not authorized");
        require(bytes(_name).length > 0, "Product name cannot be empty");

        productCounter++;

        products[productCounter] = Product({
            id: productCounter,
            name: _name,
            description: _description,
            manufacturer: msg.sender,
            timestamp: block.timestamp,
            status: defaultProductStatus,
            batchNumber: _batchNumber,
            exists: true
        });


        productHistories[productCounter].push(ProductHistory({
            timestamp: block.timestamp,
            action: "Product Created",
            actor: msg.sender,
            details: string(abi.encodePacked("Product ", _name, " created by manufacturer"))
        }));

        emit ProductCreated(productCounter, _name, msg.sender);
    }

    function createShipment(uint256[] memory _productIds, address _to, uint256 _weight) public {

        bool isAuthorized = false;
        if (manufacturers[msg.sender].exists && manufacturers[msg.sender].authorized) {
            isAuthorized = true;
        }
        if (distributors[msg.sender].exists && distributors[msg.sender].authorized) {
            isAuthorized = true;
        }
        require(isAuthorized, "Only authorized entities can create shipments");

        require(_productIds.length > 0, "Shipment must contain at least one product");
        require(_weight <= maxShipmentWeight, "Shipment weight exceeds maximum");
        require(_to != address(0), "Invalid destination address");


        for (uint256 i = 0; i < _productIds.length; i++) {
            require(products[_productIds[i]].exists, "Product does not exist");
            require(keccak256(bytes(products[_productIds[i]].status)) != keccak256(bytes("Shipped")), "Product already shipped");
        }

        shipmentCounter++;

        shipments[shipmentCounter] = Shipment({
            id: shipmentCounter,
            productIds: _productIds,
            from: msg.sender,
            to: _to,
            timestamp: block.timestamp,
            status: "Created",
            weight: _weight,
            exists: true
        });


        for (uint256 i = 0; i < _productIds.length; i++) {
            products[_productIds[i]].status = "Shipped";


            productHistories[_productIds[i]].push(ProductHistory({
                timestamp: block.timestamp,
                action: "Product Shipped",
                actor: msg.sender,
                details: string(abi.encodePacked("Product shipped in shipment #", uintToString(shipmentCounter)))
            }));
        }

        emit ShipmentCreated(shipmentCounter, msg.sender, _to);
    }

    function updateShipmentStatus(uint256 _shipmentId, string memory _status) public {
        require(shipments[_shipmentId].exists, "Shipment does not exist");


        bool canUpdate = false;
        if (msg.sender == shipments[_shipmentId].from) {
            canUpdate = true;
        }
        if (msg.sender == shipments[_shipmentId].to) {
            canUpdate = true;
        }
        if (distributors[msg.sender].exists && distributors[msg.sender].authorized) {
            canUpdate = true;
        }
        require(canUpdate, "Not authorized to update shipment status");

        shipments[_shipmentId].status = _status;


        if (keccak256(bytes(_status)) == keccak256(bytes("Delivered"))) {
            uint256[] memory productIds = shipments[_shipmentId].productIds;
            for (uint256 i = 0; i < productIds.length; i++) {
                products[productIds[i]].status = "Delivered";


                productHistories[productIds[i]].push(ProductHistory({
                    timestamp: block.timestamp,
                    action: "Product Delivered",
                    actor: msg.sender,
                    details: string(abi.encodePacked("Product delivered via shipment #", uintToString(_shipmentId)))
                }));
            }
        }

        emit ShipmentStatusUpdated(_shipmentId, _status);
    }

    function updateProductStatus(uint256 _productId, string memory _status) public {
        require(products[_productId].exists, "Product does not exist");


        bool canUpdate = false;
        if (msg.sender == products[_productId].manufacturer) {
            canUpdate = true;
        }
        if (distributors[msg.sender].exists && distributors[msg.sender].authorized) {
            canUpdate = true;
        }
        if (retailers[msg.sender].exists && retailers[msg.sender].authorized) {
            canUpdate = true;
        }
        require(canUpdate, "Not authorized to update product status");

        products[_productId].status = _status;


        productHistories[_productId].push(ProductHistory({
            timestamp: block.timestamp,
            action: "Status Updated",
            actor: msg.sender,
            details: string(abi.encodePacked("Status updated to: ", _status))
        }));

        emit ProductStatusUpdated(_productId, _status);
    }

    function getProductHistory(uint256 _productId) public view returns (ProductHistory[] memory) {
        require(products[_productId].exists, "Product does not exist");
        return productHistories[_productId];
    }

    function getShipmentProducts(uint256 _shipmentId) public view returns (uint256[] memory) {
        require(shipments[_shipmentId].exists, "Shipment does not exist");
        return shipments[_shipmentId].productIds;
    }

    function verifyProductAuthenticity(uint256 _productId) public view returns (bool, address, uint256) {
        require(products[_productId].exists, "Product does not exist");


        address manufacturer = products[_productId].manufacturer;
        require(manufacturers[manufacturer].exists, "Invalid manufacturer");
        require(manufacturers[manufacturer].authorized, "Manufacturer not authorized");

        return (true, manufacturer, products[_productId].timestamp);
    }

    function revokeManufacturerAuthorization(address _manufacturer) public {

        require(msg.sender == owner, "Only owner can revoke authorization");
        require(manufacturers[_manufacturer].exists, "Manufacturer does not exist");

        manufacturers[_manufacturer].authorized = false;
    }

    function revokeDistributorAuthorization(address _distributor) public {

        require(msg.sender == owner, "Only owner can revoke authorization");
        require(distributors[_distributor].exists, "Distributor does not exist");

        distributors[_distributor].authorized = false;
    }

    function revokeRetailerAuthorization(address _retailer) public {

        require(msg.sender == owner, "Only owner can revoke authorization");
        require(retailers[_retailer].exists, "Retailer does not exist");

        retailers[_retailer].authorized = false;
    }


    function uintToString(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }


    function emergencyPause() public {
        require(msg.sender == owner, "Only owner can pause");

    }

    function getProductCount() public view returns (uint256) {
        return productCounter;
    }

    function getShipmentCount() public view returns (uint256) {
        return shipmentCounter;
    }
}
