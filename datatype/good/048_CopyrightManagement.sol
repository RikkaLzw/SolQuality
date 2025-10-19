
pragma solidity ^0.8.19;

contract CopyrightManagement {
    struct Copyright {
        bytes32 workId;
        address owner;
        bytes32 title;
        bytes32 description;
        uint64 creationTime;
        uint64 registrationTime;
        bytes32 ipfsHash;
        bool isActive;
    }

    struct License {
        bytes32 licenseId;
        bytes32 workId;
        address licensee;
        uint64 startTime;
        uint64 endTime;
        uint256 fee;
        bool isExclusive;
        bool isActive;
    }

    mapping(bytes32 => Copyright) public copyrights;
    mapping(bytes32 => License) public licenses;
    mapping(address => bytes32[]) public ownerWorks;
    mapping(address => bytes32[]) public licensesByLicensee;
    mapping(bytes32 => bytes32[]) public workLicenses;

    uint256 public registrationFee = 0.01 ether;
    address public admin;
    uint256 public totalWorks;
    uint256 public totalLicenses;

    event CopyrightRegistered(bytes32 indexed workId, address indexed owner, bytes32 title);
    event LicenseGranted(bytes32 indexed licenseId, bytes32 indexed workId, address indexed licensee);
    event LicenseRevoked(bytes32 indexed licenseId);
    event OwnershipTransferred(bytes32 indexed workId, address indexed oldOwner, address indexed newOwner);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyOwner(bytes32 _workId) {
        require(copyrights[_workId].owner == msg.sender, "Only copyright owner can perform this action");
        _;
    }

    modifier workExists(bytes32 _workId) {
        require(copyrights[_workId].isActive, "Copyright does not exist or is inactive");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function registerCopyright(
        bytes32 _workId,
        bytes32 _title,
        bytes32 _description,
        uint64 _creationTime,
        bytes32 _ipfsHash
    ) external payable {
        require(msg.value >= registrationFee, "Insufficient registration fee");
        require(!copyrights[_workId].isActive, "Work already registered");
        require(_workId != bytes32(0), "Invalid work ID");
        require(_title != bytes32(0), "Title cannot be empty");

        copyrights[_workId] = Copyright({
            workId: _workId,
            owner: msg.sender,
            title: _title,
            description: _description,
            creationTime: _creationTime,
            registrationTime: uint64(block.timestamp),
            ipfsHash: _ipfsHash,
            isActive: true
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
        bool _isExclusive
    ) external onlyOwner(_workId) workExists(_workId) {
        require(_licensee != address(0), "Invalid licensee address");
        require(_endTime > _startTime, "Invalid time range");
        require(!licenses[_licenseId].isActive, "License ID already exists");
        require(_licenseId != bytes32(0), "Invalid license ID");

        licenses[_licenseId] = License({
            licenseId: _licenseId,
            workId: _workId,
            licensee: _licensee,
            startTime: _startTime,
            endTime: _endTime,
            fee: _fee,
            isExclusive: _isExclusive,
            isActive: true
        });

        licensesByLicensee[_licensee].push(_licenseId);
        workLicenses[_workId].push(_licenseId);
        totalLicenses++;

        emit LicenseGranted(_licenseId, _workId, _licensee);
    }

    function revokeLicense(bytes32 _licenseId) external {
        License storage license = licenses[_licenseId];
        require(license.isActive, "License does not exist or already revoked");

        Copyright storage copyright = copyrights[license.workId];
        require(
            msg.sender == copyright.owner || msg.sender == admin,
            "Only copyright owner or admin can revoke license"
        );

        license.isActive = false;
        emit LicenseRevoked(_licenseId);
    }

    function transferOwnership(bytes32 _workId, address _newOwner) external onlyOwner(_workId) workExists(_workId) {
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

        emit OwnershipTransferred(_workId, oldOwner, _newOwner);
    }

    function isLicenseValid(bytes32 _licenseId) external view returns (bool) {
        License storage license = licenses[_licenseId];
        return license.isActive &&
               uint64(block.timestamp) >= license.startTime &&
               uint64(block.timestamp) <= license.endTime;
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

        (bool success, ) = payable(admin).call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    function changeAdmin(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0), "Invalid admin address");
        admin = _newAdmin;
    }
}
