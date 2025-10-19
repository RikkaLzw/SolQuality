
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

    mapping(uint256 => Property) public properties;
    mapping(address => uint256[]) public ownerProperties;
    mapping(string => bool) public locationExists;

    uint256 public nextPropertyId;
    address public admin;

    event PropertyRegistered(uint256 indexed propertyId, address indexed owner, string location);
    event PropertyTransferred(uint256 indexed propertyId, address indexed from, address indexed to);
    event PropertyUpdated(uint256 indexed propertyId, string newLocation, uint256 newArea);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
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
        admin = msg.sender;
        nextPropertyId = 1;
    }

    function registerProperty(string memory location, uint256 area) external returns (uint256) {
        require(bytes(location).length > 0, "Location cannot be empty");
        require(area > 0, "Area must be greater than 0");
        require(!locationExists[location], "Property at this location already exists");

        uint256 propertyId = nextPropertyId;
        nextPropertyId++;

        properties[propertyId] = Property({
            id: propertyId,
            location: location,
            area: area,
            owner: msg.sender,
            isRegistered: true,
            registrationTime: block.timestamp
        });

        ownerProperties[msg.sender].push(propertyId);
        locationExists[location] = true;

        emit PropertyRegistered(propertyId, msg.sender, location);
        return propertyId;
    }

    function transferProperty(uint256 propertyId, address newOwner)
        external
        propertyExists(propertyId)
        onlyPropertyOwner(propertyId)
    {
        require(newOwner != address(0), "New owner cannot be zero address");
        require(newOwner != properties[propertyId].owner, "Cannot transfer to current owner");

        address currentOwner = properties[propertyId].owner;
        properties[propertyId].owner = newOwner;

        _removeFromOwnerProperties(currentOwner, propertyId);
        ownerProperties[newOwner].push(propertyId);

        emit PropertyTransferred(propertyId, currentOwner, newOwner);
    }

    function updateProperty(uint256 propertyId, string memory newLocation, uint256 newArea)
        external
        propertyExists(propertyId)
        onlyPropertyOwner(propertyId)
    {
        require(bytes(newLocation).length > 0, "Location cannot be empty");
        require(newArea > 0, "Area must be greater than 0");

        string memory oldLocation = properties[propertyId].location;
        if (keccak256(bytes(oldLocation)) != keccak256(bytes(newLocation))) {
            require(!locationExists[newLocation], "Property at new location already exists");
            locationExists[oldLocation] = false;
            locationExists[newLocation] = true;
        }

        properties[propertyId].location = newLocation;
        properties[propertyId].area = newArea;

        emit PropertyUpdated(propertyId, newLocation, newArea);
    }

    function getProperty(uint256 propertyId)
        external
        view
        propertyExists(propertyId)
        returns (uint256, string memory, uint256, address, uint256)
    {
        Property memory prop = properties[propertyId];
        return (prop.id, prop.location, prop.area, prop.owner, prop.registrationTime);
    }

    function getOwnerProperties(address owner) external view returns (uint256[] memory) {
        return ownerProperties[owner];
    }

    function verifyOwnership(uint256 propertyId, address owner)
        external
        view
        propertyExists(propertyId)
        returns (bool)
    {
        return properties[propertyId].owner == owner;
    }

    function changeAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "New admin cannot be zero address");
        admin = newAdmin;
    }

    function _removeFromOwnerProperties(address owner, uint256 propertyId) internal {
        uint256[] storage props = ownerProperties[owner];
        for (uint256 i = 0; i < props.length; i++) {
            if (props[i] == propertyId) {
                props[i] = props[props.length - 1];
                props.pop();
                break;
            }
        }
    }
}
