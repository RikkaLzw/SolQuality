
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
    mapping(address => bytes32[]) public licenseeWorks;
    mapping(bytes32 => bytes32[]) public workLicenses;

    uint256 public registrationFee;
    address public admin;
    uint64 public defaultCopyrightDuration;

    event CopyrightRegistered(bytes32 indexed workId, address indexed owner, bytes32 title);
    event LicenseGranted(bytes32 indexed licenseId, bytes32 indexed workId, address indexed licensee);
    event CopyrightTransferred(bytes32 indexed workId, address indexed from, address indexed to);
    event LicenseRevoked(bytes32 indexed licenseId, bytes32 indexed workId);

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

    constructor(uint256 _registrationFee, uint64 _defaultDuration) {
        admin = msg.sender;
        registrationFee = _registrationFee;
        defaultCopyrightDuration = _defaultDuration;
    }

    function registerCopyright(
        bytes32 _workId,
        bytes32 _title,
        bytes32 _description,
        bytes32 _ipfsHash
    ) external payable {
        require(msg.value >= registrationFee, "Insufficient registration fee");
        require(!copyrights[_workId].isActive, "Copyright already exists");
        require(_workId != bytes32(0), "Invalid work ID");

        uint64 currentTime = uint64(block.timestamp);

        copyrights[_workId] = Copyright({
            workId: _workId,
            owner: msg.sender,
            title: _title,
            description: _description,
            registrationTime: currentTime,
            expirationTime: currentTime + defaultCopyrightDuration,
            isActive: true,
            ipfsHash: _ipfsHash
        });

        ownerWorks[msg.sender].push(_workId);

        emit CopyrightRegistered(_workId, msg.sender, _title);
    }

    function grantLicense(
        bytes32 _licenseId,
        bytes32 _workId,
        address _licensee,
        uint64 _duration,
        uint256 _fee,
        uint8 _licenseType
    ) external onlyOwner(_workId) validWork(_workId) {
        require(_licensee != address(0), "Invalid licensee address");
        require(_licenseType >= 1 && _licenseType <= 4, "Invalid license type");
        require(!licenses[_licenseId].isActive, "License already exists");
        require(block.timestamp < copyrights[_workId].expirationTime, "Copyright has expired");

        uint64 currentTime = uint64(block.timestamp);

        licenses[_licenseId] = License({
            licenseId: _licenseId,
            workId: _workId,
            licensee: _licensee,
            startTime: currentTime,
            endTime: currentTime + _duration,
            fee: _fee,
            isActive: true,
            licenseType: _licenseType
        });

        licenseeWorks[_licensee].push(_licenseId);
        workLicenses[_workId].push(_licenseId);

        emit LicenseGranted(_licenseId, _workId, _licensee);
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
        require(license.isActive, "License does not exist or is inactive");

        bytes32 workId = license.workId;
        require(
            msg.sender == copyrights[workId].owner || msg.sender == license.licensee,
            "Only copyright owner or licensee can revoke license"
        );

        license.isActive = false;

        emit LicenseRevoked(_licenseId, workId);
    }

    function renewCopyright(bytes32 _workId, uint64 _additionalDuration) external payable onlyOwner(_workId) validWork(_workId) {
        require(msg.value >= registrationFee, "Insufficient renewal fee");
        require(_additionalDuration > 0, "Invalid duration");

        copyrights[_workId].expirationTime += _additionalDuration;
    }

    function getCopyrightInfo(bytes32 _workId) external view returns (
        address owner,
        bytes32 title,
        bytes32 description,
        uint64 registrationTime,
        uint64 expirationTime,
        bool isActive,
        bytes32 ipfsHash
    ) {
        Copyright storage copyright = copyrights[_workId];
        return (
            copyright.owner,
            copyright.title,
            copyright.description,
            copyright.registrationTime,
            copyright.expirationTime,
            copyright.isActive,
            copyright.ipfsHash
        );
    }

    function getLicenseInfo(bytes32 _licenseId) external view returns (
        bytes32 workId,
        address licensee,
        uint64 startTime,
        uint64 endTime,
        uint256 fee,
        bool isActive,
        uint8 licenseType
    ) {
        License storage license = licenses[_licenseId];
        return (
            license.workId,
            license.licensee,
            license.startTime,
            license.endTime,
            license.fee,
            license.isActive,
            license.licenseType
        );
    }

    function getOwnerWorks(address _owner) external view returns (bytes32[] memory) {
        return ownerWorks[_owner];
    }

    function getLicenseeWorks(address _licensee) external view returns (bytes32[] memory) {
        return licenseeWorks[_licensee];
    }

    function getWorkLicenses(bytes32 _workId) external view returns (bytes32[] memory) {
        return workLicenses[_workId];
    }

    function isLicenseValid(bytes32 _licenseId) external view returns (bool) {
        License storage license = licenses[_licenseId];
        return license.isActive && block.timestamp >= license.startTime && block.timestamp <= license.endTime;
    }

    function isCopyrightValid(bytes32 _workId) external view returns (bool) {
        Copyright storage copyright = copyrights[_workId];
        return copyright.isActive && block.timestamp <= copyright.expirationTime;
    }

    function setRegistrationFee(uint256 _newFee) external onlyAdmin {
        registrationFee = _newFee;
    }

    function setDefaultCopyrightDuration(uint64 _newDuration) external onlyAdmin {
        defaultCopyrightDuration = _newDuration;
    }

    function withdrawFees() external onlyAdmin {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");

        (bool success, ) = admin.call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    function transferAdmin(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0), "Invalid admin address");
        admin = _newAdmin;
    }
}
