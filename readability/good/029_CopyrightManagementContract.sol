
pragma solidity ^0.8.0;


contract CopyrightManagementContract {


    struct CopyrightInfo {
        string contentTitle;
        string contentDescription;
        string contentHash;
        address originalCreator;
        address currentOwner;
        uint256 registrationTime;
        uint256 expirationTime;
        bool isActive;
        uint256 licensePrice;
    }


    struct LicenseInfo {
        address licensee;
        uint256 copyrightId;
        uint256 licenseStartTime;
        uint256 licenseEndTime;
        uint256 paidAmount;
        bool isActive;
    }


    mapping(uint256 => CopyrightInfo) public copyrights;
    mapping(address => uint256[]) public ownerToCopyrights;
    mapping(uint256 => LicenseInfo[]) public copyrightToLicenses;
    mapping(address => uint256[]) public licenseeToLicenses;

    uint256 public nextCopyrightId;
    uint256 public copyrightDurationYears;
    address public contractOwner;
    uint256 public registrationFee;


    event CopyrightRegistered(
        uint256 indexed copyrightId,
        address indexed creator,
        string contentTitle,
        uint256 registrationTime
    );

    event CopyrightTransferred(
        uint256 indexed copyrightId,
        address indexed fromOwner,
        address indexed toOwner,
        uint256 transferTime
    );

    event LicenseGranted(
        uint256 indexed copyrightId,
        address indexed licensee,
        uint256 licenseStartTime,
        uint256 licenseEndTime,
        uint256 paidAmount
    );

    event LicenseRevoked(
        uint256 indexed copyrightId,
        address indexed licensee,
        uint256 revokeTime
    );


    modifier onlyContractOwner() {
        require(msg.sender == contractOwner, "Only contract owner can perform this action");
        _;
    }

    modifier onlyCopyrightOwner(uint256 _copyrightId) {
        require(copyrights[_copyrightId].currentOwner == msg.sender, "Only copyright owner can perform this action");
        _;
    }

    modifier copyrightExists(uint256 _copyrightId) {
        require(_copyrightId < nextCopyrightId, "Copyright does not exist");
        _;
    }

    modifier copyrightActive(uint256 _copyrightId) {
        require(copyrights[_copyrightId].isActive, "Copyright is not active");
        require(block.timestamp <= copyrights[_copyrightId].expirationTime, "Copyright has expired");
        _;
    }


    constructor(uint256 _copyrightDurationYears, uint256 _registrationFee) {
        contractOwner = msg.sender;
        copyrightDurationYears = _copyrightDurationYears;
        registrationFee = _registrationFee;
        nextCopyrightId = 1;
    }


    function registerCopyright(
        string memory _contentTitle,
        string memory _contentDescription,
        string memory _contentHash,
        uint256 _licensePrice
    ) public payable returns (uint256) {
        require(msg.value >= registrationFee, "Insufficient registration fee");
        require(bytes(_contentTitle).length > 0, "Content title cannot be empty");
        require(bytes(_contentHash).length > 0, "Content hash cannot be empty");

        uint256 copyrightId = nextCopyrightId;
        uint256 expirationTime = block.timestamp + (copyrightDurationYears * 365 days);

        copyrights[copyrightId] = CopyrightInfo({
            contentTitle: _contentTitle,
            contentDescription: _contentDescription,
            contentHash: _contentHash,
            originalCreator: msg.sender,
            currentOwner: msg.sender,
            registrationTime: block.timestamp,
            expirationTime: expirationTime,
            isActive: true,
            licensePrice: _licensePrice
        });

        ownerToCopyrights[msg.sender].push(copyrightId);
        nextCopyrightId++;

        emit CopyrightRegistered(copyrightId, msg.sender, _contentTitle, block.timestamp);

        return copyrightId;
    }


    function transferCopyright(uint256 _copyrightId, address _newOwner)
        public
        copyrightExists(_copyrightId)
        onlyCopyrightOwner(_copyrightId)
        copyrightActive(_copyrightId)
    {
        require(_newOwner != address(0), "New owner cannot be zero address");
        require(_newOwner != copyrights[_copyrightId].currentOwner, "Cannot transfer to current owner");

        address oldOwner = copyrights[_copyrightId].currentOwner;
        copyrights[_copyrightId].currentOwner = _newOwner;


        _removeCopyrightFromOwner(oldOwner, _copyrightId);


        ownerToCopyrights[_newOwner].push(_copyrightId);

        emit CopyrightTransferred(_copyrightId, oldOwner, _newOwner, block.timestamp);
    }


    function purchaseLicense(uint256 _copyrightId, uint256 _licenseDurationDays)
        public
        payable
        copyrightExists(_copyrightId)
        copyrightActive(_copyrightId)
    {
        require(_licenseDurationDays > 0, "License duration must be greater than 0");
        require(msg.value >= copyrights[_copyrightId].licensePrice, "Insufficient payment for license");
        require(msg.sender != copyrights[_copyrightId].currentOwner, "Owner cannot purchase license for own copyright");

        uint256 licenseStartTime = block.timestamp;
        uint256 licenseEndTime = licenseStartTime + (_licenseDurationDays * 1 days);

        LicenseInfo memory newLicense = LicenseInfo({
            licensee: msg.sender,
            copyrightId: _copyrightId,
            licenseStartTime: licenseStartTime,
            licenseEndTime: licenseEndTime,
            paidAmount: msg.value,
            isActive: true
        });

        copyrightToLicenses[_copyrightId].push(newLicense);
        licenseeToLicenses[msg.sender].push(_copyrightId);


        payable(copyrights[_copyrightId].currentOwner).transfer(msg.value);

        emit LicenseGranted(_copyrightId, msg.sender, licenseStartTime, licenseEndTime, msg.value);
    }


    function revokeLicense(uint256 _copyrightId, address _licensee)
        public
        copyrightExists(_copyrightId)
        onlyCopyrightOwner(_copyrightId)
    {
        LicenseInfo[] storage licenses = copyrightToLicenses[_copyrightId];

        for (uint256 i = 0; i < licenses.length; i++) {
            if (licenses[i].licensee == _licensee && licenses[i].isActive) {
                licenses[i].isActive = false;
                emit LicenseRevoked(_copyrightId, _licensee, block.timestamp);
                return;
            }
        }

        revert("License not found or already revoked");
    }


    function isLicenseValid(uint256 _copyrightId, address _licensee)
        public
        view
        returns (bool isValid)
    {
        LicenseInfo[] memory licenses = copyrightToLicenses[_copyrightId];

        for (uint256 i = 0; i < licenses.length; i++) {
            if (licenses[i].licensee == _licensee &&
                licenses[i].isActive &&
                block.timestamp >= licenses[i].licenseStartTime &&
                block.timestamp <= licenses[i].licenseEndTime) {
                return true;
            }
        }

        return false;
    }


    function getCopyrightInfo(uint256 _copyrightId)
        public
        view
        copyrightExists(_copyrightId)
        returns (CopyrightInfo memory)
    {
        return copyrights[_copyrightId];
    }


    function getOwnerCopyrights(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        return ownerToCopyrights[_owner];
    }


    function getCopyrightLicenses(uint256 _copyrightId)
        public
        view
        copyrightExists(_copyrightId)
        returns (LicenseInfo[] memory)
    {
        return copyrightToLicenses[_copyrightId];
    }


    function updateLicensePrice(uint256 _copyrightId, uint256 _newPrice)
        public
        copyrightExists(_copyrightId)
        onlyCopyrightOwner(_copyrightId)
        copyrightActive(_copyrightId)
    {
        copyrights[_copyrightId].licensePrice = _newPrice;
    }


    function deactivateCopyright(uint256 _copyrightId)
        public
        copyrightExists(_copyrightId)
        onlyCopyrightOwner(_copyrightId)
    {
        copyrights[_copyrightId].isActive = false;
    }


    function updateRegistrationFee(uint256 _newFee)
        public
        onlyContractOwner
    {
        registrationFee = _newFee;
    }


    function withdrawContractBalance()
        public
        onlyContractOwner
    {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        payable(contractOwner).transfer(balance);
    }


    function _removeCopyrightFromOwner(address _owner, uint256 _copyrightId)
        internal
    {
        uint256[] storage ownerCopyrights = ownerToCopyrights[_owner];

        for (uint256 i = 0; i < ownerCopyrights.length; i++) {
            if (ownerCopyrights[i] == _copyrightId) {
                ownerCopyrights[i] = ownerCopyrights[ownerCopyrights.length - 1];
                ownerCopyrights.pop();
                break;
            }
        }
    }


    function getContractStats()
        public
        view
        returns (uint256 totalCopyrights, uint256 activeContracts, uint256 currentRegistrationFee)
    {
        uint256 activeCount = 0;

        for (uint256 i = 1; i < nextCopyrightId; i++) {
            if (copyrights[i].isActive && block.timestamp <= copyrights[i].expirationTime) {
                activeCount++;
            }
        }

        return (nextCopyrightId - 1, activeCount, registrationFee);
    }
}
