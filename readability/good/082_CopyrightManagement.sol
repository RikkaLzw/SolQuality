
pragma solidity ^0.8.0;


contract CopyrightManagement {


    struct CopyrightWork {
        uint256 workId;
        string workTitle;
        string workDescription;
        string workHash;
        address originalOwner;
        address currentOwner;
        uint256 registrationTimestamp;
        uint256 licensePrice;
        bool isActive;
    }


    struct License {
        uint256 licenseId;
        uint256 workId;
        address licensee;
        address licensor;
        uint256 licenseStartTime;
        uint256 licenseEndTime;
        uint256 licenseFee;
        bool isActive;
    }


    mapping(uint256 => CopyrightWork) public copyrightWorks;
    mapping(address => uint256[]) public ownerToWorks;
    mapping(string => bool) public workHashExists;
    mapping(uint256 => License[]) public workLicenses;
    mapping(address => License[]) public licenseeLicenses;

    uint256 private nextWorkId;
    uint256 private nextLicenseId;
    address public contractOwner;
    uint256 public registrationFee;


    event CopyrightRegistered(
        uint256 indexed workId,
        address indexed owner,
        string workTitle,
        uint256 timestamp
    );

    event CopyrightTransferred(
        uint256 indexed workId,
        address indexed fromOwner,
        address indexed toOwner,
        uint256 timestamp
    );

    event LicenseGranted(
        uint256 indexed licenseId,
        uint256 indexed workId,
        address indexed licensee,
        address licensor,
        uint256 startTime,
        uint256 endTime,
        uint256 fee
    );

    event LicenseRevoked(
        uint256 indexed licenseId,
        uint256 indexed workId,
        address indexed licensee,
        uint256 timestamp
    );

    event RegistrationFeeUpdated(
        uint256 oldFee,
        uint256 newFee,
        uint256 timestamp
    );


    modifier onlyContractOwner() {
        require(msg.sender == contractOwner, "Only contract owner can perform this action");
        _;
    }

    modifier onlyCopyrightOwner(uint256 _workId) {
        require(copyrightWorks[_workId].currentOwner == msg.sender, "Only copyright owner can perform this action");
        _;
    }

    modifier workExists(uint256 _workId) {
        require(copyrightWorks[_workId].isActive, "Copyright work does not exist or is inactive");
        _;
    }

    modifier validWorkId(uint256 _workId) {
        require(_workId > 0 && _workId < nextWorkId, "Invalid work ID");
        _;
    }


    constructor(uint256 _registrationFee) {
        contractOwner = msg.sender;
        registrationFee = _registrationFee;
        nextWorkId = 1;
        nextLicenseId = 1;
    }


    function registerCopyright(
        string memory _workTitle,
        string memory _workDescription,
        string memory _workHash,
        uint256 _licensePrice
    ) external payable returns (uint256) {
        require(msg.value >= registrationFee, "Insufficient registration fee");
        require(bytes(_workTitle).length > 0, "Work title cannot be empty");
        require(bytes(_workHash).length > 0, "Work hash cannot be empty");
        require(!workHashExists[_workHash], "Work with this hash already exists");

        uint256 currentWorkId = nextWorkId;
        nextWorkId++;


        copyrightWorks[currentWorkId] = CopyrightWork({
            workId: currentWorkId,
            workTitle: _workTitle,
            workDescription: _workDescription,
            workHash: _workHash,
            originalOwner: msg.sender,
            currentOwner: msg.sender,
            registrationTimestamp: block.timestamp,
            licensePrice: _licensePrice,
            isActive: true
        });


        ownerToWorks[msg.sender].push(currentWorkId);
        workHashExists[_workHash] = true;


        if (msg.value > registrationFee) {
            payable(msg.sender).transfer(msg.value - registrationFee);
        }

        emit CopyrightRegistered(currentWorkId, msg.sender, _workTitle, block.timestamp);

        return currentWorkId;
    }


    function transferCopyright(
        uint256 _workId,
        address _newOwner
    ) external validWorkId(_workId) workExists(_workId) onlyCopyrightOwner(_workId) {
        require(_newOwner != address(0), "New owner cannot be zero address");
        require(_newOwner != msg.sender, "Cannot transfer to yourself");

        address previousOwner = copyrightWorks[_workId].currentOwner;


        copyrightWorks[_workId].currentOwner = _newOwner;


        ownerToWorks[_newOwner].push(_workId);


        _removeWorkFromOwner(previousOwner, _workId);

        emit CopyrightTransferred(_workId, previousOwner, _newOwner, block.timestamp);
    }


    function grantLicense(
        uint256 _workId,
        address _licensee,
        uint256 _licenseStartTime,
        uint256 _licenseEndTime
    ) external payable validWorkId(_workId) workExists(_workId) onlyCopyrightOwner(_workId) returns (uint256) {
        require(_licensee != address(0), "Licensee cannot be zero address");
        require(_licensee != msg.sender, "Cannot license to yourself");
        require(_licenseStartTime < _licenseEndTime, "Invalid license time range");
        require(_licenseStartTime >= block.timestamp, "License start time must be in the future");
        require(msg.value >= copyrightWorks[_workId].licensePrice, "Insufficient license fee");

        uint256 currentLicenseId = nextLicenseId;
        nextLicenseId++;


        License memory newLicense = License({
            licenseId: currentLicenseId,
            workId: _workId,
            licensee: _licensee,
            licensor: msg.sender,
            licenseStartTime: _licenseStartTime,
            licenseEndTime: _licenseEndTime,
            licenseFee: msg.value,
            isActive: true
        });


        workLicenses[_workId].push(newLicense);
        licenseeLicenses[_licensee].push(newLicense);


        if (msg.value > copyrightWorks[_workId].licensePrice) {
            payable(msg.sender).transfer(msg.value - copyrightWorks[_workId].licensePrice);
        }

        emit LicenseGranted(
            currentLicenseId,
            _workId,
            _licensee,
            msg.sender,
            _licenseStartTime,
            _licenseEndTime,
            msg.value
        );

        return currentLicenseId;
    }


    function revokeLicense(
        uint256 _workId,
        uint256 _licenseId
    ) external validWorkId(_workId) workExists(_workId) onlyCopyrightOwner(_workId) {
        License[] storage licenses = workLicenses[_workId];
        bool licenseFound = false;
        address licensee;


        for (uint256 i = 0; i < licenses.length; i++) {
            if (licenses[i].licenseId == _licenseId && licenses[i].isActive) {
                licenses[i].isActive = false;
                licensee = licenses[i].licensee;
                licenseFound = true;
                break;
            }
        }

        require(licenseFound, "License not found or already revoked");


        License[] storage licenseeLicenseList = licenseeLicenses[licensee];
        for (uint256 i = 0; i < licenseeLicenseList.length; i++) {
            if (licenseeLicenseList[i].licenseId == _licenseId) {
                licenseeLicenseList[i].isActive = false;
                break;
            }
        }

        emit LicenseRevoked(_licenseId, _workId, licensee, block.timestamp);
    }


    function verifyCopyrightOwnership(
        uint256 _workId,
        address _owner
    ) external view validWorkId(_workId) workExists(_workId) returns (bool) {
        return copyrightWorks[_workId].currentOwner == _owner;
    }


    function verifyLicense(
        uint256 _workId,
        address _licensee
    ) external view validWorkId(_workId) workExists(_workId) returns (bool) {
        License[] memory licenses = workLicenses[_workId];

        for (uint256 i = 0; i < licenses.length; i++) {
            if (
                licenses[i].licensee == _licensee &&
                licenses[i].isActive &&
                block.timestamp >= licenses[i].licenseStartTime &&
                block.timestamp <= licenses[i].licenseEndTime
            ) {
                return true;
            }
        }

        return false;
    }


    function getCopyrightWork(uint256 _workId) external view validWorkId(_workId) returns (CopyrightWork memory) {
        return copyrightWorks[_workId];
    }


    function getWorksByOwner(address _owner) external view returns (uint256[] memory) {
        return ownerToWorks[_owner];
    }


    function getWorkLicenses(uint256 _workId) external view validWorkId(_workId) returns (License[] memory) {
        return workLicenses[_workId];
    }


    function getLicensesByLicensee(address _licensee) external view returns (License[] memory) {
        return licenseeLicenses[_licensee];
    }


    function updateRegistrationFee(uint256 _newFee) external onlyContractOwner {
        uint256 oldFee = registrationFee;
        registrationFee = _newFee;

        emit RegistrationFeeUpdated(oldFee, _newFee, block.timestamp);
    }


    function withdrawContractBalance() external onlyContractOwner {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "No balance to withdraw");

        payable(contractOwner).transfer(contractBalance);
    }


    function getContractInfo() external view returns (
        uint256 totalWorks,
        uint256 totalLicenses,
        uint256 currentRegistrationFee
    ) {
        return (nextWorkId - 1, nextLicenseId - 1, registrationFee);
    }


    function _removeWorkFromOwner(address _owner, uint256 _workId) internal {
        uint256[] storage works = ownerToWorks[_owner];

        for (uint256 i = 0; i < works.length; i++) {
            if (works[i] == _workId) {
                works[i] = works[works.length - 1];
                works.pop();
                break;
            }
        }
    }


    receive() external payable {

    }
}
