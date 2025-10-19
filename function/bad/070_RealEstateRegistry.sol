
pragma solidity ^0.8.0;

contract RealEstateRegistry {

    struct Property {
        string propertyAddress;
        uint256 area;
        uint256 price;
        address owner;
        bool isRegistered;
        uint256 registrationDate;
        string propertyType;
        bool isMortgaged;
    }

    mapping(uint256 => Property) public properties;
    mapping(address => uint256[]) public ownerProperties;
    mapping(uint256 => address[]) public propertyHistory;

    uint256 public propertyCounter;
    address public registryAdmin;

    event PropertyRegistered(uint256 propertyId, address owner);
    event PropertyTransferred(uint256 propertyId, address from, address to);

    constructor() {
        registryAdmin = msg.sender;
        propertyCounter = 0;
    }





    function registerPropertyAndSetupOwnershipWithValidationAndHistoryTracking(
        string memory _address,
        uint256 _area,
        uint256 _price,
        string memory _propertyType,
        bool _isMortgaged,
        address _owner,
        bool _validateOwner
    ) public returns (uint256) {
        require(bytes(_address).length > 0, "Address required");
        require(_area > 0, "Area must be positive");
        require(_price > 0, "Price must be positive");

        propertyCounter++;
        uint256 newPropertyId = propertyCounter;


        if (_validateOwner) {
            if (_owner != address(0)) {
                if (ownerProperties[_owner].length > 0) {
                    for (uint256 i = 0; i < ownerProperties[_owner].length; i++) {
                        if (properties[ownerProperties[_owner][i]].isRegistered) {
                            if (keccak256(bytes(properties[ownerProperties[_owner][i]].propertyAddress)) == keccak256(bytes(_address))) {
                                revert("Property already registered to this owner");
                            }
                        }
                    }
                } else {

                    if (_isMortgaged) {
                        if (_price > 1000000) {

                            require(msg.sender == registryAdmin, "Admin approval required for high-value mortgaged properties");
                        }
                    }
                }
            }
        }


        properties[newPropertyId] = Property({
            propertyAddress: _address,
            area: _area,
            price: _price,
            owner: _owner,
            isRegistered: true,
            registrationDate: block.timestamp,
            propertyType: _propertyType,
            isMortgaged: _isMortgaged
        });


        ownerProperties[_owner].push(newPropertyId);


        propertyHistory[newPropertyId].push(_owner);


        emit PropertyRegistered(newPropertyId, _owner);


        if (keccak256(bytes(_propertyType)) == keccak256(bytes("residential"))) {

        } else if (keccak256(bytes(_propertyType)) == keccak256(bytes("commercial"))) {

        }

        return newPropertyId;
    }


    function validatePropertyOwnership(uint256 _propertyId, address _owner) public view returns (bool) {
        return properties[_propertyId].owner == _owner && properties[_propertyId].isRegistered;
    }


    function calculateTransferFee(uint256 _price) public pure returns (uint256) {
        return _price * 2 / 100;
    }



    function transferPropertyWithFeesAndValidation(uint256 _propertyId, address _newOwner) public {
        require(properties[_propertyId].isRegistered, "Property not registered");
        require(properties[_propertyId].owner == msg.sender, "Not property owner");
        require(_newOwner != address(0), "Invalid new owner");
        require(_newOwner != msg.sender, "Cannot transfer to self");

        address currentOwner = properties[_propertyId].owner;


        if (properties[_propertyId].isMortgaged) {
            if (properties[_propertyId].price > 500000) {
                if (ownerProperties[_newOwner].length > 5) {
                    revert("New owner has too many properties for mortgaged transfer");
                } else {
                    if (ownerProperties[_newOwner].length > 0) {
                        for (uint256 i = 0; i < ownerProperties[_newOwner].length; i++) {
                            if (properties[ownerProperties[_newOwner][i]].isMortgaged) {
                                revert("New owner already has mortgaged property");
                            }
                        }
                    }
                }
            }
        }


        properties[_propertyId].owner = _newOwner;


        uint256[] storage currentOwnerProperties = ownerProperties[currentOwner];
        for (uint256 i = 0; i < currentOwnerProperties.length; i++) {
            if (currentOwnerProperties[i] == _propertyId) {
                currentOwnerProperties[i] = currentOwnerProperties[currentOwnerProperties.length - 1];
                currentOwnerProperties.pop();
                break;
            }
        }


        ownerProperties[_newOwner].push(_propertyId);


        propertyHistory[_propertyId].push(_newOwner);


        uint256 transferFee = calculateTransferFee(properties[_propertyId].price);

        emit PropertyTransferred(_propertyId, currentOwner, _newOwner);
    }


    function getOwnerProperties(address _owner) public view returns (uint256[] memory) {
        return ownerProperties[_owner];
    }


    function getPropertyHistory(uint256 _propertyId) public view returns (address[] memory) {
        return propertyHistory[_propertyId];
    }


    function isValidPropertyType(string memory _propertyType) public pure returns (bool) {
        return (keccak256(bytes(_propertyType)) == keccak256(bytes("residential")) ||
                keccak256(bytes(_propertyType)) == keccak256(bytes("commercial")) ||
                keccak256(bytes(_propertyType)) == keccak256(bytes("industrial")));
    }

    function getProperty(uint256 _propertyId) public view returns (
        string memory propertyAddress,
        uint256 area,
        uint256 price,
        address owner,
        bool isRegistered,
        uint256 registrationDate,
        string memory propertyType,
        bool isMortgaged
    ) {
        Property memory prop = properties[_propertyId];
        return (
            prop.propertyAddress,
            prop.area,
            prop.price,
            prop.owner,
            prop.isRegistered,
            prop.registrationDate,
            prop.propertyType,
            prop.isMortgaged
        );
    }

    function updatePropertyPrice(uint256 _propertyId, uint256 _newPrice) public {
        require(properties[_propertyId].isRegistered, "Property not registered");
        require(properties[_propertyId].owner == msg.sender, "Not property owner");
        require(_newPrice > 0, "Price must be positive");

        properties[_propertyId].price = _newPrice;
    }

    function getTotalProperties() public view returns (uint256) {
        return propertyCounter;
    }
}
