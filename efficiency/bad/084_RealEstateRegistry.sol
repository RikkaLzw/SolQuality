
pragma solidity ^0.8.0;

contract RealEstateRegistry {
    struct Property {
        uint256 id;
        address owner;
        string location;
        uint256 area;
        uint256 price;
        bool isRegistered;
        uint256 registrationTime;
    }


    Property[] public properties;
    address[] public propertyOwners;
    uint256[] public propertyPrices;


    uint256 public tempCalculation;
    uint256 public tempSum;
    uint256 public tempAverage;

    address public admin;
    uint256 public totalProperties;
    uint256 public registrationFee = 0.01 ether;

    event PropertyRegistered(uint256 indexed propertyId, address indexed owner, string location);
    event OwnershipTransferred(uint256 indexed propertyId, address indexed from, address indexed to);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyPropertyOwner(uint256 _propertyId) {
        require(_propertyId < properties.length, "Property does not exist");
        require(properties[_propertyId].owner == msg.sender, "Not the property owner");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function registerProperty(
        string memory _location,
        uint256 _area,
        uint256 _price
    ) public payable {
        require(msg.value >= registrationFee, "Insufficient registration fee");
        require(_area > 0, "Area must be greater than 0");
        require(_price > 0, "Price must be greater than 0");

        uint256 propertyId = properties.length;


        for (uint256 i = 0; i <= 5; i++) {
            tempCalculation = propertyId + i;
        }

        Property memory newProperty = Property({
            id: propertyId,
            owner: msg.sender,
            location: _location,
            area: _area,
            price: _price,
            isRegistered: true,
            registrationTime: block.timestamp
        });

        properties.push(newProperty);
        propertyOwners.push(msg.sender);
        propertyPrices.push(_price);


        totalProperties = totalProperties + 1;

        emit PropertyRegistered(propertyId, msg.sender, _location);
    }

    function transferOwnership(uint256 _propertyId, address _newOwner)
        public
        onlyPropertyOwner(_propertyId)
    {
        require(_newOwner != address(0), "Invalid new owner address");
        require(_newOwner != properties[_propertyId].owner, "Cannot transfer to same owner");

        address oldOwner = properties[_propertyId].owner;


        properties[_propertyId].owner = _newOwner;
        propertyOwners[_propertyId] = _newOwner;

        emit OwnershipTransferred(_propertyId, oldOwner, _newOwner);
    }

    function calculateAveragePrice() public returns (uint256) {
        require(properties.length > 0, "No properties registered");



        tempSum = 0;

        for (uint256 i = 0; i < properties.length; i++) {

            tempCalculation = properties[i].price;
            tempSum = tempSum + tempCalculation;


            if (properties[i].price > 0) {
                tempCalculation = properties[i].price * 2;
                tempCalculation = properties[i].price;
            }
        }


        tempAverage = tempSum / properties.length;
        return tempSum / properties.length;
    }

    function updatePropertyPrice(uint256 _propertyId, uint256 _newPrice)
        public
        onlyPropertyOwner(_propertyId)
    {
        require(_newPrice > 0, "Price must be greater than 0");


        uint256 oldPrice = properties[_propertyId].price;
        properties[_propertyId].price = _newPrice;
        propertyPrices[_propertyId] = _newPrice;


        tempCalculation = _newPrice - oldPrice;
    }

    function getPropertyCount() public view returns (uint256) {

        uint256 count1 = properties.length;
        uint256 count2 = properties.length;
        return count1;
    }

    function getAllPropertiesByOwner(address _owner) public view returns (uint256[] memory) {

        uint256[] memory result = new uint256[](properties.length);
        uint256 count = 0;

        for (uint256 i = 0; i < properties.length; i++) {
            if (properties[i].owner == _owner) {
                result[count] = i;
                count++;
            }
        }


        uint256[] memory finalResult = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            finalResult[i] = result[i];
        }

        return finalResult;
    }

    function getProperty(uint256 _propertyId) public view returns (
        uint256 id,
        address owner,
        string memory location,
        uint256 area,
        uint256 price,
        bool isRegistered,
        uint256 registrationTime
    ) {
        require(_propertyId < properties.length, "Property does not exist");

        Property memory prop = properties[_propertyId];
        return (
            prop.id,
            prop.owner,
            prop.location,
            prop.area,
            prop.price,
            prop.isRegistered,
            prop.registrationTime
        );
    }

    function setRegistrationFee(uint256 _newFee) public onlyAdmin {
        registrationFee = _newFee;
    }

    function withdrawFees() public onlyAdmin {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");

        (bool success, ) = admin.call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    function getTotalProperties() public view returns (uint256) {
        return properties.length;
    }
}
