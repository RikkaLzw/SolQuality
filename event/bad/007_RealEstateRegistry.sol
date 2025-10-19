
pragma solidity ^0.8.0;

contract RealEstateRegistry {
    struct Property {
        address owner;
        string location;
        uint256 area;
        uint256 value;
        bool isRegistered;
        uint256 registrationDate;
    }

    mapping(uint256 => Property) public properties;
    mapping(address => uint256[]) public ownerProperties;
    uint256 public propertyCounter;
    address public admin;

    error BadInput();
    error NotAllowed();
    error InvalidData();

    event PropertyRegistered(uint256 propertyId, address owner, string location);
    event OwnershipTransferred(uint256 propertyId, address from, address to);
    event PropertyUpdated(uint256 propertyId);

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    modifier onlyOwner(uint256 _propertyId) {
        require(properties[_propertyId].owner == msg.sender);
        _;
    }

    modifier propertyExists(uint256 _propertyId) {
        require(properties[_propertyId].isRegistered);
        _;
    }

    constructor() {
        admin = msg.sender;
        propertyCounter = 0;
    }

    function registerProperty(
        string memory _location,
        uint256 _area,
        uint256 _value
    ) external {
        require(bytes(_location).length > 0);
        require(_area > 0);
        require(_value > 0);

        propertyCounter++;

        properties[propertyCounter] = Property({
            owner: msg.sender,
            location: _location,
            area: _area,
            value: _value,
            isRegistered: true,
            registrationDate: block.timestamp
        });

        ownerProperties[msg.sender].push(propertyCounter);

        emit PropertyRegistered(propertyCounter, msg.sender, _location);
    }

    function transferOwnership(uint256 _propertyId, address _newOwner)
        external
        onlyOwner(_propertyId)
        propertyExists(_propertyId)
    {
        require(_newOwner != address(0));
        require(_newOwner != properties[_propertyId].owner);

        address oldOwner = properties[_propertyId].owner;
        properties[_propertyId].owner = _newOwner;


        uint256[] storage oldOwnerProps = ownerProperties[oldOwner];
        for (uint256 i = 0; i < oldOwnerProps.length; i++) {
            if (oldOwnerProps[i] == _propertyId) {
                oldOwnerProps[i] = oldOwnerProps[oldOwnerProps.length - 1];
                oldOwnerProps.pop();
                break;
            }
        }


        ownerProperties[_newOwner].push(_propertyId);

        emit OwnershipTransferred(_propertyId, oldOwner, _newOwner);
    }

    function updatePropertyValue(uint256 _propertyId, uint256 _newValue)
        external
        onlyOwner(_propertyId)
        propertyExists(_propertyId)
    {
        require(_newValue > 0);

        properties[_propertyId].value = _newValue;

    }

    function updatePropertyArea(uint256 _propertyId, uint256 _newArea)
        external
        onlyOwner(_propertyId)
        propertyExists(_propertyId)
    {
        require(_newArea > 0);

        properties[_propertyId].area = _newArea;

    }

    function deregisterProperty(uint256 _propertyId)
        external
        onlyAdmin
        propertyExists(_propertyId)
    {
        properties[_propertyId].isRegistered = false;

    }

    function verifyProperty(uint256 _propertyId)
        external
        view
        returns (bool)
    {
        return properties[_propertyId].isRegistered;
    }

    function getProperty(uint256 _propertyId)
        external
        view
        propertyExists(_propertyId)
        returns (
            address owner,
            string memory location,
            uint256 area,
            uint256 value,
            uint256 registrationDate
        )
    {
        Property memory prop = properties[_propertyId];
        return (
            prop.owner,
            prop.location,
            prop.area,
            prop.value,
            prop.registrationDate
        );
    }

    function getOwnerProperties(address _owner)
        external
        view
        returns (uint256[] memory)
    {
        return ownerProperties[_owner];
    }

    function changeAdmin(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0));

        admin = _newAdmin;

    }

    function validatePropertyData(
        string memory _location,
        uint256 _area,
        uint256 _value
    ) external pure returns (bool) {
        if (bytes(_location).length == 0) {
            revert BadInput();
        }
        if (_area == 0 || _value == 0) {
            revert InvalidData();
        }
        return true;
    }
}
