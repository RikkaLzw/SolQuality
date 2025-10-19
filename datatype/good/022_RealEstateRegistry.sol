
pragma solidity ^0.8.0;

contract RealEstateRegistry {
    struct Property {
        bytes32 propertyId;
        address owner;
        bytes32 location;
        uint32 area;
        uint64 value;
        uint32 registrationDate;
        bool isActive;
        bytes32 propertyType;
    }

    struct Transfer {
        bytes32 transferId;
        bytes32 propertyId;
        address from;
        address to;
        uint64 transferValue;
        uint32 transferDate;
        bool isCompleted;
    }

    mapping(bytes32 => Property) public properties;
    mapping(address => bytes32[]) public ownerProperties;
    mapping(bytes32 => Transfer[]) public propertyTransfers;
    mapping(bytes32 => bool) public propertyExists;

    address public registrar;
    uint32 public totalProperties;

    event PropertyRegistered(bytes32 indexed propertyId, address indexed owner, bytes32 location);
    event PropertyTransferred(bytes32 indexed propertyId, address indexed from, address indexed to, uint64 value);
    event PropertyUpdated(bytes32 indexed propertyId, uint32 area, uint64 value);

    modifier onlyRegistrar() {
        require(msg.sender == registrar, "Only registrar can perform this action");
        _;
    }

    modifier onlyPropertyOwner(bytes32 _propertyId) {
        require(properties[_propertyId].owner == msg.sender, "Only property owner can perform this action");
        _;
    }

    modifier propertyMustExist(bytes32 _propertyId) {
        require(propertyExists[_propertyId], "Property does not exist");
        _;
    }

    constructor() {
        registrar = msg.sender;
        totalProperties = 0;
    }

    function registerProperty(
        bytes32 _propertyId,
        address _owner,
        bytes32 _location,
        uint32 _area,
        uint64 _value,
        bytes32 _propertyType
    ) external onlyRegistrar {
        require(!propertyExists[_propertyId], "Property already exists");
        require(_owner != address(0), "Invalid owner address");
        require(_area > 0, "Area must be greater than zero");

        properties[_propertyId] = Property({
            propertyId: _propertyId,
            owner: _owner,
            location: _location,
            area: _area,
            value: _value,
            registrationDate: uint32(block.timestamp),
            isActive: true,
            propertyType: _propertyType
        });

        ownerProperties[_owner].push(_propertyId);
        propertyExists[_propertyId] = true;
        totalProperties++;

        emit PropertyRegistered(_propertyId, _owner, _location);
    }

    function transferProperty(
        bytes32 _propertyId,
        address _to,
        uint64 _transferValue
    ) external propertyMustExist(_propertyId) onlyPropertyOwner(_propertyId) {
        require(_to != address(0), "Invalid recipient address");
        require(_to != properties[_propertyId].owner, "Cannot transfer to current owner");
        require(properties[_propertyId].isActive, "Property is not active");

        bytes32 transferId = keccak256(abi.encodePacked(_propertyId, msg.sender, _to, block.timestamp));

        Transfer memory newTransfer = Transfer({
            transferId: transferId,
            propertyId: _propertyId,
            from: msg.sender,
            to: _to,
            transferValue: _transferValue,
            transferDate: uint32(block.timestamp),
            isCompleted: false
        });

        propertyTransfers[_propertyId].push(newTransfer);


        _removePropertyFromOwner(msg.sender, _propertyId);


        properties[_propertyId].owner = _to;
        properties[_propertyId].value = _transferValue;


        ownerProperties[_to].push(_propertyId);


        propertyTransfers[_propertyId][propertyTransfers[_propertyId].length - 1].isCompleted = true;

        emit PropertyTransferred(_propertyId, msg.sender, _to, _transferValue);
    }

    function updatePropertyDetails(
        bytes32 _propertyId,
        uint32 _area,
        uint64 _value
    ) external propertyMustExist(_propertyId) onlyPropertyOwner(_propertyId) {
        require(_area > 0, "Area must be greater than zero");
        require(properties[_propertyId].isActive, "Property is not active");

        properties[_propertyId].area = _area;
        properties[_propertyId].value = _value;

        emit PropertyUpdated(_propertyId, _area, _value);
    }

    function deactivateProperty(bytes32 _propertyId) external onlyRegistrar propertyMustExist(_propertyId) {
        properties[_propertyId].isActive = false;
    }

    function activateProperty(bytes32 _propertyId) external onlyRegistrar propertyMustExist(_propertyId) {
        properties[_propertyId].isActive = true;
    }

    function getProperty(bytes32 _propertyId) external view propertyMustExist(_propertyId) returns (
        bytes32 propertyId,
        address owner,
        bytes32 location,
        uint32 area,
        uint64 value,
        uint32 registrationDate,
        bool isActive,
        bytes32 propertyType
    ) {
        Property memory prop = properties[_propertyId];
        return (
            prop.propertyId,
            prop.owner,
            prop.location,
            prop.area,
            prop.value,
            prop.registrationDate,
            prop.isActive,
            prop.propertyType
        );
    }

    function getOwnerProperties(address _owner) external view returns (bytes32[] memory) {
        return ownerProperties[_owner];
    }

    function getPropertyTransfers(bytes32 _propertyId) external view returns (Transfer[] memory) {
        return propertyTransfers[_propertyId];
    }

    function _removePropertyFromOwner(address _owner, bytes32 _propertyId) internal {
        bytes32[] storage ownerProps = ownerProperties[_owner];
        for (uint256 i = 0; i < ownerProps.length; i++) {
            if (ownerProps[i] == _propertyId) {
                ownerProps[i] = ownerProps[ownerProps.length - 1];
                ownerProps.pop();
                break;
            }
        }
    }

    function changeRegistrar(address _newRegistrar) external onlyRegistrar {
        require(_newRegistrar != address(0), "Invalid registrar address");
        registrar = _newRegistrar;
    }
}
