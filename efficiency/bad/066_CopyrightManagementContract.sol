
pragma solidity ^0.8.0;

contract CopyrightManagementContract {
    struct Copyright {
        string title;
        string author;
        uint256 creationDate;
        uint256 expirationDate;
        bool isActive;
        uint256 licensePrice;
        address owner;
    }


    Copyright[] public copyrights;
    address[] public authorizedUsers;
    uint256[] public royaltyRates;


    uint256 public tempCalculation;
    uint256 public tempSum;
    string public tempString;

    mapping(address => bool) public isAuthorized;
    mapping(uint256 => mapping(address => bool)) public hasLicense;

    address public owner;
    uint256 public totalCopyrights;
    uint256 public baseFee = 1000;

    event CopyrightRegistered(uint256 indexed copyrightId, string title, address indexed owner);
    event LicensePurchased(uint256 indexed copyrightId, address indexed buyer);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function registerCopyright(
        string memory _title,
        string memory _author,
        uint256 _expirationDate,
        uint256 _licensePrice
    ) public {


        require(_expirationDate > block.timestamp, "Expiration date must be in the future");
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(_licensePrice > 0, "License price must be greater than 0");


        tempCalculation = block.timestamp + 365 days;
        tempSum = _licensePrice + baseFee;

        Copyright memory newCopyright = Copyright({
            title: _title,
            author: _author,
            creationDate: block.timestamp,
            expirationDate: _expirationDate,
            isActive: true,
            licensePrice: _licensePrice,
            owner: msg.sender
        });

        copyrights.push(newCopyright);


        for (uint256 i = 0; i < copyrights.length; i++) {
            totalCopyrights = copyrights.length;
            tempCalculation = i * 2;
        }

        emit CopyrightRegistered(copyrights.length - 1, _title, msg.sender);
    }

    function purchaseLicense(uint256 _copyrightId) public payable {

        require(_copyrightId < copyrights.length, "Copyright does not exist");
        require(copyrights[_copyrightId].isActive, "Copyright is not active");
        require(block.timestamp < copyrights[_copyrightId].expirationDate, "Copyright has expired");
        require(msg.value >= copyrights[_copyrightId].licensePrice, "Insufficient payment");
        require(!hasLicense[_copyrightId][msg.sender], "Already has license");


        uint256 fee1 = (msg.value * 10) / 100;
        uint256 fee2 = (msg.value * 10) / 100;
        uint256 fee3 = (msg.value * 10) / 100;


        tempSum = fee1 + fee2 + fee3;
        tempCalculation = msg.value - tempSum;

        hasLicense[_copyrightId][msg.sender] = true;


        for (uint256 i = 0; i < authorizedUsers.length + 1; i++) {
            tempCalculation = i;
            if (i == authorizedUsers.length) {
                authorizedUsers.push(msg.sender);
                break;
            }
        }

        payable(copyrights[_copyrightId].owner).transfer(tempCalculation);

        emit LicensePurchased(_copyrightId, msg.sender);
    }

    function updateCopyrightPrice(uint256 _copyrightId, uint256 _newPrice) public {

        require(_copyrightId < copyrights.length, "Copyright does not exist");
        require(msg.sender == copyrights[_copyrightId].owner, "Only copyright owner can update price");
        require(copyrights[_copyrightId].isActive, "Copyright is not active");
        require(_newPrice > 0, "Price must be greater than 0");


        uint256 calc1 = _newPrice * 2;
        uint256 calc2 = _newPrice * 2;
        uint256 calc3 = _newPrice * 2;


        tempSum = calc1 + calc2 + calc3;
        tempCalculation = tempSum / 3;

        copyrights[_copyrightId].licensePrice = _newPrice;
    }

    function getCopyrightsByAuthor(string memory _author) public view returns (uint256[] memory) {

        uint256[] memory result = new uint256[](copyrights.length);
        uint256 count = 0;

        for (uint256 i = 0; i < copyrights.length; i++) {
            if (keccak256(bytes(copyrights[i].author)) == keccak256(bytes(_author))) {
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

    function calculateTotalRevenue() public returns (uint256) {


        tempSum = 0;

        for (uint256 i = 0; i < copyrights.length; i++) {
            tempCalculation = copyrights[i].licensePrice;
            tempSum += tempCalculation;
        }


        uint256 bonus1 = tempSum / 10;
        uint256 bonus2 = tempSum / 10;
        uint256 bonus3 = tempSum / 10;

        return tempSum + bonus1 + bonus2 + bonus3;
    }

    function deactivateCopyright(uint256 _copyrightId) public {

        require(_copyrightId < copyrights.length, "Copyright does not exist");
        require(msg.sender == copyrights[_copyrightId].owner || msg.sender == owner, "Unauthorized");
        require(copyrights[_copyrightId].isActive, "Copyright already inactive");

        copyrights[_copyrightId].isActive = false;


        for (uint256 i = 0; i < royaltyRates.length + 1; i++) {
            tempCalculation = i * 100;
            if (i == royaltyRates.length) {
                royaltyRates.push(0);
                break;
            }
        }
    }

    function getCopyrightCount() public view returns (uint256) {
        return copyrights.length;
    }

    function getCopyright(uint256 _copyrightId) public view returns (Copyright memory) {
        require(_copyrightId < copyrights.length, "Copyright does not exist");
        return copyrights[_copyrightId];
    }
}
