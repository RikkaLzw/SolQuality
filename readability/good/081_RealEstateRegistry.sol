
pragma solidity ^0.8.0;


contract RealEstateRegistry {


    struct PropertyInfo {
        uint256 propertyId;
        string propertyAddress;
        uint256 area;
        string propertyType;
        address currentOwner;
        uint256 registrationDate;
        bool isActive;
        uint256 lastTransferDate;
    }


    struct TransferRecord {
        uint256 propertyId;
        address fromOwner;
        address toOwner;
        uint256 transferDate;
        uint256 transferPrice;
        string transferReason;
    }


    address public administrator;


    uint256 private propertyIdCounter;


    mapping(uint256 => PropertyInfo) public properties;


    mapping(address => uint256[]) public ownerToProperties;


    mapping(uint256 => TransferRecord[]) public propertyTransferHistory;


    uint256[] public allPropertyIds;


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
        uint256 transferDate,
        uint256 transferPrice
    );

    event PropertyDeactivated(
        uint256 indexed propertyId,
        address indexed owner,
        uint256 deactivationDate
    );

    event AdministratorChanged(
        address indexed previousAdmin,
        address indexed newAdmin
    );


    modifier onlyAdministrator() {
        require(msg.sender == administrator, "Only administrator can call this function");
        _;
    }


    modifier onlyPropertyOwner(uint256 _propertyId) {
        require(properties[_propertyId].currentOwner == msg.sender, "Only property owner can call this function");
        _;
    }


    modifier propertyExists(uint256 _propertyId) {
        require(properties[_propertyId].isActive, "Property does not exist or is inactive");
        _;
    }


    constructor() {
        administrator = msg.sender;
        propertyIdCounter = 1;
    }


    function registerProperty(
        string memory _propertyAddress,
        uint256 _area,
        string memory _propertyType,
        address _owner
    )
        external
        onlyAdministrator
        returns (uint256)
    {
        require(_owner != address(0), "Owner address cannot be zero");
        require(bytes(_propertyAddress).length > 0, "Property address cannot be empty");
        require(_area > 0, "Property area must be greater than zero");
        require(bytes(_propertyType).length > 0, "Property type cannot be empty");

        uint256 newPropertyId = propertyIdCounter;


        properties[newPropertyId] = PropertyInfo({
            propertyId: newPropertyId,
            propertyAddress: _propertyAddress,
            area: _area,
            propertyType: _propertyType,
            currentOwner: _owner,
            registrationDate: block.timestamp,
            isActive: true,
            lastTransferDate: block.timestamp
        });


        ownerToProperties[_owner].push(newPropertyId);


        allPropertyIds.push(newPropertyId);


        propertyIdCounter++;


        emit PropertyRegistered(newPropertyId, _owner, _propertyAddress, block.timestamp);

        return newPropertyId;
    }


    function transferProperty(
        uint256 _propertyId,
        address _newOwner,
        uint256 _transferPrice,
        string memory _transferReason
    )
        external
        propertyExists(_propertyId)
        onlyPropertyOwner(_propertyId)
    {
        require(_newOwner != address(0), "New owner address cannot be zero");
        require(_newOwner != msg.sender, "Cannot transfer to the same owner");
        require(bytes(_transferReason).length > 0, "Transfer reason cannot be empty");

        address previousOwner = properties[_propertyId].currentOwner;


        properties[_propertyId].currentOwner = _newOwner;
        properties[_propertyId].lastTransferDate = block.timestamp;


        _removePropertyFromOwner(previousOwner, _propertyId);


        ownerToProperties[_newOwner].push(_propertyId);


        propertyTransferHistory[_propertyId].push(TransferRecord({
            propertyId: _propertyId,
            fromOwner: previousOwner,
            toOwner: _newOwner,
            transferDate: block.timestamp,
            transferPrice: _transferPrice,
            transferReason: _transferReason
        }));


        emit PropertyTransferred(_propertyId, previousOwner, _newOwner, block.timestamp, _transferPrice);
    }


    function deactivateProperty(uint256 _propertyId)
        external
        onlyAdministrator
        propertyExists(_propertyId)
    {
        properties[_propertyId].isActive = false;

        emit PropertyDeactivated(_propertyId, properties[_propertyId].currentOwner, block.timestamp);
    }


    function changeAdministrator(address _newAdministrator)
        external
        onlyAdministrator
    {
        require(_newAdministrator != address(0), "New administrator address cannot be zero");
        require(_newAdministrator != administrator, "New administrator must be different from current");

        address previousAdmin = administrator;
        administrator = _newAdministrator;

        emit AdministratorChanged(previousAdmin, _newAdministrator);
    }


    function getPropertyInfo(uint256 _propertyId)
        external
        view
        returns (PropertyInfo memory)
    {
        require(properties[_propertyId].propertyId != 0, "Property does not exist");
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
        returns (TransferRecord[] memory)
    {
        return propertyTransferHistory[_propertyId];
    }


    function getAllPropertyIds()
        external
        view
        returns (uint256[] memory)
    {
        return allPropertyIds;
    }


    function getActivePropertyCount()
        external
        view
        returns (uint256)
    {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < allPropertyIds.length; i++) {
            if (properties[allPropertyIds[i]].isActive) {
                activeCount++;
            }
        }
        return activeCount;
    }


    function verifyPropertyOwnership(uint256 _propertyId, address _owner)
        external
        view
        returns (bool)
    {
        return properties[_propertyId].isActive && properties[_propertyId].currentOwner == _owner;
    }


    function _removePropertyFromOwner(address _owner, uint256 _propertyId)
        private
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
}
