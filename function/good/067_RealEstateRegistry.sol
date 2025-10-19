
pragma solidity ^0.8.0;

contract RealEstateRegistry {
    struct Property {
        uint256 id;
        string location;
        uint256 area;
        address owner;
        bool isRegistered;
        uint256 registrationTime;
    }

    mapping(uint256 => Property) private properties;
    mapping(address => uint256[]) private ownerProperties;
    mapping(string => bool) private locationExists;

    uint256 private nextPropertyId;
    address private registrar;

    event PropertyRegistered(uint256 indexed propertyId, address indexed owner, string location);
    event PropertyTransferred(uint256 indexed propertyId, address indexed from, address indexed to);
    event RegistrarChanged(address indexed oldRegistrar, address indexed newRegistrar);

    modifier onlyRegistrar() {
        require(msg.sender == registrar, "Only registrar can perform this action");
        _;
    }

    modifier onlyPropertyOwner(uint256 propertyId) {
        require(properties[propertyId].owner == msg.sender, "Only property owner can perform this action");
        _;
    }

    modifier propertyExists(uint256 propertyId) {
        require(properties[propertyId].isRegistered, "Property does not exist");
        _;
    }

    constructor() {
        registrar = msg.sender;
        nextPropertyId = 1;
    }

    function registerProperty(string memory location, uint256 area, address owner)
        external
        onlyRegistrar
        returns (uint256)
    {
        require(bytes(location).length > 0, "Location cannot be empty");
        require(area > 0, "Area must be greater than zero");
        require(owner != address(0), "Invalid owner address");
        require(!locationExists[location], "Property at this location already exists");

        uint256 propertyId = nextPropertyId;

        properties[propertyId] = Property({
            id: propertyId,
            location: location,
            area: area,
            owner: owner,
            isRegistered: true,
            registrationTime: block.timestamp
        });

        ownerProperties[owner].push(propertyId);
        locationExists[location] = true;
        nextPropertyId++;

        emit PropertyRegistered(propertyId, owner, location);
        return propertyId;
    }

    function transferProperty(uint256 propertyId, address newOwner)
        external
        onlyPropertyOwner(propertyId)
        propertyExists(propertyId)
    {
        require(newOwner != address(0), "Invalid new owner address");
        require(newOwner != properties[propertyId].owner, "Cannot transfer to current owner");

        address currentOwner = properties[propertyId].owner;
        properties[propertyId].owner = newOwner;

        _removePropertyFromOwner(currentOwner, propertyId);
        ownerProperties[newOwner].push(propertyId);

        emit PropertyTransferred(propertyId, currentOwner, newOwner);
    }

    function getProperty(uint256 propertyId)
        external
        view
        propertyExists(propertyId)
        returns (uint256, string memory, uint256, address, uint256)
    {
        Property memory property = properties[propertyId];
        return (
            property.id,
            property.location,
            property.area,
            property.owner,
            property.registrationTime
        );
    }

    function getOwnerProperties(address owner)
        external
        view
        returns (uint256[] memory)
    {
        return ownerProperties[owner];
    }

    function isPropertyOwner(uint256 propertyId, address account)
        external
        view
        propertyExists(propertyId)
        returns (bool)
    {
        return properties[propertyId].owner == account;
    }

    function changeRegistrar(address newRegistrar)
        external
        onlyRegistrar
    {
        require(newRegistrar != address(0), "Invalid registrar address");
        require(newRegistrar != registrar, "Cannot set same registrar");

        address oldRegistrar = registrar;
        registrar = newRegistrar;

        emit RegistrarChanged(oldRegistrar, newRegistrar);
    }

    function getRegistrar() external view returns (address) {
        return registrar;
    }

    function getTotalProperties() external view returns (uint256) {
        return nextPropertyId - 1;
    }

    function _removePropertyFromOwner(address owner, uint256 propertyId) private {
        uint256[] storage properties = ownerProperties[owner];
        for (uint256 i = 0; i < properties.length; i++) {
            if (properties[i] == propertyId) {
                properties[i] = properties[properties.length - 1];
                properties.pop();
                break;
            }
        }
    }
}
