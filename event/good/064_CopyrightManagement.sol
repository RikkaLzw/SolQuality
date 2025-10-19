
pragma solidity ^0.8.0;

contract CopyrightManagement {
    struct Copyright {
        address owner;
        string title;
        string description;
        string contentHash;
        uint256 registrationTime;
        bool isActive;
    }

    struct License {
        uint256 copyrightId;
        address licensee;
        uint256 startTime;
        uint256 endTime;
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
    uint256 public registrationFee;

    event CopyrightRegistered(
        uint256 indexed copyrightId,
        address indexed owner,
        string indexed title,
        string contentHash,
        uint256 registrationTime
    );

    event CopyrightTransferred(
        uint256 indexed copyrightId,
        address indexed previousOwner,
        address indexed newOwner,
        uint256 transferTime
    );

    event LicenseGranted(
        uint256 indexed licenseId,
        uint256 indexed copyrightId,
        address indexed licensee,
        uint256 startTime,
        uint256 endTime,
        uint256 fee
    );

    event LicenseRevoked(
        uint256 indexed licenseId,
        uint256 indexed copyrightId,
        address indexed licensee,
        uint256 revokeTime
    );

    event CopyrightDeactivated(
        uint256 indexed copyrightId,
        address indexed owner,
        uint256 deactivationTime
    );

    event RegistrationFeeUpdated(
        uint256 previousFee,
        uint256 newFee,
        uint256 updateTime
    );

    modifier onlyAdmin() {
        require(msg.sender == admin, "CopyrightManagement: Only admin can perform this action");
        _;
    }

    modifier onlyCopyrightOwner(uint256 copyrightId) {
        require(copyrights[copyrightId].owner == msg.sender, "CopyrightManagement: Only copyright owner can perform this action");
        _;
    }

    modifier copyrightExists(uint256 copyrightId) {
        require(copyrights[copyrightId].owner != address(0), "CopyrightManagement: Copyright does not exist");
        _;
    }

    modifier copyrightActive(uint256 copyrightId) {
        require(copyrights[copyrightId].isActive, "CopyrightManagement: Copyright is not active");
        _;
    }

    modifier licenseExists(uint256 licenseId) {
        require(licenses[licenseId].licensee != address(0), "CopyrightManagement: License does not exist");
        _;
    }

    constructor(uint256 _registrationFee) {
        admin = msg.sender;
        registrationFee = _registrationFee;
    }

    function registerCopyright(
        string memory title,
        string memory description,
        string memory contentHash
    ) external payable returns (uint256) {
        require(bytes(title).length > 0, "CopyrightManagement: Title cannot be empty");
        require(bytes(contentHash).length > 0, "CopyrightManagement: Content hash cannot be empty");
        require(msg.value >= registrationFee, "CopyrightManagement: Insufficient registration fee");

        if (contentHashToCopyrightId[contentHash] != 0) {
            revert("CopyrightManagement: Content with this hash already registered");
        }

        uint256 copyrightId = nextCopyrightId++;

        copyrights[copyrightId] = Copyright({
            owner: msg.sender,
            title: title,
            description: description,
            contentHash: contentHash,
            registrationTime: block.timestamp,
            isActive: true
        });

        ownerCopyrights[msg.sender].push(copyrightId);
        contentHashToCopyrightId[contentHash] = copyrightId;

        if (msg.value > registrationFee) {
            payable(msg.sender).transfer(msg.value - registrationFee);
        }

        emit CopyrightRegistered(copyrightId, msg.sender, title, contentHash, block.timestamp);

        return copyrightId;
    }

    function transferCopyright(uint256 copyrightId, address newOwner)
        external
        copyrightExists(copyrightId)
        onlyCopyrightOwner(copyrightId)
        copyrightActive(copyrightId)
    {
        require(newOwner != address(0), "CopyrightManagement: New owner cannot be zero address");
        require(newOwner != copyrights[copyrightId].owner, "CopyrightManagement: New owner must be different from current owner");

        address previousOwner = copyrights[copyrightId].owner;
        copyrights[copyrightId].owner = newOwner;

        ownerCopyrights[newOwner].push(copyrightId);

        emit CopyrightTransferred(copyrightId, previousOwner, newOwner, block.timestamp);
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
        require(licensee != address(0), "CopyrightManagement: Licensee cannot be zero address");
        require(licensee != copyrights[copyrightId].owner, "CopyrightManagement: Cannot license to copyright owner");
        require(duration > 0, "CopyrightManagement: License duration must be greater than zero");

        uint256 licenseId = nextLicenseId++;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + duration;

        licenses[licenseId] = License({
            copyrightId: copyrightId,
            licensee: licensee,
            startTime: startTime,
            endTime: endTime,
            fee: fee,
            isActive: true
        });

        licenseeLicenses[licensee].push(licenseId);

        emit LicenseGranted(licenseId, copyrightId, licensee, startTime, endTime, fee);

        return licenseId;
    }

    function revokeLicense(uint256 licenseId)
        external
        licenseExists(licenseId)
    {
        License storage license = licenses[licenseId];
        require(license.isActive, "CopyrightManagement: License is already revoked");

        uint256 copyrightId = license.copyrightId;
        require(copyrights[copyrightId].owner == msg.sender, "CopyrightManagement: Only copyright owner can revoke license");

        license.isActive = false;

        emit LicenseRevoked(licenseId, copyrightId, license.licensee, block.timestamp);
    }

    function deactivateCopyright(uint256 copyrightId)
        external
        copyrightExists(copyrightId)
        onlyCopyrightOwner(copyrightId)
    {
        require(copyrights[copyrightId].isActive, "CopyrightManagement: Copyright is already deactivated");

        copyrights[copyrightId].isActive = false;

        emit CopyrightDeactivated(copyrightId, msg.sender, block.timestamp);
    }

    function isLicenseValid(uint256 licenseId) external view returns (bool) {
        if (licenses[licenseId].licensee == address(0)) {
            return false;
        }

        License memory license = licenses[licenseId];
        return license.isActive &&
               block.timestamp >= license.startTime &&
               block.timestamp <= license.endTime &&
               copyrights[license.copyrightId].isActive;
    }

    function getCopyrightsByOwner(address owner) external view returns (uint256[] memory) {
        return ownerCopyrights[owner];
    }

    function getLicensesByLicensee(address licensee) external view returns (uint256[] memory) {
        return licenseeLicenses[licensee];
    }

    function updateRegistrationFee(uint256 newFee) external onlyAdmin {
        uint256 previousFee = registrationFee;
        registrationFee = newFee;

        emit RegistrationFeeUpdated(previousFee, newFee, block.timestamp);
    }

    function withdrawFees() external onlyAdmin {
        uint256 balance = address(this).balance;
        require(balance > 0, "CopyrightManagement: No fees to withdraw");

        payable(admin).transfer(balance);
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "CopyrightManagement: New admin cannot be zero address");
        admin = newAdmin;
    }
}
