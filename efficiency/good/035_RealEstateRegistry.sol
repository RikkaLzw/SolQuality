
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract RealEstateRegistry is Ownable, ReentrancyGuard, Pausable {
    struct Property {
        uint256 id;
        string location;
        uint256 area;
        address owner;
        uint256 registrationTime;
        bool isActive;
        uint256 lastTransferTime;
        bytes32 documentHash;
    }

    struct TransferRecord {
        address from;
        address to;
        uint256 timestamp;
        uint256 price;
        bytes32 transferHash;
    }


    uint256 private _propertyCounter;


    mapping(uint256 => Property) private _properties;


    mapping(address => uint256[]) private _ownerProperties;


    mapping(uint256 => uint256) private _propertyOwnerIndex;


    mapping(uint256 => TransferRecord[]) private _transferHistory;


    mapping(uint256 => bool) private _propertyExists;


    mapping(address => uint256) private _ownerPropertyCount;


    event PropertyRegistered(
        uint256 indexed propertyId,
        address indexed owner,
        string location,
        uint256 area
    );

    event PropertyTransferred(
        uint256 indexed propertyId,
        address indexed from,
        address indexed to,
        uint256 price
    );

    event PropertyDeactivated(uint256 indexed propertyId);
    event PropertyReactivated(uint256 indexed propertyId);


    modifier propertyExists(uint256 propertyId) {
        require(_propertyExists[propertyId], "Property does not exist");
        _;
    }

    modifier onlyPropertyOwner(uint256 propertyId) {
        require(_properties[propertyId].owner == msg.sender, "Not property owner");
        _;
    }

    modifier propertyActive(uint256 propertyId) {
        require(_properties[propertyId].isActive, "Property is not active");
        _;
    }

    constructor() {}

    function registerProperty(
        string calldata location,
        uint256 area,
        bytes32 documentHash
    ) external whenNotPaused nonReentrant returns (uint256) {
        require(bytes(location).length > 0, "Location cannot be empty");
        require(area > 0, "Area must be greater than 0");
        require(documentHash != bytes32(0), "Document hash required");


        uint256 propertyId = ++_propertyCounter;


        Property memory newProperty = Property({
            id: propertyId,
            location: location,
            area: area,
            owner: msg.sender,
            registrationTime: block.timestamp,
            isActive: true,
            lastTransferTime: block.timestamp,
            documentHash: documentHash
        });


        _properties[propertyId] = newProperty;
        _propertyExists[propertyId] = true;


        _addPropertyToOwner(msg.sender, propertyId);

        emit PropertyRegistered(propertyId, msg.sender, location, area);

        return propertyId;
    }

    function transferProperty(
        uint256 propertyId,
        address to,
        uint256 price,
        bytes32 transferHash
    ) external
        whenNotPaused
        nonReentrant
        propertyExists(propertyId)
        onlyPropertyOwner(propertyId)
        propertyActive(propertyId)
    {
        require(to != address(0), "Invalid recipient address");
        require(to != msg.sender, "Cannot transfer to self");
        require(transferHash != bytes32(0), "Transfer hash required");


        Property storage property = _properties[propertyId];
        address previousOwner = property.owner;


        property.owner = to;
        property.lastTransferTime = block.timestamp;


        _removePropertyFromOwner(previousOwner, propertyId);
        _addPropertyToOwner(to, propertyId);


        _transferHistory[propertyId].push(TransferRecord({
            from: previousOwner,
            to: to,
            timestamp: block.timestamp,
            price: price,
            transferHash: transferHash
        }));

        emit PropertyTransferred(propertyId, previousOwner, to, price);
    }

    function deactivateProperty(uint256 propertyId)
        external
        propertyExists(propertyId)
        onlyPropertyOwner(propertyId)
    {
        Property storage property = _properties[propertyId];
        require(property.isActive, "Property already inactive");

        property.isActive = false;
        emit PropertyDeactivated(propertyId);
    }

    function reactivateProperty(uint256 propertyId)
        external
        propertyExists(propertyId)
        onlyPropertyOwner(propertyId)
    {
        Property storage property = _properties[propertyId];
        require(!property.isActive, "Property already active");

        property.isActive = true;
        emit PropertyReactivated(propertyId);
    }


    function getProperty(uint256 propertyId)
        external
        view
        propertyExists(propertyId)
        returns (Property memory)
    {
        return _properties[propertyId];
    }

    function getOwnerProperties(address owner)
        external
        view
        returns (uint256[] memory)
    {
        return _ownerProperties[owner];
    }

    function getOwnerPropertyCount(address owner)
        external
        view
        returns (uint256)
    {
        return _ownerPropertyCount[owner];
    }

    function getTransferHistory(uint256 propertyId)
        external
        view
        propertyExists(propertyId)
        returns (TransferRecord[] memory)
    {
        return _transferHistory[propertyId];
    }

    function getTotalProperties() external view returns (uint256) {
        return _propertyCounter;
    }

    function isPropertyActive(uint256 propertyId)
        external
        view
        propertyExists(propertyId)
        returns (bool)
    {
        return _properties[propertyId].isActive;
    }


    function _addPropertyToOwner(address owner, uint256 propertyId) private {
        uint256[] storage ownerProps = _ownerProperties[owner];
        _propertyOwnerIndex[propertyId] = ownerProps.length;
        ownerProps.push(propertyId);
        _ownerPropertyCount[owner]++;
    }

    function _removePropertyFromOwner(address owner, uint256 propertyId) private {
        uint256[] storage ownerProps = _ownerProperties[owner];
        uint256 index = _propertyOwnerIndex[propertyId];
        uint256 lastIndex = ownerProps.length - 1;

        if (index != lastIndex) {
            uint256 lastPropertyId = ownerProps[lastIndex];
            ownerProps[index] = lastPropertyId;
            _propertyOwnerIndex[lastPropertyId] = index;
        }

        ownerProps.pop();
        delete _propertyOwnerIndex[propertyId];
        _ownerPropertyCount[owner]--;
    }


    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function emergencyDeactivateProperty(uint256 propertyId)
        external
        onlyOwner
        propertyExists(propertyId)
    {
        _properties[propertyId].isActive = false;
        emit PropertyDeactivated(propertyId);
    }
}
