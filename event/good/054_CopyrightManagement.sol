
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
    mapping(address => uint256[]) public licenseeCopyrights;
    mapping(string => bool) public contentHashExists;

    uint256 public nextCopyrightId = 1;
    uint256 public nextLicenseId = 1;
    address public admin;

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

    event LicenseFeeWithdrawn(
        uint256 indexed licenseId,
        address indexed owner,
        uint256 amount
    );

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyCopyrightOwner(uint256 _copyrightId) {
        require(_copyrightId > 0 && _copyrightId < nextCopyrightId, "Invalid copyright ID");
        require(copyrights[_copyrightId].owner == msg.sender, "Only copyright owner can perform this action");
        _;
    }

    modifier copyrightExists(uint256 _copyrightId) {
        require(_copyrightId > 0 && _copyrightId < nextCopyrightId, "Copyright does not exist");
        require(copyrights[_copyrightId].isActive, "Copyright is not active");
        _;
    }

    modifier licenseExists(uint256 _licenseId) {
        require(_licenseId > 0 && _licenseId < nextLicenseId, "License does not exist");
        require(licenses[_licenseId].isActive, "License is not active");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function registerCopyright(
        string memory _title,
        string memory _description,
        string memory _contentHash
    ) external returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(bytes(_contentHash).length > 0, "Content hash cannot be empty");

        if (contentHashExists[_contentHash]) {
            revert("Content with this hash already registered");
        }

        uint256 copyrightId = nextCopyrightId++;

        copyrights[copyrightId] = Copyright({
            owner: msg.sender,
            title: _title,
            description: _description,
            contentHash: _contentHash,
            registrationDate: block.timestamp,
            isActive: true
        });

        ownerCopyrights[msg.sender].push(copyrightId);
        contentHashExists[_contentHash] = true;

        emit CopyrightRegistered(
            copyrightId,
            msg.sender,
            _title,
            _contentHash,
            block.timestamp
        );

        return copyrightId;
    }

    function transferCopyright(
        uint256 _copyrightId,
        address _newOwner
    ) external onlyCopyrightOwner(_copyrightId) {
        require(_newOwner != address(0), "New owner cannot be zero address");
        require(_newOwner != msg.sender, "Cannot transfer to yourself");

        address previousOwner = copyrights[_copyrightId].owner;
        copyrights[_copyrightId].owner = _newOwner;


        uint256[] storage prevOwnerCopyrights = ownerCopyrights[previousOwner];
        for (uint256 i = 0; i < prevOwnerCopyrights.length; i++) {
            if (prevOwnerCopyrights[i] == _copyrightId) {
                prevOwnerCopyrights[i] = prevOwnerCopyrights[prevOwnerCopyrights.length - 1];
                prevOwnerCopyrights.pop();
                break;
            }
        }


        ownerCopyrights[_newOwner].push(_copyrightId);

        emit CopyrightTransferred(_copyrightId, previousOwner, _newOwner);
    }

    function grantLicense(
        uint256 _copyrightId,
        address _licensee,
        uint256 _duration
    ) external payable copyrightExists(_copyrightId) onlyCopyrightOwner(_copyrightId) {
        require(_licensee != address(0), "Licensee cannot be zero address");
        require(_licensee != msg.sender, "Cannot grant license to yourself");
        require(_duration > 0, "License duration must be greater than zero");
        require(msg.value > 0, "License fee must be greater than zero");

        uint256 licenseId = nextLicenseId++;
        uint256 startDate = block.timestamp;
        uint256 endDate = startDate + _duration;

        licenses[licenseId] = License({
            copyrightId: _copyrightId,
            licensee: _licensee,
            startDate: startDate,
            endDate: endDate,
            fee: msg.value,
            isActive: true
        });

        licenseeCopyrights[_licensee].push(licenseId);

        emit LicenseGranted(
            licenseId,
            _copyrightId,
            _licensee,
            startDate,
            endDate,
            msg.value
        );
    }

    function revokeLicense(
        uint256 _licenseId
    ) external licenseExists(_licenseId) {
        License storage license = licenses[_licenseId];
        uint256 copyrightId = license.copyrightId;

        require(
            copyrights[copyrightId].owner == msg.sender,
            "Only copyright owner can revoke license"
        );

        license.isActive = false;


        address licensee = license.licensee;
        uint256[] storage licenseeCopyrightsList = licenseeCopyrights[licensee];
        for (uint256 i = 0; i < licenseeCopyrightsList.length; i++) {
            if (licenseeCopyrightsList[i] == _licenseId) {
                licenseeCopyrightsList[i] = licenseeCopyrightsList[licenseeCopyrightsList.length - 1];
                licenseeCopyrightsList.pop();
                break;
            }
        }

        emit LicenseRevoked(_licenseId, copyrightId, licensee);
    }

    function deactivateCopyright(
        uint256 _copyrightId
    ) external onlyCopyrightOwner(_copyrightId) {
        copyrights[_copyrightId].isActive = false;
        contentHashExists[copyrights[_copyrightId].contentHash] = false;

        emit CopyrightDeactivated(_copyrightId, msg.sender);
    }

    function withdrawLicenseFee(
        uint256 _licenseId
    ) external licenseExists(_licenseId) {
        License storage license = licenses[_licenseId];
        uint256 copyrightId = license.copyrightId;

        require(
            copyrights[copyrightId].owner == msg.sender,
            "Only copyright owner can withdraw license fee"
        );
        require(license.fee > 0, "No fee to withdraw");

        uint256 fee = license.fee;
        license.fee = 0;

        (bool success, ) = payable(msg.sender).call{value: fee}("");
        if (!success) {
            revert("Fee withdrawal failed");
        }

        emit LicenseFeeWithdrawn(_licenseId, msg.sender, fee);
    }

    function isLicenseValid(
        uint256 _licenseId
    ) external view returns (bool) {
        if (_licenseId == 0 || _licenseId >= nextLicenseId) {
            return false;
        }

        License storage license = licenses[_licenseId];
        return license.isActive &&
               block.timestamp >= license.startDate &&
               block.timestamp <= license.endDate;
    }

    function getCopyrightsByOwner(
        address _owner
    ) external view returns (uint256[] memory) {
        return ownerCopyrights[_owner];
    }

    function getLicensesByLicensee(
        address _licensee
    ) external view returns (uint256[] memory) {
        return licenseeCopyrights[_licensee];
    }

    function getCopyrightDetails(
        uint256 _copyrightId
    ) external view returns (
        address owner,
        string memory title,
        string memory description,
        string memory contentHash,
        uint256 registrationDate,
        bool isActive
    ) {
        require(_copyrightId > 0 && _copyrightId < nextCopyrightId, "Invalid copyright ID");

        Copyright storage copyright = copyrights[_copyrightId];
        return (
            copyright.owner,
            copyright.title,
            copyright.description,
            copyright.contentHash,
            copyright.registrationDate,
            copyright.isActive
        );
    }

    function getLicenseDetails(
        uint256 _licenseId
    ) external view returns (
        uint256 copyrightId,
        address licensee,
        uint256 startDate,
        uint256 endDate,
        uint256 fee,
        bool isActive
    ) {
        require(_licenseId > 0 && _licenseId < nextLicenseId, "Invalid license ID");

        License storage license = licenses[_licenseId];
        return (
            license.copyrightId,
            license.licensee,
            license.startDate,
            license.endDate,
            license.fee,
            license.isActive
        );
    }
}
