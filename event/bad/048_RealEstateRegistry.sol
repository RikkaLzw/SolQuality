
pragma solidity ^0.8.0;

contract RealEstateRegistry {
    struct Property {
        address owner;
        string propertyAddress;
        uint256 area;
        uint256 value;
        bool isRegistered;
        uint256 registrationTime;
    }

    mapping(uint256 => Property) public properties;
    mapping(address => uint256[]) public ownerProperties;
    uint256 public nextPropertyId;
    address public registrar;


    event PropertyRegistered(uint256 propertyId, address owner, string propertyAddress);
    event PropertyTransferred(uint256 propertyId, address from, address to);
    event PropertyValueUpdated(uint256 propertyId, uint256 newValue);


    error InvalidInput();
    error NotAuthorized();
    error PropertyNotFound();

    modifier onlyRegistrar() {

        require(msg.sender == registrar);
        _;
    }

    modifier onlyPropertyOwner(uint256 propertyId) {
        require(properties[propertyId].owner == msg.sender);
        _;
    }

    constructor() {
        registrar = msg.sender;
        nextPropertyId = 1;
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
        nextPropertyId++;

        properties[propertyId] = Property({
            owner: msg.sender,
            propertyAddress: _propertyAddress,
            area: _area,
            value: _value,
            isRegistered: true,
            registrationTime: block.timestamp
        });

        ownerProperties[msg.sender].push(propertyId);


    }

    function transferProperty(uint256 propertyId, address newOwner) external onlyPropertyOwner(propertyId) {
        require(newOwner != address(0));
        require(properties[propertyId].isRegistered);

        address previousOwner = properties[propertyId].owner;
        properties[propertyId].owner = newOwner;


        uint256[] storage ownerProps = ownerProperties[previousOwner];
        for (uint256 i = 0; i < ownerProps.length; i++) {
            if (ownerProps[i] == propertyId) {
                ownerProps[i] = ownerProps[ownerProps.length - 1];
                ownerProps.pop();
                break;
            }
        }


        ownerProperties[newOwner].push(propertyId);

        emit PropertyTransferred(propertyId, previousOwner, newOwner);
    }

    function updatePropertyValue(uint256 propertyId, uint256 newValue) external onlyRegistrar {
        require(properties[propertyId].isRegistered);
        require(newValue > 0);

        properties[propertyId].value = newValue;

        emit PropertyValueUpdated(propertyId, newValue);
    }

    function getProperty(uint256 propertyId) external view returns (Property memory) {
        require(properties[propertyId].isRegistered);
        return properties[propertyId];
    }

    function getOwnerProperties(address owner) external view returns (uint256[] memory) {
        return ownerProperties[owner];
    }

    function verifyOwnership(uint256 propertyId, address claimedOwner) external view returns (bool) {

        require(properties[propertyId].isRegistered);
        return properties[propertyId].owner == claimedOwner;
    }

    function deregisterProperty(uint256 propertyId) external onlyRegistrar {
        require(properties[propertyId].isRegistered);

        address owner = properties[propertyId].owner;
        properties[propertyId].isRegistered = false;


        uint256[] storage ownerProps = ownerProperties[owner];
        for (uint256 i = 0; i < ownerProps.length; i++) {
            if (ownerProps[i] == propertyId) {
                ownerProps[i] = ownerProps[ownerProps.length - 1];
                ownerProps.pop();
                break;
            }
        }


    }

    function changeRegistrar(address newRegistrar) external onlyRegistrar {
        require(newRegistrar != address(0));
        registrar = newRegistrar;

    }
}
