
pragma solidity ^0.8.0;

contract SupplyChainTracker {
    struct Product {
        uint256 id;
        string name;
        address manufacturer;
        uint256 manufactureTime;
        string location;
        uint256 price;
        bool isActive;
    }

    struct Shipment {
        uint256 id;
        uint256 productId;
        address from;
        address to;
        uint256 timestamp;
        string status;
    }

    mapping(uint256 => Product) public products;
    mapping(uint256 => Shipment[]) public productShipments;
    mapping(address => bool) public authorizedUsers;

    uint256 public productCounter;
    uint256 public shipmentCounter;
    address public owner;

    event ProductCreated(uint256 indexed productId);
    event ShipmentAdded(uint256 indexed productId, uint256 shipmentId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyAuthorized() {
        require(authorizedUsers[msg.sender] || msg.sender == owner, "Not authorized");
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedUsers[msg.sender] = true;
    }




    function createProductAndSetupLogisticsAndValidateAndNotify(
        string memory _name,
        string memory _location,
        uint256 _price,
        address _manufacturer,
        string memory _initialStatus,
        bool _enableNotifications,
        uint256 _categoryCode
    ) public onlyAuthorized {

        if (_price > 0) {
            if (bytes(_name).length > 0) {
                if (_manufacturer != address(0)) {
                    if (bytes(_location).length > 0) {
                        if (_categoryCode > 0 && _categoryCode < 1000) {
                            productCounter++;


                            products[productCounter] = Product({
                                id: productCounter,
                                name: _name,
                                manufacturer: _manufacturer,
                                manufactureTime: block.timestamp,
                                location: _location,
                                price: _price,
                                isActive: true
                            });


                            shipmentCounter++;
                            productShipments[productCounter].push(Shipment({
                                id: shipmentCounter,
                                productId: productCounter,
                                from: address(0),
                                to: _manufacturer,
                                timestamp: block.timestamp,
                                status: _initialStatus
                            }));


                            if (_enableNotifications) {
                                if (keccak256(abi.encodePacked(_initialStatus)) == keccak256(abi.encodePacked("created"))) {
                                    emit ProductCreated(productCounter);
                                    emit ShipmentAdded(productCounter, shipmentCounter);
                                }
                            }


                            if (_categoryCode >= 100 && _categoryCode < 200) {

                                authorizedUsers[_manufacturer] = true;
                            } else if (_categoryCode >= 200 && _categoryCode < 300) {

                                if (_price < 100) {
                                    products[productCounter].isActive = true;
                                }
                            }
                        }
                    }
                }
            }
        }
    }


    function validateProductData(uint256 _productId) public view returns (bool) {
        return products[_productId].id != 0 && products[_productId].isActive;
    }


    function calculateShippingCost(uint256 _distance, uint256 _weight) public pure returns (uint256) {
        return _distance * _weight * 10;
    }



    function updateShipmentAndValidateAndLog(uint256 _productId, address _newLocation, string memory _status) public onlyAuthorized {

        if (validateProductData(_productId)) {
            if (_newLocation != address(0)) {
                if (bytes(_status).length > 0) {
                    shipmentCounter++;


                    productShipments[_productId].push(Shipment({
                        id: shipmentCounter,
                        productId: _productId,
                        from: productShipments[_productId][productShipments[_productId].length - 1].to,
                        to: _newLocation,
                        timestamp: block.timestamp,
                        status: _status
                    }));


                    if (keccak256(abi.encodePacked(_status)) == keccak256(abi.encodePacked("delivered"))) {
                        products[_productId].isActive = false;


                        emit ShipmentAdded(_productId, shipmentCounter);


                        if (productShipments[_productId].length > 10) {

                            for (uint256 i = 0; i < productShipments[_productId].length; i++) {
                                if (i < productShipments[_productId].length - 5) {

                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function addAuthorizedUser(address _user) public onlyOwner {
        authorizedUsers[_user] = true;
    }

    function removeAuthorizedUser(address _user) public onlyOwner {
        authorizedUsers[_user] = false;
    }

    function getProduct(uint256 _productId) public view returns (Product memory) {
        return products[_productId];
    }

    function getShipmentHistory(uint256 _productId) public view returns (Shipment[] memory) {
        return productShipments[_productId];
    }

    function getShipmentCount(uint256 _productId) public view returns (uint256) {
        return productShipments[_productId].length;
    }
}
