
pragma solidity ^0.8.0;

contract RealEstateRegistry {
    struct Property {
        uint256 propertyId;
        string ownerName;
        string propertyAddress;
        uint256 propertyType;
        uint256 area;
        uint256 registrationDate;
        uint256 isActive;
        bytes propertyDescription;
        string certificateNumber;
        uint256 floors;
        uint256 rooms;
        uint256 bathrooms;
    }

    mapping(uint256 => Property) public properties;
    mapping(address => uint256[]) public ownerProperties;
    mapping(string => uint256) public certificateToPropertyId;

    uint256 public totalProperties;
    address public registrar;
    uint256 public contractActive;

    event PropertyRegistered(uint256 indexed propertyId, address indexed owner, string certificateNumber);
    event PropertyTransferred(uint256 indexed propertyId, address indexed from, address indexed to);
    event PropertyUpdated(uint256 indexed propertyId);

    modifier onlyRegistrar() {
        require(msg.sender == registrar, "Only registrar can perform this action");
        _;
    }

    modifier contractIsActive() {
        require(uint256(contractActive) == uint256(1), "Contract is not active");
        _;
    }

    constructor() {
        registrar = msg.sender;
        totalProperties = uint256(0);
        contractActive = uint256(1);
    }

    function registerProperty(
        string memory _ownerName,
        string memory _propertyAddress,
        uint256 _propertyType,
        uint256 _area,
        bytes memory _propertyDescription,
        string memory _certificateNumber,
        uint256 _floors,
        uint256 _rooms,
        uint256 _bathrooms
    ) public onlyRegistrar contractIsActive returns (uint256) {
        require(bytes(_ownerName).length > 0, "Owner name cannot be empty");
        require(bytes(_propertyAddress).length > 0, "Property address cannot be empty");
        require(bytes(_certificateNumber).length > 0, "Certificate number cannot be empty");
        require(certificateToPropertyId[_certificateNumber] == 0, "Certificate number already exists");
        require(_area > 0, "Area must be greater than 0");

        totalProperties = uint256(totalProperties + uint256(1));
        uint256 newPropertyId = totalProperties;

        properties[newPropertyId] = Property({
            propertyId: newPropertyId,
            ownerName: _ownerName,
            propertyAddress: _propertyAddress,
            propertyType: uint256(_propertyType),
            area: uint256(_area),
            registrationDate: uint256(block.timestamp),
            isActive: uint256(1),
            propertyDescription: _propertyDescription,
            certificateNumber: _certificateNumber,
            floors: uint256(_floors),
            rooms: uint256(_rooms),
            bathrooms: uint256(_bathrooms)
        });

        certificateToPropertyId[_certificateNumber] = newPropertyId;

        emit PropertyRegistered(newPropertyId, msg.sender, _certificateNumber);

        return newPropertyId;
    }

    function transferProperty(
        uint256 _propertyId,
        string memory _newOwnerName,
        address _newOwnerAddress
    ) public onlyRegistrar contractIsActive {
        require(_propertyId > 0 && _propertyId <= totalProperties, "Invalid property ID");
        require(uint256(properties[_propertyId].isActive) == uint256(1), "Property is not active");
        require(bytes(_newOwnerName).length > 0, "New owner name cannot be empty");

        address oldOwner = msg.sender;
        properties[_propertyId].ownerName = _newOwnerName;

        emit PropertyTransferred(_propertyId, oldOwner, _newOwnerAddress);
    }

    function updatePropertyDescription(
        uint256 _propertyId,
        bytes memory _newDescription
    ) public onlyRegistrar contractIsActive {
        require(_propertyId > 0 && _propertyId <= totalProperties, "Invalid property ID");
        require(uint256(properties[_propertyId].isActive) == uint256(1), "Property is not active");

        properties[_propertyId].propertyDescription = _newDescription;

        emit PropertyUpdated(_propertyId);
    }

    function deactivateProperty(uint256 _propertyId) public onlyRegistrar contractIsActive {
        require(_propertyId > 0 && _propertyId <= totalProperties, "Invalid property ID");
        require(uint256(properties[_propertyId].isActive) == uint256(1), "Property already inactive");

        properties[_propertyId].isActive = uint256(0);

        emit PropertyUpdated(_propertyId);
    }

    function activateProperty(uint256 _propertyId) public onlyRegistrar contractIsActive {
        require(_propertyId > 0 && _propertyId <= totalProperties, "Invalid property ID");
        require(uint256(properties[_propertyId].isActive) == uint256(0), "Property already active");

        properties[_propertyId].isActive = uint256(1);

        emit PropertyUpdated(_propertyId);
    }

    function getPropertyByCertificate(string memory _certificateNumber)
        public
        view
        returns (Property memory)
    {
        uint256 propertyId = certificateToPropertyId[_certificateNumber];
        require(propertyId > 0, "Property not found");
        return properties[propertyId];
    }

    function getProperty(uint256 _propertyId) public view returns (Property memory) {
        require(_propertyId > 0 && _propertyId <= totalProperties, "Invalid property ID");
        return properties[_propertyId];
    }

    function isPropertyActive(uint256 _propertyId) public view returns (bool) {
        require(_propertyId > 0 && _propertyId <= totalProperties, "Invalid property ID");
        return uint256(properties[_propertyId].isActive) == uint256(1);
    }

    function getTotalActiveProperties() public view returns (uint256) {
        uint256 activeCount = uint256(0);
        for (uint256 i = uint256(1); i <= totalProperties; i = uint256(i + uint256(1))) {
            if (uint256(properties[i].isActive) == uint256(1)) {
                activeCount = uint256(activeCount + uint256(1));
            }
        }
        return activeCount;
    }

    function setContractStatus(uint256 _status) public onlyRegistrar {
        require(_status == uint256(0) || _status == uint256(1), "Invalid status");
        contractActive = uint256(_status);
    }

    function changeRegistrar(address _newRegistrar) public onlyRegistrar {
        require(_newRegistrar != address(0), "Invalid registrar address");
        registrar = _newRegistrar;
    }
}
