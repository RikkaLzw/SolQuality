
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
        require(copyrights[_workId].owner != address(0), "Work does not exist");
        require(copyrights[_workId].isActive, "Copyright is not active");
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
        require(copyrights[_workId].owner == address(0), "Work already registered");
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
        require(_licenseType <= 3, "Invalid license type");
        require(licenses[_licenseId].licensee == address(0), "License ID already exists");
        require(_licenseId != bytes32(0), "Invalid license ID");

        uint64 currentTime = uint64(block.timestamp);
        require(currentTime < copyrights[_workId].expirationTime, "Copyright expired");

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

        workLicenses[_workId].push(_licenseId);
        licenseeWorks[_licensee].push(_licenseId);

        emit LicenseGranted(_licenseId, _workId, _licensee);
    }

    function transferCopyright(bytes32 _workId, address _newOwner) external onlyOwner(_workId) validWork(_workId) {
        require(_newOwner != address(0), "Invalid new owner address");
        require(_newOwner != msg.sender, "Cannot transfer to self");

        address oldOwner = copyrights[_workId].owner;
        copyrights[_workId].owner = _newOwner;


        _removeFromOwnerWorks(oldOwner, _workId);


        ownerWorks[_newOwner].push(_workId);

        emit CopyrightTransferred(_workId, oldOwner, _newOwner);
    }

    function revokeLicense(bytes32 _licenseId) external {
        License storage license = licenses[_licenseId];
        require(license.licensee != address(0), "License does not exist");

        bytes32 workId = license.workId;
        require(
            copyrights[workId].owner == msg.sender || license.licensee == msg.sender,
            "Only copyright owner or licensee can revoke license"
        );

        license.isActive = false;

        emit LicenseRevoked(_licenseId, workId);
    }

    function renewCopyright(bytes32 _workId, uint64 _additionalDuration) external payable onlyOwner(_workId) {
        require(msg.value >= registrationFee, "Insufficient renewal fee");
        require(copyrights[_workId].isActive, "Copyright is not active");

        copyrights[_workId].expirationTime += _additionalDuration;
    }

    function deactivateCopyright(bytes32 _workId) external onlyOwner(_workId) {
        copyrights[_workId].isActive = false;
    }

    function isLicenseValid(bytes32 _licenseId) external view returns (bool) {
        License storage license = licenses[_licenseId];
        if (!license.isActive || license.licensee == address(0)) {
            return false;
        }

        uint64 currentTime = uint64(block.timestamp);
        return currentTime >= license.startTime && currentTime <= license.endTime;
    }

    function isCopyrightValid(bytes32 _workId) external view returns (bool) {
        Copyright storage copyright = copyrights[_workId];
        if (!copyright.isActive || copyright.owner == address(0)) {
            return false;
        }

        uint64 currentTime = uint64(block.timestamp);
        return currentTime <= copyright.expirationTime;
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

    function updateRegistrationFee(uint256 _newFee) external onlyAdmin {
        registrationFee = _newFee;
    }

    function updateDefaultDuration(uint64 _newDuration) external onlyAdmin {
        defaultCopyrightDuration = _newDuration;
    }

    function withdrawFees() external onlyAdmin {
        payable(admin).transfer(address(this).balance);
    }

    function _removeFromOwnerWorks(address _owner, bytes32 _workId) internal {
        bytes32[] storage works = ownerWorks[_owner];
        for (uint256 i = 0; i < works.length; i++) {
            if (works[i] == _workId) {
                works[i] = works[works.length - 1];
                works.pop();
                break;
            }
        }
    }
}
