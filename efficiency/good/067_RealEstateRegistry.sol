
pragma solidity ^0.8.0;

contract RealEstateRegistry {
    struct Property {
        address owner;
        string propertyAddress;
        uint256 area;
        uint256 value;
        bool isRegistered;
        uint256 registrationDate;
    }

    struct Transfer {
        address from;
        address to;
        uint256 timestamp;
        uint256 price;
    }

    mapping(uint256 => Property) private properties;
    mapping(uint256 => Transfer[]) private transferHistory;
    mapping(address => uint256[]) private ownerProperties;
    mapping(uint256 => bool) private propertyExists;

    uint256 private nextPropertyId = 1;
    address private immutable registrar;

    event PropertyRegistered(uint256 indexed propertyId, address indexed owner, string propertyAddress);
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

    modifier propertyMustExist(uint256 propertyId) {
        require(propertyExists[propertyId], "Property does not exist");
        _;
    }

    constructor() {
        registrar = msg.sender;
    }

    function registerProperty(
        address owner,
        string memory propertyAddress,
        uint256 area,
        uint256 value
    ) external onlyRegistrar returns (uint256) {
        require(owner != address(0), "Invalid owner address");
        require(bytes(propertyAddress).length > 0, "Property address cannot be empty");
        require(area > 0, "Area must be greater than zero");

        uint256 propertyId = nextPropertyId++;

        properties[propertyId] = Property({
            owner: owner,
            propertyAddress: propertyAddress,
            area: area,
            value: value,
            isRegistered: true,
            registrationDate: block.timestamp
        });

        propertyExists[propertyId] = true;
        ownerProperties[owner].push(propertyId);

        emit PropertyRegistered(propertyId, owner, propertyAddress);
        return propertyId;
    }

    function transferProperty(uint256 propertyId, address newOwner, uint256 price)
        external
        onlyPropertyOwner(propertyId)
        propertyMustExist(propertyId)
    {
        require(newOwner != address(0), "Invalid new owner address");
        require(newOwner != msg.sender, "Cannot transfer to yourself");

        Property storage property = properties[propertyId];
        address currentOwner = property.owner;


        _removePropertyFromOwner(currentOwner, propertyId);


        property.owner = newOwner;


        ownerProperties[newOwner].push(propertyId);


        transferHistory[propertyId].push(Transfer({
            from: currentOwner,
            to: newOwner,
            timestamp: block.timestamp,
            price: price
        }));

        emit PropertyTransferred(propertyId, currentOwner, newOwner, price);
    }

    function updatePropertyValue(uint256 propertyId, uint256 newValue)
        external
        onlyRegistrar
        propertyMustExist(propertyId)
    {
        Property storage property = properties[propertyId];
        uint256 oldValue = property.value;
        property.value = newValue;

        emit PropertyValueUpdated(propertyId, oldValue, newValue);
    }

    function getProperty(uint256 propertyId)
        external
        view
        propertyMustExist(propertyId)
        returns (
            address owner,
            string memory propertyAddress,
            uint256 area,
            uint256 value,
            uint256 registrationDate
        )
    {
        Property memory property = properties[propertyId];
        return (
            property.owner,
            property.propertyAddress,
            property.area,
            property.value,
            property.registrationDate
        );
    }

    function getPropertiesByOwner(address owner) external view returns (uint256[] memory) {
        return ownerProperties[owner];
    }

    function getTransferHistory(uint256 propertyId)
        external
        view
        propertyMustExist(propertyId)
        returns (Transfer[] memory)
    {
        return transferHistory[propertyId];
    }

    function getTotalProperties() external view returns (uint256) {
        return nextPropertyId - 1;
    }

    function isPropertyOwner(uint256 propertyId, address account)
        external
        view
        propertyMustExist(propertyId)
        returns (bool)
    {
        return properties[propertyId].owner == account;
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
