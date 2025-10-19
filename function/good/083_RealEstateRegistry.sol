
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
    event OwnershipTransferred(uint256 indexed propertyId, address indexed from, address indexed to);
    event PropertyUpdated(uint256 indexed propertyId, string newLocation, uint256 newArea);

    modifier onlyRegistrar() {
        require(msg.sender == registrar, "Only registrar can perform this action");
        _;
    }

    modifier onlyOwner(uint256 propertyId) {
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

    function registerProperty(
        string memory location,
        uint256 area,
        address owner
    ) external onlyRegistrar returns (uint256) {
        require(bytes(location).length > 0, "Location cannot be empty");
        require(area > 0, "Area must be greater than zero");
        require(owner != address(0), "Invalid owner address");
        require(!locationExists[location], "Property already registered at this location");

        uint256 propertyId = nextPropertyId;
        nextPropertyId++;

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

        emit PropertyRegistered(propertyId, owner, location);
        return propertyId;
    }

    function transferOwnership(
        uint256 propertyId,
        address newOwner
    ) external onlyOwner(propertyId) propertyExists(propertyId) {
        require(newOwner != address(0), "Invalid new owner address");
        require(newOwner != properties[propertyId].owner, "Cannot transfer to current owner");

        address currentOwner = properties[propertyId].owner;
        properties[propertyId].owner = newOwner;

        _removePropertyFromOwner(currentOwner, propertyId);
        ownerProperties[newOwner].push(propertyId);

        emit OwnershipTransferred(propertyId, currentOwner, newOwner);
    }

    function updateProperty(
        uint256 propertyId,
        string memory newLocation,
        uint256 newArea
    ) external onlyRegistrar propertyExists(propertyId) {
        require(bytes(newLocation).length > 0, "Location cannot be empty");
        require(newArea > 0, "Area must be greater than zero");

        string memory oldLocation = properties[propertyId].location;

        if (keccak256(bytes(oldLocation)) != keccak256(bytes(newLocation))) {
            require(!locationExists[newLocation], "Property already exists at new location");
            locationExists[oldLocation] = false;
            locationExists[newLocation] = true;
        }

        properties[propertyId].location = newLocation;
        properties[propertyId].area = newArea;

        emit PropertyUpdated(propertyId, newLocation, newArea);
    }

    function getProperty(uint256 propertyId) external view propertyExists(propertyId) returns (
        uint256 id,
        string memory location,
        uint256 area,
        address owner
    ) {
        Property memory prop = properties[propertyId];
        return (prop.id, prop.location, prop.area, prop.owner);
    }

    function getOwnerProperties(address owner) external view returns (uint256[] memory) {
        return ownerProperties[owner];
    }

    function isPropertyRegistered(uint256 propertyId) external view returns (bool) {
        return properties[propertyId].isRegistered;
    }

    function getRegistrar() external view returns (address) {
        return registrar;
    }

    function _removePropertyFromOwner(address owner, uint256 propertyId) private {
        uint256[] storage ownerProps = ownerProperties[owner];
        for (uint256 i = 0; i < ownerProps.length; i++) {
            if (ownerProps[i] == propertyId) {
                ownerProps[i] = ownerProps[ownerProps.length - 1];
                ownerProps.pop();
                break;
            }
        }
    }
}
