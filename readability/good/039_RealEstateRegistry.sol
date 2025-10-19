
pragma solidity ^0.8.0;


contract RealEstateRegistry {


    struct RealEstateProperty {
        uint256 propertyId;
        string propertyAddress;
        string propertyType;
        uint256 propertyArea;
        uint256 registrationDate;
        address currentOwner;
        bool isActive;
        string additionalInfo;
    }


    struct OwnershipTransfer {
        uint256 transferId;
        uint256 propertyId;
        address previousOwner;
        address newOwner;
        uint256 transferDate;
        uint256 transferPrice;
        string transferReason;
    }


    address public contractAdmin;


    mapping(address => bool) public authorizedRegistrars;


    mapping(uint256 => RealEstateProperty) public properties;


    mapping(address => uint256[]) public ownerToProperties;


    mapping(uint256 => OwnershipTransfer[]) public propertyTransferHistory;


    uint256 public nextPropertyId;


    uint256 public nextTransferId;


    event PropertyRegistered(
        uint256 indexed propertyId,
        address indexed owner,
        string propertyAddress,
        uint256 registrationDate
    );

    event OwnershipTransferred(
        uint256 indexed propertyId,
        address indexed previousOwner,
        address indexed newOwner,
        uint256 transferDate,
        uint256 transferPrice
    );

    event RegistrarAuthorized(address indexed registrar, bool authorized);

    event PropertyDeactivated(uint256 indexed propertyId, address indexed admin);


    modifier onlyAdmin() {
        require(msg.sender == contractAdmin, "Only admin can perform this action");
        _;
    }


    modifier onlyAuthorizedRegistrar() {
        require(
            authorizedRegistrars[msg.sender] || msg.sender == contractAdmin,
            "Only authorized registrar can perform this action"
        );
        _;
    }


    modifier propertyExists(uint256 _propertyId) {
        require(
            _propertyId < nextPropertyId && properties[_propertyId].isActive,
            "Property does not exist or is inactive"
        );
        _;
    }


    modifier onlyPropertyOwner(uint256 _propertyId) {
        require(
            properties[_propertyId].currentOwner == msg.sender,
            "Only property owner can perform this action"
        );
        _;
    }


    constructor() {
        contractAdmin = msg.sender;
        nextPropertyId = 1;
        nextTransferId = 1;
        authorizedRegistrars[msg.sender] = true;
    }


    function setRegistrarAuthorization(address _registrar, bool _authorized)
        external
        onlyAdmin
    {
        require(_registrar != address(0), "Invalid registrar address");
        authorizedRegistrars[_registrar] = _authorized;
        emit RegistrarAuthorized(_registrar, _authorized);
    }


    function registerProperty(
        address _owner,
        string memory _propertyAddress,
        string memory _propertyType,
        uint256 _propertyArea,
        string memory _additionalInfo
    )
        external
        onlyAuthorizedRegistrar
        returns (uint256)
    {
        require(_owner != address(0), "Invalid owner address");
        require(bytes(_propertyAddress).length > 0, "Property address cannot be empty");
        require(_propertyArea > 0, "Property area must be greater than 0");

        uint256 propertyId = nextPropertyId;

        properties[propertyId] = RealEstateProperty({
            propertyId: propertyId,
            propertyAddress: _propertyAddress,
            propertyType: _propertyType,
            propertyArea: _propertyArea,
            registrationDate: block.timestamp,
            currentOwner: _owner,
            isActive: true,
            additionalInfo: _additionalInfo
        });

        ownerToProperties[_owner].push(propertyId);
        nextPropertyId++;

        emit PropertyRegistered(propertyId, _owner, _propertyAddress, block.timestamp);

        return propertyId;
    }


    function transferOwnership(
        uint256 _propertyId,
        address _newOwner,
        uint256 _transferPrice,
        string memory _transferReason
    )
        external
        propertyExists(_propertyId)
        onlyPropertyOwner(_propertyId)
    {
        require(_newOwner != address(0), "Invalid new owner address");
        require(_newOwner != msg.sender, "Cannot transfer to yourself");

        address previousOwner = properties[_propertyId].currentOwner;


        properties[_propertyId].currentOwner = _newOwner;


        _removePropertyFromOwner(previousOwner, _propertyId);


        ownerToProperties[_newOwner].push(_propertyId);


        uint256 transferId = nextTransferId;
        propertyTransferHistory[_propertyId].push(OwnershipTransfer({
            transferId: transferId,
            propertyId: _propertyId,
            previousOwner: previousOwner,
            newOwner: _newOwner,
            transferDate: block.timestamp,
            transferPrice: _transferPrice,
            transferReason: _transferReason
        }));

        nextTransferId++;

        emit OwnershipTransferred(
            _propertyId,
            previousOwner,
            _newOwner,
            block.timestamp,
            _transferPrice
        );
    }


    function deactivateProperty(uint256 _propertyId)
        external
        onlyAdmin
        propertyExists(_propertyId)
    {
        properties[_propertyId].isActive = false;
        emit PropertyDeactivated(_propertyId, msg.sender);
    }


    function getPropertyDetails(uint256 _propertyId)
        external
        view
        propertyExists(_propertyId)
        returns (RealEstateProperty memory)
    {
        return properties[_propertyId];
    }


    function getPropertiesByOwner(address _owner)
        external
        view
        returns (uint256[] memory)
    {
        return ownerToProperties[_owner];
    }


    function getPropertyTransferHistory(uint256 _propertyId)
        external
        view
        propertyExists(_propertyId)
        returns (OwnershipTransfer[] memory)
    {
        return propertyTransferHistory[_propertyId];
    }


    function isAuthorizedRegistrar(address _address)
        external
        view
        returns (bool)
    {
        return authorizedRegistrars[_address];
    }


    function getTotalProperties()
        external
        view
        returns (uint256)
    {
        return nextPropertyId - 1;
    }


    function _removePropertyFromOwner(address _owner, uint256 _propertyId)
        internal
    {
        uint256[] storage ownerProperties = ownerToProperties[_owner];

        for (uint256 i = 0; i < ownerProperties.length; i++) {
            if (ownerProperties[i] == _propertyId) {

                ownerProperties[i] = ownerProperties[ownerProperties.length - 1];
                ownerProperties.pop();
                break;
            }
        }
    }


    function changeAdmin(address _newAdmin)
        external
        onlyAdmin
    {
        require(_newAdmin != address(0), "Invalid admin address");
        require(_newAdmin != contractAdmin, "New admin cannot be the same as current admin");

        contractAdmin = _newAdmin;
        authorizedRegistrars[_newAdmin] = true;
    }
}
