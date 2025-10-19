
pragma solidity ^0.8.0;

contract RealEstateRegistry {
    struct Property {
        string propertyId;
        string location;
        uint256 area;
        address owner;
        bool isRegistered;
        uint256 registrationTime;
        string propertyType;
    }

    mapping(string => Property) public properties;
    mapping(address => string[]) public ownerProperties;
    mapping(string => bool) private propertyExists;

    address public registrar;
    uint256 public totalProperties;

    event PropertyRegistered(
        string indexed propertyId,
        address indexed owner,
        string location,
        uint256 area
    );

    event PropertyTransferred(
        string indexed propertyId,
        address indexed from,
        address indexed to
    );

    event RegistrarChanged(
        address indexed oldRegistrar,
        address indexed newRegistrar
    );

    modifier onlyRegistrar() {
        require(msg.sender == registrar, "Only registrar can perform this action");
        _;
    }

    modifier onlyOwner(string memory propertyId) {
        require(properties[propertyId].owner == msg.sender, "Only property owner can perform this action");
        _;
    }

    modifier propertyMustExist(string memory propertyId) {
        require(propertyExists[propertyId], "Property does not exist");
        _;
    }

    modifier propertyMustNotExist(string memory propertyId) {
        require(!propertyExists[propertyId], "Property already exists");
        _;
    }

    constructor() {
        registrar = msg.sender;
    }

    function registerProperty(
        string memory propertyId,
        string memory location,
        uint256 area,
        address owner
    ) public onlyRegistrar propertyMustNotExist(propertyId) {
        require(bytes(propertyId).length > 0, "Property ID cannot be empty");
        require(bytes(location).length > 0, "Location cannot be empty");
        require(area > 0, "Area must be greater than zero");
        require(owner != address(0), "Owner address cannot be zero");

        properties[propertyId] = Property({
            propertyId: propertyId,
            location: location,
            area: area,
            owner: owner,
            isRegistered: true,
            registrationTime: block.timestamp,
            propertyType: "residential"
        });

        ownerProperties[owner].push(propertyId);
        propertyExists[propertyId] = true;
        totalProperties++;

        emit PropertyRegistered(propertyId, owner, location, area);
    }

    function transferProperty(
        string memory propertyId,
        address newOwner
    ) public onlyOwner(propertyId) propertyMustExist(propertyId) {
        require(newOwner != address(0), "New owner address cannot be zero");
        require(newOwner != properties[propertyId].owner, "Cannot transfer to same owner");

        address oldOwner = properties[propertyId].owner;
        properties[propertyId].owner = newOwner;

        _removeFromOwnerProperties(oldOwner, propertyId);
        ownerProperties[newOwner].push(propertyId);

        emit PropertyTransferred(propertyId, oldOwner, newOwner);
    }

    function updatePropertyType(
        string memory propertyId,
        string memory newType
    ) public onlyRegistrar propertyMustExist(propertyId) {
        require(bytes(newType).length > 0, "Property type cannot be empty");
        properties[propertyId].propertyType = newType;
    }

    function changeRegistrar(address newRegistrar) public onlyRegistrar {
        require(newRegistrar != address(0), "New registrar address cannot be zero");
        require(newRegistrar != registrar, "Cannot set same registrar");

        address oldRegistrar = registrar;
        registrar = newRegistrar;

        emit RegistrarChanged(oldRegistrar, newRegistrar);
    }

    function getProperty(string memory propertyId)
        public
        view
        propertyMustExist(propertyId)
        returns (
            string memory location,
            uint256 area,
            address owner,
            uint256 registrationTime
        )
    {
        Property memory prop = properties[propertyId];
        return (prop.location, prop.area, prop.owner, prop.registrationTime);
    }

    function getOwnerProperties(address owner)
        public
        view
        returns (string[] memory)
    {
        return ownerProperties[owner];
    }

    function isPropertyRegistered(string memory propertyId)
        public
        view
        returns (bool)
    {
        return propertyExists[propertyId];
    }

    function getPropertyCount() public view returns (uint256) {
        return totalProperties;
    }

    function _removeFromOwnerProperties(
        address owner,
        string memory propertyId
    ) private {
        string[] storage properties_array = ownerProperties[owner];

        for (uint256 i = 0; i < properties_array.length; i++) {
            if (keccak256(bytes(properties_array[i])) == keccak256(bytes(propertyId))) {
                properties_array[i] = properties_array[properties_array.length - 1];
                properties_array.pop();
                break;
            }
        }
    }
}
