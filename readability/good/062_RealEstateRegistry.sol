
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
        string description;
    }


    struct TransferRecord {
        uint256 propertyId;
        address fromOwner;
        address toOwner;
        uint256 transferDate;
        uint256 transferPrice;
        string transferReason;
    }


    address public administrator;


    uint256 private propertyCounter;


    uint256 private transferCounter;


    mapping(uint256 => Property) public properties;


    mapping(address => uint256[]) public ownerToProperties;


    mapping(uint256 => TransferRecord) public transferRecords;


    mapping(uint256 => uint256[]) public propertyTransferHistory;


    mapping(address => bool) public authorizedRegistrars;


    event PropertyRegistered(
        uint256 indexed propertyId,
        address indexed owner,
        string propertyAddress
    );

    event PropertyTransferred(
        uint256 indexed propertyId,
        address indexed fromOwner,
        address indexed toOwner,
        uint256 transferPrice
    );

    event RegistrarAuthorized(address indexed registrar);
    event RegistrarRevoked(address indexed registrar);


    modifier onlyAdministrator() {
        require(msg.sender == administrator, "Only administrator can perform this action");
        _;
    }


    modifier onlyAuthorizedRegistrar() {
        require(
            authorizedRegistrars[msg.sender] || msg.sender == administrator,
            "Only authorized registrar can perform this action"
        );
        _;
    }


    modifier onlyPropertyOwner(uint256 _propertyId) {
        require(
            properties[_propertyId].currentOwner == msg.sender,
            "Only property owner can perform this action"
        );
        _;
    }


    modifier propertyExists(uint256 _propertyId) {
        require(
            _propertyId > 0 && _propertyId <= propertyCounter,
            "Property does not exist"
        );
        require(properties[_propertyId].isActive, "Property is not active");
        _;
    }


    constructor() {
        administrator = msg.sender;
        propertyCounter = 0;
        transferCounter = 0;
    }


    function authorizeRegistrar(address _registrar) external onlyAdministrator {
        require(_registrar != address(0), "Invalid registrar address");
        require(!authorizedRegistrars[_registrar], "Registrar already authorized");

        authorizedRegistrars[_registrar] = true;
        emit RegistrarAuthorized(_registrar);
    }


    function revokeRegistrar(address _registrar) external onlyAdministrator {
        require(authorizedRegistrars[_registrar], "Registrar not authorized");

        authorizedRegistrars[_registrar] = false;
        emit RegistrarRevoked(_registrar);
    }


    function registerProperty(
        address _owner,
        string memory _propertyAddress,
        string memory _propertyType,
        uint256 _area,
        string memory _description
    ) external onlyAuthorizedRegistrar returns (uint256) {
        require(_owner != address(0), "Invalid owner address");
        require(bytes(_propertyAddress).length > 0, "Property address cannot be empty");
        require(_area > 0, "Property area must be greater than zero");

        propertyCounter++;
        uint256 newPropertyId = propertyCounter;

        properties[newPropertyId] = Property({
            propertyId: newPropertyId,
            propertyAddress: _propertyAddress,
            propertyType: _propertyType,
            area: _area,
            currentOwner: _owner,
            registrationDate: block.timestamp,
            isActive: true,
            description: _description
        });

        ownerToProperties[_owner].push(newPropertyId);

        emit PropertyRegistered(newPropertyId, _owner, _propertyAddress);

        return newPropertyId;
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


        transferCounter++;
        transferRecords[transferCounter] = TransferRecord({
            propertyId: _propertyId,
            fromOwner: currentOwner,
            toOwner: _newOwner,
            transferDate: block.timestamp,
            transferPrice: _transferPrice,
            transferReason: _transferReason
        });

        propertyTransferHistory[_propertyId].push(transferCounter);

        emit PropertyTransferred(_propertyId, currentOwner, _newOwner, _transferPrice);
    }


    function deactivateProperty(uint256 _propertyId) external onlyAdministrator propertyExists(_propertyId) {
        properties[_propertyId].isActive = false;
    }


    function reactivateProperty(uint256 _propertyId) external onlyAdministrator {
        require(_propertyId > 0 && _propertyId <= propertyCounter, "Property does not exist");
        properties[_propertyId].isActive = true;
    }


    function getPropertyDetails(uint256 _propertyId) external view propertyExists(_propertyId) returns (Property memory) {
        return properties[_propertyId];
    }


    function getPropertiesByOwner(address _owner) external view returns (uint256[] memory) {
        return ownerToProperties[_owner];
    }


    function getPropertyTransferHistory(uint256 _propertyId) external view propertyExists(_propertyId) returns (uint256[] memory) {
        return propertyTransferHistory[_propertyId];
    }


    function getTransferRecord(uint256 _transferId) external view returns (TransferRecord memory) {
        require(_transferId > 0 && _transferId <= transferCounter, "Transfer record does not exist");
        return transferRecords[_transferId];
    }


    function getTotalProperties() external view returns (uint256) {
        return propertyCounter;
    }


    function getTotalTransfers() external view returns (uint256) {
        return transferCounter;
    }


    function verifyOwnership(uint256 _propertyId, address _owner) external view propertyExists(_propertyId) returns (bool) {
        return properties[_propertyId].currentOwner == _owner;
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


    function changeAdministrator(address _newAdministrator) external onlyAdministrator {
        require(_newAdministrator != address(0), "Invalid administrator address");
        require(_newAdministrator != administrator, "Same administrator address");

        administrator = _newAdministrator;
    }
}
