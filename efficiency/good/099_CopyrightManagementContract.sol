
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract CopyrightManagementContract is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;

    struct Copyright {
        address owner;
        string title;
        string contentHash;
        uint256 registrationTime;
        uint256 expirationTime;
        bool isActive;
        uint256 licensePrice;
        uint256 totalLicenses;
    }

    struct License {
        uint256 copyrightId;
        address licensee;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
    }

    Counters.Counter private _copyrightIds;
    Counters.Counter private _licenseIds;

    mapping(uint256 => Copyright) public copyrights;
    mapping(uint256 => License) public licenses;
    mapping(address => uint256[]) private _ownerCopyrights;
    mapping(address => uint256[]) private _licenseeCopyrights;
    mapping(string => uint256) private _contentHashToCopyright;
    mapping(uint256 => uint256[]) private _copyrightLicenses;

    uint256 public constant REGISTRATION_FEE = 0.01 ether;
    uint256 public constant MAX_COPYRIGHT_DURATION = 365 days * 70;

    event CopyrightRegistered(
        uint256 indexed copyrightId,
        address indexed owner,
        string title,
        string contentHash
    );

    event LicenseGranted(
        uint256 indexed licenseId,
        uint256 indexed copyrightId,
        address indexed licensee,
        uint256 duration
    );

    event CopyrightTransferred(
        uint256 indexed copyrightId,
        address indexed from,
        address indexed to
    );

    modifier onlyCopyrightOwner(uint256 copyrightId) {
        require(copyrights[copyrightId].owner == msg.sender, "Not copyright owner");
        _;
    }

    modifier validCopyright(uint256 copyrightId) {
        require(copyrights[copyrightId].owner != address(0), "Copyright does not exist");
        require(copyrights[copyrightId].isActive, "Copyright is not active");
        require(block.timestamp <= copyrights[copyrightId].expirationTime, "Copyright expired");
        _;
    }

    function registerCopyright(
        string memory title,
        string memory contentHash,
        uint256 duration,
        uint256 licensePrice
    ) external payable returns (uint256) {
        require(msg.value >= REGISTRATION_FEE, "Insufficient registration fee");
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(contentHash).length > 0, "Content hash cannot be empty");
        require(duration <= MAX_COPYRIGHT_DURATION, "Duration exceeds maximum");
        require(_contentHashToCopyright[contentHash] == 0, "Content already registered");

        _copyrightIds.increment();
        uint256 newCopyrightId = _copyrightIds.current();

        uint256 expirationTime = block.timestamp + duration;

        copyrights[newCopyrightId] = Copyright({
            owner: msg.sender,
            title: title,
            contentHash: contentHash,
            registrationTime: block.timestamp,
            expirationTime: expirationTime,
            isActive: true,
            licensePrice: licensePrice,
            totalLicenses: 0
        });

        _ownerCopyrights[msg.sender].push(newCopyrightId);
        _contentHashToCopyright[contentHash] = newCopyrightId;

        emit CopyrightRegistered(newCopyrightId, msg.sender, title, contentHash);

        return newCopyrightId;
    }

    function purchaseLicense(uint256 copyrightId, uint256 duration)
        external
        payable
        validCopyright(copyrightId)
        nonReentrant
        returns (uint256)
    {
        Copyright storage copyright = copyrights[copyrightId];
        require(msg.value >= copyright.licensePrice, "Insufficient payment");
        require(duration > 0, "Duration must be positive");

        _licenseIds.increment();
        uint256 newLicenseId = _licenseIds.current();

        uint256 licenseEndTime = block.timestamp + duration;

        licenses[newLicenseId] = License({
            copyrightId: copyrightId,
            licensee: msg.sender,
            startTime: block.timestamp,
            endTime: licenseEndTime,
            isActive: true
        });

        copyright.totalLicenses++;
        _licenseeCopyrights[msg.sender].push(newLicenseId);
        _copyrightLicenses[copyrightId].push(newLicenseId);

        uint256 payment = copyright.licensePrice;
        payable(copyright.owner).transfer(payment);

        if (msg.value > payment) {
            payable(msg.sender).transfer(msg.value - payment);
        }

        emit LicenseGranted(newLicenseId, copyrightId, msg.sender, duration);

        return newLicenseId;
    }

    function transferCopyright(uint256 copyrightId, address newOwner)
        external
        onlyCopyrightOwner(copyrightId)
        validCopyright(copyrightId)
    {
        require(newOwner != address(0), "Invalid new owner");
        require(newOwner != msg.sender, "Cannot transfer to self");

        Copyright storage copyright = copyrights[copyrightId];
        address oldOwner = copyright.owner;
        copyright.owner = newOwner;

        _removeFromOwnerArray(oldOwner, copyrightId);
        _ownerCopyrights[newOwner].push(copyrightId);

        emit CopyrightTransferred(copyrightId, oldOwner, newOwner);
    }

    function revokeLicense(uint256 licenseId)
        external
    {
        License storage license = licenses[licenseId];
        require(license.licensee != address(0), "License does not exist");

        Copyright storage copyright = copyrights[license.copyrightId];
        require(
            msg.sender == copyright.owner || msg.sender == license.licensee,
            "Not authorized to revoke"
        );

        license.isActive = false;
    }

    function updateLicensePrice(uint256 copyrightId, uint256 newPrice)
        external
        onlyCopyrightOwner(copyrightId)
        validCopyright(copyrightId)
    {
        copyrights[copyrightId].licensePrice = newPrice;
    }

    function getCopyrightsByOwner(address owner)
        external
        view
        returns (uint256[] memory)
    {
        return _ownerCopyrights[owner];
    }

    function getLicensesByLicensee(address licensee)
        external
        view
        returns (uint256[] memory)
    {
        return _licenseeCopyrights[licensee];
    }

    function getCopyrightLicenses(uint256 copyrightId)
        external
        view
        returns (uint256[] memory)
    {
        return _copyrightLicenses[copyrightId];
    }

    function isLicenseValid(uint256 licenseId)
        external
        view
        returns (bool)
    {
        License memory license = licenses[licenseId];
        return license.isActive &&
               block.timestamp >= license.startTime &&
               block.timestamp <= license.endTime;
    }

    function getCopyrightByContentHash(string memory contentHash)
        external
        view
        returns (uint256)
    {
        return _contentHashToCopyright[contentHash];
    }

    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        payable(owner()).transfer(balance);
    }

    function _removeFromOwnerArray(address owner, uint256 copyrightId) private {
        uint256[] storage ownerCopyrights = _ownerCopyrights[owner];
        uint256 length = ownerCopyrights.length;

        for (uint256 i = 0; i < length; i++) {
            if (ownerCopyrights[i] == copyrightId) {
                ownerCopyrights[i] = ownerCopyrights[length - 1];
                ownerCopyrights.pop();
                break;
            }
        }
    }
}
