
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
        bytes propertyHash;
        uint256 floors;
        uint256 rooms;
        string certificateId;
    }

    mapping(uint256 => Property) public properties;
    mapping(address => uint256[]) public ownerProperties;
    mapping(string => uint256) public addressToPropertyId;

    address public registrar;
    uint256 public totalProperties;
    uint256 public contractStatus;

    event PropertyRegistered(uint256 indexed propertyId, string ownerName, string propertyAddress);
    event PropertyTransferred(uint256 indexed propertyId, address indexed from, address indexed to);
    event PropertyStatusChanged(uint256 indexed propertyId, uint256 newStatus);

    modifier onlyRegistrar() {
        require(msg.sender == registrar, "Only registrar can perform this action");
        _;
    }

    modifier contractActive() {
        require(uint256(contractStatus) == uint256(1), "Contract is paused");
        _;
    }

    constructor() {
        registrar = msg.sender;
        totalProperties = uint256(0);
        contractStatus = uint256(1);
    }

    function registerProperty(
        string memory _ownerName,
        string memory _propertyAddress,
        uint256 _propertyType,
        uint256 _area,
        bytes memory _propertyHash,
        uint256 _floors,
        uint256 _rooms,
        string memory _certificateId
    ) public onlyRegistrar contractActive {
        require(bytes(_ownerName).length > 0, "Owner name cannot be empty");
        require(bytes(_propertyAddress).length > 0, "Property address cannot be empty");
        require(_area > uint256(0), "Area must be greater than 0");
        require(_propertyType <= uint256(2), "Invalid property type");
        require(addressToPropertyId[_propertyAddress] == uint256(0), "Property already registered");

        totalProperties = uint256(totalProperties + 1);
        uint256 newPropertyId = totalProperties;

        properties[newPropertyId] = Property({
            propertyId: newPropertyId,
            ownerName: _ownerName,
            propertyAddress: _propertyAddress,
            propertyType: _propertyType,
            area: _area,
            registrationDate: block.timestamp,
            isActive: uint256(1),
            propertyHash: _propertyHash,
            floors: _floors,
            rooms: _rooms,
            certificateId: _certificateId
        });

        ownerProperties[msg.sender].push(newPropertyId);
        addressToPropertyId[_propertyAddress] = newPropertyId;

        emit PropertyRegistered(newPropertyId, _ownerName, _propertyAddress);
    }

    function transferProperty(
        uint256 _propertyId,
        address _newOwner,
        string memory _newOwnerName
    ) public onlyRegistrar contractActive {
        require(_propertyId > uint256(0) && _propertyId <= totalProperties, "Invalid property ID");
        require(_newOwner != address(0), "Invalid new owner address");
        require(properties[_propertyId].isActive == uint256(1), "Property is not active");

        Property storage property = properties[_propertyId];
        address currentOwner = msg.sender;


        uint256[] storage currentOwnerProps = ownerProperties[currentOwner];
        for (uint256 i = uint256(0); i < currentOwnerProps.length; i++) {
            if (currentOwnerProps[i] == _propertyId) {
                currentOwnerProps[i] = currentOwnerProps[currentOwnerProps.length - uint256(1)];
                currentOwnerProps.pop();
                break;
            }
        }


        ownerProperties[_newOwner].push(_propertyId);


        property.ownerName = _newOwnerName;

        emit PropertyTransferred(_propertyId, currentOwner, _newOwner);
    }

    function updatePropertyStatus(uint256 _propertyId, uint256 _newStatus) public onlyRegistrar {
        require(_propertyId > uint256(0) && _propertyId <= totalProperties, "Invalid property ID");
        require(_newStatus == uint256(0) || _newStatus == uint256(1), "Status must be 0 or 1");

        properties[_propertyId].isActive = _newStatus;

        emit PropertyStatusChanged(_propertyId, _newStatus);
    }

    function updatePropertyHash(uint256 _propertyId, bytes memory _newHash) public onlyRegistrar contractActive {
        require(_propertyId > uint256(0) && _propertyId <= totalProperties, "Invalid property ID");
        require(properties[_propertyId].isActive == uint256(1), "Property is not active");

        properties[_propertyId].propertyHash = _newHash;
    }

    function getProperty(uint256 _propertyId) public view returns (
        uint256 propertyId,
        string memory ownerName,
        string memory propertyAddress,
        uint256 propertyType,
        uint256 area,
        uint256 registrationDate,
        uint256 isActive,
        bytes memory propertyHash,
        uint256 floors,
        uint256 rooms,
        string memory certificateId
    ) {
        require(_propertyId > uint256(0) && _propertyId <= totalProperties, "Invalid property ID");

        Property memory property = properties[_propertyId];
        return (
            property.propertyId,
            property.ownerName,
            property.propertyAddress,
            property.propertyType,
            property.area,
            property.registrationDate,
            property.isActive,
            property.propertyHash,
            property.floors,
            property.rooms,
            property.certificateId
        );
    }

    function getOwnerProperties(address _owner) public view returns (uint256[] memory) {
        return ownerProperties[_owner];
    }

    function getPropertyByAddress(string memory _address) public view returns (uint256) {
        return addressToPropertyId[_address];
    }

    function pauseContract() public onlyRegistrar {
        contractStatus = uint256(0);
    }

    function resumeContract() public onlyRegistrar {
        contractStatus = uint256(1);
    }

    function getTotalProperties() public view returns (uint256) {
        return uint256(totalProperties);
    }

    function isPropertyActive(uint256 _propertyId) public view returns (uint256) {
        require(_propertyId > uint256(0) && _propertyId <= totalProperties, "Invalid property ID");
        return properties[_propertyId].isActive;
    }
}
