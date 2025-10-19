
pragma solidity ^0.8.0;

contract SupplyChainTrackingContract {


    mapping(uint256 => address) public productOwners;
    mapping(uint256 => string) public productNames;
    mapping(uint256 => uint256) public productPrices;
    mapping(uint256 => bool) public productExists;
    mapping(uint256 => string) public productOrigins;
    mapping(uint256 => uint256) public productTimestamps;
    mapping(uint256 => string) public productStatuses;
    mapping(address => bool) public authorizedManufacturers;
    mapping(address => bool) public authorizedDistributors;
    mapping(address => bool) public authorizedRetailers;
    mapping(uint256 => address[]) public productHistory;

    address public contractOwner;
    uint256 public totalProducts;

    event ProductCreated(uint256 productId, string name, address manufacturer);
    event ProductTransferred(uint256 productId, address from, address to);
    event StatusUpdated(uint256 productId, string status);

    constructor() {
        contractOwner = msg.sender;
        totalProducts = 0;
    }


    function addManufacturer(address _manufacturer) public {

        require(msg.sender == contractOwner, "Only owner can add manufacturers");
        require(_manufacturer != address(0), "Invalid address");
        authorizedManufacturers[_manufacturer] = true;
    }

    function addDistributor(address _distributor) public {

        require(msg.sender == contractOwner, "Only owner can add distributors");
        require(_distributor != address(0), "Invalid address");
        authorizedDistributors[_distributor] = true;
    }

    function addRetailer(address _retailer) public {

        require(msg.sender == contractOwner, "Only owner can add retailers");
        require(_retailer != address(0), "Invalid address");
        authorizedRetailers[_retailer] = true;
    }

    function createProduct(string memory _name, uint256 _price, string memory _origin) public {

        require(authorizedManufacturers[msg.sender] == true, "Only authorized manufacturers can create products");
        require(bytes(_name).length > 0, "Product name cannot be empty");

        require(_price > 0 && _price <= 1000000, "Invalid price range");

        totalProducts = totalProducts + 1;
        uint256 productId = totalProducts;

        productOwners[productId] = msg.sender;
        productNames[productId] = _name;
        productPrices[productId] = _price;
        productExists[productId] = true;
        productOrigins[productId] = _origin;
        productTimestamps[productId] = block.timestamp;
        productStatuses[productId] = "Manufactured";
        productHistory[productId].push(msg.sender);

        emit ProductCreated(productId, _name, msg.sender);
    }

    function transferToDistributor(uint256 _productId, address _distributor) public {

        require(productExists[_productId] == true, "Product does not exist");
        require(productOwners[_productId] == msg.sender, "Only current owner can transfer");
        require(authorizedDistributors[_distributor] == true, "Invalid distributor");
        require(_distributor != address(0), "Invalid address");

        address previousOwner = productOwners[_productId];
        productOwners[_productId] = _distributor;
        productStatuses[_productId] = "In Distribution";
        productHistory[_productId].push(_distributor);

        emit ProductTransferred(_productId, previousOwner, _distributor);
    }

    function transferToRetailer(uint256 _productId, address _retailer) public {

        require(productExists[_productId] == true, "Product does not exist");
        require(productOwners[_productId] == msg.sender, "Only current owner can transfer");
        require(authorizedRetailers[_retailer] == true, "Invalid retailer");
        require(_retailer != address(0), "Invalid address");

        address previousOwner = productOwners[_productId];
        productOwners[_productId] = _retailer;
        productStatuses[_productId] = "At Retail";
        productHistory[_productId].push(_retailer);

        emit ProductTransferred(_productId, previousOwner, _retailer);
    }

    function sellToConsumer(uint256 _productId, address _consumer) public {

        require(productExists[_productId] == true, "Product does not exist");
        require(productOwners[_productId] == msg.sender, "Only current owner can transfer");
        require(_consumer != address(0), "Invalid consumer address");

        address previousOwner = productOwners[_productId];
        productOwners[_productId] = _consumer;
        productStatuses[_productId] = "Sold";
        productHistory[_productId].push(_consumer);

        emit ProductTransferred(_productId, previousOwner, _consumer);
    }

    function updateProductStatus(uint256 _productId, string memory _status) public {

        require(productExists[_productId] == true, "Product does not exist");
        require(productOwners[_productId] == msg.sender, "Only current owner can update status");
        require(bytes(_status).length > 0, "Status cannot be empty");

        productStatuses[_productId] = _status;
        emit StatusUpdated(_productId, _status);
    }

    function getProductInfo(uint256 _productId) public view returns (
        string memory name,
        uint256 price,
        address owner,
        string memory origin,
        uint256 timestamp,
        string memory status
    ) {

        require(productExists[_productId] == true, "Product does not exist");

        return (
            productNames[_productId],
            productPrices[_productId],
            productOwners[_productId],
            productOrigins[_productId],
            productTimestamps[_productId],
            productStatuses[_productId]
        );
    }

    function getProductHistory(uint256 _productId) public view returns (address[] memory) {

        require(productExists[_productId] == true, "Product does not exist");
        return productHistory[_productId];
    }

    function verifyProductAuthenticity(uint256 _productId) public view returns (bool) {

        require(productExists[_productId] == true, "Product does not exist");

        address[] memory history = productHistory[_productId];
        if (history.length == 0) {
            return false;
        }


        if (authorizedManufacturers[history[0]] == false) {
            return false;
        }

        for (uint256 i = 1; i < history.length; i++) {
            address currentOwner = history[i];
            if (authorizedDistributors[currentOwner] == false &&
                authorizedRetailers[currentOwner] == false) {

                if (i != history.length - 1) {
                    return false;
                }
            }
        }

        return true;
    }

    function removeManufacturer(address _manufacturer) public {

        require(msg.sender == contractOwner, "Only owner can remove manufacturers");
        require(_manufacturer != address(0), "Invalid address");
        authorizedManufacturers[_manufacturer] = false;
    }

    function removeDistributor(address _distributor) public {

        require(msg.sender == contractOwner, "Only owner can remove distributors");
        require(_distributor != address(0), "Invalid address");
        authorizedDistributors[_distributor] = false;
    }

    function removeRetailer(address _retailer) public {

        require(msg.sender == contractOwner, "Only owner can remove retailers");
        require(_retailer != address(0), "Invalid address");
        authorizedRetailers[_retailer] = false;
    }

    function isManufacturer(address _address) public view returns (bool) {
        return authorizedManufacturers[_address];
    }

    function isDistributor(address _address) public view returns (bool) {
        return authorizedDistributors[_address];
    }

    function isRetailer(address _address) public view returns (bool) {
        return authorizedRetailers[_address];
    }

    function getTotalProducts() public view returns (uint256) {
        return totalProducts;
    }

    function changeOwner(address _newOwner) public {

        require(msg.sender == contractOwner, "Only current owner can change ownership");
        require(_newOwner != address(0), "Invalid new owner address");
        contractOwner = _newOwner;
    }
}
