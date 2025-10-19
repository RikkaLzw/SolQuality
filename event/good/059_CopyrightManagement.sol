
pragma solidity ^0.8.0;

contract CopyrightManagement {
    struct Copyright {
        string title;
        string description;
        address owner;
        uint256 registrationDate;
        bool isActive;
        string ipfsHash;
        uint256 licensePrice;
    }

    struct License {
        uint256 copyrightId;
        address licensee;
        uint256 startDate;
        uint256 endDate;
        uint256 price;
        bool isActive;
    }

    mapping(uint256 => Copyright) public copyrights;
    mapping(uint256 => License[]) public copyrightLicenses;
    mapping(address => uint256[]) public ownerCopyrights;
    mapping(address => uint256[]) public licenseeLicenses;

    uint256 public nextCopyrightId = 1;
    uint256 public nextLicenseId = 1;
    address public admin;
    uint256 public registrationFee = 0.01 ether;

    event CopyrightRegistered(
        uint256 indexed copyrightId,
        address indexed owner,
        string title,
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
        uint256 price
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

    event LicensePriceUpdated(
        uint256 indexed copyrightId,
        uint256 oldPrice,
        uint256 newPrice
    );

    event RegistrationFeeUpdated(
        uint256 oldFee,
        uint256 newFee
    );

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyCopyrightOwner(uint256 copyrightId) {
        require(copyrights[copyrightId].owner == msg.sender, "Only copyright owner can perform this action");
        _;
    }

    modifier copyrightExists(uint256 copyrightId) {
        require(copyrightId > 0 && copyrightId < nextCopyrightId, "Copyright does not exist");
        _;
    }

    modifier copyrightActive(uint256 copyrightId) {
        require(copyrights[copyrightId].isActive, "Copyright is not active");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function registerCopyright(
        string memory title,
        string memory description,
        string memory ipfsHash,
        uint256 licensePrice
    ) external payable {
        require(msg.value >= registrationFee, "Insufficient registration fee");
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        require(bytes(ipfsHash).length > 0, "IPFS hash cannot be empty");

        uint256 copyrightId = nextCopyrightId++;

        copyrights[copyrightId] = Copyright({
            title: title,
            description: description,
            owner: msg.sender,
            registrationDate: block.timestamp,
            isActive: true,
            ipfsHash: ipfsHash,
            licensePrice: licensePrice
        });

        ownerCopyrights[msg.sender].push(copyrightId);

        emit CopyrightRegistered(copyrightId, msg.sender, title, block.timestamp);


        if (msg.value > registrationFee) {
            payable(msg.sender).transfer(msg.value - registrationFee);
        }
    }

    function transferCopyright(uint256 copyrightId, address newOwner)
        external
        copyrightExists(copyrightId)
        onlyCopyrightOwner(copyrightId)
        copyrightActive(copyrightId)
    {
        require(newOwner != address(0), "New owner cannot be zero address");
        require(newOwner != msg.sender, "Cannot transfer to yourself");

        address previousOwner = copyrights[copyrightId].owner;
        copyrights[copyrightId].owner = newOwner;


        _removeCopyrightFromOwner(previousOwner, copyrightId);


        ownerCopyrights[newOwner].push(copyrightId);

        emit CopyrightTransferred(copyrightId, previousOwner, newOwner);
    }

    function grantLicense(uint256 copyrightId, address licensee, uint256 durationInDays)
        external
        payable
        copyrightExists(copyrightId)
        copyrightActive(copyrightId)
    {
        require(licensee != address(0), "Licensee cannot be zero address");
        require(durationInDays > 0, "Duration must be greater than zero");
        require(msg.value >= copyrights[copyrightId].licensePrice, "Insufficient license fee");

        uint256 startDate = block.timestamp;
        uint256 endDate = startDate + (durationInDays * 1 days);
        uint256 licenseId = nextLicenseId++;

        License memory newLicense = License({
            copyrightId: copyrightId,
            licensee: licensee,
            startDate: startDate,
            endDate: endDate,
            price: msg.value,
            isActive: true
        });

        copyrightLicenses[copyrightId].push(newLicense);
        licenseeLicenses[licensee].push(licenseId);


        payable(copyrights[copyrightId].owner).transfer(msg.value);

        emit LicenseGranted(licenseId, copyrightId, licensee, startDate, endDate, msg.value);
    }

    function revokeLicense(uint256 copyrightId, uint256 licenseIndex)
        external
        copyrightExists(copyrightId)
        onlyCopyrightOwner(copyrightId)
    {
        require(licenseIndex < copyrightLicenses[copyrightId].length, "License index out of bounds");
        require(copyrightLicenses[copyrightId][licenseIndex].isActive, "License is already inactive");

        copyrightLicenses[copyrightId][licenseIndex].isActive = false;

        emit LicenseRevoked(
            licenseIndex,
            copyrightId,
            copyrightLicenses[copyrightId][licenseIndex].licensee
        );
    }

    function deactivateCopyright(uint256 copyrightId)
        external
        copyrightExists(copyrightId)
        onlyCopyrightOwner(copyrightId)
    {
        require(copyrights[copyrightId].isActive, "Copyright is already inactive");

        copyrights[copyrightId].isActive = false;

        emit CopyrightDeactivated(copyrightId, msg.sender);
    }

    function updateLicensePrice(uint256 copyrightId, uint256 newPrice)
        external
        copyrightExists(copyrightId)
        onlyCopyrightOwner(copyrightId)
        copyrightActive(copyrightId)
    {
        uint256 oldPrice = copyrights[copyrightId].licensePrice;
        copyrights[copyrightId].licensePrice = newPrice;

        emit LicensePriceUpdated(copyrightId, oldPrice, newPrice);
    }

    function updateRegistrationFee(uint256 newFee) external onlyAdmin {
        uint256 oldFee = registrationFee;
        registrationFee = newFee;

        emit RegistrationFeeUpdated(oldFee, newFee);
    }

    function isLicenseValid(uint256 copyrightId, uint256 licenseIndex)
        external
        view
        returns (bool)
    {
        if (licenseIndex >= copyrightLicenses[copyrightId].length) {
            return false;
        }

        License memory license = copyrightLicenses[copyrightId][licenseIndex];
        return license.isActive &&
               block.timestamp >= license.startDate &&
               block.timestamp <= license.endDate;
    }

    function getCopyrightInfo(uint256 copyrightId)
        external
        view
        copyrightExists(copyrightId)
        returns (
            string memory title,
            string memory description,
            address owner,
            uint256 registrationDate,
            bool isActive,
            string memory ipfsHash,
            uint256 licensePrice
        )
    {
        Copyright memory copyright = copyrights[copyrightId];
        return (
            copyright.title,
            copyright.description,
            copyright.owner,
            copyright.registrationDate,
            copyright.isActive,
            copyright.ipfsHash,
            copyright.licensePrice
        );
    }

    function getCopyrightLicenses(uint256 copyrightId)
        external
        view
        copyrightExists(copyrightId)
        returns (License[] memory)
    {
        return copyrightLicenses[copyrightId];
    }

    function getOwnerCopyrights(address owner)
        external
        view
        returns (uint256[] memory)
    {
        return ownerCopyrights[owner];
    }

    function withdrawFees() external onlyAdmin {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");

        payable(admin).transfer(balance);
    }

    function _removeCopyrightFromOwner(address owner, uint256 copyrightId) private {
        uint256[] storage ownedCopyrights = ownerCopyrights[owner];
        for (uint256 i = 0; i < ownedCopyrights.length; i++) {
            if (ownedCopyrights[i] == copyrightId) {
                ownedCopyrights[i] = ownedCopyrights[ownedCopyrights.length - 1];
                ownedCopyrights.pop();
                break;
            }
        }
    }
}
