
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
    mapping(address => uint256[]) public licenseeCopyrights;
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
        address indexed admin
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
        require(newOwner != address(0), "New owner cannot be zero address");
        require(newOwner != msg.sender, "Cannot transfer to yourself");

        address previousOwner = copyrights[copyrightId].owner;
        copyrights[copyrightId].owner = newOwner;


        uint256[] storage prevOwnerCopyrights = ownerCopyrights[previousOwner];
        for (uint256 i = 0; i < prevOwnerCopyrights.length; i++) {
            if (prevOwnerCopyrights[i] == copyrightId) {
                prevOwnerCopyrights[i] = prevOwnerCopyrights[prevOwnerCopyrights.length - 1];
                prevOwnerCopyrights.pop();
                break;
            }
        }


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
        require(licensee != address(0), "Licensee cannot be zero address");
        require(licensee != msg.sender, "Cannot grant license to yourself");
        require(duration > 0, "License duration must be greater than zero");

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

        licenseeCopyrights[licensee].push(licenseId);

        emit LicenseGranted(licenseId, copyrightId, licensee, startTime, endTime, fee);

        return licenseId;
    }

    function revokeLicense(uint256 licenseId)
        external
        copyrightExists(licenses[licenseId].copyrightId)
        onlyCopyrightOwner(licenses[licenseId].copyrightId)
    {
        require(licenses[licenseId].licensee != address(0), "License does not exist");
        require(licenses[licenseId].isActive, "License is already revoked");

        licenses[licenseId].isActive = false;

        emit LicenseRevoked(
            licenseId,
            licenses[licenseId].copyrightId,
            licenses[licenseId].licensee,
            block.timestamp
        );
    }

    function deactivateCopyright(uint256 copyrightId)
        external
        copyrightExists(copyrightId)
        onlyCopyrightOwner(copyrightId)
        copyrightActive(copyrightId)
    {
        copyrights[copyrightId].isActive = false;

        emit CopyrightDeactivated(copyrightId, msg.sender, block.timestamp);
    }

    function isLicenseValid(uint256 licenseId) external view returns (bool) {
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
        return licenseeCopyrights[licensee];
    }

    function updateRegistrationFee(uint256 newFee) external onlyAdmin {
        require(newFee > 0, "Registration fee must be greater than zero");

        uint256 previousFee = registrationFee;
        registrationFee = newFee;

        emit RegistrationFeeUpdated(previousFee, newFee, msg.sender);
    }

    function withdrawFees() external onlyAdmin {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");

        payable(admin).transfer(balance);
    }

    function transferAdminRole(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "New admin cannot be zero address");
        require(newAdmin != admin, "New admin is the same as current admin");

        admin = newAdmin;
    }
}
