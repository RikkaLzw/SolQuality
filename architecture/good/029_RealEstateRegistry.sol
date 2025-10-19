
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract RealEstateRegistry is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;


    uint256 public constant REGISTRATION_FEE = 0.01 ether;
    uint256 public constant TRANSFER_FEE = 0.005 ether;
    uint256 public constant MAX_PROPERTY_SIZE = 1000000;


    Counters.Counter private _propertyIdCounter;
    mapping(uint256 => Property) private _properties;
    mapping(address => uint256[]) private _ownerProperties;
    mapping(uint256 => bool) private _propertyExists;


    enum PropertyStatus {
        Active,
        Pending,
        Transferred,
        Disputed
    }


    struct Property {
        uint256 id;
        string location;
        uint256 size;
        address owner;
        address previousOwner;
        PropertyStatus status;
        uint256 registrationTime;
        uint256 lastTransferTime;
        string metadata;
    }


    event PropertyRegistered(
        uint256 indexed propertyId,
        address indexed owner,
        string location,
        uint256 size
    );

    event PropertyTransferred(
        uint256 indexed propertyId,
        address indexed from,
        address indexed to,
        uint256 transferTime
    );

    event PropertyStatusUpdated(
        uint256 indexed propertyId,
        PropertyStatus oldStatus,
        PropertyStatus newStatus
    );


    modifier propertyExists(uint256 _propertyId) {
        require(_propertyExists[_propertyId], "Property does not exist");
        _;
    }

    modifier onlyPropertyOwner(uint256 _propertyId) {
        require(
            _properties[_propertyId].owner == msg.sender,
            "Not the property owner"
        );
        _;
    }

    modifier validPropertySize(uint256 _size) {
        require(_size > 0 && _size <= MAX_PROPERTY_SIZE, "Invalid property size");
        _;
    }

    modifier notZeroAddress(address _address) {
        require(_address != address(0), "Invalid address");
        _;
    }

    modifier propertyActive(uint256 _propertyId) {
        require(
            _properties[_propertyId].status == PropertyStatus.Active,
            "Property is not active"
        );
        _;
    }


    function registerProperty(
        string memory _location,
        uint256 _size,
        string memory _metadata
    )
        external
        payable
        validPropertySize(_size)
        nonReentrant
    {
        require(msg.value >= REGISTRATION_FEE, "Insufficient registration fee");
        require(bytes(_location).length > 0, "Location cannot be empty");

        _propertyIdCounter.increment();
        uint256 newPropertyId = _propertyIdCounter.current();

        Property memory newProperty = Property({
            id: newPropertyId,
            location: _location,
            size: _size,
            owner: msg.sender,
            previousOwner: address(0),
            status: PropertyStatus.Active,
            registrationTime: block.timestamp,
            lastTransferTime: 0,
            metadata: _metadata
        });

        _properties[newPropertyId] = newProperty;
        _propertyExists[newPropertyId] = true;
        _ownerProperties[msg.sender].push(newPropertyId);

        emit PropertyRegistered(newPropertyId, msg.sender, _location, _size);


        if (msg.value > REGISTRATION_FEE) {
            payable(msg.sender).transfer(msg.value - REGISTRATION_FEE);
        }
    }


    function transferProperty(
        uint256 _propertyId,
        address _newOwner
    )
        external
        payable
        propertyExists(_propertyId)
        onlyPropertyOwner(_propertyId)
        propertyActive(_propertyId)
        notZeroAddress(_newOwner)
        nonReentrant
    {
        require(msg.value >= TRANSFER_FEE, "Insufficient transfer fee");
        require(_newOwner != msg.sender, "Cannot transfer to yourself");

        Property storage property = _properties[_propertyId];
        address previousOwner = property.owner;


        property.previousOwner = previousOwner;
        property.owner = _newOwner;
        property.lastTransferTime = block.timestamp;
        property.status = PropertyStatus.Transferred;


        _removePropertyFromOwner(previousOwner, _propertyId);
        _ownerProperties[_newOwner].push(_propertyId);


        property.status = PropertyStatus.Active;

        emit PropertyTransferred(_propertyId, previousOwner, _newOwner, block.timestamp);


        if (msg.value > TRANSFER_FEE) {
            payable(msg.sender).transfer(msg.value - TRANSFER_FEE);
        }
    }


    function updatePropertyStatus(
        uint256 _propertyId,
        PropertyStatus _newStatus
    )
        external
        propertyExists(_propertyId)
        onlyPropertyOwner(_propertyId)
    {
        Property storage property = _properties[_propertyId];
        PropertyStatus oldStatus = property.status;

        require(oldStatus != _newStatus, "Status is already set");

        property.status = _newStatus;

        emit PropertyStatusUpdated(_propertyId, oldStatus, _newStatus);
    }


    function updatePropertyMetadata(
        uint256 _propertyId,
        string memory _metadata
    )
        external
        propertyExists(_propertyId)
        onlyPropertyOwner(_propertyId)
    {
        _properties[_propertyId].metadata = _metadata;
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


    function getTotalProperties() external view returns (uint256) {
        return _propertyIdCounter.current();
    }


    function propertyExistsCheck(uint256 _propertyId) external view returns (bool) {
        return _propertyExists[_propertyId];
    }


    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        payable(owner()).transfer(balance);
    }


    function emergencyPause(uint256 _propertyId)
        external
        onlyOwner
        propertyExists(_propertyId)
    {
        Property storage property = _properties[_propertyId];
        PropertyStatus oldStatus = property.status;
        property.status = PropertyStatus.Disputed;

        emit PropertyStatusUpdated(_propertyId, oldStatus, PropertyStatus.Disputed);
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


    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
