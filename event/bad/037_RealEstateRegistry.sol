
pragma solidity ^0.8.0;

contract RealEstateRegistry {
    struct Property {
        address owner;
        string propertyAddress;
        uint256 area;
        uint256 value;
        bool isRegistered;
        uint256 registrationDate;
    }

    mapping(uint256 => Property) public properties;
    mapping(address => uint256[]) public ownerProperties;
    uint256 public nextPropertyId = 1;
    address public admin;


    event PropertyRegistered(uint256 propertyId, address owner, string propertyAddress);
    event PropertyTransferred(uint256 propertyId, address from, address to);
    event PropertyValueUpdated(uint256 propertyId, uint256 newValue);


    error InvalidInput();
    error NotAuthorized();
    error PropertyError();

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    modifier onlyPropertyOwner(uint256 _propertyId) {
        require(properties[_propertyId].owner == msg.sender);
        _;
    }

    modifier propertyExists(uint256 _propertyId) {
        require(properties[_propertyId].isRegistered);
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function registerProperty(
        string memory _propertyAddress,
        uint256 _area,
        uint256 _value
    ) external {
        require(bytes(_propertyAddress).length > 0);
        require(_area > 0);
        require(_value > 0);

        uint256 propertyId = nextPropertyId;

        properties[propertyId] = Property({
            owner: msg.sender,
            propertyAddress: _propertyAddress,
            area: _area,
            value: _value,
            isRegistered: true,
            registrationDate: block.timestamp
        });

        ownerProperties[msg.sender].push(propertyId);
        nextPropertyId++;



    }

    function transferProperty(uint256 _propertyId, address _newOwner)
        external
        propertyExists(_propertyId)
        onlyPropertyOwner(_propertyId)
    {
        require(_newOwner != address(0));
        require(_newOwner != properties[_propertyId].owner);

        address previousOwner = properties[_propertyId].owner;


        uint256[] storage ownerProps = ownerProperties[previousOwner];
        for (uint256 i = 0; i < ownerProps.length; i++) {
            if (ownerProps[i] == _propertyId) {
                ownerProps[i] = ownerProps[ownerProps.length - 1];
                ownerProps.pop();
                break;
            }
        }


        ownerProperties[_newOwner].push(_propertyId);
        properties[_propertyId].owner = _newOwner;

        PropertyTransferred(_propertyId, previousOwner, _newOwner);
    }

    function updatePropertyValue(uint256 _propertyId, uint256 _newValue)
        external
        propertyExists(_propertyId)
        onlyPropertyOwner(_propertyId)
    {
        require(_newValue > 0);

        properties[_propertyId].value = _newValue;



    }

    function updatePropertyAddress(uint256 _propertyId, string memory _newAddress)
        external
        propertyExists(_propertyId)
        onlyPropertyOwner(_propertyId)
    {
        require(bytes(_newAddress).length > 0);


        properties[_propertyId].propertyAddress = _newAddress;
    }

    function verifyProperty(uint256 _propertyId)
        external
        view
        propertyExists(_propertyId)
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
            string memory propertyAddress,
            uint256 area,
            uint256 value,
            uint256 registrationDate
        )
    {
        Property memory prop = properties[_propertyId];
        return (
            prop.owner,
            prop.propertyAddress,
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

    function deactivateProperty(uint256 _propertyId)
        external
        onlyAdmin
        propertyExists(_propertyId)
    {

        require(!properties[_propertyId].isRegistered == false);

        properties[_propertyId].isRegistered = false;


    }

    function changeAdmin(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0));


        admin = _newAdmin;
    }

    function getTotalProperties() external view returns (uint256) {
        return nextPropertyId - 1;
    }
}
