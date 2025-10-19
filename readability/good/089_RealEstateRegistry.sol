
pragma solidity ^0.8.0;


contract RealEstateRegistry {


    struct RealEstate {
        uint256 propertyId;
        string propertyAddress;
        string propertyType;
        uint256 propertyArea;
        uint256 propertyValue;
        address currentOwner;
        address previousOwner;
        uint256 registrationDate;
        uint256 lastTransferDate;
        bool isActive;
    }


    mapping(uint256 => RealEstate) public realEstateRegistry;
    mapping(address => uint256[]) public ownerProperties;
    mapping(uint256 => bool) public propertyExists;

    uint256 public totalProperties;
    uint256 private nextPropertyId;
    address public registryAdmin;


    event PropertyRegistered(
        uint256 indexed propertyId,
        address indexed owner,
        string propertyAddress,
        uint256 registrationDate
    );

    event PropertyTransferred(
        uint256 indexed propertyId,
        address indexed fromOwner,
        address indexed toOwner,
        uint256 transferDate
    );

    event PropertyUpdated(
        uint256 indexed propertyId,
        address indexed owner,
        uint256 newValue
    );

    event PropertyDeactivated(
        uint256 indexed propertyId,
        address indexed owner
    );


    modifier onlyAdmin() {
        require(msg.sender == registryAdmin, "Only admin can perform this action");
        _;
    }

    modifier onlyPropertyOwner(uint256 _propertyId) {
        require(propertyExists[_propertyId], "Property does not exist");
        require(
            realEstateRegistry[_propertyId].currentOwner == msg.sender,
            "Only property owner can perform this action"
        );
        _;
    }

    modifier propertyMustExist(uint256 _propertyId) {
        require(propertyExists[_propertyId], "Property does not exist");
        _;
    }

    modifier propertyMustBeActive(uint256 _propertyId) {
        require(
            realEstateRegistry[_propertyId].isActive,
            "Property is not active"
        );
        _;
    }


    constructor() {
        registryAdmin = msg.sender;
        nextPropertyId = 1;
        totalProperties = 0;
    }


    function registerProperty(
        string memory _propertyAddress,
        string memory _propertyType,
        uint256 _propertyArea,
        uint256 _propertyValue,
        address _owner
    ) public onlyAdmin returns (uint256) {
        require(_owner != address(0), "Invalid owner address");
        require(bytes(_propertyAddress).length > 0, "Property address cannot be empty");
        require(bytes(_propertyType).length > 0, "Property type cannot be empty");
        require(_propertyArea > 0, "Property area must be greater than zero");
        require(_propertyValue > 0, "Property value must be greater than zero");

        uint256 propertyId = nextPropertyId;


        realEstateRegistry[propertyId] = RealEstate({
            propertyId: propertyId,
            propertyAddress: _propertyAddress,
            propertyType: _propertyType,
            propertyArea: _propertyArea,
            propertyValue: _propertyValue,
            currentOwner: _owner,
            previousOwner: address(0),
            registrationDate: block.timestamp,
            lastTransferDate: block.timestamp,
            isActive: true
        });


        propertyExists[propertyId] = true;
        ownerProperties[_owner].push(propertyId);
        totalProperties++;
        nextPropertyId++;


        emit PropertyRegistered(propertyId, _owner, _propertyAddress, block.timestamp);

        return propertyId;
    }


    function transferProperty(
        uint256 _propertyId,
        address _newOwner
    ) public
        propertyMustExist(_propertyId)
        propertyMustBeActive(_propertyId)
        onlyPropertyOwner(_propertyId)
    {
        require(_newOwner != address(0), "Invalid new owner address");
        require(_newOwner != msg.sender, "Cannot transfer to yourself");

        RealEstate storage property = realEstateRegistry[_propertyId];
        address previousOwner = property.currentOwner;


        property.previousOwner = previousOwner;
        property.currentOwner = _newOwner;
        property.lastTransferDate = block.timestamp;


        _removePropertyFromOwner(previousOwner, _propertyId);
        ownerProperties[_newOwner].push(_propertyId);


        emit PropertyTransferred(_propertyId, previousOwner, _newOwner, block.timestamp);
    }


    function updatePropertyValue(
        uint256 _propertyId,
        uint256 _newValue
    ) public
        propertyMustExist(_propertyId)
        propertyMustBeActive(_propertyId)
        onlyAdmin
    {
        require(_newValue > 0, "Property value must be greater than zero");

        realEstateRegistry[_propertyId].propertyValue = _newValue;

        emit PropertyUpdated(
            _propertyId,
            realEstateRegistry[_propertyId].currentOwner,
            _newValue
        );
    }


    function deactivateProperty(uint256 _propertyId)
        public
        propertyMustExist(_propertyId)
        onlyAdmin
    {
        require(realEstateRegistry[_propertyId].isActive, "Property already deactivated");

        realEstateRegistry[_propertyId].isActive = false;

        emit PropertyDeactivated(
            _propertyId,
            realEstateRegistry[_propertyId].currentOwner
        );
    }


    function getPropertyDetails(uint256 _propertyId)
        public
        view
        propertyMustExist(_propertyId)
        returns (
            uint256 propertyId,
            string memory propertyAddress,
            string memory propertyType,
            uint256 propertyArea,
            uint256 propertyValue,
            address currentOwner,
            address previousOwner,
            uint256 registrationDate,
            uint256 lastTransferDate,
            bool isActive
        )
    {
        RealEstate memory property = realEstateRegistry[_propertyId];

        return (
            property.propertyId,
            property.propertyAddress,
            property.propertyType,
            property.propertyArea,
            property.propertyValue,
            property.currentOwner,
            property.previousOwner,
            property.registrationDate,
            property.lastTransferDate,
            property.isActive
        );
    }


    function getOwnerProperties(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        return ownerProperties[_owner];
    }


    function getOwnerPropertyCount(address _owner)
        public
        view
        returns (uint256)
    {
        return ownerProperties[_owner].length;
    }


    function isPropertyOwner(address _owner, uint256 _propertyId)
        public
        view
        propertyMustExist(_propertyId)
        returns (bool)
    {
        return realEstateRegistry[_propertyId].currentOwner == _owner;
    }


    function changeAdmin(address _newAdmin) public onlyAdmin {
        require(_newAdmin != address(0), "Invalid admin address");
        require(_newAdmin != registryAdmin, "New admin cannot be the same as current admin");

        registryAdmin = _newAdmin;
    }


    function _removePropertyFromOwner(address _owner, uint256 _propertyId) private {
        uint256[] storage properties = ownerProperties[_owner];

        for (uint256 i = 0; i < properties.length; i++) {
            if (properties[i] == _propertyId) {

                properties[i] = properties[properties.length - 1];
                properties.pop();
                break;
            }
        }
    }


    function getContractStats()
        public
        view
        returns (uint256 totalProps, address adminAddr)
    {
        return (totalProperties, registryAdmin);
    }
}
