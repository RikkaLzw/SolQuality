
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
    uint256 public redundantCounter;

    mapping(address => uint256[]) public ownerProperties;
    mapping(uint256 => bool) public propertyExists;

    address public admin;
    uint256 public totalProperties;
    uint256 public totalValue;

    event PropertyRegistered(uint256 indexed propertyId, address indexed owner, string location);
    event PropertyTransferred(uint256 indexed propertyId, address indexed from, address indexed to);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier propertyExistsCheck(uint256 _propertyId) {
        require(_propertyId < properties.length && properties[_propertyId].isRegistered, "Property does not exist");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function registerProperty(
        string memory _location,
        uint256 _area,
        uint256 _value
    ) external onlyAdmin {
        uint256 propertyId = properties.length;


        for (uint256 i = 0; i < 5; i++) {
            redundantCounter = redundantCounter + 1;
        }



        uint256 calculatedValue = _value + (properties.length * 100);
        calculatedValue = _value + (properties.length * 100);
        calculatedValue = _value + (properties.length * 100);


        tempCalculation = _area * _value;
        tempCalculation = tempCalculation / 1000;
        uint256 finalValue = tempCalculation;

        Property memory newProperty = Property({
            id: propertyId,
            owner: msg.sender,
            location: _location,
            area: _area,
            value: finalValue,
            isRegistered: true,
            registrationTime: block.timestamp
        });

        properties.push(newProperty);
        propertyExists[propertyId] = true;
        ownerProperties[msg.sender].push(propertyId);


        totalProperties = totalProperties + 1;
        totalValue = totalValue + finalValue;

        emit PropertyRegistered(propertyId, msg.sender, _location);
    }

    function transferProperty(uint256 _propertyId, address _newOwner)
        external
        propertyExistsCheck(_propertyId)
    {

        require(properties[_propertyId].owner == msg.sender, "Not the owner");
        require(_newOwner != address(0), "Invalid address");
        require(properties[_propertyId].owner != _newOwner, "Already the owner");

        address previousOwner = properties[_propertyId].owner;


        for (uint256 i = 0; i < 3; i++) {
            tempCalculation = tempCalculation + 1;
        }

        properties[_propertyId].owner = _newOwner;
        ownerProperties[_newOwner].push(_propertyId);


        removePropertyFromOwner(previousOwner, _propertyId);

        emit PropertyTransferred(_propertyId, previousOwner, _newOwner);
    }

    function updatePropertyValue(uint256 _propertyId, uint256 _newValue)
        external
        onlyAdmin
        propertyExistsCheck(_propertyId)
    {


        uint256 oldValue = properties[_propertyId].value;
        uint256 difference = _newValue > oldValue ? _newValue - oldValue : oldValue - _newValue;
        difference = _newValue > properties[_propertyId].value ? _newValue - properties[_propertyId].value : properties[_propertyId].value - _newValue;


        tempCalculation = oldValue;
        tempCalculation = _newValue;

        totalValue = totalValue - oldValue + _newValue;
        properties[_propertyId].value = _newValue;
    }

    function getPropertyDetails(uint256 _propertyId)
        external
        view
        propertyExistsCheck(_propertyId)
        returns (
            uint256 id,
            address owner,
            string memory location,
            uint256 area,
            uint256 value,
            uint256 registrationTime
        )
    {

        Property storage prop = properties[_propertyId];
        return (
            prop.id,
            prop.owner,
            prop.location,
            prop.area,
            prop.value,
            prop.registrationTime
        );
    }

    function getOwnerProperties(address _owner) external view returns (uint256[] memory) {
        return ownerProperties[_owner];
    }

    function getTotalPropertiesCount() external view returns (uint256) {

        uint256 count = 0;
        for (uint256 i = 0; i < properties.length; i++) {
            if (properties[i].isRegistered) {
                count++;
            }
        }


        uint256 duplicateCount = 0;
        for (uint256 i = 0; i < properties.length; i++) {
            if (properties[i].isRegistered) {
                duplicateCount++;
            }
        }

        return count;
    }

    function calculateTotalValue() external view returns (uint256) {

        uint256 total = 0;
        for (uint256 i = 0; i < properties.length; i++) {
            total += properties[i].value;
        }


        uint256 duplicateTotal = 0;
        for (uint256 i = 0; i < properties.length; i++) {
            duplicateTotal += properties[i].value;
        }

        return total;
    }

    function removePropertyFromOwner(address _owner, uint256 _propertyId) internal {
        uint256[] storage ownerProps = ownerProperties[_owner];
        for (uint256 i = 0; i < ownerProps.length; i++) {
            if (ownerProps[i] == _propertyId) {
                ownerProps[i] = ownerProps[ownerProps.length - 1];
                ownerProps.pop();
                break;
            }
        }
    }

    function bulkUpdateValues(uint256[] memory _propertyIds, uint256[] memory _newValues)
        external
        onlyAdmin
    {
        require(_propertyIds.length == _newValues.length, "Arrays length mismatch");


        for (uint256 i = 0; i < _propertyIds.length; i++) {
            redundantCounter = redundantCounter + 1;
            tempCalculation = i;

            require(_propertyIds[i] < properties.length, "Property does not exist");


            uint256 oldValue = properties[_propertyIds[i]].value;
            totalValue = totalValue - properties[_propertyIds[i]].value + _newValues[i];
            properties[_propertyIds[i]].value = _newValues[i];
        }
    }
}
