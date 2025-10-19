
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract RealEstateRegistry is Ownable, ReentrancyGuard, Pausable {

    struct Property {
        uint256 id;
        address owner;
        string location;
        uint256 area;
        uint256 value;
        bool isRegistered;
        uint256 registrationTimestamp;
        bytes32 documentHash;
    }

    struct Transfer {
        uint256 propertyId;
        address from;
        address to;
        uint256 timestamp;
        uint256 price;
        bytes32 contractHash;
    }


    uint256 private _propertyCounter;
    uint256 private _transferCounter;


    mapping(uint256 => Property) private _properties;
    mapping(address => uint256[]) private _ownerProperties;
    mapping(bytes32 => bool) private _usedDocumentHashes;
    mapping(uint256 => Transfer[]) private _propertyTransfers;
    mapping(address => bool) private _authorizedAgents;


    event PropertyRegistered(uint256 indexed propertyId, address indexed owner, string location);
    event PropertyTransferred(uint256 indexed propertyId, address indexed from, address indexed to, uint256 price);
    event PropertyValueUpdated(uint256 indexed propertyId, uint256 oldValue, uint256 newValue);
    event AgentAuthorized(address indexed agent);
    event AgentRevoked(address indexed agent);


    error PropertyNotFound();
    error NotPropertyOwner();
    error PropertyAlreadyRegistered();
    error DocumentHashAlreadyUsed();
    error InvalidPropertyValue();
    error InvalidArea();
    error UnauthorizedAgent();
    error InvalidAddress();
    error TransferToSelf();

    modifier onlyPropertyOwner(uint256 propertyId) {
        if (_properties[propertyId].owner != msg.sender) revert NotPropertyOwner();
        _;
    }

    modifier onlyAuthorizedAgent() {
        if (!_authorizedAgents[msg.sender] && msg.sender != owner()) revert UnauthorizedAgent();
        _;
    }

    modifier propertyExists(uint256 propertyId) {
        if (!_properties[propertyId].isRegistered) revert PropertyNotFound();
        _;
    }

    constructor() {
        _authorizedAgents[msg.sender] = true;
    }

    function registerProperty(
        address propertyOwner,
        string calldata location,
        uint256 area,
        uint256 value,
        bytes32 documentHash
    ) external onlyAuthorizedAgent whenNotPaused returns (uint256) {
        if (propertyOwner == address(0)) revert InvalidAddress();
        if (area == 0) revert InvalidArea();
        if (value == 0) revert InvalidPropertyValue();
        if (_usedDocumentHashes[documentHash]) revert DocumentHashAlreadyUsed();

        uint256 propertyId = ++_propertyCounter;


        Property storage newProperty = _properties[propertyId];
        newProperty.id = propertyId;
        newProperty.owner = propertyOwner;
        newProperty.location = location;
        newProperty.area = area;
        newProperty.value = value;
        newProperty.isRegistered = true;
        newProperty.registrationTimestamp = block.timestamp;
        newProperty.documentHash = documentHash;


        _ownerProperties[propertyOwner].push(propertyId);


        _usedDocumentHashes[documentHash] = true;

        emit PropertyRegistered(propertyId, propertyOwner, location);

        return propertyId;
    }

    function transferProperty(
        uint256 propertyId,
        address newOwner,
        uint256 price,
        bytes32 contractHash
    ) external propertyExists(propertyId) onlyPropertyOwner(propertyId) whenNotPaused nonReentrant {
        if (newOwner == address(0)) revert InvalidAddress();
        if (newOwner == msg.sender) revert TransferToSelf();


        address currentOwner = _properties[propertyId].owner;


        _properties[propertyId].owner = newOwner;


        _removePropertyFromOwner(currentOwner, propertyId);


        _ownerProperties[newOwner].push(propertyId);


        uint256 transferId = _transferCounter++;
        _propertyTransfers[propertyId].push(Transfer({
            propertyId: propertyId,
            from: currentOwner,
            to: newOwner,
            timestamp: block.timestamp,
            price: price,
            contractHash: contractHash
        }));

        emit PropertyTransferred(propertyId, currentOwner, newOwner, price);
    }

    function updatePropertyValue(
        uint256 propertyId,
        uint256 newValue
    ) external propertyExists(propertyId) onlyPropertyOwner(propertyId) whenNotPaused {
        if (newValue == 0) revert InvalidPropertyValue();

        uint256 oldValue = _properties[propertyId].value;
        _properties[propertyId].value = newValue;

        emit PropertyValueUpdated(propertyId, oldValue, newValue);
    }

    function getProperty(uint256 propertyId) external view propertyExists(propertyId) returns (Property memory) {
        return _properties[propertyId];
    }

    function getPropertiesByOwner(address owner) external view returns (uint256[] memory) {
        return _ownerProperties[owner];
    }

    function getPropertyTransfers(uint256 propertyId) external view propertyExists(propertyId) returns (Transfer[] memory) {
        return _propertyTransfers[propertyId];
    }

    function getPropertyCount() external view returns (uint256) {
        return _propertyCounter;
    }

    function isDocumentHashUsed(bytes32 documentHash) external view returns (bool) {
        return _usedDocumentHashes[documentHash];
    }

    function authorizeAgent(address agent) external onlyOwner {
        if (agent == address(0)) revert InvalidAddress();
        _authorizedAgents[agent] = true;
        emit AgentAuthorized(agent);
    }

    function revokeAgent(address agent) external onlyOwner {
        _authorizedAgents[agent] = false;
        emit AgentRevoked(agent);
    }

    function isAuthorizedAgent(address agent) external view returns (bool) {
        return _authorizedAgents[agent];
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _removePropertyFromOwner(address owner, uint256 propertyId) private {
        uint256[] storage properties = _ownerProperties[owner];
        uint256 length = properties.length;


        for (uint256 i = 0; i < length; ) {
            if (properties[i] == propertyId) {

                properties[i] = properties[length - 1];
                properties.pop();
                break;
            }
            unchecked { ++i; }
        }
    }
}
