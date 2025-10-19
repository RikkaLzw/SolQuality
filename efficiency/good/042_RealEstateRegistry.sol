
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract RealEstateRegistry is Ownable, ReentrancyGuard, Pausable {

    struct Property {
        uint256 id;
        string propertyAddress;
        uint256 area;
        uint256 price;
        address currentOwner;
        bool isRegistered;
        uint256 registrationTimestamp;
        bytes32 documentHash;
    }

    struct TransferRecord {
        address from;
        address to;
        uint256 timestamp;
        uint256 price;
    }


    uint256 private _propertyIdCounter;


    mapping(uint256 => Property) public properties;
    mapping(address => uint256[]) private _ownerToPropertyIds;
    mapping(uint256 => TransferRecord[]) private _propertyTransferHistory;
    mapping(bytes32 => uint256) private _documentHashToPropertyId;
    mapping(address => bool) public authorizedRegistrars;


    event PropertyRegistered(
        uint256 indexed propertyId,
        address indexed owner,
        string propertyAddress,
        uint256 area,
        bytes32 documentHash
    );

    event PropertyTransferred(
        uint256 indexed propertyId,
        address indexed from,
        address indexed to,
        uint256 price,
        uint256 timestamp
    );

    event RegistrarAuthorized(address indexed registrar);
    event RegistrarRevoked(address indexed registrar);

    modifier onlyAuthorizedRegistrar() {
        require(authorizedRegistrars[msg.sender] || msg.sender == owner(), "Not authorized registrar");
        _;
    }

    modifier propertyExists(uint256 _propertyId) {
        require(properties[_propertyId].isRegistered, "Property does not exist");
        _;
    }

    modifier onlyPropertyOwner(uint256 _propertyId) {
        require(properties[_propertyId].currentOwner == msg.sender, "Not property owner");
        _;
    }

    constructor() {
        _propertyIdCounter = 1;
        authorizedRegistrars[msg.sender] = true;
    }

    function registerProperty(
        string memory _propertyAddress,
        uint256 _area,
        uint256 _price,
        address _owner,
        bytes32 _documentHash
    ) external onlyAuthorizedRegistrar whenNotPaused returns (uint256) {
        require(_owner != address(0), "Invalid owner address");
        require(_area > 0, "Area must be greater than 0");
        require(bytes(_propertyAddress).length > 0, "Property address required");
        require(_documentHashToPropertyId[_documentHash] == 0, "Document already registered");

        uint256 propertyId = _propertyIdCounter;


        Property memory newProperty = Property({
            id: propertyId,
            propertyAddress: _propertyAddress,
            area: _area,
            price: _price,
            currentOwner: _owner,
            isRegistered: true,
            registrationTimestamp: block.timestamp,
            documentHash: _documentHash
        });


        properties[propertyId] = newProperty;


        _ownerToPropertyIds[_owner].push(propertyId);
        _documentHashToPropertyId[_documentHash] = propertyId;


        _propertyIdCounter++;

        emit PropertyRegistered(propertyId, _owner, _propertyAddress, _area, _documentHash);

        return propertyId;
    }

    function transferProperty(
        uint256 _propertyId,
        address _newOwner,
        uint256 _transferPrice
    ) external propertyExists(_propertyId) onlyPropertyOwner(_propertyId) whenNotPaused nonReentrant {
        require(_newOwner != address(0), "Invalid new owner address");
        require(_newOwner != msg.sender, "Cannot transfer to self");


        address currentOwner = properties[_propertyId].currentOwner;


        properties[_propertyId].currentOwner = _newOwner;
        properties[_propertyId].price = _transferPrice;


        _removePropertyFromOwner(currentOwner, _propertyId);
        _ownerToPropertyIds[_newOwner].push(_propertyId);


        _propertyTransferHistory[_propertyId].push(TransferRecord({
            from: currentOwner,
            to: _newOwner,
            timestamp: block.timestamp,
            price: _transferPrice
        }));

        emit PropertyTransferred(_propertyId, currentOwner, _newOwner, _transferPrice, block.timestamp);
    }

    function updatePropertyPrice(
        uint256 _propertyId,
        uint256 _newPrice
    ) external propertyExists(_propertyId) onlyPropertyOwner(_propertyId) whenNotPaused {
        properties[_propertyId].price = _newPrice;
    }

    function getProperty(uint256 _propertyId) external view propertyExists(_propertyId) returns (
        uint256 id,
        string memory propertyAddress,
        uint256 area,
        uint256 price,
        address currentOwner,
        uint256 registrationTimestamp,
        bytes32 documentHash
    ) {
        Property storage prop = properties[_propertyId];
        return (
            prop.id,
            prop.propertyAddress,
            prop.area,
            prop.price,
            prop.currentOwner,
            prop.registrationTimestamp,
            prop.documentHash
        );
    }

    function getPropertiesByOwner(address _owner) external view returns (uint256[] memory) {
        return _ownerToPropertyIds[_owner];
    }

    function getPropertyTransferHistory(uint256 _propertyId) external view propertyExists(_propertyId) returns (
        address[] memory fromAddresses,
        address[] memory toAddresses,
        uint256[] memory timestamps,
        uint256[] memory prices
    ) {
        TransferRecord[] storage transfers = _propertyTransferHistory[_propertyId];
        uint256 length = transfers.length;

        fromAddresses = new address[](length);
        toAddresses = new address[](length);
        timestamps = new uint256[](length);
        prices = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            TransferRecord storage transfer = transfers[i];
            fromAddresses[i] = transfer.from;
            toAddresses[i] = transfer.to;
            timestamps[i] = transfer.timestamp;
            prices[i] = transfer.price;
        }
    }

    function getPropertyByDocumentHash(bytes32 _documentHash) external view returns (uint256) {
        uint256 propertyId = _documentHashToPropertyId[_documentHash];
        require(propertyId != 0, "Property not found for document hash");
        return propertyId;
    }

    function getTotalProperties() external view returns (uint256) {
        return _propertyIdCounter - 1;
    }

    function authorizeRegistrar(address _registrar) external onlyOwner {
        require(_registrar != address(0), "Invalid registrar address");
        authorizedRegistrars[_registrar] = true;
        emit RegistrarAuthorized(_registrar);
    }

    function revokeRegistrar(address _registrar) external onlyOwner {
        authorizedRegistrars[_registrar] = false;
        emit RegistrarRevoked(_registrar);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _removePropertyFromOwner(address _owner, uint256 _propertyId) private {
        uint256[] storage ownerProperties = _ownerToPropertyIds[_owner];
        uint256 length = ownerProperties.length;

        for (uint256 i = 0; i < length; i++) {
            if (ownerProperties[i] == _propertyId) {

                ownerProperties[i] = ownerProperties[length - 1];
                ownerProperties.pop();
                break;
            }
        }
    }
}
