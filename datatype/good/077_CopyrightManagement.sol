
pragma solidity ^0.8.0;

contract CopyrightManagement {
    struct Copyright {
        bytes32 workId;
        address owner;
        bytes32 title;
        bytes32 description;
        uint64 creationTimestamp;
        uint64 registrationTimestamp;
        bytes32 ipfsHash;
        bool isActive;
        uint16 licenseType;
    }

    struct License {
        bytes32 licenseId;
        bytes32 workId;
        address licensee;
        uint64 startTime;
        uint64 endTime;
        uint256 fee;
        bool isActive;
        uint8 licenseScope;
    }

    mapping(bytes32 => Copyright) public copyrights;
    mapping(bytes32 => License) public licenses;
    mapping(address => bytes32[]) public ownerWorks;
    mapping(address => bytes32[]) public licenseeLicenses;

    uint256 public totalWorks;
    uint256 public totalLicenses;
    address public admin;
    uint256 public registrationFee;

    event CopyrightRegistered(bytes32 indexed workId, address indexed owner, bytes32 title);
    event LicenseGranted(bytes32 indexed licenseId, bytes32 indexed workId, address indexed licensee);
    event LicenseRevoked(bytes32 indexed licenseId);
    event CopyrightTransferred(bytes32 indexed workId, address indexed from, address indexed to);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyOwner(bytes32 _workId) {
        require(copyrights[_workId].owner == msg.sender, "Only copyright owner can perform this action");
        _;
    }

    modifier workExists(bytes32 _workId) {
        require(copyrights[_workId].isActive, "Copyright work does not exist");
        _;
    }

    constructor(uint256 _registrationFee) {
        admin = msg.sender;
        registrationFee = _registrationFee;
    }

    function registerCopyright(
        bytes32 _workId,
        bytes32 _title,
        bytes32 _description,
        uint64 _creationTimestamp,
        bytes32 _ipfsHash,
        uint16 _licenseType
    ) external payable {
        require(msg.value >= registrationFee, "Insufficient registration fee");
        require(!copyrights[_workId].isActive, "Work ID already exists");
        require(_workId != bytes32(0), "Invalid work ID");

        copyrights[_workId] = Copyright({
            workId: _workId,
            owner: msg.sender,
            title: _title,
            description: _description,
            creationTimestamp: _creationTimestamp,
            registrationTimestamp: uint64(block.timestamp),
            ipfsHash: _ipfsHash,
            isActive: true,
            licenseType: _licenseType
        });

        ownerWorks[msg.sender].push(_workId);
        totalWorks++;

        emit CopyrightRegistered(_workId, msg.sender, _title);
    }

    function grantLicense(
        bytes32 _licenseId,
        bytes32 _workId,
        address _licensee,
        uint64 _startTime,
        uint64 _endTime,
        uint256 _fee,
        uint8 _licenseScope
    ) external onlyOwner(_workId) workExists(_workId) {
        require(!licenses[_licenseId].isActive, "License ID already exists");
        require(_licensee != address(0), "Invalid licensee address");
        require(_endTime > _startTime, "Invalid license duration");
        require(_licenseId != bytes32(0), "Invalid license ID");

        licenses[_licenseId] = License({
            licenseId: _licenseId,
            workId: _workId,
            licensee: _licensee,
            startTime: _startTime,
            endTime: _endTime,
            fee: _fee,
            isActive: true,
            licenseScope: _licenseScope
        });

        licenseeLicenses[_licensee].push(_licenseId);
        totalLicenses++;

        emit LicenseGranted(_licenseId, _workId, _licensee);
    }

    function revokeLicense(bytes32 _licenseId) external {
        License storage license = licenses[_licenseId];
        require(license.isActive, "License does not exist or already revoked");

        bytes32 workId = license.workId;
        require(
            copyrights[workId].owner == msg.sender || msg.sender == admin,
            "Only copyright owner or admin can revoke license"
        );

        license.isActive = false;

        emit LicenseRevoked(_licenseId);
    }

    function transferCopyright(bytes32 _workId, address _newOwner) external onlyOwner(_workId) workExists(_workId) {
        require(_newOwner != address(0), "Invalid new owner address");
        require(_newOwner != msg.sender, "Cannot transfer to yourself");

        address oldOwner = copyrights[_workId].owner;
        copyrights[_workId].owner = _newOwner;


        bytes32[] storage oldOwnerWorks = ownerWorks[oldOwner];
        for (uint256 i = 0; i < oldOwnerWorks.length; i++) {
            if (oldOwnerWorks[i] == _workId) {
                oldOwnerWorks[i] = oldOwnerWorks[oldOwnerWorks.length - 1];
                oldOwnerWorks.pop();
                break;
            }
        }


        ownerWorks[_newOwner].push(_workId);

        emit CopyrightTransferred(_workId, oldOwner, _newOwner);
    }

    function updateRegistrationFee(uint256 _newFee) external onlyAdmin {
        registrationFee = _newFee;
    }

    function withdrawFees() external onlyAdmin {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");

        (bool success, ) = payable(admin).call{value: balance}("");
        require(success, "Fee withdrawal failed");
    }

    function getCopyrightInfo(bytes32 _workId) external view returns (
        address owner,
        bytes32 title,
        bytes32 description,
        uint64 creationTimestamp,
        uint64 registrationTimestamp,
        bytes32 ipfsHash,
        bool isActive,
        uint16 licenseType
    ) {
        Copyright storage copyright = copyrights[_workId];
        return (
            copyright.owner,
            copyright.title,
            copyright.description,
            copyright.creationTimestamp,
            copyright.registrationTimestamp,
            copyright.ipfsHash,
            copyright.isActive,
            copyright.licenseType
        );
    }

    function getLicenseInfo(bytes32 _licenseId) external view returns (
        bytes32 workId,
        address licensee,
        uint64 startTime,
        uint64 endTime,
        uint256 fee,
        bool isActive,
        uint8 licenseScope
    ) {
        License storage license = licenses[_licenseId];
        return (
            license.workId,
            license.licensee,
            license.startTime,
            license.endTime,
            license.fee,
            license.isActive,
            license.licenseScope
        );
    }

    function getOwnerWorks(address _owner) external view returns (bytes32[] memory) {
        return ownerWorks[_owner];
    }

    function getLicenseeLicenses(address _licensee) external view returns (bytes32[] memory) {
        return licenseeLicenses[_licensee];
    }

    function isLicenseValid(bytes32 _licenseId) external view returns (bool) {
        License storage license = licenses[_licenseId];
        return license.isActive &&
               block.timestamp >= license.startTime &&
               block.timestamp <= license.endTime;
    }
}
