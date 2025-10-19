
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract RealEstateRegistry is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;


    uint256 public constant REGISTRATION_FEE = 0.01 ether;
    uint256 public constant TRANSFER_FEE = 0.005 ether;
    uint256 public constant MAX_PROPERTY_SIZE = 10000;


    enum PropertyStatus {
        Active,
        Pending,
        Sold,
        Disputed
    }


    struct Property {
        uint256 id;
        string location;
        uint256 size;
        uint256 price;
        address owner;
        PropertyStatus status;
        uint256 registrationTime;
        string metadataURI;
    }


    Counters.Counter private _propertyIds;
    mapping(uint256 => Property) private _properties;
    mapping(address => uint256[]) private _ownerProperties;
    mapping(string => bool) private _locationExists;


    event PropertyRegistered(
        uint256 indexed propertyId,
        address indexed owner,
        string location,
        uint256 size,
        uint256 price
    );

    event PropertyTransferred(
        uint256 indexed propertyId,
        address indexed from,
        address indexed to,
        uint256 price
    );

    event PropertyStatusChanged(
        uint256 indexed propertyId,
        PropertyStatus oldStatus,
        PropertyStatus newStatus
    );

    event PropertyUpdated(
        uint256 indexed propertyId,
        uint256 newPrice,
        string newMetadataURI
    );


    modifier propertyExists(uint256 _propertyId) {
        require(_propertyId > 0 && _propertyId <= _propertyIds.current(), "Property does not exist");
        _;
    }

    modifier onlyPropertyOwner(uint256 _propertyId) {
        require(_properties[_propertyId].owner == msg.sender, "Not property owner");
        _;
    }

    modifier validPropertyData(string memory _location, uint256 _size, uint256 _price) {
        require(bytes(_location).length > 0, "Location cannot be empty");
        require(_size > 0 && _size <= MAX_PROPERTY_SIZE, "Invalid property size");
        require(_price > 0, "Price must be greater than 0");
        require(!_locationExists[_location], "Location already registered");
        _;
    }

    modifier propertyActive(uint256 _propertyId) {
        require(_properties[_propertyId].status == PropertyStatus.Active, "Property not active");
        _;
    }

    constructor() {}


    function registerProperty(
        string memory _location,
        uint256 _size,
        uint256 _price,
        string memory _metadataURI
    )
        external
        payable
        validPropertyData(_location, _size, _price)
        nonReentrant
    {
        require(msg.value >= REGISTRATION_FEE, "Insufficient registration fee");

        _propertyIds.increment();
        uint256 newPropertyId = _propertyIds.current();

        Property memory newProperty = Property({
            id: newPropertyId,
            location: _location,
            size: _size,
            price: _price,
            owner: msg.sender,
            status: PropertyStatus.Active,
            registrationTime: block.timestamp,
            metadataURI: _metadataURI
        });

        _properties[newPropertyId] = newProperty;
        _ownerProperties[msg.sender].push(newPropertyId);
        _locationExists[_location] = true;

        emit PropertyRegistered(newPropertyId, msg.sender, _location, _size, _price);


        if (msg.value > REGISTRATION_FEE) {
            payable(msg.sender).transfer(msg.value - REGISTRATION_FEE);
        }
    }


    function transferProperty(uint256 _propertyId, address _newOwner)
        external
        payable
        propertyExists(_propertyId)
        onlyPropertyOwner(_propertyId)
        propertyActive(_propertyId)
        nonReentrant
    {
        require(_newOwner != address(0), "Invalid new owner address");
        require(_newOwner != msg.sender, "Cannot transfer to yourself");
        require(msg.value >= TRANSFER_FEE, "Insufficient transfer fee");

        Property storage property = _properties[_propertyId];
        address oldOwner = property.owner;


        property.owner = _newOwner;
        property.status = PropertyStatus.Pending;


        _removePropertyFromOwner(oldOwner, _propertyId);
        _ownerProperties[_newOwner].push(_propertyId);

        emit PropertyTransferred(_propertyId, oldOwner, _newOwner, property.price);


        if (msg.value > TRANSFER_FEE) {
            payable(msg.sender).transfer(msg.value - TRANSFER_FEE);
        }
    }


    function confirmTransfer(uint256 _propertyId)
        external
        propertyExists(_propertyId)
        onlyPropertyOwner(_propertyId)
    {
        Property storage property = _properties[_propertyId];
        require(property.status == PropertyStatus.Pending, "Transfer not pending");

        PropertyStatus oldStatus = property.status;
        property.status = PropertyStatus.Active;

        emit PropertyStatusChanged(_propertyId, oldStatus, PropertyStatus.Active);
    }


    function updateProperty(
        uint256 _propertyId,
        uint256 _newPrice,
        string memory _newMetadataURI
    )
        external
        propertyExists(_propertyId)
        onlyPropertyOwner(_propertyId)
        propertyActive(_propertyId)
    {
        require(_newPrice > 0, "Price must be greater than 0");

        Property storage property = _properties[_propertyId];
        property.price = _newPrice;
        property.metadataURI = _newMetadataURI;

        emit PropertyUpdated(_propertyId, _newPrice, _newMetadataURI);
    }


    function setPropertyStatus(uint256 _propertyId, PropertyStatus _status)
        external
        onlyOwner
        propertyExists(_propertyId)
    {
        Property storage property = _properties[_propertyId];
        PropertyStatus oldStatus = property.status;
        property.status = _status;

        emit PropertyStatusChanged(_propertyId, oldStatus, _status);
    }


    function getProperty(uint256 _propertyId)
        external
        view
        propertyExists(_propertyId)
        returns (Property memory)
    {
        return _properties[_propertyId];
    }


    function getOwnerProperties(address _owner)
        external
        view
        returns (uint256[] memory)
    {
        return _ownerProperties[_owner];
    }


    function isLocationRegistered(string memory _location)
        external
        view
        returns (bool)
    {
        return _locationExists[_location];
    }


    function getTotalProperties() external view returns (uint256) {
        return _propertyIds.current();
    }


    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");

        payable(owner()).transfer(balance);
    }


    function _removePropertyFromOwner(address _owner, uint256 _propertyId) private {
        uint256[] storage properties = _ownerProperties[_owner];
        for (uint256 i = 0; i < properties.length; i++) {
            if (properties[i] == _propertyId) {
                properties[i] = properties[properties.length - 1];
                properties.pop();
                break;
            }
        }
    }


    function getBatchProperties(uint256[] memory _propertyIds)
        external
        view
        returns (Property[] memory)
    {
        Property[] memory properties = new Property[](_propertyIds.length);

        for (uint256 i = 0; i < _propertyIds.length; i++) {
            if (_propertyIds[i] > 0 && _propertyIds[i] <= _propertyIds.current()) {
                properties[i] = _properties[_propertyIds[i]];
            }
        }

        return properties;
    }


    function getPropertiesByStatus(PropertyStatus _status)
        external
        view
        returns (uint256 count)
    {
        for (uint256 i = 1; i <= _propertyIds.current(); i++) {
            if (_properties[i].status == _status) {
                count++;
            }
        }
    }
}
