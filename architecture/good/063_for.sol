
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
        string propertyAddress;
        string description;
        uint256 area;
        uint256 value;
        address owner;
        bool isActive;
        uint256 registrationDate;
        uint256 lastTransferDate;
    }

    struct PropertyTransfer {
        uint256 propertyId;
        address from;
        address to;
        uint256 transferDate;
        uint256 transferValue;
    }


    event PropertyRegistered(
        uint256 indexed propertyId,
        address indexed owner,
        string propertyAddress,
        uint256 value
    );

    event PropertyTransferred(
        uint256 indexed propertyId,
        address indexed from,
        address indexed to,
        uint256 transferValue
    );

    event PropertyValueUpdated(
        uint256 indexed propertyId,
        uint256 oldValue,
        uint256 newValue
    );

    event PropertyDeactivated(uint256 indexed propertyId);


    modifier propertyExists(uint256 _propertyId) {
        require(_propertyExists[_propertyId], "Property does not exist");
        _;
    }

    modifier onlyPropertyOwner(uint256 _propertyId) {
        require(_properties[_propertyId].owner == msg.sender, "Not property owner");
        _;
    }

    modifier propertyActive(uint256 _propertyId) {
        require(_properties[_propertyId].isActive, "Property is not active");
        _;
    }

    modifier validAddress(address _addr) {
        require(_addr != address(0), "Invalid address");
        _;
    }

    modifier validValue(uint256 _value) {
        require(_value > 0 && _value <= MAX_PROPERTY_VALUE, "Invalid property value");
        _;
    }

    constructor() {}


    function registerProperty(
        string memory _propertyAddress,
        string memory _description,
        uint256 _area,
        uint256 _value
    ) external payable validValue(_value) nonReentrant {
        require(msg.value >= REGISTRATION_FEE, "Insufficient registration fee");
        require(bytes(_propertyAddress).length > 0, "Property address required");
        require(_area > 0, "Area must be greater than 0");

        _propertyIds.increment();
        uint256 newPropertyId = _propertyIds.current();

        Property memory newProperty = Property({
            id: newPropertyId,
            propertyAddress: _propertyAddress,
            description: _description,
            area: _area,
            value: _value,
            owner: msg.sender,
            isActive: true,
            registrationDate: block.timestamp,
            lastTransferDate: block.timestamp
        });

        _properties[newPropertyId] = newProperty;
        _ownerProperties[msg.sender].push(newPropertyId);
        _propertyExists[newPropertyId] = true;

        emit PropertyRegistered(newPropertyId, msg.sender, _propertyAddress, _value);
    }


    function transferProperty(uint256 _propertyId, address _newOwner)
        external
        payable
        propertyExists(_propertyId)
        onlyPropertyOwner(_propertyId)
        propertyActive(_propertyId)
        validAddress(_newOwner)
        nonReentrant
    {
        require(msg.value >= TRANSFER_FEE, "Insufficient transfer fee");
        require(_newOwner != msg.sender, "Cannot transfer to self");

        Property storage property = _properties[_propertyId];
        address previousOwner = property.owner;


        property.owner = _newOwner;
        property.lastTransferDate = block.timestamp;


        _removePropertyFromOwner(previousOwner, _propertyId);
        _ownerProperties[_newOwner].push(_propertyId);

        emit PropertyTransferred(_propertyId, previousOwner, _newOwner, property.value);
    }


    function updatePropertyValue(uint256 _propertyId, uint256 _newValue)
        external
        propertyExists(_propertyId)
        onlyPropertyOwner(_propertyId)
        propertyActive(_propertyId)
        validValue(_newValue)
    {
        Property storage property = _properties[_propertyId];
        uint256 oldValue = property.value;
        property.value = _newValue;

        emit PropertyValueUpdated(_propertyId, oldValue, _newValue);
    }


    function deactivateProperty(uint256 _propertyId)
        external
        propertyExists(_propertyId)
        onlyPropertyOwner(_propertyId)
        propertyActive(_propertyId)
    {
        _properties[_propertyId].isActive = false;
        emit PropertyDeactivated(_propertyId);
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


    function isPropertyActive(uint256 _propertyId) external view returns (bool) {
        return _propertyExists[_propertyId] && _properties[_propertyId].isActive;
    }


    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }


    function _removePropertyFromOwner(address _owner, uint256 _propertyId) private {
        uint256[] storage ownerProps = _ownerProperties[_owner];
        for (uint256 i = 0; i < ownerProps.length; i++) {
            if (ownerProps[i] == _propertyId) {
                ownerProps[i] = ownerProps[ownerProps.length - 1];
                ownerProps.pop();
                break;
            }
        }
    }


    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }


    bool private _paused;

    modifier whenNotPaused() {
        require(!_paused, "Contract is paused");
        _;
    }

    function pause() external onlyOwner {
        _paused = true;
    }

    function unpause() external onlyOwner {
        _paused = false;
    }

    function isPaused() external view returns (bool) {
        return _paused;
    }
}
