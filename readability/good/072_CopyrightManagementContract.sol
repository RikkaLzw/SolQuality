
pragma solidity ^0.8.0;


contract CopyrightManagementContract {


    struct CopyrightInfo {
        string contentTitle;
        string contentDescription;
        string contentHash;
        address originalOwner;
        address currentOwner;
        uint256 registrationTime;
        uint256 expirationTime;
        bool isActive;
        uint256 licensePrice;
    }


    struct LicenseInfo {
        uint256 copyrightId;
        address licensee;
        uint256 licenseStartTime;
        uint256 licenseEndTime;
        uint256 paidAmount;
        bool isActive;
    }


    mapping(uint256 => CopyrightInfo) public copyrights;
    mapping(address => uint256[]) public ownerToCopyrights;
    mapping(uint256 => LicenseInfo[]) public copyrightToLicenses;
    mapping(address => uint256[]) public licenseeToLicenses;

    uint256 public nextCopyrightId;
    uint256 public registrationFee;
    address public contractOwner;


    event CopyrightRegistered(
        uint256 indexed copyrightId,
        address indexed owner,
        string contentTitle,
        uint256 registrationTime
    );

    event CopyrightTransferred(
        uint256 indexed copyrightId,
        address indexed fromOwner,
        address indexed toOwner,
        uint256 transferTime
    );

    event LicenseGranted(
        uint256 indexed copyrightId,
        address indexed licensee,
        uint256 licenseStartTime,
        uint256 licenseEndTime,
        uint256 paidAmount
    );

    event CopyrightRevoked(
        uint256 indexed copyrightId,
        address indexed owner,
        uint256 revokeTime
    );


    modifier onlyContractOwner() {
        require(msg.sender == contractOwner, "Only contract owner can perform this action");
        _;
    }

    modifier onlyCopyrightOwner(uint256 copyrightId) {
        require(copyrights[copyrightId].currentOwner == msg.sender, "Only copyright owner can perform this action");
        _;
    }

    modifier copyrightExists(uint256 copyrightId) {
        require(copyrights[copyrightId].isActive, "Copyright does not exist or is inactive");
        _;
    }

    modifier validCopyrightId(uint256 copyrightId) {
        require(copyrightId < nextCopyrightId, "Invalid copyright ID");
        _;
    }


    constructor(uint256 initialRegistrationFee) {
        contractOwner = msg.sender;
        registrationFee = initialRegistrationFee;
        nextCopyrightId = 1;
    }


    function registerCopyright(
        string memory contentTitle,
        string memory contentDescription,
        string memory contentHash,
        uint256 copyrightDuration,
        uint256 licensePrice
    ) external payable returns (uint256) {
        require(msg.value >= registrationFee, "Insufficient registration fee");
        require(bytes(contentTitle).length > 0, "Content title cannot be empty");
        require(bytes(contentHash).length > 0, "Content hash cannot be empty");
        require(copyrightDuration > 0, "Copyright duration must be greater than zero");

        uint256 copyrightId = nextCopyrightId;
        uint256 currentTime = block.timestamp;

        copyrights[copyrightId] = CopyrightInfo({
            contentTitle: contentTitle,
            contentDescription: contentDescription,
            contentHash: contentHash,
            originalOwner: msg.sender,
            currentOwner: msg.sender,
            registrationTime: currentTime,
            expirationTime: currentTime + copyrightDuration,
            isActive: true,
            licensePrice: licensePrice
        });

        ownerToCopyrights[msg.sender].push(copyrightId);
        nextCopyrightId++;

        emit CopyrightRegistered(copyrightId, msg.sender, contentTitle, currentTime);

        return copyrightId;
    }


    function transferCopyright(
        uint256 copyrightId,
        address newOwner
    ) external validCopyrightId(copyrightId) onlyCopyrightOwner(copyrightId) copyrightExists(copyrightId) {
        require(newOwner != address(0), "New owner cannot be zero address");
        require(newOwner != msg.sender, "Cannot transfer to yourself");
        require(block.timestamp < copyrights[copyrightId].expirationTime, "Copyright has expired");

        address oldOwner = copyrights[copyrightId].currentOwner;
        copyrights[copyrightId].currentOwner = newOwner;


        ownerToCopyrights[newOwner].push(copyrightId);
        _removeCopyrightFromOwner(oldOwner, copyrightId);

        emit CopyrightTransferred(copyrightId, oldOwner, newOwner, block.timestamp);
    }


    function purchaseLicense(
        uint256 copyrightId,
        uint256 licenseDuration
    ) external payable validCopyrightId(copyrightId) copyrightExists(copyrightId) {
        require(licenseDuration > 0, "License duration must be greater than zero");
        require(block.timestamp < copyrights[copyrightId].expirationTime, "Copyright has expired");

        uint256 requiredPayment = copyrights[copyrightId].licensePrice;
        require(msg.value >= requiredPayment, "Insufficient payment for license");

        uint256 currentTime = block.timestamp;
        uint256 licenseEndTime = currentTime + licenseDuration;


        if (licenseEndTime > copyrights[copyrightId].expirationTime) {
            licenseEndTime = copyrights[copyrightId].expirationTime;
        }

        LicenseInfo memory newLicense = LicenseInfo({
            copyrightId: copyrightId,
            licensee: msg.sender,
            licenseStartTime: currentTime,
            licenseEndTime: licenseEndTime,
            paidAmount: msg.value,
            isActive: true
        });

        copyrightToLicenses[copyrightId].push(newLicense);
        licenseeToLicenses[msg.sender].push(copyrightToLicenses[copyrightId].length - 1);


        payable(copyrights[copyrightId].currentOwner).transfer(msg.value);

        emit LicenseGranted(copyrightId, msg.sender, currentTime, licenseEndTime, msg.value);
    }


    function revokeCopyright(
        uint256 copyrightId
    ) external validCopyrightId(copyrightId) onlyCopyrightOwner(copyrightId) {
        require(copyrights[copyrightId].isActive, "Copyright is already inactive");

        copyrights[copyrightId].isActive = false;

        emit CopyrightRevoked(copyrightId, msg.sender, block.timestamp);
    }


    function hasValidLicense(
        uint256 copyrightId,
        address user
    ) external view validCopyrightId(copyrightId) returns (bool) {
        LicenseInfo[] memory licenses = copyrightToLicenses[copyrightId];
        uint256 currentTime = block.timestamp;

        for (uint256 i = 0; i < licenses.length; i++) {
            if (licenses[i].licensee == user &&
                licenses[i].isActive &&
                currentTime >= licenses[i].licenseStartTime &&
                currentTime <= licenses[i].licenseEndTime) {
                return true;
            }
        }

        return false;
    }


    function getCopyrightInfo(
        uint256 copyrightId
    ) external view validCopyrightId(copyrightId) returns (CopyrightInfo memory) {
        return copyrights[copyrightId];
    }


    function getOwnerCopyrights(address owner) external view returns (uint256[] memory) {
        return ownerToCopyrights[owner];
    }


    function getCopyrightLicenses(
        uint256 copyrightId
    ) external view validCopyrightId(copyrightId) returns (LicenseInfo[] memory) {
        return copyrightToLicenses[copyrightId];
    }


    function setRegistrationFee(uint256 newFee) external onlyContractOwner {
        registrationFee = newFee;
    }


    function withdrawContractBalance() external onlyContractOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        payable(contractOwner).transfer(balance);
    }


    function _removeCopyrightFromOwner(address owner, uint256 copyrightId) internal {
        uint256[] storage ownerCopyrights = ownerToCopyrights[owner];

        for (uint256 i = 0; i < ownerCopyrights.length; i++) {
            if (ownerCopyrights[i] == copyrightId) {
                ownerCopyrights[i] = ownerCopyrights[ownerCopyrights.length - 1];
                ownerCopyrights.pop();
                break;
            }
        }
    }


    function isCopyrightExpired(uint256 copyrightId) external view validCopyrightId(copyrightId) returns (bool) {
        return block.timestamp >= copyrights[copyrightId].expirationTime;
    }


    function getContractStats() external view returns (
        uint256 totalCopyrights,
        uint256 activeCopyrights,
        uint256 contractBalance
    ) {
        totalCopyrights = nextCopyrightId - 1;

        for (uint256 i = 1; i < nextCopyrightId; i++) {
            if (copyrights[i].isActive && block.timestamp < copyrights[i].expirationTime) {
                activeCopyrights++;
            }
        }

        contractBalance = address(this).balance;

        return (totalCopyrights, activeCopyrights, contractBalance);
    }
}
