
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
        bytes32 legalDescription;
    }

    struct Transfer {
        bytes32 transferId;
        bytes32 propertyId;
        address from;
        address to;
        uint64 price;
        uint32 transferDate;
        bool isCompleted;
    }

    mapping(bytes32 => Property) public properties;
    mapping(address => bytes32[]) public ownerProperties;
    mapping(bytes32 => Transfer[]) public propertyTransfers;
    mapping(bytes32 => bool) public propertyExists;

    address public registrar;
    uint32 public totalProperties;

    event PropertyRegistered(bytes32 indexed propertyId, address indexed owner, uint32 area, uint64 value);
    event PropertyTransferred(bytes32 indexed propertyId, address indexed from, address indexed to, uint64 price);
    event PropertyUpdated(bytes32 indexed propertyId, uint64 newValue);
    event PropertyDeactivated(bytes32 indexed propertyId);

    modifier onlyRegistrar() {
        require(msg.sender == registrar, "Only registrar can perform this action");
        _;
    }

    modifier onlyOwner(bytes32 _propertyId) {
        require(properties[_propertyId].owner == msg.sender, "Only property owner can perform this action");
        _;
    }

    modifier propertyMustExist(bytes32 _propertyId) {
        require(propertyExists[_propertyId], "Property does not exist");
        _;
    }

    modifier propertyMustBeActive(bytes32 _propertyId) {
        require(properties[_propertyId].isActive, "Property is not active");
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
        bytes32 _propertyType,
        bytes32 _legalDescription
    ) external onlyRegistrar {
        require(!propertyExists[_propertyId], "Property already exists");
        require(_owner != address(0), "Invalid owner address");
        require(_area > 0, "Area must be greater than 0");

        properties[_propertyId] = Property({
            propertyId: _propertyId,
            owner: _owner,
            location: _location,
            area: _area,
            value: _value,
            registrationDate: uint32(block.timestamp),
            isActive: true,
            propertyType: _propertyType,
            legalDescription: _legalDescription
        });

        ownerProperties[_owner].push(_propertyId);
        propertyExists[_propertyId] = true;
        totalProperties++;

        emit PropertyRegistered(_propertyId, _owner, _area, _value);
    }

    function transferProperty(
        bytes32 _propertyId,
        address _to,
        uint64 _price
    ) external
        propertyMustExist(_propertyId)
        onlyOwner(_propertyId)
        propertyMustBeActive(_propertyId)
    {
        require(_to != address(0), "Invalid recipient address");
        require(_to != properties[_propertyId].owner, "Cannot transfer to current owner");

        bytes32 transferId = keccak256(abi.encodePacked(_propertyId, msg.sender, _to, block.timestamp));

        Transfer memory newTransfer = Transfer({
            transferId: transferId,
            propertyId: _propertyId,
            from: msg.sender,
            to: _to,
            price: _price,
            transferDate: uint32(block.timestamp),
            isCompleted: false
        });

        propertyTransfers[_propertyId].push(newTransfer);


        _removePropertyFromOwner(msg.sender, _propertyId);


        ownerProperties[_to].push(_propertyId);


        properties[_propertyId].owner = _to;


        propertyTransfers[_propertyId][propertyTransfers[_propertyId].length - 1].isCompleted = true;

        emit PropertyTransferred(_propertyId, msg.sender, _to, _price);
    }

    function updatePropertyValue(
        bytes32 _propertyId,
        uint64 _newValue
    ) external
        onlyRegistrar
        propertyMustExist(_propertyId)
        propertyMustBeActive(_propertyId)
    {
        properties[_propertyId].value = _newValue;
        emit PropertyUpdated(_propertyId, _newValue);
    }

    function deactivateProperty(bytes32 _propertyId)
        external
        onlyRegistrar
        propertyMustExist(_propertyId)
    {
        properties[_propertyId].isActive = false;
        emit PropertyDeactivated(_propertyId);
    }

    function getProperty(bytes32 _propertyId)
        external
        view
        propertyMustExist(_propertyId)
        returns (
            bytes32 propertyId,
            address owner,
            bytes32 location,
            uint32 area,
            uint64 value,
            uint32 registrationDate,
            bool isActive,
            bytes32 propertyType,
            bytes32 legalDescription
        )
    {
        Property memory prop = properties[_propertyId];
        return (
            prop.propertyId,
            prop.owner,
            prop.location,
            prop.area,
            prop.value,
            prop.registrationDate,
            prop.isActive,
            prop.propertyType,
            prop.legalDescription
        );
    }

    function getOwnerProperties(address _owner)
        external
        view
        returns (bytes32[] memory)
    {
        return ownerProperties[_owner];
    }

    function getPropertyTransfers(bytes32 _propertyId)
        external
        view
        propertyMustExist(_propertyId)
        returns (Transfer[] memory)
    {
        return propertyTransfers[_propertyId];
    }

    function isPropertyOwner(bytes32 _propertyId, address _address)
        external
        view
        propertyMustExist(_propertyId)
        returns (bool)
    {
        return properties[_propertyId].owner == _address;
    }

    function _removePropertyFromOwner(address _owner, bytes32 _propertyId) private {
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
