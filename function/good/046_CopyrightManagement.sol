
pragma solidity ^0.8.0;

contract CopyrightManagement {
    struct Copyright {
        address owner;
        string title;
        string description;
        uint256 registrationTime;
        bool isActive;
    }

    struct License {
        address licensee;
        uint256 copyrightId;
        uint256 expirationTime;
        uint256 fee;
        bool isActive;
    }

    mapping(uint256 => Copyright) public copyrights;
    mapping(uint256 => License) public licenses;
    mapping(address => uint256[]) public ownerCopyrights;
    mapping(address => uint256[]) public licenseeCopyrights;

    uint256 public nextCopyrightId;
    uint256 public nextLicenseId;
    address public admin;

    event CopyrightRegistered(uint256 indexed copyrightId, address indexed owner, string title);
    event CopyrightTransferred(uint256 indexed copyrightId, address indexed from, address indexed to);
    event LicenseGranted(uint256 indexed licenseId, uint256 indexed copyrightId, address indexed licensee);
    event LicenseRevoked(uint256 indexed licenseId);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyCopyrightOwner(uint256 copyrightId) {
        require(copyrights[copyrightId].owner == msg.sender, "Only copyright owner can perform this action");
        _;
    }

    modifier validCopyright(uint256 copyrightId) {
        require(copyrights[copyrightId].isActive, "Copyright does not exist or is inactive");
        _;
    }

    constructor() {
        admin = msg.sender;
        nextCopyrightId = 1;
        nextLicenseId = 1;
    }

    function registerCopyright(string memory title, string memory description) external returns (uint256) {
        require(bytes(title).length > 0, "Title cannot be empty");

        uint256 copyrightId = nextCopyrightId++;

        copyrights[copyrightId] = Copyright({
            owner: msg.sender,
            title: title,
            description: description,
            registrationTime: block.timestamp,
            isActive: true
        });

        ownerCopyrights[msg.sender].push(copyrightId);

        emit CopyrightRegistered(copyrightId, msg.sender, title);
        return copyrightId;
    }

    function transferCopyright(uint256 copyrightId, address newOwner) external
        onlyCopyrightOwner(copyrightId)
        validCopyright(copyrightId)
    {
        require(newOwner != address(0), "Invalid new owner address");
        require(newOwner != msg.sender, "Cannot transfer to self");

        address oldOwner = copyrights[copyrightId].owner;
        copyrights[copyrightId].owner = newOwner;

        _removeCopyrightFromOwner(oldOwner, copyrightId);
        ownerCopyrights[newOwner].push(copyrightId);

        emit CopyrightTransferred(copyrightId, oldOwner, newOwner);
    }

    function grantLicense(uint256 copyrightId, address licensee, uint256 duration) external payable
        onlyCopyrightOwner(copyrightId)
        validCopyright(copyrightId)
        returns (uint256)
    {
        require(licensee != address(0), "Invalid licensee address");
        require(duration > 0, "Duration must be greater than 0");

        uint256 licenseId = nextLicenseId++;

        licenses[licenseId] = License({
            licensee: licensee,
            copyrightId: copyrightId,
            expirationTime: block.timestamp + duration,
            fee: msg.value,
            isActive: true
        });

        licenseeCopyrights[licensee].push(licenseId);

        emit LicenseGranted(licenseId, copyrightId, licensee);
        return licenseId;
    }

    function revokeLicense(uint256 licenseId) external {
        License storage license = licenses[licenseId];
        require(license.isActive, "License does not exist or is inactive");

        uint256 copyrightId = license.copyrightId;
        require(copyrights[copyrightId].owner == msg.sender, "Only copyright owner can revoke license");

        license.isActive = false;

        emit LicenseRevoked(licenseId);
    }

    function deactivateCopyright(uint256 copyrightId) external onlyAdmin {
        require(copyrights[copyrightId].isActive, "Copyright already inactive");
        copyrights[copyrightId].isActive = false;
    }

    function withdrawFees() external onlyAdmin {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");

        payable(admin).transfer(balance);
    }

    function getCopyrightInfo(uint256 copyrightId) external view returns (
        address owner,
        string memory title,
        string memory description,
        uint256 registrationTime
    ) {
        Copyright storage copyright = copyrights[copyrightId];
        require(copyright.isActive, "Copyright does not exist or is inactive");

        return (
            copyright.owner,
            copyright.title,
            copyright.description,
            copyright.registrationTime
        );
    }

    function getLicenseInfo(uint256 licenseId) external view returns (
        address licensee,
        uint256 copyrightId,
        uint256 expirationTime,
        bool isValid
    ) {
        License storage license = licenses[licenseId];
        require(license.isActive, "License does not exist or is inactive");

        bool isValid = block.timestamp < license.expirationTime;

        return (
            license.licensee,
            license.copyrightId,
            license.expirationTime,
            isValid
        );
    }

    function getOwnerCopyrights(address owner) external view returns (uint256[] memory) {
        return ownerCopyrights[owner];
    }

    function getLicenseeCopyrights(address licensee) external view returns (uint256[] memory) {
        return licenseeCopyrights[licensee];
    }

    function _removeCopyrightFromOwner(address owner, uint256 copyrightId) private {
        uint256[] storage ownedCopyrights = ownerCopyrights[owner];

        for (uint256 i = 0; i < ownedCopyrights.length; i++) {
            if (ownedCopyrights[i] == copyrightId) {
                ownedCopyrights[i] = ownedCopyrights[ownedCopyrights.length - 1];
                ownedCopyrights.pop();
                break;
            }
        }
    }
}
