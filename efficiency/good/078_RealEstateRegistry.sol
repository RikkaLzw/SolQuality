
pragma solidity ^0.8.0;

contract RealEstateRegistry {
    struct Property {
        address owner;
        string propertyAddress;
        uint256 area;
        uint256 value;
        uint256 registrationDate;
        bool isActive;
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
    mapping(string => uint256) private addressToPropertyId;

    uint256 private nextPropertyId = 1;
    address private admin;

    event PropertyRegistered(uint256 indexed propertyId, address indexed owner, string propertyAddress);
    event PropertyTransferred(uint256 indexed propertyId, address indexed from, address indexed to, uint256 price);
    event PropertyValueUpdated(uint256 indexed propertyId, uint256 oldValue, uint256 newValue);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyPropertyOwner(uint256 propertyId) {
        require(properties[propertyId].owner == msg.sender, "Only property owner can perform this action");
        _;
    }

    modifier validProperty(uint256 propertyId) {
        require(propertyId > 0 && propertyId < nextPropertyId, "Invalid property ID");
        require(properties[propertyId].isActive, "Property is not active");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function registerProperty(
        address owner,
        string calldata propertyAddress,
        uint256 area,
        uint256 value
    ) external onlyAdmin returns (uint256) {
        require(owner != address(0), "Invalid owner address");
        require(bytes(propertyAddress).length > 0, "Property address cannot be empty");
        require(area > 0, "Area must be greater than 0");
        require(addressToPropertyId[propertyAddress] == 0, "Property already registered");

        uint256 propertyId = nextPropertyId++;

        properties[propertyId] = Property({
            owner: owner,
            propertyAddress: propertyAddress,
            area: area,
            value: value,
            registrationDate: block.timestamp,
            isActive: true
        });

        ownerProperties[owner].push(propertyId);
        addressToPropertyId[propertyAddress] = propertyId;

        emit PropertyRegistered(propertyId, owner, propertyAddress);
        return propertyId;
    }

    function transferProperty(uint256 propertyId, address newOwner, uint256 price)
        external
        onlyPropertyOwner(propertyId)
        validProperty(propertyId)
    {
        require(newOwner != address(0), "Invalid new owner address");
        require(newOwner != msg.sender, "Cannot transfer to yourself");

        Property storage property = properties[propertyId];
        address previousOwner = property.owner;


        property.owner = newOwner;


        ownerProperties[newOwner].push(propertyId);


        uint256[] storage prevOwnerProps = ownerProperties[previousOwner];
        uint256 length = prevOwnerProps.length;
        for (uint256 i = 0; i < length;) {
            if (prevOwnerProps[i] == propertyId) {
                prevOwnerProps[i] = prevOwnerProps[length - 1];
                prevOwnerProps.pop();
                break;
            }
            unchecked { ++i; }
        }


        transferHistory[propertyId].push(Transfer({
            from: previousOwner,
            to: newOwner,
            timestamp: block.timestamp,
            price: price
        }));

        emit PropertyTransferred(propertyId, previousOwner, newOwner, price);
    }

    function updatePropertyValue(uint256 propertyId, uint256 newValue)
        external
        onlyAdmin
        validProperty(propertyId)
    {
        require(newValue > 0, "Value must be greater than 0");

        Property storage property = properties[propertyId];
        uint256 oldValue = property.value;
        property.value = newValue;

        emit PropertyValueUpdated(propertyId, oldValue, newValue);
    }

    function deactivateProperty(uint256 propertyId)
        external
        onlyAdmin
        validProperty(propertyId)
    {
        properties[propertyId].isActive = false;
    }

    function getProperty(uint256 propertyId)
        external
        view
        returns (
            address owner,
            string memory propertyAddress,
            uint256 area,
            uint256 value,
            uint256 registrationDate,
            bool isActive
        )
    {
        require(propertyId > 0 && propertyId < nextPropertyId, "Invalid property ID");

        Property memory property = properties[propertyId];
        return (
            property.owner,
            property.propertyAddress,
            property.area,
            property.value,
            property.registrationDate,
            property.isActive
        );
    }

    function getPropertiesByOwner(address owner)
        external
        view
        returns (uint256[] memory)
    {
        return ownerProperties[owner];
    }

    function getPropertyByAddress(string calldata propertyAddress)
        external
        view
        returns (uint256)
    {
        return addressToPropertyId[propertyAddress];
    }

    function getTransferHistory(uint256 propertyId)
        external
        view
        validProperty(propertyId)
        returns (Transfer[] memory)
    {
        return transferHistory[propertyId];
    }

    function getTotalProperties() external view returns (uint256) {
        return nextPropertyId - 1;
    }

    function isPropertyOwner(address account, uint256 propertyId)
        external
        view
        returns (bool)
    {
        if (propertyId == 0 || propertyId >= nextPropertyId) {
            return false;
        }
        return properties[propertyId].owner == account && properties[propertyId].isActive;
    }
}
