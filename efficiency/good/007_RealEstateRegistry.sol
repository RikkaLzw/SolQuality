
pragma solidity ^0.8.0;

contract RealEstateRegistry {

    struct Property {
        uint256 id;
        address owner;
        string location;
        uint256 area;
        uint256 value;
        bool isRegistered;
        uint256 registrationTimestamp;
    }

    struct Transfer {
        uint256 propertyId;
        address from;
        address to;
        uint256 timestamp;
        uint256 price;
    }


    address public immutable registrar;
    uint256 private _propertyCounter;


    mapping(uint256 => Property) public properties;
    mapping(address => uint256[]) public ownerProperties;
    mapping(uint256 => Transfer[]) public propertyTransfers;
    mapping(address => bool) public authorizedAgents;


    event PropertyRegistered(uint256 indexed propertyId, address indexed owner, string location);
    event PropertyTransferred(uint256 indexed propertyId, address indexed from, address indexed to, uint256 price);
    event AgentAuthorized(address indexed agent);
    event AgentRevoked(address indexed agent);


    modifier onlyRegistrar() {
        require(msg.sender == registrar, "Only registrar can perform this action");
        _;
    }

    modifier onlyOwnerOrAgent(uint256 propertyId) {
        Property storage property = properties[propertyId];
        require(
            msg.sender == property.owner ||
            (authorizedAgents[msg.sender] && property.isRegistered),
            "Not authorized to manage this property"
        );
        _;
    }

    modifier propertyExists(uint256 propertyId) {
        require(properties[propertyId].isRegistered, "Property does not exist");
        _;
    }

    constructor() {
        registrar = msg.sender;
    }


    function registerProperty(
        address owner,
        string calldata location,
        uint256 area,
        uint256 value
    ) external onlyRegistrar returns (uint256) {
        require(owner != address(0), "Invalid owner address");
        require(area > 0, "Area must be greater than 0");
        require(bytes(location).length > 0, "Location cannot be empty");

        uint256 propertyId = ++_propertyCounter;


        Property storage newProperty = properties[propertyId];
        newProperty.id = propertyId;
        newProperty.owner = owner;
        newProperty.location = location;
        newProperty.area = area;
        newProperty.value = value;
        newProperty.isRegistered = true;
        newProperty.registrationTimestamp = block.timestamp;


        ownerProperties[owner].push(propertyId);

        emit PropertyRegistered(propertyId, owner, location);
        return propertyId;
    }


    function transferProperty(
        uint256 propertyId,
        address newOwner,
        uint256 salePrice
    ) external propertyExists(propertyId) onlyOwnerOrAgent(propertyId) {
        require(newOwner != address(0), "Invalid new owner address");


        Property storage property = properties[propertyId];
        address currentOwner = property.owner;
        require(newOwner != currentOwner, "Cannot transfer to current owner");


        _removePropertyFromOwner(currentOwner, propertyId);


        ownerProperties[newOwner].push(propertyId);


        property.owner = newOwner;


        propertyTransfers[propertyId].push(Transfer({
            propertyId: propertyId,
            from: currentOwner,
            to: newOwner,
            timestamp: block.timestamp,
            price: salePrice
        }));

        emit PropertyTransferred(propertyId, currentOwner, newOwner, salePrice);
    }


    function updatePropertyValue(uint256 propertyId, uint256 newValue)
        external
        propertyExists(propertyId)
        onlyOwnerOrAgent(propertyId)
    {
        require(newValue > 0, "Value must be greater than 0");
        properties[propertyId].value = newValue;
    }


    function authorizeAgent(address agent) external onlyRegistrar {
        require(agent != address(0), "Invalid agent address");
        authorizedAgents[agent] = true;
        emit AgentAuthorized(agent);
    }


    function revokeAgent(address agent) external onlyRegistrar {
        authorizedAgents[agent] = false;
        emit AgentRevoked(agent);
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
            uint256 registrationTimestamp
        )
    {
        Property storage property = properties[propertyId];
        return (
            property.owner,
            property.location,
            property.area,
            property.value,
            property.registrationTimestamp
        );
    }


    function getOwnerProperties(address owner) external view returns (uint256[] memory) {
        return ownerProperties[owner];
    }


    function getPropertyTransfers(uint256 propertyId)
        external
        view
        propertyExists(propertyId)
        returns (Transfer[] memory)
    {
        return propertyTransfers[propertyId];
    }


    function getTotalProperties() external view returns (uint256) {
        return _propertyCounter;
    }


    function _removePropertyFromOwner(address owner, uint256 propertyId) private {
        uint256[] storage ownerProps = ownerProperties[owner];
        uint256 length = ownerProps.length;

        for (uint256 i = 0; i < length; i++) {
            if (ownerProps[i] == propertyId) {

                ownerProps[i] = ownerProps[length - 1];
                ownerProps.pop();
                break;
            }
        }
    }
}
