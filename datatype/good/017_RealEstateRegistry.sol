
pragma solidity ^0.8.0;

contract RealEstateRegistry {
    struct Property {
        bytes32 propertyId;
        address owner;
        bytes32 location;
        uint256 area;
        uint256 price;
        bytes32 propertyType;
        bool isRegistered;
        uint64 registrationDate;
        bytes32 documentHash;
    }

    struct Transfer {
        bytes32 propertyId;
        address from;
        address to;
        uint256 price;
        uint64 transferDate;
        bytes32 documentHash;
    }

    mapping(bytes32 => Property) public properties;
    mapping(bytes32 => Transfer[]) public propertyTransfers;
    mapping(address => bytes32[]) public ownerProperties;

    address public registrar;
    uint256 public registrationFee;
    uint256 public transferFee;

    event PropertyRegistered(bytes32 indexed propertyId, address indexed owner, uint256 area, uint256 price);
    event PropertyTransferred(bytes32 indexed propertyId, address indexed from, address indexed to, uint256 price);
    event RegistrarChanged(address indexed oldRegistrar, address indexed newRegistrar);
    event FeesUpdated(uint256 registrationFee, uint256 transferFee);

    modifier onlyRegistrar() {
        require(msg.sender == registrar, "Only registrar can perform this action");
        _;
    }

    modifier propertyExists(bytes32 _propertyId) {
        require(properties[_propertyId].isRegistered, "Property does not exist");
        _;
    }

    modifier onlyOwner(bytes32 _propertyId) {
        require(properties[_propertyId].owner == msg.sender, "Only property owner can perform this action");
        _;
    }

    constructor(uint256 _registrationFee, uint256 _transferFee) {
        registrar = msg.sender;
        registrationFee = _registrationFee;
        transferFee = _transferFee;
    }

    function registerProperty(
        bytes32 _propertyId,
        address _owner,
        bytes32 _location,
        uint256 _area,
        uint256 _price,
        bytes32 _propertyType,
        bytes32 _documentHash
    ) external payable onlyRegistrar {
        require(!properties[_propertyId].isRegistered, "Property already registered");
        require(msg.value >= registrationFee, "Insufficient registration fee");
        require(_owner != address(0), "Invalid owner address");
        require(_area > 0, "Area must be greater than zero");

        properties[_propertyId] = Property({
            propertyId: _propertyId,
            owner: _owner,
            location: _location,
            area: _area,
            price: _price,
            propertyType: _propertyType,
            isRegistered: true,
            registrationDate: uint64(block.timestamp),
            documentHash: _documentHash
        });

        ownerProperties[_owner].push(_propertyId);

        emit PropertyRegistered(_propertyId, _owner, _area, _price);
    }

    function transferProperty(
        bytes32 _propertyId,
        address _newOwner,
        uint256 _price,
        bytes32 _documentHash
    ) external payable propertyExists(_propertyId) onlyOwner(_propertyId) {
        require(msg.value >= transferFee, "Insufficient transfer fee");
        require(_newOwner != address(0), "Invalid new owner address");
        require(_newOwner != properties[_propertyId].owner, "Cannot transfer to current owner");

        address oldOwner = properties[_propertyId].owner;


        properties[_propertyId].owner = _newOwner;
        properties[_propertyId].price = _price;


        propertyTransfers[_propertyId].push(Transfer({
            propertyId: _propertyId,
            from: oldOwner,
            to: _newOwner,
            price: _price,
            transferDate: uint64(block.timestamp),
            documentHash: _documentHash
        }));


        _removePropertyFromOwner(oldOwner, _propertyId);
        ownerProperties[_newOwner].push(_propertyId);

        emit PropertyTransferred(_propertyId, oldOwner, _newOwner, _price);
    }

    function updatePropertyPrice(
        bytes32 _propertyId,
        uint256 _newPrice
    ) external propertyExists(_propertyId) onlyOwner(_propertyId) {
        properties[_propertyId].price = _newPrice;
    }

    function getProperty(bytes32 _propertyId) external view returns (
        bytes32 propertyId,
        address owner,
        bytes32 location,
        uint256 area,
        uint256 price,
        bytes32 propertyType,
        bool isRegistered,
        uint64 registrationDate,
        bytes32 documentHash
    ) {
        Property memory prop = properties[_propertyId];
        return (
            prop.propertyId,
            prop.owner,
            prop.location,
            prop.area,
            prop.price,
            prop.propertyType,
            prop.isRegistered,
            prop.registrationDate,
            prop.documentHash
        );
    }

    function getOwnerProperties(address _owner) external view returns (bytes32[] memory) {
        return ownerProperties[_owner];
    }

    function getPropertyTransferHistory(bytes32 _propertyId) external view returns (Transfer[] memory) {
        return propertyTransfers[_propertyId];
    }

    function verifyOwnership(bytes32 _propertyId, address _owner) external view returns (bool) {
        return properties[_propertyId].isRegistered && properties[_propertyId].owner == _owner;
    }

    function changeRegistrar(address _newRegistrar) external onlyRegistrar {
        require(_newRegistrar != address(0), "Invalid registrar address");
        address oldRegistrar = registrar;
        registrar = _newRegistrar;
        emit RegistrarChanged(oldRegistrar, _newRegistrar);
    }

    function updateFees(uint256 _registrationFee, uint256 _transferFee) external onlyRegistrar {
        registrationFee = _registrationFee;
        transferFee = _transferFee;
        emit FeesUpdated(_registrationFee, _transferFee);
    }

    function withdrawFees() external onlyRegistrar {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        payable(registrar).transfer(balance);
    }

    function _removePropertyFromOwner(address _owner, bytes32 _propertyId) private {
        bytes32[] storage properties_owned = ownerProperties[_owner];
        uint256 length = properties_owned.length;

        for (uint256 i = 0; i < length; i++) {
            if (properties_owned[i] == _propertyId) {
                properties_owned[i] = properties_owned[length - 1];
                properties_owned.pop();
                break;
            }
        }
    }
}
