
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract CopyrightManagement is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;


    uint256 public constant REGISTRATION_FEE = 0.01 ether;
    uint256 public constant LICENSE_FEE_PERCENTAGE = 5;
    uint256 public constant MAX_ROYALTY_PERCENTAGE = 50;
    uint256 public constant MIN_LICENSE_DURATION = 1 days;
    uint256 public constant MAX_LICENSE_DURATION = 365 days;


    Counters.Counter private _copyrightIds;
    Counters.Counter private _licenseIds;


    enum CopyrightStatus { Active, Suspended, Revoked }
    enum LicenseStatus { Active, Expired, Revoked }
    enum WorkType { Text, Image, Audio, Video, Software, Other }


    struct Copyright {
        uint256 id;
        address owner;
        string title;
        string description;
        string ipfsHash;
        WorkType workType;
        uint256 registrationDate;
        uint256 royaltyPercentage;
        CopyrightStatus status;
        bool transferable;
    }

    struct License {
        uint256 id;
        uint256 copyrightId;
        address licensee;
        uint256 fee;
        uint256 startDate;
        uint256 endDate;
        LicenseStatus status;
        bool exclusive;
        string terms;
    }


    mapping(uint256 => Copyright) public copyrights;
    mapping(uint256 => License) public licenses;
    mapping(uint256 => uint256[]) public copyrightLicenses;
    mapping(address => uint256[]) public userCopyrights;
    mapping(address => uint256[]) public userLicenses;
    mapping(uint256 => mapping(address => bool)) public copyrightApprovals;

    uint256 public totalRegistrationFees;
    uint256 public totalLicenseFees;


    event CopyrightRegistered(
        uint256 indexed copyrightId,
        address indexed owner,
        string title,
        WorkType workType
    );

    event LicenseGranted(
        uint256 indexed licenseId,
        uint256 indexed copyrightId,
        address indexed licensee,
        uint256 fee,
        uint256 duration
    );

    event CopyrightTransferred(
        uint256 indexed copyrightId,
        address indexed from,
        address indexed to
    );

    event RoyaltyPaid(
        uint256 indexed copyrightId,
        address indexed payer,
        address indexed recipient,
        uint256 amount
    );

    event CopyrightStatusChanged(
        uint256 indexed copyrightId,
        CopyrightStatus oldStatus,
        CopyrightStatus newStatus
    );


    modifier onlyCopyrightOwner(uint256 _copyrightId) {
        require(
            copyrights[_copyrightId].owner == msg.sender,
            "Not copyright owner"
        );
        _;
    }

    modifier copyrightExists(uint256 _copyrightId) {
        require(
            copyrights[_copyrightId].owner != address(0),
            "Copyright does not exist"
        );
        _;
    }

    modifier validCopyrightStatus(uint256 _copyrightId) {
        require(
            copyrights[_copyrightId].status == CopyrightStatus.Active,
            "Copyright not active"
        );
        _;
    }

    modifier validLicenseDuration(uint256 _duration) {
        require(
            _duration >= MIN_LICENSE_DURATION && _duration <= MAX_LICENSE_DURATION,
            "Invalid license duration"
        );
        _;
    }

    modifier validRoyaltyPercentage(uint256 _percentage) {
        require(
            _percentage <= MAX_ROYALTY_PERCENTAGE,
            "Royalty percentage too high"
        );
        _;
    }

    constructor() {}


    function registerCopyright(
        string memory _title,
        string memory _description,
        string memory _ipfsHash,
        WorkType _workType,
        uint256 _royaltyPercentage,
        bool _transferable
    ) external payable validRoyaltyPercentage(_royaltyPercentage) {
        require(msg.value >= REGISTRATION_FEE, "Insufficient registration fee");
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_ipfsHash).length > 0, "IPFS hash cannot be empty");

        _copyrightIds.increment();
        uint256 newCopyrightId = _copyrightIds.current();

        copyrights[newCopyrightId] = Copyright({
            id: newCopyrightId,
            owner: msg.sender,
            title: _title,
            description: _description,
            ipfsHash: _ipfsHash,
            workType: _workType,
            registrationDate: block.timestamp,
            royaltyPercentage: _royaltyPercentage,
            status: CopyrightStatus.Active,
            transferable: _transferable
        });

        userCopyrights[msg.sender].push(newCopyrightId);
        totalRegistrationFees += msg.value;

        emit CopyrightRegistered(newCopyrightId, msg.sender, _title, _workType);
    }


    function grantLicense(
        uint256 _copyrightId,
        address _licensee,
        uint256 _duration,
        bool _exclusive,
        string memory _terms
    ) external payable
      copyrightExists(_copyrightId)
      validCopyrightStatus(_copyrightId)
      validLicenseDuration(_duration)
      nonReentrant
    {
        require(_licensee != address(0), "Invalid licensee address");
        require(_licensee != copyrights[_copyrightId].owner, "Owner cannot license to self");
        require(msg.value > 0, "License fee must be greater than 0");


        if (_exclusive) {
            _checkExclusiveLicenseConflict(_copyrightId, _duration);
        }

        _licenseIds.increment();
        uint256 newLicenseId = _licenseIds.current();

        licenses[newLicenseId] = License({
            id: newLicenseId,
            copyrightId: _copyrightId,
            licensee: _licensee,
            fee: msg.value,
            startDate: block.timestamp,
            endDate: block.timestamp + _duration,
            status: LicenseStatus.Active,
            exclusive: _exclusive,
            terms: _terms
        });

        copyrightLicenses[_copyrightId].push(newLicenseId);
        userLicenses[_licensee].push(newLicenseId);


        _distributeLicenseFee(_copyrightId, msg.value);

        emit LicenseGranted(newLicenseId, _copyrightId, _licensee, msg.value, _duration);
    }


    function transferCopyright(uint256 _copyrightId, address _to)
        external
        copyrightExists(_copyrightId)
        onlyCopyrightOwner(_copyrightId)
    {
        require(_to != address(0), "Invalid recipient address");
        require(_to != msg.sender, "Cannot transfer to self");
        require(copyrights[_copyrightId].transferable, "Copyright not transferable");

        address from = copyrights[_copyrightId].owner;
        copyrights[_copyrightId].owner = _to;


        _removeCopyrightFromUser(from, _copyrightId);
        userCopyrights[_to].push(_copyrightId);

        emit CopyrightTransferred(_copyrightId, from, _to);
    }


    function payRoyalty(uint256 _copyrightId)
        external
        payable
        copyrightExists(_copyrightId)
        validCopyrightStatus(_copyrightId)
        nonReentrant
    {
        require(msg.value > 0, "Royalty amount must be greater than 0");

        address copyrightOwner = copyrights[_copyrightId].owner;
        require(copyrightOwner != msg.sender, "Owner cannot pay royalty to self");

        (bool success, ) = payable(copyrightOwner).call{value: msg.value}("");
        require(success, "Royalty payment failed");

        emit RoyaltyPaid(_copyrightId, msg.sender, copyrightOwner, msg.value);
    }


    function updateCopyrightStatus(uint256 _copyrightId, CopyrightStatus _newStatus)
        external
        onlyOwner
        copyrightExists(_copyrightId)
    {
        CopyrightStatus oldStatus = copyrights[_copyrightId].status;
        copyrights[_copyrightId].status = _newStatus;

        emit CopyrightStatusChanged(_copyrightId, oldStatus, _newStatus);
    }


    function revokeLicense(uint256 _licenseId) external {
        require(licenses[_licenseId].licensee != address(0), "License does not exist");

        uint256 copyrightId = licenses[_licenseId].copyrightId;
        require(
            msg.sender == copyrights[copyrightId].owner || msg.sender == owner(),
            "Not authorized to revoke license"
        );

        licenses[_licenseId].status = LicenseStatus.Revoked;
    }


    function isLicenseValid(uint256 _licenseId) external view returns (bool) {
        License memory license = licenses[_licenseId];

        return license.licensee != address(0) &&
               license.status == LicenseStatus.Active &&
               block.timestamp >= license.startDate &&
               block.timestamp <= license.endDate;
    }


    function getCopyright(uint256 _copyrightId) external view returns (Copyright memory) {
        return copyrights[_copyrightId];
    }


    function getLicense(uint256 _licenseId) external view returns (License memory) {
        return licenses[_licenseId];
    }


    function getUserCopyrights(address _user) external view returns (uint256[] memory) {
        return userCopyrights[_user];
    }


    function getUserLicenses(address _user) external view returns (uint256[] memory) {
        return userLicenses[_user];
    }


    function getCopyrightLicenses(uint256 _copyrightId) external view returns (uint256[] memory) {
        return copyrightLicenses[_copyrightId];
    }


    function withdrawFees() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }


    function _distributeLicenseFee(uint256 _copyrightId, uint256 _totalFee) internal {
        uint256 platformFee = (_totalFee * LICENSE_FEE_PERCENTAGE) / 100;
        uint256 ownerFee = _totalFee - platformFee;

        totalLicenseFees += platformFee;

        address copyrightOwner = copyrights[_copyrightId].owner;
        (bool success, ) = payable(copyrightOwner).call{value: ownerFee}("");
        require(success, "Owner fee payment failed");
    }

    function _checkExclusiveLicenseConflict(uint256 _copyrightId, uint256 _duration) internal view {
        uint256[] memory licenseIds = copyrightLicenses[_copyrightId];
        uint256 newEndDate = block.timestamp + _duration;

        for (uint256 i = 0; i < licenseIds.length; i++) {
            License memory existingLicense = licenses[licenseIds[i]];

            if (existingLicense.exclusive && existingLicense.status == LicenseStatus.Active) {
                require(
                    block.timestamp > existingLicense.endDate || newEndDate < existingLicense.startDate,
                    "Exclusive license conflict"
                );
            }
        }
    }

    function _removeCopyrightFromUser(address _user, uint256 _copyrightId) internal {
        uint256[] storage userCopyrightsArray = userCopyrights[_user];
        for (uint256 i = 0; i < userCopyrightsArray.length; i++) {
            if (userCopyrightsArray[i] == _copyrightId) {
                userCopyrightsArray[i] = userCopyrightsArray[userCopyrightsArray.length - 1];
                userCopyrightsArray.pop();
                break;
            }
        }
    }


    function getCurrentCopyrightId() external view returns (uint256) {
        return _copyrightIds.current();
    }


    function getCurrentLicenseId() external view returns (uint256) {
        return _licenseIds.current();
    }
}
