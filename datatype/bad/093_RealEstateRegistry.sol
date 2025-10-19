
pragma solidity ^0.8.0;

contract RealEstateRegistry {
    address public owner;
    uint256 public totalProperties;

    struct Property {
        uint256 propertyId;
        string ownerName;
        string propertyAddress;
        uint256 propertySize;
        uint256 propertyType;
        uint256 isActive;
        string certificateNumber;
        bytes propertyDescription;
        uint256 registrationDate;
        uint256 lastTransferDate;
    }

    mapping(uint256 => Property) public properties;
    mapping(address => uint256[]) public ownerProperties;
    mapping(string => uint256) public certificateToPropertyId;

    event PropertyRegistered(uint256 indexed propertyId, string ownerName, string certificateNumber);
    event PropertyTransferred(uint256 indexed propertyId, string newOwnerName, string oldOwnerName);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only contract owner can perform this action");
        _;
    }

    modifier propertyExists(uint256 _propertyId) {
        require(uint256(properties[_propertyId].isActive) == uint256(1), "Property does not exist or is inactive");
        _;
    }

    constructor() {
        owner = msg.sender;
        totalProperties = uint256(0);
    }

    function registerProperty(
        string memory _ownerName,
        string memory _propertyAddress,
        uint256 _propertySize,
        uint256 _propertyType,
        string memory _certificateNumber,
        bytes memory _propertyDescription
    ) public onlyOwner {
        require(bytes(_ownerName).length > 0, "Owner name cannot be empty");
        require(bytes(_propertyAddress).length > 0, "Property address cannot be empty");
        require(_propertySize > uint256(0), "Property size must be greater than 0");
        require(_propertyType >= uint256(1) && _propertyType <= uint256(2), "Invalid property type");
        require(certificateToPropertyId[_certificateNumber] == uint256(0), "Certificate number already exists");

        totalProperties = totalProperties + uint256(1);
        uint256 newPropertyId = totalProperties;

        properties[newPropertyId] = Property({
            propertyId: newPropertyId,
            ownerName: _ownerName,
            propertyAddress: _propertyAddress,
            propertySize: _propertySize,
            propertyType: _propertyType,
            isActive: uint256(1),
            certificateNumber: _certificateNumber,
            propertyDescription: _propertyDescription,
            registrationDate: block.timestamp,
            lastTransferDate: block.timestamp
        });

        ownerProperties[msg.sender].push(newPropertyId);
        certificateToPropertyId[_certificateNumber] = newPropertyId;

        emit PropertyRegistered(newPropertyId, _ownerName, _certificateNumber);
    }

    function transferProperty(
        uint256 _propertyId,
        string memory _newOwnerName,
        address _newOwnerAddress
    ) public onlyOwner propertyExists(_propertyId) {
        require(bytes(_newOwnerName).length > 0, "New owner name cannot be empty");
        require(_newOwnerAddress != address(0), "Invalid new owner address");

        Property storage property = properties[_propertyId];
        string memory oldOwnerName = property.ownerName;

        property.ownerName = _newOwnerName;
        property.lastTransferDate = block.timestamp;

        ownerProperties[_newOwnerAddress].push(_propertyId);

        emit PropertyTransferred(_propertyId, _newOwnerName, oldOwnerName);
    }

    function deactivateProperty(uint256 _propertyId) public onlyOwner propertyExists(_propertyId) {
        properties[_propertyId].isActive = uint256(0);
    }

    function activateProperty(uint256 _propertyId) public onlyOwner {
        require(properties[_propertyId].propertyId != uint256(0), "Property does not exist");
        properties[_propertyId].isActive = uint256(1);
    }

    function getPropertyDetails(uint256 _propertyId) public view propertyExists(_propertyId) returns (
        uint256 propertyId,
        string memory ownerName,
        string memory propertyAddress,
        uint256 propertySize,
        uint256 propertyType,
        uint256 isActive,
        string memory certificateNumber,
        bytes memory propertyDescription,
        uint256 registrationDate,
        uint256 lastTransferDate
    ) {
        Property memory property = properties[_propertyId];
        return (
            property.propertyId,
            property.ownerName,
            property.propertyAddress,
            property.propertySize,
            property.propertyType,
            property.isActive,
            property.certificateNumber,
            property.propertyDescription,
            property.registrationDate,
            property.lastTransferDate
        );
    }

    function getPropertiesByOwner(address _ownerAddress) public view returns (uint256[] memory) {
        return ownerProperties[_ownerAddress];
    }

    function getPropertyByCertificate(string memory _certificateNumber) public view returns (uint256) {
        uint256 propertyId = certificateToPropertyId[_certificateNumber];
        require(propertyId != uint256(0), "Certificate number not found");
        return propertyId;
    }

    function isPropertyActive(uint256 _propertyId) public view returns (uint256) {
        return properties[_propertyId].isActive;
    }

    function updatePropertyDescription(uint256 _propertyId, bytes memory _newDescription) public onlyOwner propertyExists(_propertyId) {
        properties[_propertyId].propertyDescription = _newDescription;
    }

    function getTotalActiveProperties() public view returns (uint256) {
        uint256 activeCount = uint256(0);
        for (uint256 i = uint256(1); i <= totalProperties; i = i + uint256(1)) {
            if (properties[i].isActive == uint256(1)) {
                activeCount = activeCount + uint256(1);
            }
        }
        return activeCount;
    }
}
