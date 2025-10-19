
pragma solidity ^0.8.0;

contract RealEstateRegistry {
    struct Property {
        string propertyId;
        string location;
        uint256 area;
        address owner;
        uint256 registrationDate;
        bool isActive;
        string propertyType;
        uint256 value;
    }

    mapping(string => Property) public properties;
    mapping(address => string[]) public ownerProperties;
    mapping(string => bool) public propertyExists;

    address public registrar;
    uint256 public totalProperties;

    event PropertyRegistered(
        string indexed propertyId,
        address indexed owner,
        string location,
        uint256 area,
        uint256 value,
        uint256 registrationDate
    );

    event PropertyTransferred(
        string indexed propertyId,
        address indexed previousOwner,
        address indexed newOwner,
        uint256 transferDate
    );

    event PropertyUpdated(
        string indexed propertyId,
        address indexed owner,
        uint256 newValue,
        uint256 updateDate
    );

    event PropertyDeactivated(
        string indexed propertyId,
        address indexed owner,
        uint256 deactivationDate
    );

    event RegistrarChanged(
        address indexed previousRegistrar,
        address indexed newRegistrar
    );

    modifier onlyRegistrar() {
        require(msg.sender == registrar, "Only registrar can perform this action");
        _;
    }

    modifier onlyPropertyOwner(string memory _propertyId) {
        require(propertyExists[_propertyId], "Property does not exist");
        require(properties[_propertyId].owner == msg.sender, "Only property owner can perform this action");
        _;
    }

    modifier propertyMustExist(string memory _propertyId) {
        require(propertyExists[_propertyId], "Property does not exist");
        _;
    }

    modifier propertyMustNotExist(string memory _propertyId) {
        require(!propertyExists[_propertyId], "Property already exists");
        _;
    }

    modifier validAddress(address _address) {
        require(_address != address(0), "Invalid address: cannot be zero address");
        _;
    }

    modifier validPropertyData(string memory _propertyId, uint256 _area, uint256 _value) {
        require(bytes(_propertyId).length > 0, "Property ID cannot be empty");
        require(_area > 0, "Property area must be greater than zero");
        require(_value > 0, "Property value must be greater than zero");
        _;
    }

    constructor() {
        registrar = msg.sender;
    }

    function registerProperty(
        string memory _propertyId,
        string memory _location,
        uint256 _area,
        address _owner,
        string memory _propertyType,
        uint256 _value
    )
        external
        onlyRegistrar
        propertyMustNotExist(_propertyId)
        validAddress(_owner)
        validPropertyData(_propertyId, _area, _value)
    {
        require(bytes(_location).length > 0, "Location cannot be empty");
        require(bytes(_propertyType).length > 0, "Property type cannot be empty");

        Property memory newProperty = Property({
            propertyId: _propertyId,
            location: _location,
            area: _area,
            owner: _owner,
            registrationDate: block.timestamp,
            isActive: true,
            propertyType: _propertyType,
            value: _value
        });

        properties[_propertyId] = newProperty;
        ownerProperties[_owner].push(_propertyId);
        propertyExists[_propertyId] = true;
        totalProperties++;

        emit PropertyRegistered(
            _propertyId,
            _owner,
            _location,
            _area,
            _value,
            block.timestamp
        );
    }

    function transferProperty(
        string memory _propertyId,
        address _newOwner
    )
        external
        propertyMustExist(_propertyId)
        onlyPropertyOwner(_propertyId)
        validAddress(_newOwner)
    {
        Property storage property = properties[_propertyId];
        require(property.isActive, "Cannot transfer inactive property");
        require(property.owner != _newOwner, "Cannot transfer to the same owner");

        address previousOwner = property.owner;


        _removePropertyFromOwner(previousOwner, _propertyId);


        ownerProperties[_newOwner].push(_propertyId);


        property.owner = _newOwner;

        emit PropertyTransferred(
            _propertyId,
            previousOwner,
            _newOwner,
            block.timestamp
        );
    }

    function updatePropertyValue(
        string memory _propertyId,
        uint256 _newValue
    )
        external
        onlyRegistrar
        propertyMustExist(_propertyId)
    {
        require(_newValue > 0, "Property value must be greater than zero");

        Property storage property = properties[_propertyId];
        require(property.isActive, "Cannot update value of inactive property");

        property.value = _newValue;

        emit PropertyUpdated(
            _propertyId,
            property.owner,
            _newValue,
            block.timestamp
        );
    }

    function deactivateProperty(
        string memory _propertyId
    )
        external
        onlyRegistrar
        propertyMustExist(_propertyId)
    {
        Property storage property = properties[_propertyId];
        require(property.isActive, "Property is already inactive");

        property.isActive = false;

        emit PropertyDeactivated(
            _propertyId,
            property.owner,
            block.timestamp
        );
    }

    function changeRegistrar(address _newRegistrar)
        external
        onlyRegistrar
        validAddress(_newRegistrar)
    {
        require(_newRegistrar != registrar, "New registrar cannot be the same as current registrar");

        address previousRegistrar = registrar;
        registrar = _newRegistrar;

        emit RegistrarChanged(previousRegistrar, _newRegistrar);
    }

    function getProperty(string memory _propertyId)
        external
        view
        propertyMustExist(_propertyId)
        returns (
            string memory propertyId,
            string memory location,
            uint256 area,
            address owner,
            uint256 registrationDate,
            bool isActive,
            string memory propertyType,
            uint256 value
        )
    {
        Property memory property = properties[_propertyId];
        return (
            property.propertyId,
            property.location,
            property.area,
            property.owner,
            property.registrationDate,
            property.isActive,
            property.propertyType,
            property.value
        );
    }

    function getOwnerProperties(address _owner)
        external
        view
        validAddress(_owner)
        returns (string[] memory)
    {
        return ownerProperties[_owner];
    }

    function getOwnerPropertyCount(address _owner)
        external
        view
        validAddress(_owner)
        returns (uint256)
    {
        return ownerProperties[_owner].length;
    }

    function isPropertyActive(string memory _propertyId)
        external
        view
        propertyMustExist(_propertyId)
        returns (bool)
    {
        return properties[_propertyId].isActive;
    }

    function _removePropertyFromOwner(address _owner, string memory _propertyId)
        internal
    {
        string[] storage ownerProps = ownerProperties[_owner];
        for (uint256 i = 0; i < ownerProps.length; i++) {
            if (keccak256(bytes(ownerProps[i])) == keccak256(bytes(_propertyId))) {
                ownerProps[i] = ownerProps[ownerProps.length - 1];
                ownerProps.pop();
                break;
            }
        }
    }
}
