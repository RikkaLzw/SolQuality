
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract RealEstateRegistry is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;


    uint256 public constant REGISTRATION_FEE = 0.01 ether;
    uint256 public constant TRANSFER_FEE = 0.005 ether;
    uint256 public constant MAX_PROPERTY_VALUE = 1000000 ether;


    Counters.Counter private _propertyIds;
    mapping(uint256 => Property) private _properties;
    mapping(address => uint256[]) private _ownerProperties;
    mapping(uint256 => bool) private _propertyExists;


    enum PropertyStatus {
        Active,
        Pending,
        Sold,
        Disputed
    }


    struct Property {
        uint256 id;
        string location;
        uint256 area;
        uint256 value;
        address owner;
        PropertyStatus status;
        uint256 registrationTime;
        string metadataHash;
    }


    event PropertyRegistered(
        uint256 indexed propertyId,
        address indexed owner,
        string location,
        uint256 value
    );

    event PropertyTransferred(
        uint256 indexed propertyId,
        address indexed from,
        address indexed to,
        uint256 value
    );

    event PropertyStatusChanged(
        uint256 indexed propertyId,
        PropertyStatus oldStatus,
        PropertyStatus newStatus
    );

    event PropertyValueUpdated(
        uint256 indexed propertyId,
        uint256 oldValue,
        uint256 newValue
    );


    modifier propertyExists(uint256 propertyId) {
        require(_propertyExists[propertyId], "Property does not exist");
        _;
    }

    modifier onlyPropertyOwner(uint256 propertyId) {
        require(_properties[propertyId].owner == msg.sender, "Not property owner");
        _;
    }

    modifier validPropertyValue(uint256 value) {
        require(value > 0 && value <= MAX_PROPERTY_VALUE, "Invalid property value");
        _;
    }

    modifier validAddress(address addr) {
        require(addr != address(0), "Invalid address");
        _;
    }

    constructor() {}


    function registerProperty(
        string memory location,
        uint256 area,
        uint256 value,
        string memory metadataHash
    )
        external
        payable
        nonReentrant
        validPropertyValue(value)
    {
        require(msg.value >= REGISTRATION_FEE, "Insufficient registration fee");
        require(bytes(location).length > 0, "Location cannot be empty");
        require(area > 0, "Area must be greater than 0");
        require(bytes(metadataHash).length > 0, "Metadata hash cannot be empty");

        _propertyIds.increment();
        uint256 newPropertyId = _propertyIds.current();

        Property memory newProperty = Property({
            id: newPropertyId,
            location: location,
            area: area,
            value: value,
            owner: msg.sender,
            status: PropertyStatus.Active,
            registrationTime: block.timestamp,
            metadataHash: metadataHash
        });

        _properties[newPropertyId] = newProperty;
        _propertyExists[newPropertyId] = true;
        _ownerProperties[msg.sender].push(newPropertyId);

        emit PropertyRegistered(newPropertyId, msg.sender, location, value);


        if (msg.value > REGISTRATION_FEE) {
            payable(msg.sender).transfer(msg.value - REGISTRATION_FEE);
        }
    }


    function transferProperty(uint256 propertyId, address to)
        external
        payable
        nonReentrant
        propertyExists(propertyId)
        onlyPropertyOwner(propertyId)
        validAddress(to)
    {
        require(msg.value >= TRANSFER_FEE, "Insufficient transfer fee");
        require(_properties[propertyId].status == PropertyStatus.Active, "Property not available for transfer");
        require(to != msg.sender, "Cannot transfer to self");

        Property storage property = _properties[propertyId];
        address previousOwner = property.owner;


        property.owner = to;
        property.status = PropertyStatus.Pending;


        _removePropertyFromOwner(previousOwner, propertyId);
        _ownerProperties[to].push(propertyId);

        emit PropertyTransferred(propertyId, previousOwner, to, property.value);


        if (msg.value > TRANSFER_FEE) {
            payable(msg.sender).transfer(msg.value - TRANSFER_FEE);
        }
    }


    function confirmTransfer(uint256 propertyId)
        external
        propertyExists(propertyId)
        onlyPropertyOwner(propertyId)
    {
        Property storage property = _properties[propertyId];
        require(property.status == PropertyStatus.Pending, "Transfer not pending");

        PropertyStatus oldStatus = property.status;
        property.status = PropertyStatus.Active;

        emit PropertyStatusChanged(propertyId, oldStatus, PropertyStatus.Active);
    }


    function updatePropertyValue(uint256 propertyId, uint256 newValue)
        external
        propertyExists(propertyId)
        onlyPropertyOwner(propertyId)
        validPropertyValue(newValue)
    {
        Property storage property = _properties[propertyId];
        require(property.status == PropertyStatus.Active, "Property not active");

        uint256 oldValue = property.value;
        property.value = newValue;

        emit PropertyValueUpdated(propertyId, oldValue, newValue);
    }


    function setPropertyStatus(uint256 propertyId, PropertyStatus newStatus)
        external
        onlyOwner
        propertyExists(propertyId)
    {
        Property storage property = _properties[propertyId];
        PropertyStatus oldStatus = property.status;
        property.status = newStatus;

        emit PropertyStatusChanged(propertyId, oldStatus, newStatus);
    }


    function getProperty(uint256 propertyId)
        external
        view
        propertyExists(propertyId)
        returns (Property memory)
    {
        return _properties[propertyId];
    }


    function getOwnerProperties(address owner)
        external
        view
        validAddress(owner)
        returns (uint256[] memory)
    {
        return _ownerProperties[owner];
    }


    function getTotalProperties() external view returns (uint256) {
        return _propertyIds.current();
    }


    function propertyExistsCheck(uint256 propertyId) external view returns (bool) {
        return _propertyExists[propertyId];
    }


    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        payable(owner()).transfer(balance);
    }


    function _removePropertyFromOwner(address owner, uint256 propertyId) private {
        uint256[] storage properties = _ownerProperties[owner];
        for (uint256 i = 0; i < properties.length; i++) {
            if (properties[i] == propertyId) {
                properties[i] = properties[properties.length - 1];
                properties.pop();
                break;
            }
        }
    }


    function emergencyPause(uint256 propertyId)
        external
        onlyOwner
        propertyExists(propertyId)
    {
        _properties[propertyId].status = PropertyStatus.Disputed;
        emit PropertyStatusChanged(propertyId, _properties[propertyId].status, PropertyStatus.Disputed);
    }
}
