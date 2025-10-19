
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
        uint256 transferCount;
    }

    mapping(uint256 => Property) public properties;
    mapping(address => uint256[]) public ownerProperties;
    mapping(string => uint256) public certificateToPropertyId;

    address public registrar;
    uint256 public totalProperties;
    uint256 public registrationFee;

    event PropertyRegistered(uint256 indexed propertyId, string ownerName, string propertyAddress);
    event PropertyTransferred(uint256 indexed propertyId, string previousOwner, string newOwner);
    event PropertyStatusChanged(uint256 indexed propertyId, uint256 newStatus);

    modifier onlyRegistrar() {
        require(msg.sender == registrar, "Only registrar can perform this action");
        _;
    }

    modifier validPropertyId(uint256 _propertyId) {
        require(_propertyId > 0 && _propertyId <= totalProperties, "Invalid property ID");
        _;
    }

    constructor() {
        registrar = msg.sender;
        totalProperties = uint256(0);
        registrationFee = uint256(1000000000000000000);
    }

    function registerProperty(
        string memory _ownerName,
        string memory _propertyAddress,
        uint256 _propertyType,
        uint256 _area,
        bytes memory _propertyDescription,
        string memory _certificateNumber
    ) public payable {
        require(msg.value >= registrationFee, "Insufficient registration fee");
        require(bytes(_ownerName).length > 0, "Owner name cannot be empty");
        require(bytes(_propertyAddress).length > 0, "Property address cannot be empty");
        require(_area > uint256(0), "Area must be greater than zero");
        require(_propertyType <= uint256(2), "Invalid property type");

        totalProperties = totalProperties + uint256(1);
        uint256 newPropertyId = totalProperties;

        properties[newPropertyId] = Property({
            propertyId: newPropertyId,
            ownerName: _ownerName,
            propertyAddress: _propertyAddress,
            propertyType: _propertyType,
            area: _area,
            registrationDate: uint256(block.timestamp),
            isActive: uint256(1),
            propertyDescription: _propertyDescription,
            certificateNumber: _certificateNumber,
            transferCount: uint256(0)
        });

        ownerProperties[msg.sender].push(newPropertyId);
        certificateToPropertyId[_certificateNumber] = newPropertyId;

        emit PropertyRegistered(newPropertyId, _ownerName, _propertyAddress);
    }

    function transferProperty(
        uint256 _propertyId,
        string memory _newOwnerName,
        address _newOwnerAddress
    ) public validPropertyId(_propertyId) {
        Property storage property = properties[_propertyId];
        require(property.isActive == uint256(1), "Property is not active");

        string memory previousOwner = property.ownerName;
        property.ownerName = _newOwnerName;
        property.transferCount = property.transferCount + uint256(1);


        uint256[] storage currentOwnerProperties = ownerProperties[msg.sender];
        for (uint256 i = uint256(0); i < currentOwnerProperties.length; i = i + uint256(1)) {
            if (currentOwnerProperties[i] == _propertyId) {
                currentOwnerProperties[i] = currentOwnerProperties[currentOwnerProperties.length - uint256(1)];
                currentOwnerProperties.pop();
                break;
            }
        }


        ownerProperties[_newOwnerAddress].push(_propertyId);

        emit PropertyTransferred(_propertyId, previousOwner, _newOwnerName);
    }

    function updatePropertyStatus(uint256 _propertyId, uint256 _newStatus)
        public
        onlyRegistrar
        validPropertyId(_propertyId)
    {
        require(_newStatus <= uint256(1), "Invalid status value");
        properties[_propertyId].isActive = _newStatus;
        emit PropertyStatusChanged(_propertyId, _newStatus);
    }

    function updatePropertyDescription(uint256 _propertyId, bytes memory _newDescription)
        public
        validPropertyId(_propertyId)
    {
        Property storage property = properties[_propertyId];
        require(property.isActive == uint256(1), "Property is not active");
        property.propertyDescription = _newDescription;
    }

    function getPropertyDetails(uint256 _propertyId)
        public
        view
        validPropertyId(_propertyId)
        returns (
            uint256 propertyId,
            string memory ownerName,
            string memory propertyAddress,
            uint256 propertyType,
            uint256 area,
            uint256 registrationDate,
            uint256 isActive,
            bytes memory propertyDescription,
            string memory certificateNumber,
            uint256 transferCount
        )
    {
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
            property.certificateNumber,
            property.transferCount
        );
    }

    function getPropertiesByOwner(address _owner) public view returns (uint256[] memory) {
        return ownerProperties[_owner];
    }

    function getPropertyByCertificate(string memory _certificateNumber) public view returns (uint256) {
        return certificateToPropertyId[_certificateNumber];
    }

    function isPropertyActive(uint256 _propertyId) public view validPropertyId(_propertyId) returns (bool) {
        return properties[_propertyId].isActive == uint256(1);
    }

    function setRegistrationFee(uint256 _newFee) public onlyRegistrar {
        registrationFee = _newFee;
    }

    function withdrawFees() public onlyRegistrar {
        payable(registrar).transfer(address(this).balance);
    }

    function changeRegistrar(address _newRegistrar) public onlyRegistrar {
        require(_newRegistrar != address(0), "Invalid registrar address");
        registrar = _newRegistrar;
    }
}
