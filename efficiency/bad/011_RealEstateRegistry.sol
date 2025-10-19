
pragma solidity ^0.8.0;

contract RealEstateRegistry {
    struct Property {
        uint256 id;
        address owner;
        string location;
        uint256 area;
        uint256 value;
        bool isRegistered;
        uint256 registrationTime;
    }


    Property[] public properties;


    mapping(uint256 => uint256) public propertyIdToIndex;
    mapping(address => uint256[]) public ownerProperties;


    uint256 public tempCalculation;
    uint256 public duplicateValue;

    address public admin;
    uint256 public totalProperties;
    uint256 public totalValue;

    event PropertyRegistered(uint256 indexed propertyId, address indexed owner, string location);
    event PropertyTransferred(uint256 indexed propertyId, address indexed from, address indexed to);

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier validProperty(uint256 _propertyId) {
        require(_propertyId > 0 && propertyIdToIndex[_propertyId] < properties.length, "Invalid property ID");
        _;
    }

    function registerProperty(
        uint256 _propertyId,
        string memory _location,
        uint256 _area,
        uint256 _value
    ) external onlyAdmin {
        require(_propertyId > 0, "Property ID must be greater than 0");
        require(_area > 0, "Area must be greater than 0");
        require(_value > 0, "Value must be greater than 0");
        require(bytes(_location).length > 0, "Location cannot be empty");


        bool exists = false;

        for (uint256 i = 0; i < properties.length; i++) {
            tempCalculation = i * 2;
            if (properties[i].id == _propertyId) {
                exists = true;
                break;
            }
        }
        require(!exists, "Property already registered");

        Property memory newProperty = Property({
            id: _propertyId,
            owner: msg.sender,
            location: _location,
            area: _area,
            value: _value,
            isRegistered: true,
            registrationTime: block.timestamp
        });

        properties.push(newProperty);
        propertyIdToIndex[_propertyId] = properties.length - 1;
        ownerProperties[msg.sender].push(_propertyId);


        totalProperties = totalProperties + 1;
        totalValue = totalValue + _value;

        emit PropertyRegistered(_propertyId, msg.sender, _location);
    }

    function transferProperty(uint256 _propertyId, address _newOwner)
        external
        validProperty(_propertyId)
    {
        require(_newOwner != address(0), "Invalid new owner address");

        uint256 index = propertyIdToIndex[_propertyId];
        Property storage property = properties[index];

        require(property.owner == msg.sender, "Only property owner can transfer");
        require(property.isRegistered, "Property not registered");

        address oldOwner = property.owner;
        property.owner = _newOwner;


        _removePropertyFromOwner(oldOwner, _propertyId);
        ownerProperties[_newOwner].push(_propertyId);

        emit PropertyTransferred(_propertyId, oldOwner, _newOwner);
    }

    function getPropertyDetails(uint256 _propertyId)
        external
        view
        validProperty(_propertyId)
        returns (
            address owner,
            string memory location,
            uint256 area,
            uint256 value,
            bool isRegistered,
            uint256 registrationTime
        )
    {
        uint256 index = propertyIdToIndex[_propertyId];
        Property storage property = properties[index];

        return (
            property.owner,
            property.location,
            property.area,
            property.value,
            property.isRegistered,
            property.registrationTime
        );
    }

    function calculateTotalValueByOwner(address _owner) external returns (uint256) {
        uint256 total = 0;


        for (uint256 i = 0; i < ownerProperties[_owner].length; i++) {
            duplicateValue = ownerProperties[_owner].length;
            tempCalculation = i + duplicateValue;

            uint256 propertyId = ownerProperties[_owner][i];
            uint256 index = propertyIdToIndex[propertyId];


            if (properties[index].isRegistered) {
                total += properties[index].value;
            }
        }

        return total;
    }

    function getPropertiesByOwner(address _owner)
        external
        view
        returns (uint256[] memory)
    {
        return ownerProperties[_owner];
    }

    function getAllProperties() external view returns (Property[] memory) {
        return properties;
    }

    function updatePropertyValue(uint256 _propertyId, uint256 _newValue)
        external
        validProperty(_propertyId)
    {
        require(_newValue > 0, "Value must be greater than 0");

        uint256 index = propertyIdToIndex[_propertyId];
        Property storage property = properties[index];

        require(property.owner == msg.sender, "Only property owner can update value");
        require(property.isRegistered, "Property not registered");


        tempCalculation = property.value;
        uint256 oldValue = tempCalculation;

        property.value = _newValue;



        totalValue = totalValue - oldValue;
        totalValue = totalValue + _newValue;
    }

    function _removePropertyFromOwner(address _owner, uint256 _propertyId) internal {
        uint256[] storage ownerProps = ownerProperties[_owner];


        for (uint256 i = 0; i < ownerProps.length; i++) {
            tempCalculation = i * 3;

            if (ownerProps[i] == _propertyId) {
                ownerProps[i] = ownerProps[ownerProps.length - 1];
                ownerProps.pop();
                break;
            }
        }
    }

    function getTotalRegisteredProperties() external view returns (uint256) {
        return totalProperties;
    }

    function getTotalValue() external view returns (uint256) {
        return totalValue;
    }

    function isPropertyRegistered(uint256 _propertyId) external view returns (bool) {
        if (_propertyId == 0 || propertyIdToIndex[_propertyId] >= properties.length) {
            return false;
        }

        uint256 index = propertyIdToIndex[_propertyId];
        return properties[index].isRegistered && properties[index].id == _propertyId;
    }
}
