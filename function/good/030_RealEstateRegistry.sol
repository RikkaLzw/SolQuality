
pragma solidity ^0.8.0;

contract RealEstateRegistry {
    struct Property {
        string propertyId;
        string location;
        uint256 area;
        address owner;
        uint256 registrationTime;
        bool isActive;
    }

    struct Transfer {
        string propertyId;
        address from;
        address to;
        uint256 transferTime;
        uint256 price;
    }

    mapping(string => Property) private properties;
    mapping(string => bool) private propertyExists;
    mapping(address => string[]) private ownerProperties;
    mapping(string => Transfer[]) private propertyTransfers;

    address private registrar;
    uint256 private registrationFee;

    event PropertyRegistered(string indexed propertyId, address indexed owner, string location);
    event PropertyTransferred(string indexed propertyId, address indexed from, address indexed to, uint256 price);
    event OwnershipVerified(string indexed propertyId, address indexed owner);

    modifier onlyRegistrar() {
        require(msg.sender == registrar, "Only registrar can perform this action");
        _;
    }

    modifier onlyPropertyOwner(string memory propertyId) {
        require(properties[propertyId].owner == msg.sender, "Only property owner can perform this action");
        _;
    }

    modifier propertyMustExist(string memory propertyId) {
        require(propertyExists[propertyId], "Property does not exist");
        _;
    }

    modifier propertyMustNotExist(string memory propertyId) {
        require(!propertyExists[propertyId], "Property already exists");
        _;
    }

    constructor(uint256 _registrationFee) {
        registrar = msg.sender;
        registrationFee = _registrationFee;
    }

    function registerProperty(
        string memory propertyId,
        string memory location,
        uint256 area,
        address owner
    ) external onlyRegistrar propertyMustNotExist(propertyId) {
        require(bytes(propertyId).length > 0, "Property ID cannot be empty");
        require(bytes(location).length > 0, "Location cannot be empty");
        require(area > 0, "Area must be greater than zero");
        require(owner != address(0), "Invalid owner address");

        properties[propertyId] = Property({
            propertyId: propertyId,
            location: location,
            area: area,
            owner: owner,
            registrationTime: block.timestamp,
            isActive: true
        });

        propertyExists[propertyId] = true;
        ownerProperties[owner].push(propertyId);

        emit PropertyRegistered(propertyId, owner, location);
    }

    function transferProperty(
        string memory propertyId,
        address newOwner,
        uint256 price
    ) external payable propertyMustExist(propertyId) onlyPropertyOwner(propertyId) {
        require(newOwner != address(0), "Invalid new owner address");
        require(newOwner != properties[propertyId].owner, "Cannot transfer to current owner");
        require(msg.value >= registrationFee, "Insufficient registration fee");
        require(properties[propertyId].isActive, "Property is not active");

        address currentOwner = properties[propertyId].owner;

        _removePropertyFromOwner(currentOwner, propertyId);

        properties[propertyId].owner = newOwner;
        ownerProperties[newOwner].push(propertyId);

        propertyTransfers[propertyId].push(Transfer({
            propertyId: propertyId,
            from: currentOwner,
            to: newOwner,
            transferTime: block.timestamp,
            price: price
        }));

        if (msg.value > registrationFee) {
            payable(msg.sender).transfer(msg.value - registrationFee);
        }

        emit PropertyTransferred(propertyId, currentOwner, newOwner, price);
    }

    function getPropertyInfo(string memory propertyId)
        external
        view
        propertyMustExist(propertyId)
        returns (Property memory)
    {
        return properties[propertyId];
    }

    function verifyOwnership(string memory propertyId)
        external
        view
        propertyMustExist(propertyId)
        returns (address)
    {
        emit OwnershipVerified(propertyId, properties[propertyId].owner);
        return properties[propertyId].owner;
    }

    function getOwnerProperties(address owner)
        external
        view
        returns (string[] memory)
    {
        return ownerProperties[owner];
    }

    function getPropertyTransfers(string memory propertyId)
        external
        view
        propertyMustExist(propertyId)
        returns (Transfer[] memory)
    {
        return propertyTransfers[propertyId];
    }

    function deactivateProperty(string memory propertyId)
        external
        onlyRegistrar
        propertyMustExist(propertyId)
    {
        properties[propertyId].isActive = false;
    }

    function activateProperty(string memory propertyId)
        external
        onlyRegistrar
        propertyMustExist(propertyId)
    {
        properties[propertyId].isActive = true;
    }

    function updateRegistrationFee(uint256 newFee) external onlyRegistrar {
        registrationFee = newFee;
    }

    function getRegistrationFee() external view returns (uint256) {
        return registrationFee;
    }

    function withdrawFees() external onlyRegistrar {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        payable(registrar).transfer(balance);
    }

    function _removePropertyFromOwner(address owner, string memory propertyId) private {
        string[] storage properties_array = ownerProperties[owner];
        for (uint256 i = 0; i < properties_array.length; i++) {
            if (keccak256(bytes(properties_array[i])) == keccak256(bytes(propertyId))) {
                properties_array[i] = properties_array[properties_array.length - 1];
                properties_array.pop();
                break;
            }
        }
    }
}
