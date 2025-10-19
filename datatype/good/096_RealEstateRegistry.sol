
pragma solidity ^0.8.0;

contract RealEstateRegistry {
    struct Property {
        bytes32 propertyId;
        address owner;
        bytes32 location;
        uint256 area;
        uint256 value;
        bytes32 propertyType;
        bool isRegistered;
        uint64 registrationDate;
        bytes32 documentHash;
    }

    struct Transfer {
        bytes32 propertyId;
        address from;
        address to;
        uint256 transferDate;
        uint256 price;
        bytes32 documentHash;
    }

    mapping(bytes32 => Property) public properties;
    mapping(bytes32 => Transfer[]) public transferHistory;
    mapping(address => bytes32[]) public ownerProperties;

    address public registrar;
    uint256 public totalProperties;

    event PropertyRegistered(bytes32 indexed propertyId, address indexed owner, bytes32 location);
    event PropertyTransferred(bytes32 indexed propertyId, address indexed from, address indexed to, uint256 price);
    event PropertyUpdated(bytes32 indexed propertyId, uint256 newValue);

    modifier onlyRegistrar() {
        require(msg.sender == registrar, "Only registrar can perform this action");
        _;
    }

    modifier onlyOwner(bytes32 _propertyId) {
        require(properties[_propertyId].owner == msg.sender, "Only property owner can perform this action");
        _;
    }

    modifier propertyExists(bytes32 _propertyId) {
        require(properties[_propertyId].isRegistered, "Property does not exist");
        _;
    }

    constructor() {
        registrar = msg.sender;
    }

    function registerProperty(
        bytes32 _propertyId,
        address _owner,
        bytes32 _location,
        uint256 _area,
        uint256 _value,
        bytes32 _propertyType,
        bytes32 _documentHash
    ) external onlyRegistrar {
        require(!properties[_propertyId].isRegistered, "Property already registered");
        require(_owner != address(0), "Invalid owner address");
        require(_area > 0, "Area must be greater than zero");

        properties[_propertyId] = Property({
            propertyId: _propertyId,
            owner: _owner,
            location: _location,
            area: _area,
            value: _value,
            propertyType: _propertyType,
            isRegistered: true,
            registrationDate: uint64(block.timestamp),
            documentHash: _documentHash
        });

        ownerProperties[_owner].push(_propertyId);
        totalProperties++;

        emit PropertyRegistered(_propertyId, _owner, _location);
    }

    function transferProperty(
        bytes32 _propertyId,
        address _newOwner,
        uint256 _price,
        bytes32 _documentHash
    ) external propertyExists(_propertyId) onlyOwner(_propertyId) {
        require(_newOwner != address(0), "Invalid new owner address");
        require(_newOwner != properties[_propertyId].owner, "Cannot transfer to current owner");

        address previousOwner = properties[_propertyId].owner;


        _removePropertyFromOwner(previousOwner, _propertyId);


        ownerProperties[_newOwner].push(_propertyId);


        properties[_propertyId].owner = _newOwner;


        transferHistory[_propertyId].push(Transfer({
            propertyId: _propertyId,
            from: previousOwner,
            to: _newOwner,
            transferDate: block.timestamp,
            price: _price,
            documentHash: _documentHash
        }));

        emit PropertyTransferred(_propertyId, previousOwner, _newOwner, _price);
    }

    function updatePropertyValue(
        bytes32 _propertyId,
        uint256 _newValue
    ) external propertyExists(_propertyId) onlyRegistrar {
        properties[_propertyId].value = _newValue;
        emit PropertyUpdated(_propertyId, _newValue);
    }

    function getProperty(bytes32 _propertyId) external view returns (
        bytes32 propertyId,
        address owner,
        bytes32 location,
        uint256 area,
        uint256 value,
        bytes32 propertyType,
        bool isRegistered,
        uint64 registrationDate,
        bytes32 documentHash
    ) {
        Property memory prop = properties[_propertyId];
        return (
            prop.propertyId,
            prop.owner,
            prop.location,
            prop.area,
            prop.value,
            prop.propertyType,
            prop.isRegistered,
            prop.registrationDate,
            prop.documentHash
        );
    }

    function getOwnerProperties(address _owner) external view returns (bytes32[] memory) {
        return ownerProperties[_owner];
    }

    function getTransferHistory(bytes32 _propertyId) external view returns (Transfer[] memory) {
        return transferHistory[_propertyId];
    }

    function verifyOwnership(bytes32 _propertyId, address _owner) external view returns (bool) {
        return properties[_propertyId].isRegistered && properties[_propertyId].owner == _owner;
    }

    function changeRegistrar(address _newRegistrar) external onlyRegistrar {
        require(_newRegistrar != address(0), "Invalid registrar address");
        registrar = _newRegistrar;
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
}
