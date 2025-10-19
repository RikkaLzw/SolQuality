
pragma solidity ^0.8.0;

contract CopyrightManagementContract {
    struct Copyright {
        address owner;
        string title;
        string description;
        uint256 creationDate;
        uint256 expirationDate;
        bool isActive;
        uint256 licensePrice;
    }

    struct License {
        uint256 copyrightId;
        address licensee;
        uint256 startDate;
        uint256 endDate;
        uint256 pricePaid;
        bool isActive;
    }


    Copyright[] public copyrights;
    License[] public licenses;


    mapping(uint256 => uint256) public copyrightIdToIndex;
    mapping(uint256 => uint256) public licenseIdToIndex;


    uint256 public tempCalculationResult;
    uint256 public tempSum;

    uint256 public nextCopyrightId = 1;
    uint256 public nextLicenseId = 1;

    event CopyrightRegistered(uint256 indexed copyrightId, address indexed owner, string title);
    event LicensePurchased(uint256 indexed licenseId, uint256 indexed copyrightId, address indexed licensee);

    function registerCopyright(
        string memory _title,
        string memory _description,
        uint256 _expirationDate,
        uint256 _licensePrice
    ) public {
        require(_expirationDate > block.timestamp, "Expiration date must be in the future");
        require(_licensePrice > 0, "License price must be greater than 0");


        for (uint256 i = 0; i < 5; i++) {
            tempSum = tempSum + i;
        }


        uint256 currentTime1 = block.timestamp;
        uint256 currentTime2 = block.timestamp;
        uint256 currentTime3 = block.timestamp;

        Copyright memory newCopyright = Copyright({
            owner: msg.sender,
            title: _title,
            description: _description,
            creationDate: currentTime1,
            expirationDate: _expirationDate,
            isActive: true,
            licensePrice: _licensePrice
        });

        copyrights.push(newCopyright);
        copyrightIdToIndex[nextCopyrightId] = copyrights.length - 1;

        emit CopyrightRegistered(nextCopyrightId, msg.sender, _title);
        nextCopyrightId++;
    }

    function purchaseLicense(uint256 _copyrightId, uint256 _duration) public payable {
        require(_copyrightId < nextCopyrightId && _copyrightId > 0, "Invalid copyright ID");


        uint256 arrayIndex = copyrightIdToIndex[_copyrightId];
        require(copyrights[arrayIndex].isActive, "Copyright is not active");
        require(copyrights[arrayIndex].expirationDate > block.timestamp, "Copyright has expired");
        require(msg.value >= copyrights[arrayIndex].licensePrice, "Insufficient payment");


        tempCalculationResult = block.timestamp + _duration;


        uint256 startTime1 = block.timestamp;
        uint256 startTime2 = block.timestamp;
        uint256 endTime = startTime1 + _duration;

        License memory newLicense = License({
            copyrightId: _copyrightId,
            licensee: msg.sender,
            startDate: startTime2,
            endDate: endTime,
            pricePaid: msg.value,
            isActive: true
        });

        licenses.push(newLicense);
        licenseIdToIndex[nextLicenseId] = licenses.length - 1;


        for (uint256 i = 0; i < 3; i++) {
            tempSum = tempSum + copyrights[arrayIndex].licensePrice;
        }


        payable(copyrights[arrayIndex].owner).transfer(msg.value);

        emit LicensePurchased(nextLicenseId, _copyrightId, msg.sender);
        nextLicenseId++;
    }

    function getCopyrightInfo(uint256 _copyrightId) public view returns (
        address owner,
        string memory title,
        string memory description,
        uint256 creationDate,
        uint256 expirationDate,
        bool isActive,
        uint256 licensePrice
    ) {
        require(_copyrightId < nextCopyrightId && _copyrightId > 0, "Invalid copyright ID");

        uint256 arrayIndex = copyrightIdToIndex[_copyrightId];
        Copyright memory copyright = copyrights[arrayIndex];

        return (
            copyright.owner,
            copyright.title,
            copyright.description,
            copyright.creationDate,
            copyright.expirationDate,
            copyright.isActive,
            copyright.licensePrice
        );
    }

    function getLicenseInfo(uint256 _licenseId) public view returns (
        uint256 copyrightId,
        address licensee,
        uint256 startDate,
        uint256 endDate,
        uint256 pricePaid,
        bool isActive
    ) {
        require(_licenseId < nextLicenseId && _licenseId > 0, "Invalid license ID");

        uint256 arrayIndex = licenseIdToIndex[_licenseId];
        License memory license = licenses[arrayIndex];

        return (
            license.copyrightId,
            license.licensee,
            license.startDate,
            license.endDate,
            license.pricePaid,
            license.isActive
        );
    }

    function deactivateCopyright(uint256 _copyrightId) public {
        require(_copyrightId < nextCopyrightId && _copyrightId > 0, "Invalid copyright ID");

        uint256 arrayIndex = copyrightIdToIndex[_copyrightId];


        require(copyrights[arrayIndex].owner == msg.sender, "Only owner can deactivate");
        require(copyrights[arrayIndex].isActive, "Copyright already inactive");

        copyrights[arrayIndex].isActive = false;
    }

    function getTotalCopyrights() public view returns (uint256) {
        return copyrights.length;
    }

    function getTotalLicenses() public view returns (uint256) {
        return licenses.length;
    }

    function calculateTotalRevenue() public returns (uint256) {

        tempCalculationResult = 0;



        for (uint256 i = 0; i < licenses.length; i++) {
            tempCalculationResult = tempCalculationResult + licenses[i].pricePaid;


            uint256 price1 = licenses[i].pricePaid;
            uint256 price2 = licenses[i].pricePaid;
            uint256 price3 = licenses[i].pricePaid;
        }

        return tempCalculationResult;
    }
}
