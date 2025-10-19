
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract CopyrightManagement is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;


    uint256 public constant REGISTRATION_FEE = 0.01 ether;
    uint256 public constant TRANSFER_FEE = 0.005 ether;
    uint256 public constant MAX_DESCRIPTION_LENGTH = 500;
    uint256 public constant COPYRIGHT_DURATION = 70 * 365 days;


    Counters.Counter private _copyrightIds;
    mapping(uint256 => Copyright) private _copyrights;
    mapping(address => uint256[]) private _ownerCopyrights;
    mapping(bytes32 => uint256) private _contentHashToCopyrightId;


    struct Copyright {
        uint256 id;
        address owner;
        string title;
        string description;
        bytes32 contentHash;
        uint256 registrationTime;
        uint256 expirationTime;
        bool isActive;
        uint256 licensePrice;
        mapping(address => LicenseInfo) licenses;
    }


    struct LicenseInfo {
        bool isLicensed;
        uint256 licenseTime;
        uint256 expirationTime;
        uint256 paidAmount;
    }


    event CopyrightRegistered(
        uint256 indexed copyrightId,
        address indexed owner,
        string title,
        bytes32 contentHash
    );

    event CopyrightTransferred(
        uint256 indexed copyrightId,
        address indexed from,
        address indexed to
    );

    event LicenseGranted(
        uint256 indexed copyrightId,
        address indexed licensee,
        uint256 amount,
        uint256 duration
    );

    event CopyrightRevoked(uint256 indexed copyrightId);


    modifier copyrightExists(uint256 _copyrightId) {
        require(_copyrightId > 0 && _copyrightId <= _copyrightIds.current(), "Copyright does not exist");
        _;
    }

    modifier onlyCopyrightOwner(uint256 _copyrightId) {
        require(_copyrights[_copyrightId].owner == msg.sender, "Not copyright owner");
        _;
    }

    modifier copyrightActive(uint256 _copyrightId) {
        require(_copyrights[_copyrightId].isActive, "Copyright is not active");
        require(block.timestamp < _copyrights[_copyrightId].expirationTime, "Copyright has expired");
        _;
    }

    modifier validDescription(string memory _description) {
        require(bytes(_description).length <= MAX_DESCRIPTION_LENGTH, "Description too long");
        _;
    }

    constructor() {}


    function registerCopyright(
        string memory _title,
        string memory _description,
        bytes32 _contentHash,
        uint256 _licensePrice
    )
        external
        payable
        validDescription(_description)
        nonReentrant
    {
        require(msg.value >= REGISTRATION_FEE, "Insufficient registration fee");
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(_contentHash != bytes32(0), "Invalid content hash");
        require(_contentHashToCopyrightId[_contentHash] == 0, "Content already registered");

        _copyrightIds.increment();
        uint256 newCopyrightId = _copyrightIds.current();

        Copyright storage newCopyright = _copyrights[newCopyrightId];
        newCopyright.id = newCopyrightId;
        newCopyright.owner = msg.sender;
        newCopyright.title = _title;
        newCopyright.description = _description;
        newCopyright.contentHash = _contentHash;
        newCopyright.registrationTime = block.timestamp;
        newCopyright.expirationTime = block.timestamp + COPYRIGHT_DURATION;
        newCopyright.isActive = true;
        newCopyright.licensePrice = _licensePrice;

        _ownerCopyrights[msg.sender].push(newCopyrightId);
        _contentHashToCopyrightId[_contentHash] = newCopyrightId;

        emit CopyrightRegistered(newCopyrightId, msg.sender, _title, _contentHash);
    }


    function transferCopyright(uint256 _copyrightId, address _newOwner)
        external
        payable
        copyrightExists(_copyrightId)
        onlyCopyrightOwner(_copyrightId)
        copyrightActive(_copyrightId)
        nonReentrant
    {
        require(msg.value >= TRANSFER_FEE, "Insufficient transfer fee");
        require(_newOwner != address(0), "Invalid new owner address");
        require(_newOwner != msg.sender, "Cannot transfer to yourself");

        address oldOwner = _copyrights[_copyrightId].owner;
        _copyrights[_copyrightId].owner = _newOwner;


        _removeFromOwnerList(oldOwner, _copyrightId);
        _ownerCopyrights[_newOwner].push(_copyrightId);

        emit CopyrightTransferred(_copyrightId, oldOwner, _newOwner);
    }


    function purchaseLicense(uint256 _copyrightId, uint256 _duration)
        external
        payable
        copyrightExists(_copyrightId)
        copyrightActive(_copyrightId)
        nonReentrant
    {
        require(_duration > 0, "Duration must be greater than 0");
        require(msg.sender != _copyrights[_copyrightId].owner, "Owner cannot license own copyright");

        uint256 requiredAmount = _copyrights[_copyrightId].licensePrice;
        require(msg.value >= requiredAmount, "Insufficient payment for license");

        LicenseInfo storage license = _copyrights[_copyrightId].licenses[msg.sender];
        license.isLicensed = true;
        license.licenseTime = block.timestamp;
        license.expirationTime = block.timestamp + _duration;
        license.paidAmount = msg.value;


        address copyrightOwner = _copyrights[_copyrightId].owner;
        (bool success, ) = payable(copyrightOwner).call{value: requiredAmount}("");
        require(success, "Payment to copyright owner failed");


        if (msg.value > requiredAmount) {
            (bool refundSuccess, ) = payable(msg.sender).call{value: msg.value - requiredAmount}("");
            require(refundSuccess, "Refund failed");
        }

        emit LicenseGranted(_copyrightId, msg.sender, requiredAmount, _duration);
    }


    function revokeCopyright(uint256 _copyrightId)
        external
        copyrightExists(_copyrightId)
        onlyCopyrightOwner(_copyrightId)
    {
        _copyrights[_copyrightId].isActive = false;
        emit CopyrightRevoked(_copyrightId);
    }


    function updateLicensePrice(uint256 _copyrightId, uint256 _newPrice)
        external
        copyrightExists(_copyrightId)
        onlyCopyrightOwner(_copyrightId)
        copyrightActive(_copyrightId)
    {
        _copyrights[_copyrightId].licensePrice = _newPrice;
    }


    function getCopyright(uint256 _copyrightId)
        external
        view
        copyrightExists(_copyrightId)
        returns (
            uint256 id,
            address owner,
            string memory title,
            string memory description,
            bytes32 contentHash,
            uint256 registrationTime,
            uint256 expirationTime,
            bool isActive,
            uint256 licensePrice
        )
    {
        Copyright storage copyright = _copyrights[_copyrightId];
        return (
            copyright.id,
            copyright.owner,
            copyright.title,
            copyright.description,
            copyright.contentHash,
            copyright.registrationTime,
            copyright.expirationTime,
            copyright.isActive,
            copyright.licensePrice
        );
    }


    function checkLicense(uint256 _copyrightId, address _licensee)
        external
        view
        copyrightExists(_copyrightId)
        returns (bool isLicensed, uint256 expirationTime)
    {
        LicenseInfo storage license = _copyrights[_copyrightId].licenses[_licensee];
        bool isValid = license.isLicensed && block.timestamp < license.expirationTime;
        return (isValid, license.expirationTime);
    }


    function getOwnerCopyrights(address _owner) external view returns (uint256[] memory) {
        return _ownerCopyrights[_owner];
    }


    function getCopyrightByHash(bytes32 _contentHash) external view returns (uint256) {
        return _contentHashToCopyrightId[_contentHash];
    }


    function getTotalCopyrights() external view returns (uint256) {
        return _copyrightIds.current();
    }


    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }


    function _removeFromOwnerList(address _owner, uint256 _copyrightId) private {
        uint256[] storage ownerList = _ownerCopyrights[_owner];
        for (uint256 i = 0; i < ownerList.length; i++) {
            if (ownerList[i] == _copyrightId) {
                ownerList[i] = ownerList[ownerList.length - 1];
                ownerList.pop();
                break;
            }
        }
    }
}
