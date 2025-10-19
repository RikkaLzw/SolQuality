
pragma solidity ^0.8.0;

contract RealEstateRegistry {
    struct Property {
        uint256 id;
        string location;
        uint256 area;
        address owner;
        bool isRegistered;
        uint256 registrationDate;
        string propertyType;
        uint256 value;
    }

    struct Transfer {
        uint256 propertyId;
        address from;
        address to;
        uint256 transferDate;
        uint256 transferPrice;
    }

    mapping(uint256 => Property) public properties;
    mapping(address => uint256[]) public ownerProperties;
    mapping(uint256 => Transfer[]) public propertyTransferHistory;

    uint256 public nextPropertyId;
    address public registrar;


    event PropertyRegistered(
        uint256 indexed propertyId,
        address indexed owner,
        string location,
        uint256 area,
        string propertyType,
        uint256 value
    );

    event PropertyTransferred(
        uint256 indexed propertyId,
        address indexed from,
        address indexed to,
        uint256 transferPrice,
        uint256 transferDate
    );

    event PropertyValueUpdated(
        uint256 indexed propertyId,
        uint256 oldValue,
        uint256 newValue,
        address indexed updatedBy
    );

    event RegistrarChanged(
        address indexed oldRegistrar,
        address indexed newRegistrar
    );

    modifier onlyRegistrar() {
        require(msg.sender == registrar, "Only registrar can perform this action");
        _;
    }

    modifier onlyPropertyOwner(uint256 _propertyId) {
        require(properties[_propertyId].isRegistered, "Property does not exist");
        require(properties[_propertyId].owner == msg.sender, "Only property owner can perform this action");
        _;
    }

    modifier propertyExists(uint256 _propertyId) {
        require(properties[_propertyId].isRegistered, "Property does not exist");
        _;
    }

    constructor() {
        registrar = msg.sender;
        nextPropertyId = 1;
    }

    function registerProperty(
        string memory _location,
        uint256 _area,
        address _owner,
        string memory _propertyType,
        uint256 _value
    ) external onlyRegistrar returns (uint256) {
        require(bytes(_location).length > 0, "Location cannot be empty");
        require(_area > 0, "Area must be greater than zero");
        require(_owner != address(0), "Owner address cannot be zero");
        require(bytes(_propertyType).length > 0, "Property type cannot be empty");
        require(_value > 0, "Property value must be greater than zero");

        uint256 propertyId = nextPropertyId;
        nextPropertyId++;

        properties[propertyId] = Property({
            id: propertyId,
            location: _location,
            area: _area,
            owner: _owner,
            isRegistered: true,
            registrationDate: block.timestamp,
            propertyType: _propertyType,
            value: _value
        });

        ownerProperties[_owner].push(propertyId);

        emit PropertyRegistered(
            propertyId,
            _owner,
            _location,
            _area,
            _propertyType,
            _value
        );

        return propertyId;
    }

    function transferProperty(
        uint256 _propertyId,
        address _newOwner,
        uint256 _transferPrice
    ) external onlyPropertyOwner(_propertyId) {
        require(_newOwner != address(0), "New owner address cannot be zero");
        require(_newOwner != msg.sender, "Cannot transfer property to yourself");
        require(_transferPrice > 0, "Transfer price must be greater than zero");

        Property storage property = properties[_propertyId];
        address oldOwner = property.owner;


        _removePropertyFromOwner(oldOwner, _propertyId);


        ownerProperties[_newOwner].push(_propertyId);


        property.owner = _newOwner;


        propertyTransferHistory[_propertyId].push(Transfer({
            propertyId: _propertyId,
            from: oldOwner,
            to: _newOwner,
            transferDate: block.timestamp,
            transferPrice: _transferPrice
        }));

        emit PropertyTransferred(
            _propertyId,
            oldOwner,
            _newOwner,
            _transferPrice,
            block.timestamp
        );
    }

    function updatePropertyValue(
        uint256 _propertyId,
        uint256 _newValue
    ) external onlyRegistrar propertyExists(_propertyId) {
        require(_newValue > 0, "Property value must be greater than zero");

        Property storage property = properties[_propertyId];
        uint256 oldValue = property.value;

        if (oldValue == _newValue) {
            revert("New value must be different from current value");
        }

        property.value = _newValue;

        emit PropertyValueUpdated(_propertyId, oldValue, _newValue, msg.sender);
    }

    function changeRegistrar(address _newRegistrar) external onlyRegistrar {
        require(_newRegistrar != address(0), "New registrar address cannot be zero");
        require(_newRegistrar != registrar, "New registrar must be different from current registrar");

        address oldRegistrar = registrar;
        registrar = _newRegistrar;

        emit RegistrarChanged(oldRegistrar, _newRegistrar);
    }

    function getProperty(uint256 _propertyId) external view propertyExists(_propertyId) returns (
        uint256 id,
        string memory location,
        uint256 area,
        address owner,
        uint256 registrationDate,
        string memory propertyType,
        uint256 value
    ) {
        Property memory property = properties[_propertyId];
        return (
            property.id,
            property.location,
            property.area,
            property.owner,
            property.registrationDate,
            property.propertyType,
            property.value
        );
    }

    function getOwnerProperties(address _owner) external view returns (uint256[] memory) {
        return ownerProperties[_owner];
    }

    function getPropertyTransferHistory(uint256 _propertyId) external view propertyExists(_propertyId) returns (Transfer[] memory) {
        return propertyTransferHistory[_propertyId];
    }

    function getPropertyCount() external view returns (uint256) {
        return nextPropertyId - 1;
    }

    function _removePropertyFromOwner(address _owner, uint256 _propertyId) internal {
        uint256[] storage properties = ownerProperties[_owner];
        for (uint256 i = 0; i < properties.length; i++) {
            if (properties[i] == _propertyId) {
                properties[i] = properties[properties.length - 1];
                properties.pop();
                break;
            }
        }
    }
}
