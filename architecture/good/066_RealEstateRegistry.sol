
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


    struct Property {
        uint256 id;
        address owner;
        string location;
        uint256 area;
        uint256 value;
        string propertyType;
        uint256 registrationTime;
        bool isActive;
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
        uint256 transferTime
    );

    event PropertyUpdated(
        uint256 indexed propertyId,
        uint256 newValue,
        string newLocation
    );

    event PropertyDeactivated(uint256 indexed propertyId);


    modifier propertyExists(uint256 _propertyId) {
        require(_propertyExists[_propertyId], "Property does not exist");
        _;
    }

    modifier onlyPropertyOwner(uint256 _propertyId) {
        require(
            _properties[_propertyId].owner == msg.sender,
            "Only property owner can perform this action"
        );
        _;
    }

    modifier validAddress(address _addr) {
        require(_addr != address(0), "Invalid address");
        _;
    }

    modifier validPropertyValue(uint256 _value) {
        require(_value > 0 && _value <= MAX_PROPERTY_VALUE, "Invalid property value");
        _;
    }

    modifier propertyIsActive(uint256 _propertyId) {
        require(_properties[_propertyId].isActive, "Property is not active");
        _;
    }

    constructor() {}


    function registerProperty(
        string memory _location,
        uint256 _area,
        uint256 _value,
        string memory _propertyType
    )
        external
        payable
        nonReentrant
        validPropertyValue(_value)
    {
        require(msg.value >= REGISTRATION_FEE, "Insufficient registration fee");
        require(_area > 0, "Area must be greater than 0");
        require(bytes(_location).length > 0, "Location cannot be empty");
        require(bytes(_propertyType).length > 0, "Property type cannot be empty");

        _propertyIds.increment();
        uint256 newPropertyId = _propertyIds.current();

        _properties[newPropertyId] = Property({
            id: newPropertyId,
            owner: msg.sender,
            location: _location,
            area: _area,
            value: _value,
            propertyType: _propertyType,
            registrationTime: block.timestamp,
            isActive: true
        });

        _propertyExists[newPropertyId] = true;
        _ownerProperties[msg.sender].push(newPropertyId);

        emit PropertyRegistered(newPropertyId, msg.sender, _location, _value);


        if (msg.value > REGISTRATION_FEE) {
            payable(msg.sender).transfer(msg.value - REGISTRATION_FEE);
        }
    }


    function transferProperty(uint256 _propertyId, address _newOwner)
        external
        payable
        nonReentrant
        propertyExists(_propertyId)
        onlyPropertyOwner(_propertyId)
        validAddress(_newOwner)
        propertyIsActive(_propertyId)
    {
        require(msg.value >= TRANSFER_FEE, "Insufficient transfer fee");
        require(_newOwner != msg.sender, "Cannot transfer to yourself");

        address previousOwner = _properties[_propertyId].owner;
        _properties[_propertyId].owner = _newOwner;


        _removePropertyFromOwner(previousOwner, _propertyId);
        _ownerProperties[_newOwner].push(_propertyId);

        emit PropertyTransferred(_propertyId, previousOwner, _newOwner, block.timestamp);


        if (msg.value > TRANSFER_FEE) {
            payable(msg.sender).transfer(msg.value - TRANSFER_FEE);
        }
    }


    function updateProperty(
        uint256 _propertyId,
        string memory _newLocation,
        uint256 _newValue
    )
        external
        propertyExists(_propertyId)
        onlyPropertyOwner(_propertyId)
        validPropertyValue(_newValue)
        propertyIsActive(_propertyId)
    {
        require(bytes(_newLocation).length > 0, "Location cannot be empty");

        _properties[_propertyId].location = _newLocation;
        _properties[_propertyId].value = _newValue;

        emit PropertyUpdated(_propertyId, _newValue, _newLocation);
    }


    function deactivateProperty(uint256 _propertyId)
        external
        propertyExists(_propertyId)
        onlyPropertyOwner(_propertyId)
        propertyIsActive(_propertyId)
    {
        _properties[_propertyId].isActive = false;
        emit PropertyDeactivated(_propertyId);
    }


    function reactivateProperty(uint256 _propertyId)
        external
        onlyOwner
        propertyExists(_propertyId)
    {
        require(!_properties[_propertyId].isActive, "Property is already active");
        _properties[_propertyId].isActive = true;
    }


    function getProperty(uint256 _propertyId)
        external
        view
        propertyExists(_propertyId)
        returns (Property memory)
    {
        return _properties[_propertyId];
    }


    function getPropertiesByOwner(address _owner)
        external
        view
        validAddress(_owner)
        returns (uint256[] memory)
    {
        return _ownerProperties[_owner];
    }


    function getTotalProperties() external view returns (uint256) {
        return _propertyIds.current();
    }


    function isPropertyActive(uint256 _propertyId)
        external
        view
        propertyExists(_propertyId)
        returns (bool)
    {
        return _properties[_propertyId].isActive;
    }


    function getPropertyOwner(uint256 _propertyId)
        external
        view
        propertyExists(_propertyId)
        returns (address)
    {
        return _properties[_propertyId].owner;
    }


    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

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


    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }


    function emergencyStop() external onlyOwner {
        selfdestruct(payable(owner()));
    }
}
