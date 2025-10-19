
pragma solidity ^0.8.0;

contract SupplyChainTrackingContract {


    mapping(uint256 => Product) public products;
    mapping(uint256 => Shipment) public shipments;
    mapping(address => Supplier) public suppliers;
    mapping(address => bool) public authorizedUsers;
    mapping(uint256 => ProductHistory[]) public productHistories;

    uint256 public productCounter;
    uint256 public shipmentCounter;
    address public owner;

    struct Product {
        uint256 id;
        string name;
        string origin;
        uint256 timestamp;
        address manufacturer;
        string status;
        uint256 price;
        string category;
    }

    struct Shipment {
        uint256 id;
        uint256 productId;
        address from;
        address to;
        uint256 timestamp;
        string location;
        string status;
        uint256 temperature;
    }

    struct Supplier {
        address supplierAddress;
        string name;
        string location;
        bool isActive;
        uint256 registrationTime;
    }

    struct ProductHistory {
        uint256 timestamp;
        string action;
        address actor;
        string details;
    }

    event ProductCreated(uint256 indexed productId, string name, address manufacturer);
    event ShipmentCreated(uint256 indexed shipmentId, uint256 productId, address from, address to);
    event ProductStatusUpdated(uint256 indexed productId, string status);
    event SupplierRegistered(address indexed supplier, string name);

    constructor() {
        owner = msg.sender;
        productCounter = 0;
        shipmentCounter = 0;

        authorizedUsers[msg.sender] = true;
    }


    function createProduct(
        string memory _name,
        string memory _origin,
        uint256 _price,
        string memory _category
    ) public {

        require(msg.sender == owner || authorizedUsers[msg.sender], "Not authorized");
        require(bytes(_name).length > 0, "Name cannot be empty");

        productCounter++;

        products[productCounter] = Product({
            id: productCounter,
            name: _name,
            origin: _origin,
            timestamp: block.timestamp,
            manufacturer: msg.sender,
            status: "Created",
            price: _price,
            category: _category
        });


        ProductHistory memory newHistory = ProductHistory({
            timestamp: block.timestamp,
            action: "Product Created",
            actor: msg.sender,
            details: string(abi.encodePacked("Product ", _name, " created"))
        });
        productHistories[productCounter].push(newHistory);

        emit ProductCreated(productCounter, _name, msg.sender);
    }


    function updateProductStatus(uint256 _productId, string memory _status) public {

        require(msg.sender == owner || authorizedUsers[msg.sender], "Not authorized");
        require(_productId > 0 && _productId <= productCounter, "Invalid product ID");

        products[_productId].status = _status;


        ProductHistory memory newHistory = ProductHistory({
            timestamp: block.timestamp,
            action: "Status Updated",
            actor: msg.sender,
            details: string(abi.encodePacked("Status changed to ", _status))
        });
        productHistories[_productId].push(newHistory);

        emit ProductStatusUpdated(_productId, _status);
    }


    function createShipment(
        uint256 _productId,
        address _to,
        string memory _location
    ) public {

        require(msg.sender == owner || authorizedUsers[msg.sender], "Not authorized");
        require(_productId > 0 && _productId <= productCounter, "Invalid product ID");
        require(_to != address(0), "Invalid recipient address");

        shipmentCounter++;

        shipments[shipmentCounter] = Shipment({
            id: shipmentCounter,
            productId: _productId,
            from: msg.sender,
            to: _to,
            timestamp: block.timestamp,
            location: _location,
            status: "In Transit",
            temperature: 25
        });


        ProductHistory memory newHistory = ProductHistory({
            timestamp: block.timestamp,
            action: "Shipment Created",
            actor: msg.sender,
            details: string(abi.encodePacked("Shipment to ", _location, " created"))
        });
        productHistories[_productId].push(newHistory);

        emit ShipmentCreated(shipmentCounter, _productId, msg.sender, _to);
    }


    function updateShipmentStatus(uint256 _shipmentId, string memory _status, string memory _location) public {

        require(msg.sender == owner || authorizedUsers[msg.sender], "Not authorized");
        require(_shipmentId > 0 && _shipmentId <= shipmentCounter, "Invalid shipment ID");

        shipments[_shipmentId].status = _status;
        shipments[_shipmentId].location = _location;

        uint256 productId = shipments[_shipmentId].productId;


        ProductHistory memory newHistory = ProductHistory({
            timestamp: block.timestamp,
            action: "Shipment Updated",
            actor: msg.sender,
            details: string(abi.encodePacked("Shipment status: ", _status, " at ", _location))
        });
        productHistories[productId].push(newHistory);
    }


    function registerSupplier(address _supplier, string memory _name, string memory _location) public {

        require(msg.sender == owner || authorizedUsers[msg.sender], "Not authorized");
        require(_supplier != address(0), "Invalid supplier address");
        require(bytes(_name).length > 0, "Name cannot be empty");

        suppliers[_supplier] = Supplier({
            supplierAddress: _supplier,
            name: _name,
            location: _location,
            isActive: true,
            registrationTime: block.timestamp
        });

        emit SupplierRegistered(_supplier, _name);
    }


    function authorizeUser(address _user) public {

        require(msg.sender == owner || authorizedUsers[msg.sender], "Not authorized");
        require(_user != address(0), "Invalid user address");

        authorizedUsers[_user] = true;
    }


    function revokeUserAuthorization(address _user) public {

        require(msg.sender == owner || authorizedUsers[msg.sender], "Not authorized");
        require(_user != address(0), "Invalid user address");

        authorizedUsers[_user] = false;
    }


    function getProductDetails(uint256 _productId) public view returns (Product memory) {
        require(_productId > 0 && _productId <= productCounter, "Invalid product ID");
        require(bytes(products[_productId].name).length > 0, "Product does not exist");

        return products[_productId];
    }


    function getProductHistory(uint256 _productId) public view returns (ProductHistory[] memory) {
        require(_productId > 0 && _productId <= productCounter, "Invalid product ID");
        require(bytes(products[_productId].name).length > 0, "Product does not exist");

        return productHistories[_productId];
    }


    function getShipmentDetails(uint256 _shipmentId) public view returns (Shipment memory) {
        require(_shipmentId > 0 && _shipmentId <= shipmentCounter, "Invalid shipment ID");
        require(shipments[_shipmentId].productId > 0, "Shipment does not exist");

        return shipments[_shipmentId];
    }


    function updateProductPrice(uint256 _productId, uint256 _newPrice) public {

        require(msg.sender == owner || authorizedUsers[msg.sender], "Not authorized");
        require(_productId > 0 && _productId <= productCounter, "Invalid product ID");

        products[_productId].price = _newPrice;


        ProductHistory memory newHistory = ProductHistory({
            timestamp: block.timestamp,
            action: "Price Updated",
            actor: msg.sender,
            details: string(abi.encodePacked("Price updated to ", toString(_newPrice)))
        });
        productHistories[_productId].push(newHistory);
    }


    function updateShipmentTemperature(uint256 _shipmentId, uint256 _temperature) public {

        require(msg.sender == owner || authorizedUsers[msg.sender], "Not authorized");
        require(_shipmentId > 0 && _shipmentId <= shipmentCounter, "Invalid shipment ID");

        shipments[_shipmentId].temperature = _temperature;

        uint256 productId = shipments[_shipmentId].productId;


        ProductHistory memory newHistory = ProductHistory({
            timestamp: block.timestamp,
            action: "Temperature Updated",
            actor: msg.sender,
            details: string(abi.encodePacked("Temperature set to ", toString(_temperature), " degrees"))
        });
        productHistories[productId].push(newHistory);
    }


    function getSupplierInfo(address _supplier) public view returns (Supplier memory) {
        require(_supplier != address(0), "Invalid supplier address");
        require(suppliers[_supplier].supplierAddress != address(0), "Supplier not found");

        return suppliers[_supplier];
    }


    function deactivateSupplier(address _supplier) public {

        require(msg.sender == owner || authorizedUsers[msg.sender], "Not authorized");
        require(_supplier != address(0), "Invalid supplier address");

        suppliers[_supplier].isActive = false;
    }


    function activateSupplier(address _supplier) public {

        require(msg.sender == owner || authorizedUsers[msg.sender], "Not authorized");
        require(_supplier != address(0), "Invalid supplier address");

        suppliers[_supplier].isActive = true;
    }


    function batchUpdateProductStatus(uint256[] memory _productIds, string[] memory _statuses) public {

        require(msg.sender == owner || authorizedUsers[msg.sender], "Not authorized");
        require(_productIds.length == _statuses.length, "Arrays length mismatch");
        require(_productIds.length <= 100, "Batch size too large");

        for (uint256 i = 0; i < _productIds.length; i++) {
            require(_productIds[i] > 0 && _productIds[i] <= productCounter, "Invalid product ID");

            products[_productIds[i]].status = _statuses[i];


            ProductHistory memory newHistory = ProductHistory({
                timestamp: block.timestamp,
                action: "Batch Status Update",
                actor: msg.sender,
                details: string(abi.encodePacked("Status changed to ", _statuses[i]))
            });
            productHistories[_productIds[i]].push(newHistory);
        }
    }


    function findProductsByManufacturer(address _manufacturer) public view returns (uint256[] memory) {
        require(_manufacturer != address(0), "Invalid manufacturer address");

        uint256[] memory result = new uint256[](productCounter);
        uint256 count = 0;

        for (uint256 i = 1; i <= productCounter; i++) {
            if (products[i].manufacturer == _manufacturer && bytes(products[i].name).length > 0) {
                result[count] = i;
                count++;
            }
        }


        uint256[] memory finalResult = new uint256[](count);
        for (uint256 j = 0; j < count; j++) {
            finalResult[j] = result[j];
        }

        return finalResult;
    }


    function findProductsByCategory(string memory _category) public view returns (uint256[] memory) {
        require(bytes(_category).length > 0, "Category cannot be empty");

        uint256[] memory result = new uint256[](productCounter);
        uint256 count = 0;

        for (uint256 i = 1; i <= productCounter; i++) {
            if (keccak256(bytes(products[i].category)) == keccak256(bytes(_category)) && bytes(products[i].name).length > 0) {
                result[count] = i;
                count++;
            }
        }


        uint256[] memory finalResult = new uint256[](count);
        for (uint256 j = 0; j < count; j++) {
            finalResult[j] = result[j];
        }

        return finalResult;
    }


    function toString(uint256 value) public pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }


    function emergencyStop() public {

        require(msg.sender == owner || authorizedUsers[msg.sender], "Not authorized");



    }


    function getContractStats() public view returns (uint256, uint256, uint256) {
        uint256 activeSuppliers = 0;


        for (uint256 i = 0; i < 1000; i++) {
            address supplierAddr = address(uint160(i));
            if (suppliers[supplierAddr].isActive && suppliers[supplierAddr].supplierAddress != address(0)) {
                activeSuppliers++;
            }
        }

        return (productCounter, shipmentCounter, activeSuppliers);
    }
}
