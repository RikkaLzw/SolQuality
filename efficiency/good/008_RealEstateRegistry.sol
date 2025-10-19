
pragma solidity ^0.8.0;

contract RealEstateRegistry {
    struct Property {
        address owner;
        string location;
        uint256 area;
        uint256 value;
        uint256 registrationDate;
        bool isActive;
    }

    struct TransferRecord {
        address from;
        address to;
        uint256 timestamp;
        uint256 price;
    }

    mapping(uint256 => Property) public properties;
    mapping(uint256 => TransferRecord[]) public transferHistory;
    mapping(address => uint256[]) private ownerProperties;
    mapping(uint256 => uint256) private ownerPropertyIndex;

    uint256 private nextPropertyId = 1;
    uint256 public totalProperties;
    address public registrar;

    event PropertyRegistered(uint256 indexed propertyId, address indexed owner, string location);
    event PropertyTransferred(uint256 indexed propertyId, address indexed from, address indexed to, uint256 price);
    event PropertyValueUpdated(uint256 indexed propertyId, uint256 oldValue, uint256 newValue);

    modifier onlyRegistrar() {
        require(msg.sender == registrar, "Only registrar can perform this action");
        _;
    }

    modifier onlyPropertyOwner(uint256 propertyId) {
        require(properties[propertyId].owner == msg.sender, "Only property owner can perform this action");
        _;
    }

    modifier propertyExists(uint256 propertyId) {
        require(properties[propertyId].isActive, "Property does not exist or is inactive");
        _;
    }

    constructor() {
        registrar = msg.sender;
    }

    function registerProperty(
        address owner,
        string memory location,
        uint256 area,
        uint256 value
    ) external onlyRegistrar returns (uint256) {
        uint256 propertyId = nextPropertyId++;

        Property storage newProperty = properties[propertyId];
        newProperty.owner = owner;
        newProperty.location = location;
        newProperty.area = area;
        newProperty.value = value;
        newProperty.registrationDate = block.timestamp;
        newProperty.isActive = true;

        ownerProperties[owner].push(propertyId);
        ownerPropertyIndex[propertyId] = ownerProperties[owner].length - 1;

        unchecked {
            totalProperties++;
        }

        emit PropertyRegistered(propertyId, owner, location);
        return propertyId;
    }

    function transferProperty(uint256 propertyId, address to, uint256 price)
        external
        onlyPropertyOwner(propertyId)
        propertyExists(propertyId)
    {
        require(to != address(0), "Invalid recipient address");
        require(to != msg.sender, "Cannot transfer to yourself");

        Property storage property = properties[propertyId];
        address from = property.owner;

        _removeFromOwnerProperties(from, propertyId);

        property.owner = to;
        ownerProperties[to].push(propertyId);
        ownerPropertyIndex[propertyId] = ownerProperties[to].length - 1;

        transferHistory[propertyId].push(TransferRecord({
            from: from,
            to: to,
            timestamp: block.timestamp,
            price: price
        }));

        emit PropertyTransferred(propertyId, from, to, price);
    }

    function updatePropertyValue(uint256 propertyId, uint256 newValue)
        external
        onlyRegistrar
        propertyExists(propertyId)
    {
        Property storage property = properties[propertyId];
        uint256 oldValue = property.value;
        property.value = newValue;

        emit PropertyValueUpdated(propertyId, oldValue, newValue);
    }

    function getProperty(uint256 propertyId)
        external
        view
        propertyExists(propertyId)
        returns (
            address owner,
            string memory location,
            uint256 area,
            uint256 value,
            uint256 registrationDate
        )
    {
        Property memory property = properties[propertyId];
        return (
            property.owner,
            property.location,
            property.area,
            property.value,
            property.registrationDate
        );
    }

    function getOwnerProperties(address owner) external view returns (uint256[] memory) {
        return ownerProperties[owner];
    }

    function getTransferHistory(uint256 propertyId)
        external
        view
        propertyExists(propertyId)
        returns (TransferRecord[] memory)
    {
        return transferHistory[propertyId];
    }

    function getPropertyCount(address owner) external view returns (uint256) {
        return ownerProperties[owner].length;
    }

    function _removeFromOwnerProperties(address owner, uint256 propertyId) private {
        uint256[] storage properties = ownerProperties[owner];
        uint256 index = ownerPropertyIndex[propertyId];
        uint256 lastIndex = properties.length - 1;

        if (index != lastIndex) {
            uint256 lastPropertyId = properties[lastIndex];
            properties[index] = lastPropertyId;
            ownerPropertyIndex[lastPropertyId] = index;
        }

        properties.pop();
        delete ownerPropertyIndex[propertyId];
    }

    function changeRegistrar(address newRegistrar) external onlyRegistrar {
        require(newRegistrar != address(0), "Invalid registrar address");
        registrar = newRegistrar;
    }
}
