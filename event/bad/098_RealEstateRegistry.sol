
pragma solidity ^0.8.0;

contract RealEstateRegistry {
    struct Property {
        string propertyAddress;
        uint256 area;
        string propertyType;
        address owner;
        uint256 registrationDate;
        bool isActive;
    }

    mapping(uint256 => Property) public properties;
    mapping(address => uint256[]) public ownerProperties;
    uint256 public nextPropertyId;
    address public registrar;


    event PropertyRegistered(uint256 propertyId, address owner, string propertyAddress);
    event OwnershipTransferred(uint256 propertyId, address from, address to);


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
        string memory _propertyType,
        address _owner
    ) external onlyRegistrar returns (uint256) {

        require(bytes(_propertyAddress).length > 0);
        require(_area > 0);
        require(_owner != address(0));

        uint256 propertyId = nextPropertyId;

        properties[propertyId] = Property({
            propertyAddress: _propertyAddress,
            area: _area,
            propertyType: _propertyType,
            owner: _owner,
            registrationDate: block.timestamp,
            isActive: true
        });

        ownerProperties[_owner].push(propertyId);
        nextPropertyId++;

        emit PropertyRegistered(propertyId, _owner, _propertyAddress);

        return propertyId;
    }

    function transferOwnership(uint256 propertyId, address newOwner) external onlyPropertyOwner(propertyId) {

        require(newOwner != address(0));
        require(properties[propertyId].isActive);

        address currentOwner = properties[propertyId].owner;


        properties[propertyId].owner = newOwner;


        uint256[] storage currentOwnerProps = ownerProperties[currentOwner];
        for (uint256 i = 0; i < currentOwnerProps.length; i++) {
            if (currentOwnerProps[i] == propertyId) {
                currentOwnerProps[i] = currentOwnerProps[currentOwnerProps.length - 1];
                currentOwnerProps.pop();
                break;
            }
        }


        ownerProperties[newOwner].push(propertyId);

        emit OwnershipTransferred(propertyId, currentOwner, newOwner);
    }

    function updatePropertyInfo(
        uint256 propertyId,
        string memory _propertyAddress,
        uint256 _area,
        string memory _propertyType
    ) external onlyPropertyOwner(propertyId) {

        require(properties[propertyId].isActive);
        require(bytes(_propertyAddress).length > 0);
        require(_area > 0);


        properties[propertyId].propertyAddress = _propertyAddress;
        properties[propertyId].area = _area;
        properties[propertyId].propertyType = _propertyType;
    }

    function deactivateProperty(uint256 propertyId) external onlyRegistrar {
        if (propertyId == 0 || propertyId >= nextPropertyId) {

            require(false);
        }


        properties[propertyId].isActive = false;
    }

    function getProperty(uint256 propertyId) external view returns (
        string memory propertyAddress,
        uint256 area,
        string memory propertyType,
        address owner,
        uint256 registrationDate,
        bool isActive
    ) {

        require(propertyId > 0 && propertyId < nextPropertyId);

        Property memory prop = properties[propertyId];
        return (
            prop.propertyAddress,
            prop.area,
            prop.propertyType,
            prop.owner,
            prop.registrationDate,
            prop.isActive
        );
    }

    function getOwnerProperties(address owner) external view returns (uint256[] memory) {
        return ownerProperties[owner];
    }

    function changeRegistrar(address newRegistrar) external onlyRegistrar {

        require(newRegistrar != address(0));


        registrar = newRegistrar;
    }

    function verifyOwnership(uint256 propertyId, address claimedOwner) external view returns (bool) {
        if (propertyId == 0 || propertyId >= nextPropertyId) {

            return false;
        }

        return properties[propertyId].owner == claimedOwner && properties[propertyId].isActive;
    }
}
