
pragma solidity ^0.8.0;


contract CopyrightManagementContract {


    struct CopyrightWork {
        uint256 workId;
        string workTitle;
        string workDescription;
        string workHash;
        address originalCreator;
        address currentOwner;
        uint256 registrationTimestamp;
        uint256 licensePrice;
        bool isActive;
        string[] licenseTerms;
    }


    struct License {
        uint256 licenseId;
        uint256 workId;
        address licensee;
        uint256 licenseStartTime;
        uint256 licenseEndTime;
        uint256 paidAmount;
        bool isActive;
        string licenseType;
    }


    mapping(uint256 => CopyrightWork) public copyrightWorks;
    mapping(address => uint256[]) public creatorWorks;
    mapping(address => uint256[]) public ownerWorks;
    mapping(uint256 => License[]) public workLicenses;
    mapping(address => License[]) public userLicenses;

    uint256 private nextWorkId;
    uint256 private nextLicenseId;
    address public contractOwner;
    uint256 public platformFeePercentage;


    event CopyrightRegistered(
        uint256 indexed workId,
        address indexed creator,
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
        uint256 paidAmount,
        uint256 startTime,
        uint256 endTime
    );

    event LicenseRevoked(
        uint256 indexed licenseId,
        uint256 indexed workId,
        address indexed licensee,
        uint256 timestamp
    );

    event PlatformFeeUpdated(
        uint256 oldFeePercentage,
        uint256 newFeePercentage,
        uint256 timestamp
    );


    modifier onlyContractOwner() {
        require(msg.sender == contractOwner, "Only contract owner can perform this action");
        _;
    }

    modifier onlyWorkOwner(uint256 _workId) {
        require(copyrightWorks[_workId].currentOwner == msg.sender, "Only work owner can perform this action");
        _;
    }

    modifier workExists(uint256 _workId) {
        require(copyrightWorks[_workId].isActive, "Work does not exist or is inactive");
        _;
    }

    modifier validAddress(address _address) {
        require(_address != address(0), "Invalid address");
        _;
    }


    constructor(uint256 _platformFeePercentage) {
        contractOwner = msg.sender;
        platformFeePercentage = _platformFeePercentage;
        nextWorkId = 1;
        nextLicenseId = 1;
    }


    function registerCopyright(
        string memory _workTitle,
        string memory _workDescription,
        string memory _workHash,
        uint256 _licensePrice,
        string[] memory _licenseTerms
    ) external returns (uint256 workId) {
        require(bytes(_workTitle).length > 0, "Work title cannot be empty");
        require(bytes(_workHash).length > 0, "Work hash cannot be empty");
        require(_licensePrice > 0, "License price must be greater than 0");

        workId = nextWorkId;
        nextWorkId++;


        CopyrightWork storage newWork = copyrightWorks[workId];
        newWork.workId = workId;
        newWork.workTitle = _workTitle;
        newWork.workDescription = _workDescription;
        newWork.workHash = _workHash;
        newWork.originalCreator = msg.sender;
        newWork.currentOwner = msg.sender;
        newWork.registrationTimestamp = block.timestamp;
        newWork.licensePrice = _licensePrice;
        newWork.isActive = true;
        newWork.licenseTerms = _licenseTerms;


        creatorWorks[msg.sender].push(workId);
        ownerWorks[msg.sender].push(workId);

        emit CopyrightRegistered(workId, msg.sender, _workTitle, block.timestamp);

        return workId;
    }


    function transferCopyright(
        uint256 _workId,
        address _newOwner
    ) external workExists(_workId) onlyWorkOwner(_workId) validAddress(_newOwner) {
        require(_newOwner != msg.sender, "Cannot transfer to yourself");

        address oldOwner = copyrightWorks[_workId].currentOwner;
        copyrightWorks[_workId].currentOwner = _newOwner;


        _removeWorkFromOwner(oldOwner, _workId);
        ownerWorks[_newOwner].push(_workId);

        emit CopyrightTransferred(_workId, oldOwner, _newOwner, block.timestamp);
    }


    function purchaseLicense(
        uint256 _workId,
        uint256 _licenseDuration,
        string memory _licenseType
    ) external payable workExists(_workId) {
        require(_licenseDuration > 0, "License duration must be greater than 0");
        require(msg.value >= copyrightWorks[_workId].licensePrice, "Insufficient payment");
        require(bytes(_licenseType).length > 0, "License type cannot be empty");

        uint256 licenseId = nextLicenseId;
        nextLicenseId++;

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + _licenseDuration;


        License memory newLicense = License({
            licenseId: licenseId,
            workId: _workId,
            licensee: msg.sender,
            licenseStartTime: startTime,
            licenseEndTime: endTime,
            paidAmount: msg.value,
            isActive: true,
            licenseType: _licenseType
        });


        workLicenses[_workId].push(newLicense);
        userLicenses[msg.sender].push(newLicense);


        uint256 platformFee = (msg.value * platformFeePercentage) / 10000;
        uint256 ownerRevenue = msg.value - platformFee;


        address payable workOwner = payable(copyrightWorks[_workId].currentOwner);
        workOwner.transfer(ownerRevenue);



        emit LicenseGranted(licenseId, _workId, msg.sender, msg.value, startTime, endTime);
    }


    function revokeLicense(
        uint256 _workId,
        uint256 _licenseId
    ) external workExists(_workId) onlyWorkOwner(_workId) {
        License[] storage licenses = workLicenses[_workId];

        for (uint256 i = 0; i < licenses.length; i++) {
            if (licenses[i].licenseId == _licenseId && licenses[i].isActive) {
                licenses[i].isActive = false;


                _updateUserLicenseStatus(licenses[i].licensee, _licenseId, false);

                emit LicenseRevoked(_licenseId, _workId, licenses[i].licensee, block.timestamp);
                return;
            }
        }

        revert("License not found or already inactive");
    }


    function checkLicenseValidity(
        uint256 _workId,
        address _licensee
    ) external view returns (bool isValid) {
        License[] memory licenses = workLicenses[_workId];

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


    function getWorkInfo(uint256 _workId) external view workExists(_workId) returns (CopyrightWork memory work) {
        return copyrightWorks[_workId];
    }


    function getCreatorWorks(address _creator) external view returns (uint256[] memory workIds) {
        return creatorWorks[_creator];
    }


    function getOwnerWorks(address _owner) external view returns (uint256[] memory workIds) {
        return ownerWorks[_owner];
    }


    function getUserLicenses(address _user) external view returns (License[] memory licenses) {
        return userLicenses[_user];
    }


    function getWorkLicenses(uint256 _workId) external view workExists(_workId) returns (License[] memory licenses) {
        return workLicenses[_workId];
    }


    function updatePlatformFee(uint256 _newFeePercentage) external onlyContractOwner {
        require(_newFeePercentage <= 1000, "Platform fee cannot exceed 10%");

        uint256 oldFeePercentage = platformFeePercentage;
        platformFeePercentage = _newFeePercentage;

        emit PlatformFeeUpdated(oldFeePercentage, _newFeePercentage, block.timestamp);
    }


    function withdrawPlatformFees() external onlyContractOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");

        payable(contractOwner).transfer(balance);
    }


    function updateLicensePrice(
        uint256 _workId,
        uint256 _newPrice
    ) external workExists(_workId) onlyWorkOwner(_workId) {
        require(_newPrice > 0, "License price must be greater than 0");

        copyrightWorks[_workId].licensePrice = _newPrice;
    }


    function deactivateWork(uint256 _workId) external workExists(_workId) onlyWorkOwner(_workId) {
        copyrightWorks[_workId].isActive = false;
    }


    function _removeWorkFromOwner(address _owner, uint256 _workId) internal {
        uint256[] storage works = ownerWorks[_owner];

        for (uint256 i = 0; i < works.length; i++) {
            if (works[i] == _workId) {
                works[i] = works[works.length - 1];
                works.pop();
                break;
            }
        }
    }


    function _updateUserLicenseStatus(address _user, uint256 _licenseId, bool _isActive) internal {
        License[] storage licenses = userLicenses[_user];

        for (uint256 i = 0; i < licenses.length; i++) {
            if (licenses[i].licenseId == _licenseId) {
                licenses[i].isActive = _isActive;
                break;
            }
        }
    }


    function getContractInfo() external view returns (
        address owner,
        uint256 feePercentage,
        uint256 totalWorks,
        uint256 totalLicenses
    ) {
        return (
            contractOwner,
            platformFeePercentage,
            nextWorkId - 1,
            nextLicenseId - 1
        );
    }
}
