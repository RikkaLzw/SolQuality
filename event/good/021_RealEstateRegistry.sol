
pragma solidity ^0.8.0;

contract RealEstateRegistry {
    struct Property {
        uint256 id;
        string propertyAddress;
        string description;
        uint256 area;
        address owner;
        bool isRegistered;
        uint256 registrationDate;
        uint256 lastTransferDate;
    }

    struct Transfer {
        uint256 propertyId;
        address from;
        address to;
        uint256 transferDate;
        uint256 price;
        string transferType;
    }

    mapping(uint256 => Property) public properties;
    mapping(address => uint256[]) public ownerProperties;
    mapping(uint256 => Transfer[]) public propertyTransferHistory;

    uint256 private nextPropertyId = 1;
    address public registrar;


    event PropertyRegistered(
        uint256 indexed propertyId,
        address indexed owner,
        string propertyAddress,
        uint256 area
    );

    event PropertyTransferred(
        uint256 indexed propertyId,
        address indexed from,
        address indexed to,
        uint256 price,
        string transferType
    );

    event RegistrarChanged(
        address indexed oldRegistrar,
        address indexed newRegistrar
    );

    event PropertyUpdated(
        uint256 indexed propertyId,
        string newDescription,
        uint256 newArea
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
    }

    function registerProperty(
        address _owner,
        string memory _propertyAddress,
        string memory _description,
        uint256 _area
    ) external onlyRegistrar returns (uint256) {
        require(_owner != address(0), "Owner cannot be zero address");
        require(bytes(_propertyAddress).length > 0, "Property address cannot be empty");
        require(_area > 0, "Property area must be greater than zero");

        uint256 propertyId = nextPropertyId++;

        properties[propertyId] = Property({
            id: propertyId,
            propertyAddress: _propertyAddress,
            description: _description,
            area: _area,
            owner: _owner,
            isRegistered: true,
            registrationDate: block.timestamp,
            lastTransferDate: block.timestamp
        });

        ownerProperties[_owner].push(propertyId);

        emit PropertyRegistered(propertyId, _owner, _propertyAddress, _area);

        return propertyId;
    }

    function transferProperty(
        uint256 _propertyId,
        address _newOwner,
        uint256 _price,
        string memory _transferType
    ) external onlyPropertyOwner(_propertyId) {
        require(_newOwner != address(0), "New owner cannot be zero address");
        require(_newOwner != properties[_propertyId].owner, "Cannot transfer to current owner");
        require(bytes(_transferType).length > 0, "Transfer type cannot be empty");

        address currentOwner = properties[_propertyId].owner;


        properties[_propertyId].owner = _newOwner;
        properties[_propertyId].lastTransferDate = block.timestamp;


        _removePropertyFromOwner(currentOwner, _propertyId);
        ownerProperties[_newOwner].push(_propertyId);


        propertyTransferHistory[_propertyId].push(Transfer({
            propertyId: _propertyId,
            from: currentOwner,
            to: _newOwner,
            transferDate: block.timestamp,
            price: _price,
            transferType: _transferType
        }));

        emit PropertyTransferred(_propertyId, currentOwner, _newOwner, _price, _transferType);
    }

    function updatePropertyDetails(
        uint256 _propertyId,
        string memory _newDescription,
        uint256 _newArea
    ) external onlyPropertyOwner(_propertyId) {
        require(bytes(_newDescription).length > 0, "Description cannot be empty");
        require(_newArea > 0, "Area must be greater than zero");

        properties[_propertyId].description = _newDescription;
        properties[_propertyId].area = _newArea;

        emit PropertyUpdated(_propertyId, _newDescription, _newArea);
    }

    function changeRegistrar(address _newRegistrar) external onlyRegistrar {
        require(_newRegistrar != address(0), "New registrar cannot be zero address");
        require(_newRegistrar != registrar, "New registrar must be different from current registrar");

        address oldRegistrar = registrar;
        registrar = _newRegistrar;

        emit RegistrarChanged(oldRegistrar, _newRegistrar);
    }

    function getProperty(uint256 _propertyId) external view propertyExists(_propertyId) returns (Property memory) {
        return properties[_propertyId];
    }

    function getPropertiesByOwner(address _owner) external view returns (uint256[] memory) {
        require(_owner != address(0), "Owner cannot be zero address");
        return ownerProperties[_owner];
    }

    function getPropertyTransferHistory(uint256 _propertyId) external view propertyExists(_propertyId) returns (Transfer[] memory) {
        return propertyTransferHistory[_propertyId];
    }

    function isPropertyOwner(uint256 _propertyId, address _address) external view propertyExists(_propertyId) returns (bool) {
        return properties[_propertyId].owner == _address;
    }

    function getTotalProperties() external view returns (uint256) {
        return nextPropertyId - 1;
    }

    function _removePropertyFromOwner(address _owner, uint256 _propertyId) private {
        uint256[] storage ownerProps = ownerProperties[_owner];
        for (uint256 i = 0; i < ownerProps.length; i++) {
            if (ownerProps[i] == _propertyId) {
                ownerProps[i] = ownerProps[ownerProps.length - 1];
                ownerProps.pop();
                break;
            }
        }
    }
}
