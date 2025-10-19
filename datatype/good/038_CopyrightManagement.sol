
pragma solidity ^0.8.0;

contract CopyrightManagement {
    struct Copyright {
        bytes32 workId;
        address owner;
        bytes32 title;
        bytes32 description;
        uint64 registrationTime;
        uint64 expirationTime;
        bool isActive;
        bytes32 ipfsHash;
    }

    struct License {
        bytes32 licenseId;
        bytes32 workId;
        address licensee;
        uint64 startTime;
        uint64 endTime;
        uint256 fee;
        bool isActive;
        uint8 licenseType;
    }

    mapping(bytes32 => Copyright) public copyrights;
    mapping(bytes32 => License) public licenses;
    mapping(address => bytes32[]) public ownerWorks;
    mapping(address => bytes32[]) public licensesByLicensee;
    mapping(bytes32 => bytes32[]) public workLicenses;

    uint256 public registrationFee;
    address public admin;
    uint32 public totalWorks;
    uint32 public totalLicenses;

    event CopyrightRegistered(bytes32 indexed workId, address indexed owner, bytes32 title);
    event LicenseGranted(bytes32 indexed licenseId, bytes32 indexed workId, address indexed licensee);
    event CopyrightTransferred(bytes32 indexed workId, address indexed from, address indexed to);
    event LicenseRevoked(bytes32 indexed licenseId);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyOwner(bytes32 _workId) {
        require(copyrights[_workId].owner == msg.sender, "Only copyright owner can perform this action");
        _;
    }

    modifier validWork(bytes32 _workId) {
        require(copyrights[_workId].isActive, "Copyright does not exist or is inactive");
        _;
    }

    constructor(uint256 _registrationFee) {
        admin = msg.sender;
        registrationFee = _registrationFee;
    }

    function registerCopyright(
        bytes32 _title,
        bytes32 _description,
        uint64 _expirationTime,
        bytes32 _ipfsHash
    ) external payable returns (bytes32) {
        require(msg.value >= registrationFee, "Insufficient registration fee");
        require(_expirationTime > block.timestamp, "Expiration time must be in the future");

        bytes32 workId = keccak256(abi.encodePacked(msg.sender, _title, block.timestamp, totalWorks));

        copyrights[workId] = Copyright({
            workId: workId,
            owner: msg.sender,
            title: _title,
            description: _description,
            registrationTime: uint64(block.timestamp),
            expirationTime: _expirationTime,
            isActive: true,
            ipfsHash: _ipfsHash
        });

        ownerWorks[msg.sender].push(workId);
        totalWorks++;

        emit CopyrightRegistered(workId, msg.sender, _title);
        return workId;
    }

    function grantLicense(
        bytes32 _workId,
        address _licensee,
        uint64 _startTime,
        uint64 _endTime,
        uint256 _fee,
        uint8 _licenseType
    ) external onlyOwner(_workId) validWork(_workId) returns (bytes32) {
        require(_licensee != address(0), "Invalid licensee address");
        require(_startTime >= block.timestamp, "Start time must be in the future");
        require(_endTime > _startTime, "End time must be after start time");
        require(_endTime <= copyrights[_workId].expirationTime, "License cannot exceed copyright expiration");
        require(_licenseType <= 3, "Invalid license type");

        bytes32 licenseId = keccak256(abi.encodePacked(_workId, _licensee, block.timestamp, totalLicenses));

        licenses[licenseId] = License({
            licenseId: licenseId,
            workId: _workId,
            licensee: _licensee,
            startTime: _startTime,
            endTime: _endTime,
            fee: _fee,
            isActive: true,
            licenseType: _licenseType
        });

        licensesByLicensee[_licensee].push(licenseId);
        workLicenses[_workId].push(licenseId);
        totalLicenses++;

        emit LicenseGranted(licenseId, _workId, _licensee);
        return licenseId;
    }

    function transferCopyright(bytes32 _workId, address _newOwner) external onlyOwner(_workId) validWork(_workId) {
        require(_newOwner != address(0), "Invalid new owner address");
        require(_newOwner != copyrights[_workId].owner, "Cannot transfer to current owner");

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

    function revokeLicense(bytes32 _licenseId) external {
        License storage license = licenses[_licenseId];
        require(license.isActive, "License does not exist or already revoked");

        Copyright storage copyright = copyrights[license.workId];
        require(msg.sender == copyright.owner || msg.sender == admin, "Only owner or admin can revoke license");

        license.isActive = false;
        emit LicenseRevoked(_licenseId);
    }

    function isLicenseValid(bytes32 _licenseId) external view returns (bool) {
        License storage license = licenses[_licenseId];
        return license.isActive &&
               block.timestamp >= license.startTime &&
               block.timestamp <= license.endTime &&
               copyrights[license.workId].isActive;
    }

    function getCopyright(bytes32 _workId) external view returns (Copyright memory) {
        return copyrights[_workId];
    }

    function getLicense(bytes32 _licenseId) external view returns (License memory) {
        return licenses[_licenseId];
    }

    function getOwnerWorks(address _owner) external view returns (bytes32[] memory) {
        return ownerWorks[_owner];
    }

    function getLicensesByLicensee(address _licensee) external view returns (bytes32[] memory) {
        return licensesByLicensee[_licensee];
    }

    function getWorkLicenses(bytes32 _workId) external view returns (bytes32[] memory) {
        return workLicenses[_workId];
    }

    function setRegistrationFee(uint256 _newFee) external onlyAdmin {
        registrationFee = _newFee;
    }

    function withdrawFees() external onlyAdmin {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");

        (bool success, ) = admin.call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    function deactivateCopyright(bytes32 _workId) external onlyOwner(_workId) validWork(_workId) {
        copyrights[_workId].isActive = false;


        bytes32[] storage workLicenseIds = workLicenses[_workId];
        for (uint256 i = 0; i < workLicenseIds.length; i++) {
            licenses[workLicenseIds[i]].isActive = false;
        }
    }
}
