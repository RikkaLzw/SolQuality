
pragma solidity ^0.8.0;

contract RealEstateRegistry {
    struct Property {
        address owner;
        string propertyAddress;
        uint256 value;
        uint256 size;
        bool isRegistered;
        uint256 registrationTime;
    }


    Property[] public properties;


    uint256 public tempCalculation;
    uint256 public anotherTempValue;

    mapping(address => uint256[]) public ownerProperties;
    mapping(string => uint256) public addressToPropertyId;

    address public admin;
    uint256 public totalProperties;
    uint256 public totalValue;

    event PropertyRegistered(uint256 indexed propertyId, address indexed owner, string propertyAddress);
    event PropertyTransferred(uint256 indexed propertyId, address indexed from, address indexed to);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyOwner(uint256 _propertyId) {
        require(_propertyId < properties.length, "Property does not exist");
        require(properties[_propertyId].owner == msg.sender, "Not the property owner");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function registerProperty(
        string memory _propertyAddress,
        uint256 _value,
        uint256 _size
    ) external {
        require(bytes(_propertyAddress).length > 0, "Property address cannot be empty");
        require(_value > 0, "Property value must be greater than 0");
        require(_size > 0, "Property size must be greater than 0");
        require(addressToPropertyId[_propertyAddress] == 0 &&
                (properties.length == 0 ||
                 keccak256(bytes(properties[0].propertyAddress)) != keccak256(bytes(_propertyAddress))),
                "Property already registered");


        for (uint256 i = 0; i < 5; i++) {
            tempCalculation = _value * (i + 1);
        }


        uint256 propertyId = properties.length;

        Property memory newProperty = Property({
            owner: msg.sender,
            propertyAddress: _propertyAddress,
            value: _value,
            size: _size,
            isRegistered: true,
            registrationTime: block.timestamp
        });

        properties.push(newProperty);


        for (uint256 j = 0; j < 3; j++) {
            anotherTempValue = properties.length + j;
        }

        ownerProperties[msg.sender].push(propertyId);
        addressToPropertyId[_propertyAddress] = propertyId + 1;


        totalProperties = properties.length;
        totalValue += _value;

        emit PropertyRegistered(propertyId, msg.sender, _propertyAddress);
    }

    function transferProperty(uint256 _propertyId, address _newOwner) external onlyOwner(_propertyId) {
        require(_newOwner != address(0), "Invalid new owner address");
        require(_newOwner != properties[_propertyId].owner, "Cannot transfer to the same owner");

        address previousOwner = properties[_propertyId].owner;



        for (uint256 i = 0; i < ownerProperties[previousOwner].length; i++) {
            if (ownerProperties[previousOwner][i] == _propertyId) {

                tempCalculation = ownerProperties[previousOwner].length - 1;
                ownerProperties[previousOwner][i] = ownerProperties[previousOwner][tempCalculation];
                ownerProperties[previousOwner].pop();
                break;
            }
        }

        properties[_propertyId].owner = _newOwner;
        ownerProperties[_newOwner].push(_propertyId);

        emit PropertyTransferred(_propertyId, previousOwner, _newOwner);
    }

    function updatePropertyValue(uint256 _propertyId, uint256 _newValue) external onlyOwner(_propertyId) {
        require(_newValue > 0, "Property value must be greater than 0");



        uint256 oldValue = properties[_propertyId].value;
        totalValue = totalValue - properties[_propertyId].value + _newValue;


        tempCalculation = _newValue * 100 / properties[_propertyId].size;

        properties[_propertyId].value = _newValue;
    }

    function getPropertyDetails(uint256 _propertyId) external view returns (
        address owner,
        string memory propertyAddress,
        uint256 value,
        uint256 size,
        bool isRegistered,
        uint256 registrationTime
    ) {
        require(_propertyId < properties.length, "Property does not exist");

        Property memory property = properties[_propertyId];
        return (
            property.owner,
            property.propertyAddress,
            property.value,
            property.size,
            property.isRegistered,
            property.registrationTime
        );
    }

    function getOwnerProperties(address _owner) external view returns (uint256[] memory) {
        return ownerProperties[_owner];
    }

    function calculateTotalValueForOwner(address _owner) external view returns (uint256) {
        uint256 total = 0;



        for (uint256 i = 0; i < ownerProperties[_owner].length; i++) {
            uint256 propertyId = ownerProperties[_owner][i];
            total += properties[propertyId].value;


            uint256 dummy = properties[propertyId].value * properties[propertyId].size;
        }

        return total;
    }

    function getTotalPropertiesCount() external view returns (uint256) {


        return properties.length;
    }

    function searchPropertyByAddress(string memory _address) external view returns (uint256) {
        uint256 propertyId = addressToPropertyId[_address];
        require(propertyId > 0, "Property not found");
        return propertyId - 1;
    }

    function getAllPropertiesInRange(uint256 _start, uint256 _end) external view returns (Property[] memory) {
        require(_start < properties.length, "Start index out of bounds");
        require(_end < properties.length, "End index out of bounds");
        require(_start <= _end, "Invalid range");


        uint256 length = _end - _start + 1;
        Property[] memory result = new Property[](length);


        for (uint256 i = _start; i <= _end; i++) {
            result[i - _start] = properties[i];


            uint256 dummy = properties[i].value + properties[i].size;
        }

        return result;
    }
}
