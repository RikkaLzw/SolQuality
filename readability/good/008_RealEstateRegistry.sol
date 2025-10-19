
pragma solidity ^0.8.0;


contract RealEstateRegistry {


    struct Property {
        uint256 propertyId;
        string propertyAddress;
        string propertyType;
        uint256 area;
        address currentOwner;
        uint256 registrationDate;
        bool isActive;
        string additionalInfo;
    }


    struct TransferRecord {
        uint256 propertyId;
        address fromOwner;
        address toOwner;
        uint256 transferDate;
        uint256 transferPrice;
        string transferReason;
    }


    address public registryAdmin;
    uint256 private nextPropertyId;
    uint256 private nextTransferRecordId;


    mapping(uint256 => Property) public properties;
    mapping(address => uint256[]) public ownerToProperties;
    mapping(uint256 => TransferRecord[]) public propertyTransferHistory;
    mapping(address => bool) public authorizedRegistrars;


    event PropertyRegistered(
        uint256 indexed propertyId,
        address indexed owner,
        string propertyAddress,
        uint256 registrationDate
    );

    event PropertyTransferred(
        uint256 indexed propertyId,
        address indexed fromOwner,
        address indexed toOwner,
        uint256 transferDate,
        uint256 transferPrice
    );

    event RegistrarAuthorized(address indexed registrar);
    event RegistrarRevoked(address indexed registrar);


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
        nextPropertyId = 1;
        nextTransferRecordId = 1;
        authorizedRegistrars[msg.sender] = true;
    }


    function authorizeRegistrar(address _registrar) external onlyAdmin {
        require(_registrar != address(0), "Invalid registrar address");
        require(!authorizedRegistrars[_registrar], "Registrar already authorized");

        authorizedRegistrars[_registrar] = true;
        emit RegistrarAuthorized(_registrar);
    }


    function revokeRegistrar(address _registrar) external onlyAdmin {
        require(authorizedRegistrars[_registrar], "Registrar not authorized");
        require(_registrar != registryAdmin, "Cannot revoke admin authorization");

        authorizedRegistrars[_registrar] = false;
        emit RegistrarRevoked(_registrar);
    }


    function registerProperty(
        address _owner,
        string memory _propertyAddress,
        string memory _propertyType,
        uint256 _area,
        string memory _additionalInfo
    ) external onlyAuthorizedRegistrar returns (uint256) {
        require(_owner != address(0), "Invalid owner address");
        require(bytes(_propertyAddress).length > 0, "Property address cannot be empty");
        require(_area > 0, "Property area must be greater than zero");

        uint256 propertyId = nextPropertyId;
        nextPropertyId++;

        properties[propertyId] = Property({
            propertyId: propertyId,
            propertyAddress: _propertyAddress,
            propertyType: _propertyType,
            area: _area,
            currentOwner: _owner,
            registrationDate: block.timestamp,
            isActive: true,
            additionalInfo: _additionalInfo
        });

        ownerToProperties[_owner].push(propertyId);

        emit PropertyRegistered(propertyId, _owner, _propertyAddress, block.timestamp);

        return propertyId;
    }


    function transferProperty(
        uint256 _propertyId,
        address _newOwner,
        uint256 _transferPrice,
        string memory _transferReason
    ) external propertyExists(_propertyId) onlyPropertyOwner(_propertyId) {
        require(_newOwner != address(0), "Invalid new owner address");
        require(_newOwner != msg.sender, "Cannot transfer to yourself");

        address currentOwner = properties[_propertyId].currentOwner;


        properties[_propertyId].currentOwner = _newOwner;


        _removePropertyFromOwner(currentOwner, _propertyId);


        ownerToProperties[_newOwner].push(_propertyId);


        propertyTransferHistory[_propertyId].push(TransferRecord({
            propertyId: _propertyId,
            fromOwner: currentOwner,
            toOwner: _newOwner,
            transferDate: block.timestamp,
            transferPrice: _transferPrice,
            transferReason: _transferReason
        }));

        emit PropertyTransferred(_propertyId, currentOwner, _newOwner, block.timestamp, _transferPrice);
    }


    function updatePropertyInfo(
        uint256 _propertyId,
        string memory _propertyAddress,
        string memory _propertyType,
        uint256 _area,
        string memory _additionalInfo
    ) external propertyExists(_propertyId) onlyAuthorizedRegistrar {
        require(bytes(_propertyAddress).length > 0, "Property address cannot be empty");
        require(_area > 0, "Property area must be greater than zero");

        Property storage property = properties[_propertyId];
        property.propertyAddress = _propertyAddress;
        property.propertyType = _propertyType;
        property.area = _area;
        property.additionalInfo = _additionalInfo;
    }


    function deactivateProperty(uint256 _propertyId) external propertyExists(_propertyId) onlyAuthorizedRegistrar {
        properties[_propertyId].isActive = false;
    }


    function reactivateProperty(uint256 _propertyId) external onlyAuthorizedRegistrar {
        require(properties[_propertyId].propertyId != 0, "Property does not exist");
        properties[_propertyId].isActive = true;
    }


    function getProperty(uint256 _propertyId) external view returns (Property memory) {
        require(properties[_propertyId].propertyId != 0, "Property does not exist");
        return properties[_propertyId];
    }


    function getPropertiesByOwner(address _owner) external view returns (uint256[] memory) {
        return ownerToProperties[_owner];
    }


    function getPropertyTransferHistory(uint256 _propertyId) external view returns (TransferRecord[] memory) {
        return propertyTransferHistory[_propertyId];
    }


    function getTotalProperties() external view returns (uint256) {
        return nextPropertyId - 1;
    }


    function verifyOwnership(uint256 _propertyId, address _owner) external view returns (bool) {
        return properties[_propertyId].isActive && properties[_propertyId].currentOwner == _owner;
    }


    function _removePropertyFromOwner(address _owner, uint256 _propertyId) internal {
        uint256[] storage ownerProperties = ownerToProperties[_owner];

        for (uint256 i = 0; i < ownerProperties.length; i++) {
            if (ownerProperties[i] == _propertyId) {
                ownerProperties[i] = ownerProperties[ownerProperties.length - 1];
                ownerProperties.pop();
                break;
            }
        }
    }


    function transferAdminRole(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0), "Invalid new admin address");
        require(_newAdmin != registryAdmin, "New admin is the same as current admin");

        registryAdmin = _newAdmin;
        authorizedRegistrars[_newAdmin] = true;
    }
}
