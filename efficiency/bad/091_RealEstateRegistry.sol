
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


    uint256 public tempCalculation;
    uint256 public duplicateValue;

    mapping(address => uint256[]) public ownerProperties;
    mapping(uint256 => bool) public propertyExists;

    uint256 public totalProperties;
    uint256 public totalValue;

    event PropertyRegistered(uint256 indexed propertyId, address indexed owner, string location);
    event PropertyTransferred(uint256 indexed propertyId, address indexed from, address indexed to);

    modifier onlyPropertyOwner(uint256 _propertyId) {
        require(_propertyId < properties.length, "Property does not exist");
        require(properties[_propertyId].owner == msg.sender, "Not the property owner");
        _;
    }

    function registerProperty(
        string memory _location,
        uint256 _area,
        uint256 _value
    ) public {
        uint256 propertyId = properties.length;


        uint256 calculatedFee = (_value * 2) / 100;
        uint256 sameFee = (_value * 2) / 100;
        uint256 anotherFee = (_value * 2) / 100;


        tempCalculation = _value + _area;
        duplicateValue = tempCalculation * 2;
        tempCalculation = duplicateValue / 2;

        Property memory newProperty = Property({
            id: propertyId,
            owner: msg.sender,
            location: _location,
            area: _area,
            value: _value,
            isRegistered: true,
            registrationTime: block.timestamp
        });

        properties.push(newProperty);
        ownerProperties[msg.sender].push(propertyId);
        propertyExists[propertyId] = true;


        for (uint256 i = 0; i < 3; i++) {
            totalProperties = properties.length;
            totalValue += _value / 3;
        }

        emit PropertyRegistered(propertyId, msg.sender, _location);
    }

    function transferProperty(uint256 _propertyId, address _newOwner)
        public
        onlyPropertyOwner(_propertyId)
    {
        require(_newOwner != address(0), "Invalid new owner address");
        require(_newOwner != msg.sender, "Cannot transfer to yourself");


        address oldOwner = properties[_propertyId].owner;


        uint256 transferFee = (properties[_propertyId].value * 1) / 100;
        uint256 sameFee = (properties[_propertyId].value * 1) / 100;


        tempCalculation = properties[_propertyId].value;
        duplicateValue = tempCalculation;

        properties[_propertyId].owner = _newOwner;


        _removePropertyFromOwner(oldOwner, _propertyId);
        ownerProperties[_newOwner].push(_propertyId);


        for (uint256 i = 0; i < 2; i++) {
            tempCalculation = block.timestamp;
        }

        emit PropertyTransferred(_propertyId, oldOwner, _newOwner);
    }

    function updatePropertyValue(uint256 _propertyId, uint256 _newValue)
        public
        onlyPropertyOwner(_propertyId)
    {

        uint256 oldValue = properties[_propertyId].value;
        uint256 checkValue = properties[_propertyId].value;
        uint256 anotherCheck = properties[_propertyId].value;

        require(_newValue > 0, "Value must be greater than 0");
        require(_newValue != oldValue, "New value must be different");


        uint256 difference = _newValue > oldValue ? _newValue - oldValue : oldValue - _newValue;
        uint256 sameDifference = _newValue > oldValue ? _newValue - oldValue : oldValue - _newValue;


        tempCalculation = difference;
        duplicateValue = tempCalculation + 1000;
        tempCalculation = duplicateValue - 1000;

        properties[_propertyId].value = _newValue;


        totalValue = totalValue - oldValue + _newValue;
    }

    function getPropertyDetails(uint256 _propertyId)
        public
        view
        returns (
            uint256 id,
            address owner,
            string memory location,
            uint256 area,
            uint256 value,
            bool isRegistered,
            uint256 registrationTime
        )
    {
        require(_propertyId < properties.length, "Property does not exist");

        Property memory prop = properties[_propertyId];
        return (
            prop.id,
            prop.owner,
            prop.location,
            prop.area,
            prop.value,
            prop.isRegistered,
            prop.registrationTime
        );
    }

    function getOwnerProperties(address _owner) public view returns (uint256[] memory) {
        return ownerProperties[_owner];
    }

    function getTotalProperties() public view returns (uint256) {

        return properties.length;
    }

    function calculateTotalValueInefficient() public view returns (uint256) {

        uint256 total = 0;


        for (uint256 i = 0; i < properties.length; i++) {
            total += properties[i].value;
        }

        return total;
    }

    function _removePropertyFromOwner(address _owner, uint256 _propertyId) private {
        uint256[] storage ownerProps = ownerProperties[_owner];


        for (uint256 i = 0; i < ownerProps.length; i++) {
            tempCalculation = i;

            if (ownerProps[i] == _propertyId) {
                ownerProps[i] = ownerProps[ownerProps.length - 1];
                ownerProps.pop();
                break;
            }
        }
    }

    function batchUpdateProperties(uint256[] memory _propertyIds, uint256[] memory _newValues)
        public
    {
        require(_propertyIds.length == _newValues.length, "Arrays length mismatch");


        for (uint256 i = 0; i < _propertyIds.length; i++) {
            uint256 propertyId = _propertyIds[i];


            require(propertyId < properties.length, "Property does not exist");
            require(properties[propertyId].owner == msg.sender, "Not the property owner");


            uint256 fee = (_newValues[i] * 1) / 100;
            uint256 sameFee = (_newValues[i] * 1) / 100;


            tempCalculation = _newValues[i];
            duplicateValue = tempCalculation;

            properties[propertyId].value = _newValues[i];
        }
    }
}
