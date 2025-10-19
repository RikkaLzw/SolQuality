
pragma solidity ^0.8.0;

contract RealEstateRegistryContract {
    struct Property {
        uint256 propertyId;
        string ownerName;
        string propertyAddress;
        uint256 propertyType;
        uint256 area;
        uint256 registrationDate;
        uint256 isActive;
        bytes propertyDescription;
        string propertyCode;
        uint256 floors;
        uint256 rooms;
        uint256 bathrooms;
    }

    mapping(uint256 => Property) public properties;
    mapping(address => uint256[]) public ownerProperties;
    mapping(string => uint256) public propertyCodeToId;

    uint256 public totalProperties;
    uint256 public contractStatus;
    address public admin;

    event PropertyRegistered(uint256 indexed propertyId, string ownerName, string propertyAddress);
    event PropertyTransferred(uint256 indexed propertyId, address indexed oldOwner, address indexed newOwner);
    event PropertyStatusChanged(uint256 indexed propertyId, uint256 newStatus);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier contractActive() {
        require(uint256(contractStatus) == uint256(1), "Contract is paused");
        _;
    }

    constructor() {
        admin = msg.sender;
        totalProperties = uint256(0);
        contractStatus = uint256(1);
    }

    function registerProperty(
        string memory _ownerName,
        string memory _propertyAddress,
        uint256 _propertyType,
        uint256 _area,
        bytes memory _propertyDescription,
        string memory _propertyCode,
        uint256 _floors,
        uint256 _rooms,
        uint256 _bathrooms
    ) public onlyAdmin contractActive {
        require(bytes(_ownerName).length > 0, "Owner name cannot be empty");
        require(bytes(_propertyAddress).length > 0, "Property address cannot be empty");
        require(_area > 0, "Area must be greater than 0");
        require(propertyCodeToId[_propertyCode] == 0, "Property code already exists");
        require(uint256(_propertyType) <= uint256(2), "Invalid property type");

        totalProperties = uint256(totalProperties) + uint256(1);

        Property storage newProperty = properties[totalProperties];
        newProperty.propertyId = totalProperties;
        newProperty.ownerName = _ownerName;
        newProperty.propertyAddress = _propertyAddress;
        newProperty.propertyType = uint256(_propertyType);
        newProperty.area = _area;
        newProperty.registrationDate = uint256(block.timestamp);
        newProperty.isActive = uint256(1);
        newProperty.propertyDescription = _propertyDescription;
        newProperty.propertyCode = _propertyCode;
        newProperty.floors = uint256(_floors);
        newProperty.rooms = uint256(_rooms);
        newProperty.bathrooms = uint256(_bathrooms);

        ownerProperties[msg.sender].push(totalProperties);
        propertyCodeToId[_propertyCode] = totalProperties;

        emit PropertyRegistered(totalProperties, _ownerName, _propertyAddress);
    }

    function transferProperty(
        uint256 _propertyId,
        address _newOwner,
        string memory _newOwnerName
    ) public onlyAdmin contractActive {
        require(_propertyId > 0 && _propertyId <= totalProperties, "Invalid property ID");
        require(_newOwner != address(0), "Invalid new owner address");
        require(bytes(_newOwnerName).length > 0, "New owner name cannot be empty");
        require(uint256(properties[_propertyId].isActive) == uint256(1), "Property is not active");

        Property storage property = properties[_propertyId];


        uint256[] storage oldOwnerProps = ownerProperties[msg.sender];
        for (uint256 i = uint256(0); i < oldOwnerProps.length; i = uint256(i) + uint256(1)) {
            if (oldOwnerProps[i] == _propertyId) {
                oldOwnerProps[i] = oldOwnerProps[oldOwnerProps.length - 1];
                oldOwnerProps.pop();
                break;
            }
        }


        ownerProperties[_newOwner].push(_propertyId);


        property.ownerName = _newOwnerName;

        emit PropertyTransferred(_propertyId, msg.sender, _newOwner);
    }

    function updatePropertyStatus(uint256 _propertyId, uint256 _status) public onlyAdmin {
        require(_propertyId > 0 && _propertyId <= totalProperties, "Invalid property ID");
        require(uint256(_status) == uint256(0) || uint256(_status) == uint256(1), "Status must be 0 or 1");

        properties[_propertyId].isActive = uint256(_status);

        emit PropertyStatusChanged(_propertyId, _status);
    }

    function updatePropertyDescription(uint256 _propertyId, bytes memory _newDescription) public onlyAdmin contractActive {
        require(_propertyId > 0 && _propertyId <= totalProperties, "Invalid property ID");
        require(uint256(properties[_propertyId].isActive) == uint256(1), "Property is not active");

        properties[_propertyId].propertyDescription = _newDescription;
    }

    function getProperty(uint256 _propertyId) public view returns (
        uint256 propertyId,
        string memory ownerName,
        string memory propertyAddress,
        uint256 propertyType,
        uint256 area,
        uint256 registrationDate,
        uint256 isActive,
        bytes memory propertyDescription,
        string memory propertyCode,
        uint256 floors,
        uint256 rooms,
        uint256 bathrooms
    ) {
        require(_propertyId > 0 && _propertyId <= totalProperties, "Invalid property ID");

        Property storage property = properties[_propertyId];
        return (
            property.propertyId,
            property.ownerName,
            property.propertyAddress,
            property.propertyType,
            property.area,
            property.registrationDate,
            property.isActive,
            property.propertyDescription,
            property.propertyCode,
            property.floors,
            property.rooms,
            property.bathrooms
        );
    }

    function getPropertiesByOwner(address _owner) public view returns (uint256[] memory) {
        return ownerProperties[_owner];
    }

    function getPropertyByCode(string memory _propertyCode) public view returns (uint256) {
        return propertyCodeToId[_propertyCode];
    }

    function pauseContract() public onlyAdmin {
        contractStatus = uint256(0);
    }

    function resumeContract() public onlyAdmin {
        contractStatus = uint256(1);
    }

    function isContractActive() public view returns (uint256) {
        return uint256(contractStatus);
    }

    function getActivePropertiesCount() public view returns (uint256) {
        uint256 count = uint256(0);
        for (uint256 i = uint256(1); i <= totalProperties; i = uint256(i) + uint256(1)) {
            if (uint256(properties[i].isActive) == uint256(1)) {
                count = uint256(count) + uint256(1);
            }
        }
        return count;
    }
}
