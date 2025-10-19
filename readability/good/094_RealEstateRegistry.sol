
pragma solidity ^0.8.0;


contract RealEstateRegistry {


    struct Property {
        uint256 propertyId;
        string propertyAddress;
        string propertyType;
        uint256 propertyArea;
        string legalDescription;
        address currentOwner;
        uint256 registrationDate;
        bool isActive;
        uint256 propertyValue;
    }


    struct OwnershipTransfer {
        uint256 transferId;
        uint256 propertyId;
        address previousOwner;
        address newOwner;
        uint256 transferDate;
        uint256 transferPrice;
        string transferReason;
    }


    address public registryAdmin;
    uint256 public totalProperties;
    uint256 public totalTransfers;


    mapping(uint256 => Property) public properties;
    mapping(address => uint256[]) public ownerProperties;
    mapping(uint256 => OwnershipTransfer[]) public propertyTransferHistory;
    mapping(address => bool) public authorizedRegistrars;


    event PropertyRegistered(
        uint256 indexed propertyId,
        address indexed owner,
        string propertyAddress,
        uint256 registrationDate
    );

    event OwnershipTransferred(
        uint256 indexed propertyId,
        address indexed previousOwner,
        address indexed newOwner,
        uint256 transferDate,
        uint256 transferPrice
    );

    event RegistrarAuthorized(address indexed registrar);
    event RegistrarRevoked(address indexed registrar);
    event PropertyUpdated(uint256 indexed propertyId);


    modifier onlyAdmin() {
        require(msg.sender == registryAdmin, "Only admin can perform this action");
        _;
    }

    modifier onlyAuthorizedRegistrar() {
        require(
            authorizedRegistrars[msg.sender] || msg.sender == registryAdmin,
            "Only authorized registrar can perform this action"
        );
        _;
    }

    modifier propertyExists(uint256 _propertyId) {
        require(properties[_propertyId].isActive, "Property does not exist or is inactive");
        _;
    }

    modifier onlyPropertyOwner(uint256 _propertyId) {
        require(
            properties[_propertyId].currentOwner == msg.sender,
            "Only property owner can perform this action"
        );
        _;
    }


    constructor() {
        registryAdmin = msg.sender;
        authorizedRegistrars[msg.sender] = true;
    }


    function authorizeRegistrar(address _registrar) external onlyAdmin {
        require(_registrar != address(0), "Invalid registrar address");
        require(!authorizedRegistrars[_registrar], "Registrar already authorized");

        authorizedRegistrars[_registrar] = true;
        emit RegistrarAuthorized(_registrar);
    }


    function revokeRegistrar(address _registrar) external onlyAdmin {
        require(_registrar != registryAdmin, "Cannot revoke admin authorization");
        require(authorizedRegistrars[_registrar], "Registrar not authorized");

        authorizedRegistrars[_registrar] = false;
        emit RegistrarRevoked(_registrar);
    }


    function registerProperty(
        string memory _propertyAddress,
        string memory _propertyType,
        uint256 _propertyArea,
        string memory _legalDescription,
        address _owner,
        uint256 _propertyValue
    ) external onlyAuthorizedRegistrar {
        require(_owner != address(0), "Invalid owner address");
        require(bytes(_propertyAddress).length > 0, "Property address cannot be empty");
        require(_propertyArea > 0, "Property area must be greater than zero");

        totalProperties++;
        uint256 newPropertyId = totalProperties;

        properties[newPropertyId] = Property({
            propertyId: newPropertyId,
            propertyAddress: _propertyAddress,
            propertyType: _propertyType,
            propertyArea: _propertyArea,
            legalDescription: _legalDescription,
            currentOwner: _owner,
            registrationDate: block.timestamp,
            isActive: true,
            propertyValue: _propertyValue
        });

        ownerProperties[_owner].push(newPropertyId);

        emit PropertyRegistered(newPropertyId, _owner, _propertyAddress, block.timestamp);
    }


    function transferOwnership(
        uint256 _propertyId,
        address _newOwner,
        uint256 _transferPrice,
        string memory _transferReason
    ) external propertyExists(_propertyId) onlyPropertyOwner(_propertyId) {
        require(_newOwner != address(0), "Invalid new owner address");
        require(_newOwner != properties[_propertyId].currentOwner, "New owner cannot be the same as current owner");

        address previousOwner = properties[_propertyId].currentOwner;


        properties[_propertyId].currentOwner = _newOwner;


        _removePropertyFromOwner(previousOwner, _propertyId);


        ownerProperties[_newOwner].push(_propertyId);


        totalTransfers++;
        propertyTransferHistory[_propertyId].push(OwnershipTransfer({
            transferId: totalTransfers,
            propertyId: _propertyId,
            previousOwner: previousOwner,
            newOwner: _newOwner,
            transferDate: block.timestamp,
            transferPrice: _transferPrice,
            transferReason: _transferReason
        }));

        emit OwnershipTransferred(_propertyId, previousOwner, _newOwner, block.timestamp, _transferPrice);
    }


    function updatePropertyInfo(
        uint256 _propertyId,
        uint256 _propertyValue,
        string memory _propertyType
    ) external onlyAuthorizedRegistrar propertyExists(_propertyId) {
        properties[_propertyId].propertyValue = _propertyValue;
        properties[_propertyId].propertyType = _propertyType;

        emit PropertyUpdated(_propertyId);
    }


    function deactivateProperty(uint256 _propertyId) external onlyAuthorizedRegistrar propertyExists(_propertyId) {
        properties[_propertyId].isActive = false;
    }


    function getPropertyDetails(uint256 _propertyId) external view returns (Property memory) {
        require(properties[_propertyId].propertyId != 0, "Property does not exist");
        return properties[_propertyId];
    }


    function getOwnerProperties(address _owner) external view returns (uint256[] memory) {
        return ownerProperties[_owner];
    }


    function getPropertyTransferHistory(uint256 _propertyId) external view returns (OwnershipTransfer[] memory) {
        return propertyTransferHistory[_propertyId];
    }


    function verifyOwnership(uint256 _propertyId, address _owner) external view returns (bool) {
        return properties[_propertyId].isActive && properties[_propertyId].currentOwner == _owner;
    }


    function getContractStats() external view returns (uint256 totalProps, uint256 totalTrans) {
        return (totalProperties, totalTransfers);
    }


    function _removePropertyFromOwner(address _owner, uint256 _propertyId) internal {
        uint256[] storage ownerProps = ownerProperties[_owner];
        for (uint256 i = 0; i < ownerProps.length; i++) {
            if (ownerProps[i] == _propertyId) {
                ownerProps[i] = ownerProps[ownerProps.length - 1];
                ownerProps.pop();
                break;
            }
        }
    }


    function transferAdminRole(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0), "Invalid new admin address");
        require(_newAdmin != registryAdmin, "New admin cannot be the same as current admin");

        registryAdmin = _newAdmin;
        authorizedRegistrars[_newAdmin] = true;
    }
}
