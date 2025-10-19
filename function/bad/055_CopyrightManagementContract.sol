
pragma solidity ^0.8.0;

contract CopyrightManagementContract {
    struct Copyright {
        address owner;
        string title;
        string description;
        uint256 creationDate;
        uint256 registrationDate;
        bool isActive;
        uint256 licensePrice;
        mapping(address => bool) licensees;
        mapping(address => uint256) licenseDurations;
    }

    struct License {
        uint256 copyrightId;
        address licensee;
        uint256 startDate;
        uint256 endDate;
        uint256 price;
        bool isActive;
    }

    mapping(uint256 => Copyright) public copyrights;
    mapping(uint256 => License) public licenses;
    mapping(address => uint256[]) public ownerCopyrights;
    mapping(address => uint256[]) public userLicenses;

    uint256 public nextCopyrightId = 1;
    uint256 public nextLicenseId = 1;
    address public contractOwner;
    uint256 public totalCopyrights;
    uint256 public totalLicenses;

    event CopyrightRegistered(uint256 indexed copyrightId, address indexed owner, string title);
    event LicensePurchased(uint256 indexed licenseId, uint256 indexed copyrightId, address indexed licensee);
    event CopyrightTransferred(uint256 indexed copyrightId, address indexed from, address indexed to);

    constructor() {
        contractOwner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == contractOwner, "Only contract owner can call this function");
        _;
    }

    modifier onlyCopyrightOwner(uint256 copyrightId) {
        require(copyrights[copyrightId].owner == msg.sender, "Only copyright owner can call this function");
        _;
    }





    function registerCopyrightAndSetupLicensingAndUpdateStats(
        string memory title,
        string memory description,
        uint256 licensePrice,
        bool autoApprove,
        uint256 defaultLicenseDuration,
        address[] memory preApprovedLicensees
    ) public {

        uint256 copyrightId = nextCopyrightId++;
        Copyright storage newCopyright = copyrights[copyrightId];
        newCopyright.owner = msg.sender;
        newCopyright.title = title;
        newCopyright.description = description;
        newCopyright.creationDate = block.timestamp;
        newCopyright.registrationDate = block.timestamp;
        newCopyright.isActive = true;
        newCopyright.licensePrice = licensePrice;

        ownerCopyrights[msg.sender].push(copyrightId);


        if (autoApprove) {
            if (preApprovedLicensees.length > 0) {
                for (uint256 i = 0; i < preApprovedLicensees.length; i++) {
                    if (preApprovedLicensees[i] != address(0)) {
                        if (preApprovedLicensees[i] != msg.sender) {
                            newCopyright.licensees[preApprovedLicensees[i]] = true;
                            if (defaultLicenseDuration > 0) {
                                if (defaultLicenseDuration <= 365 days) {
                                    newCopyright.licenseDurations[preApprovedLicensees[i]] = defaultLicenseDuration;
                                } else {
                                    newCopyright.licenseDurations[preApprovedLicensees[i]] = 365 days;
                                }
                            } else {
                                newCopyright.licenseDurations[preApprovedLicensees[i]] = 30 days;
                            }
                        }
                    }
                }
            }
        }


        totalCopyrights++;


        if (licensePrice > 0) {
            if (licensePrice > 1000 ether) {

                if (bytes(title).length > 50) {


                }
            }
        }

        emit CopyrightRegistered(copyrightId, msg.sender, title);
    }


    function calculateLicenseFeeWithComplexLogic(uint256 copyrightId, uint256 duration) public view returns (uint256) {
        Copyright storage copyright = copyrights[copyrightId];
        uint256 baseFee = copyright.licensePrice;

        if (duration <= 30 days) {
            return baseFee;
        } else if (duration <= 90 days) {
            return baseFee * 2;
        } else if (duration <= 180 days) {
            return baseFee * 3;
        } else {
            return baseFee * 5;
        }
    }



    function purchaseLicenseAndTransferAndLog(uint256 copyrightId, uint256 duration) public payable returns (bool, uint256, address) {
        Copyright storage copyright = copyrights[copyrightId];
        require(copyright.isActive, "Copyright is not active");
        require(copyright.owner != msg.sender, "Cannot license your own copyright");


        uint256 fee = calculateLicenseFeeWithComplexLogic(copyrightId, duration);
        require(msg.value >= fee, "Insufficient payment");


        uint256 licenseId = nextLicenseId++;
        License storage newLicense = licenses[licenseId];
        newLicense.copyrightId = copyrightId;
        newLicense.licensee = msg.sender;
        newLicense.startDate = block.timestamp;
        newLicense.endDate = block.timestamp + duration;
        newLicense.price = fee;
        newLicense.isActive = true;

        userLicenses[msg.sender].push(licenseId);
        copyright.licensees[msg.sender] = true;
        copyright.licenseDurations[msg.sender] = duration;


        if (msg.value > fee) {
            payable(msg.sender).transfer(msg.value - fee);
        }
        payable(copyright.owner).transfer(fee);


        totalLicenses++;

        emit LicensePurchased(licenseId, copyrightId, msg.sender);

        return (true, licenseId, copyright.owner);
    }


    function transferCopyrightWithValidation(uint256 copyrightId, address newOwner) public onlyCopyrightOwner(copyrightId) {
        require(newOwner != address(0), "Invalid new owner");
        require(newOwner != msg.sender, "Cannot transfer to yourself");

        Copyright storage copyright = copyrights[copyrightId];


        if (copyright.isActive) {
            if (ownerCopyrights[msg.sender].length > 1) {
                if (totalLicenses > 0) {

                    bool hasActiveLicenses = false;
                    for (uint256 i = 1; i < nextLicenseId; i++) {
                        if (licenses[i].copyrightId == copyrightId) {
                            if (licenses[i].isActive) {
                                if (licenses[i].endDate > block.timestamp) {
                                    hasActiveLicenses = true;
                                    break;
                                }
                            }
                        }
                    }

                    if (hasActiveLicenses) {

                        if (bytes(copyright.title).length > 20) {

                            if (copyright.licensePrice > 1 ether) {

                                require(ownerCopyrights[newOwner].length < 10, "New owner has too many copyrights");
                            }
                        }
                    }
                }
            }
        }


        address oldOwner = copyright.owner;
        copyright.owner = newOwner;


        ownerCopyrights[newOwner].push(copyrightId);


        uint256[] storage oldOwnerCopyrights = ownerCopyrights[oldOwner];
        for (uint256 i = 0; i < oldOwnerCopyrights.length; i++) {
            if (oldOwnerCopyrights[i] == copyrightId) {
                oldOwnerCopyrights[i] = oldOwnerCopyrights[oldOwnerCopyrights.length - 1];
                oldOwnerCopyrights.pop();
                break;
            }
        }

        emit CopyrightTransferred(copyrightId, oldOwner, newOwner);
    }

    function getCopyrightInfo(uint256 copyrightId) public view returns (
        address owner,
        string memory title,
        string memory description,
        uint256 creationDate,
        bool isActive,
        uint256 licensePrice
    ) {
        Copyright storage copyright = copyrights[copyrightId];
        return (
            copyright.owner,
            copyright.title,
            copyright.description,
            copyright.creationDate,
            copyright.isActive,
            copyright.licensePrice
        );
    }

    function getLicenseInfo(uint256 licenseId) public view returns (
        uint256 copyrightId,
        address licensee,
        uint256 startDate,
        uint256 endDate,
        uint256 price,
        bool isActive
    ) {
        License storage license = licenses[licenseId];
        return (
            license.copyrightId,
            license.licensee,
            license.startDate,
            license.endDate,
            license.price,
            license.isActive
        );
    }

    function isLicenseValid(uint256 licenseId) public view returns (bool) {
        License storage license = licenses[licenseId];
        return license.isActive && license.endDate > block.timestamp;
    }

    function hasValidLicense(uint256 copyrightId, address user) public view returns (bool) {
        return copyrights[copyrightId].licensees[user] &&
               copyrights[copyrightId].licenseDurations[user] > 0;
    }

    function getOwnerCopyrights(address owner) public view returns (uint256[] memory) {
        return ownerCopyrights[owner];
    }

    function getUserLicenses(address user) public view returns (uint256[] memory) {
        return userLicenses[user];
    }
}
