
pragma solidity ^0.8.0;

contract RealEstateRegistry {
    address public owner;
    uint256 public totalProperties;

    struct Property {
        string propertyId;
        address propertyOwner;
        bytes location;
        uint256 area;
        uint256 rooms;
        uint256 isActive;
        uint256 propertyType;
        uint256 registrationDate;
        uint256 lastTransferDate;
    }

    mapping(string => Property) public properties;
    mapping(address => string[]) public ownerProperties;

    event PropertyRegistered(string propertyId, address owner);
    event PropertyTransferred(string propertyId, address from, address to);
    event PropertyUpdated(string propertyId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only contract owner can perform this action");
        _;
    }

    modifier onlyPropertyOwner(string memory _propertyId) {
        require(properties[_propertyId].propertyOwner == msg.sender, "Only property owner can perform this action");
        _;
    }

    modifier propertyExists(string memory _propertyId) {
        require(properties[_propertyId].propertyOwner != address(0), "Property does not exist");
        _;
    }

    constructor() {
        owner = msg.sender;
        totalProperties = uint256(0);
    }

    function registerProperty(
        string memory _propertyId,
        bytes memory _location,
        uint256 _area,
        uint256 _rooms,
        uint256 _propertyType
    ) public {
        require(properties[_propertyId].propertyOwner == address(0), "Property already exists");
        require(_area > uint256(0), "Area must be greater than 0");
        require(_rooms > uint256(0), "Rooms must be greater than 0");

        Property memory newProperty = Property({
            propertyId: _propertyId,
            propertyOwner: msg.sender,
            location: _location,
            area: _area,
            rooms: _rooms,
            isActive: uint256(1),
            propertyType: _propertyType,
            registrationDate: block.timestamp,
            lastTransferDate: block.timestamp
        });

        properties[_propertyId] = newProperty;
        ownerProperties[msg.sender].push(_propertyId);
        totalProperties = totalProperties + uint256(1);

        emit PropertyRegistered(_propertyId, msg.sender);
    }

    function transferProperty(string memory _propertyId, address _newOwner)
        public
        propertyExists(_propertyId)
        onlyPropertyOwner(_propertyId)
    {
        require(_newOwner != address(0), "Invalid new owner address");
        require(_newOwner != properties[_propertyId].propertyOwner, "Cannot transfer to current owner");
        require(properties[_propertyId].isActive == uint256(1), "Property is not active");

        address previousOwner = properties[_propertyId].propertyOwner;


        string[] storage ownerProps = ownerProperties[previousOwner];
        for (uint256 i = uint256(0); i < ownerProps.length; i++) {
            if (keccak256(bytes(ownerProps[i])) == keccak256(bytes(_propertyId))) {
                ownerProps[i] = ownerProps[ownerProps.length - uint256(1)];
                ownerProps.pop();
                break;
            }
        }


        properties[_propertyId].propertyOwner = _newOwner;
        properties[_propertyId].lastTransferDate = block.timestamp;


        ownerProperties[_newOwner].push(_propertyId);

        emit PropertyTransferred(_propertyId, previousOwner, _newOwner);
    }

    function updatePropertyDetails(
        string memory _propertyId,
        bytes memory _location,
        uint256 _area,
        uint256 _rooms
    ) public propertyExists(_propertyId) onlyPropertyOwner(_propertyId) {
        require(_area > uint256(0), "Area must be greater than 0");
        require(_rooms > uint256(0), "Rooms must be greater than 0");

        properties[_propertyId].location = _location;
        properties[_propertyId].area = _area;
        properties[_propertyId].rooms = _rooms;

        emit PropertyUpdated(_propertyId);
    }

    function deactivateProperty(string memory _propertyId)
        public
        propertyExists(_propertyId)
        onlyPropertyOwner(_propertyId)
    {
        properties[_propertyId].isActive = uint256(0);
    }

    function activateProperty(string memory _propertyId)
        public
        propertyExists(_propertyId)
        onlyPropertyOwner(_propertyId)
    {
        properties[_propertyId].isActive = uint256(1);
    }

    function getProperty(string memory _propertyId)
        public
        view
        propertyExists(_propertyId)
        returns (
            string memory propertyId,
            address propertyOwner,
            bytes memory location,
            uint256 area,
            uint256 rooms,
            uint256 isActive,
            uint256 propertyType,
            uint256 registrationDate,
            uint256 lastTransferDate
        )
    {
        Property memory prop = properties[_propertyId];
        return (
            prop.propertyId,
            prop.propertyOwner,
            prop.location,
            prop.area,
            prop.rooms,
            prop.isActive,
            prop.propertyType,
            prop.registrationDate,
            prop.lastTransferDate
        );
    }

    function getOwnerProperties(address _owner) public view returns (string[] memory) {
        return ownerProperties[_owner];
    }

    function isPropertyActive(string memory _propertyId)
        public
        view
        propertyExists(_propertyId)
        returns (bool)
    {
        return properties[_propertyId].isActive == uint256(1);
    }

    function getPropertyCount() public view returns (uint256) {
        return totalProperties;
    }
}
