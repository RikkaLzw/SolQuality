
pragma solidity ^0.8.0;

contract SupplyChainTrackingContract {


    mapping(uint256 => Product) public products;
    mapping(address => bool) public manufacturers;
    mapping(address => bool) public distributors;
    mapping(address => bool) public retailers;
    mapping(uint256 => ProductHistory[]) public productHistories;
    uint256 public productCounter;
    address public owner;

    struct Product {
        uint256 id;
        string name;
        address manufacturer;
        uint256 manufacturingDate;
        string origin;
        uint256 price;
        string status;
        address currentOwner;
    }

    struct ProductHistory {
        address from;
        address to;
        uint256 timestamp;
        string location;
        string action;
    }

    event ProductCreated(uint256 indexed productId, string name, address manufacturer);
    event ProductTransferred(uint256 indexed productId, address from, address to);
    event StatusUpdated(uint256 indexed productId, string newStatus);

    constructor() {
        owner = msg.sender;
        manufacturers[msg.sender] = true;
        distributors[msg.sender] = true;
        retailers[msg.sender] = true;
    }


    function addManufacturer(address _manufacturer) public {

        require(msg.sender == owner, "Only owner can add manufacturers");
        require(_manufacturer != address(0), "Invalid address");
        manufacturers[_manufacturer] = true;
    }

    function addDistributor(address _distributor) public {

        require(msg.sender == owner, "Only owner can add distributors");
        require(_distributor != address(0), "Invalid address");
        distributors[_distributor] = true;
    }

    function addRetailer(address _retailer) public {

        require(msg.sender == owner, "Only owner can add retailers");
        require(_retailer != address(0), "Invalid address");
        retailers[_retailer] = true;
    }

    function createProduct(string memory _name, string memory _origin, uint256 _price) public {

        require(manufacturers[msg.sender] == true, "Only manufacturers can create products");
        require(bytes(_name).length > 0, "Product name cannot be empty");

        require(_price > 0 && _price <= 1000000, "Invalid price range");

        productCounter++;

        Product memory newProduct = Product({
            id: productCounter,
            name: _name,
            manufacturer: msg.sender,
            manufacturingDate: block.timestamp,
            origin: _origin,
            price: _price,
            status: "Manufactured",
            currentOwner: msg.sender
        });

        products[productCounter] = newProduct;


        ProductHistory memory history = ProductHistory({
            from: address(0),
            to: msg.sender,
            timestamp: block.timestamp,
            location: _origin,
            action: "Product Created"
        });
        productHistories[productCounter].push(history);

        emit ProductCreated(productCounter, _name, msg.sender);
    }

    function transferToDistributor(uint256 _productId, address _distributor, string memory _location) public {

        require(_productId > 0 && _productId <= productCounter, "Invalid product ID");
        require(products[_productId].currentOwner == msg.sender, "You don't own this product");
        require(distributors[_distributor] == true, "Invalid distributor");
        require(bytes(_location).length > 0, "Location cannot be empty");


        require(keccak256(bytes(products[_productId].status)) == keccak256(bytes("Manufactured")) ||
                keccak256(bytes(products[_productId].status)) == keccak256(bytes("In Transit")),
                "Invalid product status for transfer");

        products[_productId].currentOwner = _distributor;
        products[_productId].status = "In Transit";


        ProductHistory memory history = ProductHistory({
            from: msg.sender,
            to: _distributor,
            timestamp: block.timestamp,
            location: _location,
            action: "Transferred to Distributor"
        });
        productHistories[_productId].push(history);

        emit ProductTransferred(_productId, msg.sender, _distributor);
        emit StatusUpdated(_productId, "In Transit");
    }

    function transferToRetailer(uint256 _productId, address _retailer, string memory _location) public {

        require(_productId > 0 && _productId <= productCounter, "Invalid product ID");
        require(products[_productId].currentOwner == msg.sender, "You don't own this product");
        require(retailers[_retailer] == true, "Invalid retailer");
        require(bytes(_location).length > 0, "Location cannot be empty");


        require(keccak256(bytes(products[_productId].status)) == keccak256(bytes("In Transit")) ||
                keccak256(bytes(products[_productId].status)) == keccak256(bytes("At Distributor")),
                "Invalid product status for transfer");

        products[_productId].currentOwner = _retailer;
        products[_productId].status = "At Retailer";


        ProductHistory memory history = ProductHistory({
            from: msg.sender,
            to: _retailer,
            timestamp: block.timestamp,
            location: _location,
            action: "Transferred to Retailer"
        });
        productHistories[_productId].push(history);

        emit ProductTransferred(_productId, msg.sender, _retailer);
        emit StatusUpdated(_productId, "At Retailer");
    }

    function sellToConsumer(uint256 _productId, address _consumer, string memory _location) public {

        require(_productId > 0 && _productId <= productCounter, "Invalid product ID");
        require(products[_productId].currentOwner == msg.sender, "You don't own this product");
        require(_consumer != address(0), "Invalid consumer address");
        require(bytes(_location).length > 0, "Location cannot be empty");


        require(keccak256(bytes(products[_productId].status)) == keccak256(bytes("At Retailer")),
                "Product must be at retailer to sell");

        products[_productId].currentOwner = _consumer;
        products[_productId].status = "Sold";


        ProductHistory memory history = ProductHistory({
            from: msg.sender,
            to: _consumer,
            timestamp: block.timestamp,
            location: _location,
            action: "Sold to Consumer"
        });
        productHistories[_productId].push(history);

        emit ProductTransferred(_productId, msg.sender, _consumer);
        emit StatusUpdated(_productId, "Sold");
    }

    function updateProductStatus(uint256 _productId, string memory _newStatus, string memory _location) public {

        require(_productId > 0 && _productId <= productCounter, "Invalid product ID");
        require(products[_productId].currentOwner == msg.sender, "You don't own this product");
        require(bytes(_newStatus).length > 0, "Status cannot be empty");
        require(bytes(_location).length > 0, "Location cannot be empty");

        products[_productId].status = _newStatus;


        ProductHistory memory history = ProductHistory({
            from: msg.sender,
            to: msg.sender,
            timestamp: block.timestamp,
            location: _location,
            action: string(abi.encodePacked("Status updated to: ", _newStatus))
        });
        productHistories[_productId].push(history);

        emit StatusUpdated(_productId, _newStatus);
    }

    function getProduct(uint256 _productId) public view returns (Product memory) {

        require(_productId > 0 && _productId <= productCounter, "Invalid product ID");
        return products[_productId];
    }

    function getProductHistory(uint256 _productId) public view returns (ProductHistory[] memory) {

        require(_productId > 0 && _productId <= productCounter, "Invalid product ID");
        return productHistories[_productId];
    }

    function verifyProduct(uint256 _productId) public view returns (bool, string memory, address, uint256) {

        require(_productId > 0 && _productId <= productCounter, "Invalid product ID");

        Product memory product = products[_productId];
        bool isValid = true;


        if (block.timestamp - product.manufacturingDate > 31536000) {
            isValid = false;
        }

        return (isValid, product.status, product.currentOwner, product.manufacturingDate);
    }

    function getAllProductsByManufacturer(address _manufacturer) public view returns (uint256[] memory) {

        uint256[] memory result = new uint256[](productCounter);
        uint256 count = 0;

        for (uint256 i = 1; i <= productCounter; i++) {
            if (products[i].manufacturer == _manufacturer) {
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

    function getAllProductsByCurrentOwner(address _owner) public view returns (uint256[] memory) {

        uint256[] memory result = new uint256[](productCounter);
        uint256 count = 0;

        for (uint256 i = 1; i <= productCounter; i++) {
            if (products[i].currentOwner == _owner) {
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

    function getProductsByStatus(string memory _status) public view returns (uint256[] memory) {

        uint256[] memory result = new uint256[](productCounter);
        uint256 count = 0;

        for (uint256 i = 1; i <= productCounter; i++) {
            if (keccak256(bytes(products[i].status)) == keccak256(bytes(_status))) {
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


    function getTotalProducts() public view returns (uint256) {
        return productCounter;
    }


    function isManufacturer(address _address) public view returns (bool) {
        return manufacturers[_address];
    }

    function isDistributor(address _address) public view returns (bool) {
        return distributors[_address];
    }

    function isRetailer(address _address) public view returns (bool) {
        return retailers[_address];
    }
}
