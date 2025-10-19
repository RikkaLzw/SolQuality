
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract CopyrightManagementContract is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;


    uint256 public constant REGISTRATION_FEE = 0.01 ether;
    uint256 public constant LICENSE_DURATION = 365 days;
    uint256 public constant MAX_ROYALTY_PERCENTAGE = 5000;
    uint256 public constant BASIS_POINTS = 10000;


    Counters.Counter private _copyrightIdCounter;
    Counters.Counter private _licenseIdCounter;

    mapping(uint256 => Copyright) private _copyrights;
    mapping(uint256 => License) private _licenses;
    mapping(address => uint256[]) private _ownerCopyrights;
    mapping(address => uint256[]) private _licenseeContracts;
    mapping(bytes32 => uint256) private _contentHashToCopyrightId;


    struct Copyright {
        uint256 id;
        address owner;
        string title;
        string description;
        bytes32 contentHash;
        uint256 registrationTimestamp;
        uint256 royaltyPercentage;
        bool isActive;
    }

    struct License {
        uint256 id;
        uint256 copyrightId;
        address licensee;
        uint256 fee;
        uint256 startTime;
        uint256 endTime;
        LicenseType licenseType;
        bool isActive;
    }

    enum LicenseType {
        Personal,
        Commercial,
        Educational,
        Exclusive
    }


    event CopyrightRegistered(
        uint256 indexed copyrightId,
        address indexed owner,
        string title,
        bytes32 contentHash
    );

    event LicenseGranted(
        uint256 indexed licenseId,
        uint256 indexed copyrightId,
        address indexed licensee,
        LicenseType licenseType,
        uint256 fee
    );

    event RoyaltyPaid(
        uint256 indexed copyrightId,
        address indexed payer,
        uint256 amount
    );

    event CopyrightTransferred(
        uint256 indexed copyrightId,
        address indexed from,
        address indexed to
    );


    modifier copyrightExists(uint256 copyrightId) {
        require(_copyrights[copyrightId].id != 0, "Copyright does not exist");
        _;
    }

    modifier onlyCopyrightOwner(uint256 copyrightId) {
        require(
            _copyrights[copyrightId].owner == msg.sender,
            "Not the copyright owner"
        );
        _;
    }

    modifier validRoyaltyPercentage(uint256 percentage) {
        require(
            percentage <= MAX_ROYALTY_PERCENTAGE,
            "Royalty percentage exceeds maximum"
        );
        _;
    }

    modifier uniqueContent(bytes32 contentHash) {
        require(
            _contentHashToCopyrightId[contentHash] == 0,
            "Content already registered"
        );
        _;
    }


    function registerCopyright(
        string memory title,
        string memory description,
        bytes32 contentHash,
        uint256 royaltyPercentage
    )
        external
        payable
        uniqueContent(contentHash)
        validRoyaltyPercentage(royaltyPercentage)
        nonReentrant
    {
        require(msg.value >= REGISTRATION_FEE, "Insufficient registration fee");
        require(bytes(title).length > 0, "Title cannot be empty");

        _copyrightIdCounter.increment();
        uint256 newCopyrightId = _copyrightIdCounter.current();

        _copyrights[newCopyrightId] = Copyright({
            id: newCopyrightId,
            owner: msg.sender,
            title: title,
            description: description,
            contentHash: contentHash,
            registrationTimestamp: block.timestamp,
            royaltyPercentage: royaltyPercentage,
            isActive: true
        });

        _ownerCopyrights[msg.sender].push(newCopyrightId);
        _contentHashToCopyrightId[contentHash] = newCopyrightId;

        emit CopyrightRegistered(newCopyrightId, msg.sender, title, contentHash);
    }


    function grantLicense(
        uint256 copyrightId,
        address licensee,
        uint256 fee,
        LicenseType licenseType
    )
        external
        payable
        copyrightExists(copyrightId)
        onlyCopyrightOwner(copyrightId)
        nonReentrant
    {
        require(licensee != address(0), "Invalid licensee address");
        require(msg.value >= fee, "Insufficient license fee");
        require(_copyrights[copyrightId].isActive, "Copyright is not active");

        _licenseIdCounter.increment();
        uint256 newLicenseId = _licenseIdCounter.current();

        _licenses[newLicenseId] = License({
            id: newLicenseId,
            copyrightId: copyrightId,
            licensee: licensee,
            fee: fee,
            startTime: block.timestamp,
            endTime: block.timestamp + LICENSE_DURATION,
            licenseType: licenseType,
            isActive: true
        });

        _licenseeContracts[licensee].push(newLicenseId);


        payable(msg.sender).transfer(fee);

        emit LicenseGranted(newLicenseId, copyrightId, licensee, licenseType, fee);
    }


    function payRoyalty(uint256 copyrightId)
        external
        payable
        copyrightExists(copyrightId)
        nonReentrant
    {
        require(msg.value > 0, "Royalty amount must be greater than 0");
        require(_copyrights[copyrightId].isActive, "Copyright is not active");

        address copyrightOwner = _copyrights[copyrightId].owner;
        uint256 royaltyAmount = (msg.value * _copyrights[copyrightId].royaltyPercentage) / BASIS_POINTS;

        payable(copyrightOwner).transfer(royaltyAmount);

        emit RoyaltyPaid(copyrightId, msg.sender, royaltyAmount);
    }


    function transferCopyright(uint256 copyrightId, address newOwner)
        external
        copyrightExists(copyrightId)
        onlyCopyrightOwner(copyrightId)
    {
        require(newOwner != address(0), "Invalid new owner address");
        require(newOwner != msg.sender, "Cannot transfer to yourself");

        address previousOwner = _copyrights[copyrightId].owner;
        _copyrights[copyrightId].owner = newOwner;


        _removeFromOwnerCopyrights(previousOwner, copyrightId);
        _ownerCopyrights[newOwner].push(copyrightId);

        emit CopyrightTransferred(copyrightId, previousOwner, newOwner);
    }


    function revokeLicense(uint256 licenseId)
        external
        copyrightExists(_licenses[licenseId].copyrightId)
        onlyCopyrightOwner(_licenses[licenseId].copyrightId)
    {
        require(_licenses[licenseId].id != 0, "License does not exist");
        require(_licenses[licenseId].isActive, "License already revoked");

        _licenses[licenseId].isActive = false;
    }


    function updateRoyaltyPercentage(uint256 copyrightId, uint256 newPercentage)
        external
        copyrightExists(copyrightId)
        onlyCopyrightOwner(copyrightId)
        validRoyaltyPercentage(newPercentage)
    {
        _copyrights[copyrightId].royaltyPercentage = newPercentage;
    }


    function getCopyright(uint256 copyrightId)
        external
        view
        copyrightExists(copyrightId)
        returns (Copyright memory)
    {
        return _copyrights[copyrightId];
    }


    function getLicense(uint256 licenseId)
        external
        view
        returns (License memory)
    {
        require(_licenses[licenseId].id != 0, "License does not exist");
        return _licenses[licenseId];
    }


    function getOwnerCopyrights(address owner)
        external
        view
        returns (uint256[] memory)
    {
        return _ownerCopyrights[owner];
    }


    function getLicenseeLicenses(address licensee)
        external
        view
        returns (uint256[] memory)
    {
        return _licenseeContracts[licensee];
    }


    function isLicenseValid(uint256 licenseId)
        external
        view
        returns (bool)
    {
        if (_licenses[licenseId].id == 0) return false;

        License memory license = _licenses[licenseId];
        return license.isActive &&
               block.timestamp >= license.startTime &&
               block.timestamp <= license.endTime;
    }


    function getCopyrightIdByContentHash(bytes32 contentHash)
        external
        view
        returns (uint256)
    {
        return _contentHashToCopyrightId[contentHash];
    }


    function withdraw()
        external
        onlyOwner
        nonReentrant
    {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        payable(owner()).transfer(balance);
    }


    function _removeFromOwnerCopyrights(address owner, uint256 copyrightId)
        internal
    {
        uint256[] storage ownerCopyrights = _ownerCopyrights[owner];
        for (uint256 i = 0; i < ownerCopyrights.length; i++) {
            if (ownerCopyrights[i] == copyrightId) {
                ownerCopyrights[i] = ownerCopyrights[ownerCopyrights.length - 1];
                ownerCopyrights.pop();
                break;
            }
        }
    }
}
