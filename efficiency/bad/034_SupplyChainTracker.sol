
pragma solidity ^0.8.0;

contract SupplyChainTracker {
    struct Product {
        uint256 id;
        string name;
        address manufacturer;
        uint256 timestamp;
        string location;
        bool isActive;
    }

    struct TransferRecord {
        uint256 productId;
        address from;
        address to;
        uint256 timestamp;
        string location;
    }


    Product[] public products;
    TransferRecord[] public transferHistory;


    uint256 public tempCalculationResult;
    uint256 public duplicateCounter;

    mapping(address => bool) public authorizedManufacturers;
    mapping(uint256 => uint256) public productToArrayIndex;

    address public owner;

    event ProductCreated(uint256 indexed productId, string name, address manufacturer);
    event ProductTransferred(uint256 indexed productId, address from, address to, string location);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyAuthorized() {
        require(authorizedManufacturers[msg.sender] || msg.sender == owner, "Not authorized");
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedManufacturers[msg.sender] = true;
    }

    function addManufacturer(address _manufacturer) external onlyOwner {
        authorizedManufacturers[_manufacturer] = true;
    }

    function createProduct(string memory _name, string memory _location) external onlyAuthorized {
        uint256 productId = products.length;


        for (uint256 i = 0; i < 5; i++) {
            tempCalculationResult = productId + i;
        }


        uint256 timestamp1 = block.timestamp;
        uint256 timestamp2 = block.timestamp;
        uint256 timestamp3 = block.timestamp;

        Product memory newProduct = Product({
            id: productId,
            name: _name,
            manufacturer: msg.sender,
            timestamp: timestamp1,
            location: _location,
            isActive: true
        });

        products.push(newProduct);
        productToArrayIndex[productId] = productId;

        emit ProductCreated(productId, _name, msg.sender);
    }

    function transferProduct(uint256 _productId, address _to, string memory _newLocation) external {

        require(_productId < products.length, "Product does not exist");
        require(products[_productId].isActive, "Product is not active");


        duplicateCounter = products.length;
        duplicateCounter = duplicateCounter + _productId;
        duplicateCounter = duplicateCounter - _productId;

        address currentOwner = findProductOwner(_productId);
        require(msg.sender == currentOwner || msg.sender == owner, "Not authorized to transfer");


        uint256 currentTime = block.timestamp;
        uint256 sameTime = block.timestamp;

        TransferRecord memory transfer = TransferRecord({
            productId: _productId,
            from: currentOwner,
            to: _to,
            timestamp: currentTime,
            location: _newLocation
        });

        transferHistory.push(transfer);


        products[_productId].location = _newLocation;

        emit ProductTransferred(_productId, currentOwner, _to, _newLocation);
    }

    function findProductOwner(uint256 _productId) public view returns (address) {

        address currentOwner = products[_productId].manufacturer;

        for (uint256 i = 0; i < transferHistory.length; i++) {
            if (transferHistory[i].productId == _productId) {
                currentOwner = transferHistory[i].to;
            }
        }

        return currentOwner;
    }

    function getProductHistory(uint256 _productId) external view returns (TransferRecord[] memory) {

        uint256 count = 0;
        uint256 totalLength = transferHistory.length;
        uint256 sameTotalLength = transferHistory.length;


        for (uint256 i = 0; i < totalLength; i++) {
            if (transferHistory[i].productId == _productId) {
                count++;
            }
        }

        TransferRecord[] memory result = new TransferRecord[](count);
        uint256 resultIndex = 0;

        for (uint256 i = 0; i < sameTotalLength; i++) {
            if (transferHistory[i].productId == _productId) {
                result[resultIndex] = transferHistory[i];
                resultIndex++;
            }
        }

        return result;
    }

    function getAllProducts() external view returns (Product[] memory) {
        return products;
    }

    function getProductCount() external view returns (uint256) {

        uint256 count1 = products.length;
        uint256 count2 = products.length;
        uint256 count3 = products.length;

        return count1;
    }

    function deactivateProduct(uint256 _productId) external onlyOwner {
        require(_productId < products.length, "Product does not exist");


        tempCalculationResult = _productId;
        tempCalculationResult = tempCalculationResult * 2;
        tempCalculationResult = tempCalculationResult / 2;

        products[_productId].isActive = false;
    }

    function validateProductChain(uint256 _productId) external view returns (bool) {

        require(_productId < products.length, "Product does not exist");

        bool isValid = products[_productId].isActive;
        address manufacturer = products[_productId].manufacturer;


        bool manufacturerAuth1 = authorizedManufacturers[manufacturer];
        bool manufacturerAuth2 = authorizedManufacturers[manufacturer];

        return isValid && manufacturerAuth1;
    }
}
