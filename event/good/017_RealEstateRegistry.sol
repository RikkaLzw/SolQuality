
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

    struct PropertyTransfer {
        uint256 propertyId;
        address from;
        address to;
        uint256 transferDate;
        uint256 price;
        string transferReason;
    }

    mapping(uint256 => Property) public properties;
    mapping(address => uint256[]) public ownerProperties;
    mapping(uint256 => PropertyTransfer[]) public propertyTransferHistory;
    mapping(string => bool) public addressExists;

    uint256 public nextPropertyId = 1;
    address public registrar;
    bool public contractActive = true;

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
        string transferReason
    );

    event PropertyUpdated(
        uint256 indexed propertyId,
        string newDescription,
        uint256 newArea
    );

    event RegistrarChanged(
        address indexed oldRegistrar,
        address indexed newRegistrar
    );

    event ContractStatusChanged(bool active);

    modifier onlyRegistrar() {
        require(msg.sender == registrar, "Only registrar can perform this action");
        _;
    }

    modifier onlyPropertyOwner(uint256 _propertyId) {
        require(properties[_propertyId].isRegistered, "Property does not exist");
        require(properties[_propertyId].owner == msg.sender, "Only property owner can perform this action");
        _;
    }

    modifier contractIsActive() {
        require(contractActive, "Contract is currently inactive");
        _;
    }

    modifier validPropertyId(uint256 _propertyId) {
        require(_propertyId > 0 && _propertyId < nextPropertyId, "Invalid property ID");
        require(properties[_propertyId].isRegistered, "Property is not registered");
        _;
    }

    constructor() {
        registrar = msg.sender;
    }

    function registerProperty(
        string memory _propertyAddress,
        string memory _description,
        uint256 _area,
        address _owner
    ) external onlyRegistrar contractIsActive {
        require(bytes(_propertyAddress).length > 0, "Property address cannot be empty");
        require(bytes(_description).length > 0, "Property description cannot be empty");
        require(_area > 0, "Property area must be greater than zero");
        require(_owner != address(0), "Owner address cannot be zero address");
        require(!addressExists[_propertyAddress], "Property address already registered");

        uint256 propertyId = nextPropertyId;
        nextPropertyId++;

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
        addressExists[_propertyAddress] = true;

        emit PropertyRegistered(propertyId, _owner, _propertyAddress, _area);
    }

    function transferProperty(
        uint256 _propertyId,
        address _newOwner,
        uint256 _price,
        string memory _transferReason
    ) external onlyPropertyOwner(_propertyId) contractIsActive {
        require(_newOwner != address(0), "New owner cannot be zero address");
        require(_newOwner != msg.sender, "Cannot transfer property to yourself");
        require(bytes(_transferReason).length > 0, "Transfer reason cannot be empty");

        address previousOwner = properties[_propertyId].owner;
        properties[_propertyId].owner = _newOwner;
        properties[_propertyId].lastTransferDate = block.timestamp;


        _removePropertyFromOwner(previousOwner, _propertyId);


        ownerProperties[_newOwner].push(_propertyId);


        propertyTransferHistory[_propertyId].push(PropertyTransfer({
            propertyId: _propertyId,
            from: previousOwner,
            to: _newOwner,
            transferDate: block.timestamp,
            price: _price,
            transferReason: _transferReason
        }));

        emit PropertyTransferred(_propertyId, previousOwner, _newOwner, _price, _transferReason);
    }

    function updatePropertyDetails(
        uint256 _propertyId,
        string memory _newDescription,
        uint256 _newArea
    ) external onlyPropertyOwner(_propertyId) contractIsActive {
        require(bytes(_newDescription).length > 0, "Property description cannot be empty");
        require(_newArea > 0, "Property area must be greater than zero");

        properties[_propertyId].description = _newDescription;
        properties[_propertyId].area = _newArea;

        emit PropertyUpdated(_propertyId, _newDescription, _newArea);
    }

    function getProperty(uint256 _propertyId) external view validPropertyId(_propertyId) returns (
        uint256 id,
        string memory propertyAddress,
        string memory description,
        uint256 area,
        address owner,
        uint256 registrationDate,
        uint256 lastTransferDate
    ) {
        Property memory prop = properties[_propertyId];
        return (
            prop.id,
            prop.propertyAddress,
            prop.description,
            prop.area,
            prop.owner,
            prop.registrationDate,
            prop.lastTransferDate
        );
    }

    function getOwnerProperties(address _owner) external view returns (uint256[] memory) {
        require(_owner != address(0), "Owner address cannot be zero address");
        return ownerProperties[_owner];
    }

    function getPropertyTransferHistory(uint256 _propertyId) external view validPropertyId(_propertyId) returns (PropertyTransfer[] memory) {
        return propertyTransferHistory[_propertyId];
    }

    function changeRegistrar(address _newRegistrar) external onlyRegistrar {
        require(_newRegistrar != address(0), "New registrar cannot be zero address");
        require(_newRegistrar != registrar, "New registrar must be different from current registrar");

        address oldRegistrar = registrar;
        registrar = _newRegistrar;

        emit RegistrarChanged(oldRegistrar, _newRegistrar);
    }

    function setContractStatus(bool _active) external onlyRegistrar {
        require(contractActive != _active, "Contract status is already set to this value");

        contractActive = _active;
        emit ContractStatusChanged(_active);
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

    function getTotalProperties() external view returns (uint256) {
        return nextPropertyId - 1;
    }

    function isPropertyOwner(uint256 _propertyId, address _address) external view validPropertyId(_propertyId) returns (bool) {
        return properties[_propertyId].owner == _address;
    }
}
