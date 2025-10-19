
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
        bytes32 documentHash;
    }

    struct Transfer {
        bytes32 propertyId;
        address from;
        address to;
        uint256 transferDate;
        uint256 price;
        bytes32 transferHash;
    }

    mapping(bytes32 => Property) public properties;
    mapping(bytes32 => bool) public propertyExists;
    mapping(address => bytes32[]) public ownerProperties;
    mapping(bytes32 => Transfer[]) public propertyTransfers;

    bytes32[] public allPropertyIds;

    address public registrar;
    bool public contractActive;

    event PropertyRegistered(bytes32 indexed propertyId, address indexed owner, uint256 value);
    event PropertyTransferred(bytes32 indexed propertyId, address indexed from, address indexed to, uint256 price);
    event PropertyUpdated(bytes32 indexed propertyId, uint256 newValue);
    event PropertyDeactivated(bytes32 indexed propertyId);

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

    modifier propertyMustBeActive(bytes32 _propertyId) {
        require(properties[_propertyId].isActive, "Property is not active");
        _;
    }

    modifier contractMustBeActive() {
        require(contractActive, "Contract is not active");
        _;
    }

    constructor() {
        registrar = msg.sender;
        contractActive = true;
    }

    function registerProperty(
        bytes32 _propertyId,
        address _owner,
        bytes32 _location,
        uint256 _area,
        uint256 _value,
        bytes32 _propertyType,
        bytes32 _documentHash
    ) external onlyRegistrar contractMustBeActive {
        require(!propertyExists[_propertyId], "Property already exists");
        require(_owner != address(0), "Invalid owner address");
        require(_area > 0, "Area must be greater than 0");

        properties[_propertyId] = Property({
            propertyId: _propertyId,
            owner: _owner,
            location: _location,
            area: _area,
            value: _value,
            propertyType: _propertyType,
            registrationDate: uint64(block.timestamp),
            isActive: true,
            documentHash: _documentHash
        });

        propertyExists[_propertyId] = true;
        ownerProperties[_owner].push(_propertyId);
        allPropertyIds.push(_propertyId);

        emit PropertyRegistered(_propertyId, _owner, _value);
    }

    function transferProperty(
        bytes32 _propertyId,
        address _newOwner,
        uint256 _price,
        bytes32 _transferHash
    ) external
        propertyMustExist(_propertyId)
        propertyMustBeActive(_propertyId)
        onlyPropertyOwner(_propertyId)
        contractMustBeActive
    {
        require(_newOwner != address(0), "Invalid new owner address");
        require(_newOwner != properties[_propertyId].owner, "Cannot transfer to current owner");

        address previousOwner = properties[_propertyId].owner;
        properties[_propertyId].owner = _newOwner;


        _removePropertyFromOwner(previousOwner, _propertyId);


        ownerProperties[_newOwner].push(_propertyId);


        propertyTransfers[_propertyId].push(Transfer({
            propertyId: _propertyId,
            from: previousOwner,
            to: _newOwner,
            transferDate: block.timestamp,
            price: _price,
            transferHash: _transferHash
        }));

        emit PropertyTransferred(_propertyId, previousOwner, _newOwner, _price);
    }

    function updatePropertyValue(
        bytes32 _propertyId,
        uint256 _newValue
    ) external
        propertyMustExist(_propertyId)
        propertyMustBeActive(_propertyId)
        onlyRegistrar
        contractMustBeActive
    {
        properties[_propertyId].value = _newValue;
        emit PropertyUpdated(_propertyId, _newValue);
    }

    function deactivateProperty(
        bytes32 _propertyId
    ) external
        propertyMustExist(_propertyId)
        propertyMustBeActive(_propertyId)
        onlyRegistrar
        contractMustBeActive
    {
        properties[_propertyId].isActive = false;
        emit PropertyDeactivated(_propertyId);
    }

    function getProperty(bytes32 _propertyId) external view propertyMustExist(_propertyId) returns (
        bytes32 propertyId,
        address owner,
        bytes32 location,
        uint256 area,
        uint256 value,
        bytes32 propertyType,
        uint64 registrationDate,
        bool isActive,
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
            prop.registrationDate,
            prop.isActive,
            prop.documentHash
        );
    }

    function getOwnerProperties(address _owner) external view returns (bytes32[] memory) {
        return ownerProperties[_owner];
    }

    function getPropertyTransferHistory(bytes32 _propertyId) external view propertyMustExist(_propertyId) returns (Transfer[] memory) {
        return propertyTransfers[_propertyId];
    }

    function getTotalProperties() external view returns (uint256) {
        return allPropertyIds.length;
    }

    function getAllPropertyIds() external view returns (bytes32[] memory) {
        return allPropertyIds;
    }

    function changeRegistrar(address _newRegistrar) external onlyRegistrar {
        require(_newRegistrar != address(0), "Invalid registrar address");
        registrar = _newRegistrar;
    }

    function toggleContractStatus() external onlyRegistrar {
        contractActive = !contractActive;
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
}
