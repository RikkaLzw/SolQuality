
pragma solidity ^0.8.0;

contract CopyrightManagement {
    struct Copyright {
        address owner;
        string title;
        string description;
        string contentHash;
        uint256 registrationDate;
        bool isActive;
    }

    struct License {
        uint256 copyrightId;
        address licensee;
        uint256 startDate;
        uint256 endDate;
        uint256 fee;
        bool isActive;
    }

    mapping(uint256 => Copyright) public copyrights;
    mapping(uint256 => License) public licenses;
    mapping(address => uint256[]) public ownerCopyrights;
    mapping(address => uint256[]) public licenseeLicenses;
    mapping(string => uint256) public contentHashToCopyrightId;

    uint256 public nextCopyrightId = 1;
    uint256 public nextLicenseId = 1;
    address public admin;
    uint256 public registrationFee = 0.01 ether;

    event CopyrightRegistered(
        uint256 indexed copyrightId,
        address indexed owner,
        string indexed title,
        string contentHash,
        uint256 registrationDate
    );

    event CopyrightTransferred(
        uint256 indexed copyrightId,
        address indexed previousOwner,
        address indexed newOwner
    );

    event LicenseGranted(
        uint256 indexed licenseId,
        uint256 indexed copyrightId,
        address indexed licensee,
        uint256 startDate,
        uint256 endDate,
        uint256 fee
    );

    event LicenseRevoked(
        uint256 indexed licenseId,
        uint256 indexed copyrightId,
        address indexed licensee
    );

    event CopyrightDeactivated(
        uint256 indexed copyrightId,
        address indexed owner
    );

    event RegistrationFeeUpdated(
        uint256 previousFee,
        uint256 newFee
    );

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyCopyrightOwner(uint256 copyrightId) {
        require(copyrights[copyrightId].owner == msg.sender, "Only copyright owner can perform this action");
        _;
    }

    modifier copyrightExists(uint256 copyrightId) {
        require(copyrights[copyrightId].owner != address(0), "Copyright does not exist");
        _;
    }

    modifier copyrightActive(uint256 copyrightId) {
        require(copyrights[copyrightId].isActive, "Copyright is not active");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function registerCopyright(
        string memory title,
        string memory description,
        string memory contentHash
    ) external payable returns (uint256) {
        require(msg.value >= registrationFee, "Insufficient registration fee");
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(contentHash).length > 0, "Content hash cannot be empty");
        require(contentHashToCopyrightId[contentHash] == 0, "Content already registered");

        uint256 copyrightId = nextCopyrightId++;

        copyrights[copyrightId] = Copyright({
            owner: msg.sender,
            title: title,
            description: description,
            contentHash: contentHash,
            registrationDate: block.timestamp,
            isActive: true
        });

        ownerCopyrights[msg.sender].push(copyrightId);
        contentHashToCopyrightId[contentHash] = copyrightId;

        emit CopyrightRegistered(copyrightId, msg.sender, title, contentHash, block.timestamp);


        if (msg.value > registrationFee) {
            payable(msg.sender).transfer(msg.value - registrationFee);
        }

        return copyrightId;
    }

    function transferCopyright(uint256 copyrightId, address newOwner)
        external
        copyrightExists(copyrightId)
        onlyCopyrightOwner(copyrightId)
        copyrightActive(copyrightId)
    {
        require(newOwner != address(0), "New owner cannot be zero address");
        require(newOwner != msg.sender, "Cannot transfer to yourself");

        address previousOwner = copyrights[copyrightId].owner;
        copyrights[copyrightId].owner = newOwner;


        _removeCopyrightFromOwner(previousOwner, copyrightId);
        ownerCopyrights[newOwner].push(copyrightId);

        emit CopyrightTransferred(copyrightId, previousOwner, newOwner);
    }

    function grantLicense(
        uint256 copyrightId,
        address licensee,
        uint256 duration,
        uint256 fee
    )
        external
        copyrightExists(copyrightId)
        onlyCopyrightOwner(copyrightId)
        copyrightActive(copyrightId)
        returns (uint256)
    {
        require(licensee != address(0), "Licensee cannot be zero address");
        require(licensee != msg.sender, "Cannot license to yourself");
        require(duration > 0, "Duration must be greater than zero");

        uint256 licenseId = nextLicenseId++;
        uint256 startDate = block.timestamp;
        uint256 endDate = startDate + duration;

        licenses[licenseId] = License({
            copyrightId: copyrightId,
            licensee: licensee,
            startDate: startDate,
            endDate: endDate,
            fee: fee,
            isActive: true
        });

        licenseeLicenses[licensee].push(licenseId);

        emit LicenseGranted(licenseId, copyrightId, licensee, startDate, endDate, fee);

        return licenseId;
    }

    function revokeLicense(uint256 licenseId)
        external
        copyrightExists(licenses[licenseId].copyrightId)
        onlyCopyrightOwner(licenses[licenseId].copyrightId)
    {
        require(licenses[licenseId].licensee != address(0), "License does not exist");
        require(licenses[licenseId].isActive, "License is already inactive");

        licenses[licenseId].isActive = false;

        emit LicenseRevoked(licenseId, licenses[licenseId].copyrightId, licenses[licenseId].licensee);
    }

    function deactivateCopyright(uint256 copyrightId)
        external
        copyrightExists(copyrightId)
        onlyCopyrightOwner(copyrightId)
    {
        require(copyrights[copyrightId].isActive, "Copyright is already inactive");

        copyrights[copyrightId].isActive = false;

        emit CopyrightDeactivated(copyrightId, msg.sender);
    }

    function isLicenseValid(uint256 licenseId) external view returns (bool) {
        License memory license = licenses[licenseId];
        return license.isActive &&
               block.timestamp >= license.startDate &&
               block.timestamp <= license.endDate &&
               copyrights[license.copyrightId].isActive;
    }

    function getCopyrightsByOwner(address owner) external view returns (uint256[] memory) {
        return ownerCopyrights[owner];
    }

    function getLicensesByLicensee(address licensee) external view returns (uint256[] memory) {
        return licenseeLicenses[licensee];
    }

    function updateRegistrationFee(uint256 newFee) external onlyAdmin {
        require(newFee > 0, "Registration fee must be greater than zero");

        uint256 previousFee = registrationFee;
        registrationFee = newFee;

        emit RegistrationFeeUpdated(previousFee, newFee);
    }

    function withdrawFees() external onlyAdmin {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");

        payable(admin).transfer(balance);
    }

    function _removeCopyrightFromOwner(address owner, uint256 copyrightId) private {
        uint256[] storage copyrightIds = ownerCopyrights[owner];
        for (uint256 i = 0; i < copyrightIds.length; i++) {
            if (copyrightIds[i] == copyrightId) {
                copyrightIds[i] = copyrightIds[copyrightIds.length - 1];
                copyrightIds.pop();
                break;
            }
        }
    }
}
