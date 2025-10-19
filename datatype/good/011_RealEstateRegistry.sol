
pragma solidity ^0.8.0;

contract RealEstateRegistry {
    struct Property {
        bytes32 propertyId;
        address owner;
        bytes32 location;
        uint256 area;
        uint256 value;
        bytes32 propertyType;
        uint64 registrationDate;
        bool isActive;
    }

    struct Transfer {
        bytes32 transferId;
        bytes32 propertyId;
        address from;
        address to;
        uint256 transferDate;
        uint256 price;
        bool isCompleted;
    }

    mapping(bytes32 => Property) public properties;
    mapping(address => bytes32[]) public ownerProperties;
    mapping(bytes32 => Transfer[]) public propertyTransfers;
    mapping(bytes32 => bool) public propertyExists;

    address public registrar;
    uint256 public totalProperties;

    event PropertyRegistered(bytes32 indexed propertyId, address indexed owner, bytes32 location);
    event PropertyTransferred(bytes32 indexed propertyId, address indexed from, address indexed to, uint256 price);
    event PropertyUpdated(bytes32 indexed propertyId, uint256 newValue);

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
        uint256 _area,
        uint256 _value,
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
            propertyType: _propertyType,
            registrationDate: uint64(block.timestamp),
            isActive: true
        });

        ownerProperties[_owner].push(_propertyId);
        propertyExists[_propertyId] = true;
        totalProperties++;

        emit PropertyRegistered(_propertyId, _owner, _location);
    }

    function transferProperty(
        bytes32 _propertyId,
        address _newOwner,
        uint256 _price
    ) external propertyMustExist(_propertyId) onlyPropertyOwner(_propertyId) {
        require(_newOwner != address(0), "Invalid new owner address");
        require(_newOwner != properties[_propertyId].owner, "Cannot transfer to current owner");
        require(properties[_propertyId].isActive, "Property is not active");

        bytes32 transferId = keccak256(abi.encodePacked(_propertyId, block.timestamp, msg.sender, _newOwner));

        Transfer memory newTransfer = Transfer({
            transferId: transferId,
            propertyId: _propertyId,
            from: properties[_propertyId].owner,
            to: _newOwner,
            transferDate: block.timestamp,
            price: _price,
            isCompleted: true
        });

        propertyTransfers[_propertyId].push(newTransfer);


        _removePropertyFromOwner(properties[_propertyId].owner, _propertyId);


        properties[_propertyId].owner = _newOwner;


        ownerProperties[_newOwner].push(_propertyId);

        emit PropertyTransferred(_propertyId, newTransfer.from, _newOwner, _price);
    }

    function updatePropertyValue(
        bytes32 _propertyId,
        uint256 _newValue
    ) external propertyMustExist(_propertyId) onlyRegistrar {
        require(_newValue > 0, "Value must be greater than zero");

        properties[_propertyId].value = _newValue;

        emit PropertyUpdated(_propertyId, _newValue);
    }

    function deactivateProperty(bytes32 _propertyId) external propertyMustExist(_propertyId) onlyRegistrar {
        properties[_propertyId].isActive = false;
    }

    function activateProperty(bytes32 _propertyId) external propertyMustExist(_propertyId) onlyRegistrar {
        properties[_propertyId].isActive = true;
    }

    function getProperty(bytes32 _propertyId) external view propertyMustExist(_propertyId) returns (
        bytes32 propertyId,
        address owner,
        bytes32 location,
        uint256 area,
        uint256 value,
        bytes32 propertyType,
        uint64 registrationDate,
        bool isActive
    ) {
        Property memory prop = properties[_propertyId];
        return (
            prop.propertyId,
            prop.owner,
            prop.location,
            prop.area,
            prop.value,
            prop.propertyType,
            prop.registrationDate,
            prop.isActive
        );
    }

    function getOwnerProperties(address _owner) external view returns (bytes32[] memory) {
        return ownerProperties[_owner];
    }

    function getPropertyTransferHistory(bytes32 _propertyId) external view propertyMustExist(_propertyId) returns (Transfer[] memory) {
        return propertyTransfers[_propertyId];
    }

    function getPropertyTransferCount(bytes32 _propertyId) external view propertyMustExist(_propertyId) returns (uint256) {
        return propertyTransfers[_propertyId].length;
    }

    function changeRegistrar(address _newRegistrar) external onlyRegistrar {
        require(_newRegistrar != address(0), "Invalid registrar address");
        registrar = _newRegistrar;
    }

    function _removePropertyFromOwner(address _owner, bytes32 _propertyId) internal {
        bytes32[] storage ownerProps = ownerProperties[_owner];
        uint256 length = ownerProps.length;

        for (uint256 i = 0; i < length; i++) {
            if (ownerProps[i] == _propertyId) {
                ownerProps[i] = ownerProps[length - 1];
                ownerProps.pop();
                break;
            }
        }
    }
}
