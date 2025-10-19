
pragma solidity ^0.8.0;

contract CopyrightManagement {
    struct Copyright {
        address owner;
        string title;
        string description;
        uint256 registrationDate;
        bool isActive;
    }

    mapping(uint256 => Copyright) public copyrights;
    mapping(address => uint256[]) public ownerCopyrights;
    mapping(uint256 => address) public licenseHolders;

    uint256 private nextCopyrightId;
    address private admin;

    event CopyrightRegistered(uint256 indexed copyrightId, address indexed owner, string title);
    event CopyrightTransferred(uint256 indexed copyrightId, address indexed from, address indexed to);
    event LicenseGranted(uint256 indexed copyrightId, address indexed licensee);
    event LicenseRevoked(uint256 indexed copyrightId, address indexed licensee);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyCopyrightOwner(uint256 copyrightId) {
        require(copyrights[copyrightId].owner == msg.sender, "Only copyright owner can perform this action");
        _;
    }

    modifier copyrightExists(uint256 copyrightId) {
        require(copyrights[copyrightId].owner != address(0), "Copyright does not exist");
        _;
    }

    constructor() {
        admin = msg.sender;
        nextCopyrightId = 1;
    }

    function registerCopyright(string memory title, string memory description) external returns (uint256) {
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");

        uint256 copyrightId = nextCopyrightId;
        nextCopyrightId++;

        copyrights[copyrightId] = Copyright({
            owner: msg.sender,
            title: title,
            description: description,
            registrationDate: block.timestamp,
            isActive: true
        });

        ownerCopyrights[msg.sender].push(copyrightId);

        emit CopyrightRegistered(copyrightId, msg.sender, title);
        return copyrightId;
    }

    function transferCopyright(uint256 copyrightId, address newOwner) external
        copyrightExists(copyrightId)
        onlyCopyrightOwner(copyrightId)
    {
        require(newOwner != address(0), "New owner cannot be zero address");
        require(newOwner != copyrights[copyrightId].owner, "Cannot transfer to same owner");

        address previousOwner = copyrights[copyrightId].owner;
        copyrights[copyrightId].owner = newOwner;

        _removeFromOwnerList(previousOwner, copyrightId);
        ownerCopyrights[newOwner].push(copyrightId);

        emit CopyrightTransferred(copyrightId, previousOwner, newOwner);
    }

    function grantLicense(uint256 copyrightId, address licensee) external
        copyrightExists(copyrightId)
        onlyCopyrightOwner(copyrightId)
    {
        require(licensee != address(0), "Licensee cannot be zero address");
        require(licenseHolders[copyrightId] == address(0), "License already granted");

        licenseHolders[copyrightId] = licensee;
        emit LicenseGranted(copyrightId, licensee);
    }

    function revokeLicense(uint256 copyrightId) external
        copyrightExists(copyrightId)
        onlyCopyrightOwner(copyrightId)
    {
        address licensee = licenseHolders[copyrightId];
        require(licensee != address(0), "No license to revoke");

        delete licenseHolders[copyrightId];
        emit LicenseRevoked(copyrightId, licensee);
    }

    function deactivateCopyright(uint256 copyrightId) external
        copyrightExists(copyrightId)
        onlyCopyrightOwner(copyrightId)
    {
        copyrights[copyrightId].isActive = false;
    }

    function getCopyrightInfo(uint256 copyrightId) external view
        copyrightExists(copyrightId)
        returns (address, string memory, string memory, uint256, bool)
    {
        Copyright memory copyright = copyrights[copyrightId];
        return (
            copyright.owner,
            copyright.title,
            copyright.description,
            copyright.registrationDate,
            copyright.isActive
        );
    }

    function getOwnerCopyrights(address owner) external view returns (uint256[] memory) {
        return ownerCopyrights[owner];
    }

    function getLicenseHolder(uint256 copyrightId) external view returns (address) {
        return licenseHolders[copyrightId];
    }

    function isLicenseActive(uint256 copyrightId) external view returns (bool) {
        return licenseHolders[copyrightId] != address(0) && copyrights[copyrightId].isActive;
    }

    function _removeFromOwnerList(address owner, uint256 copyrightId) private {
        uint256[] storage copyrightList = ownerCopyrights[owner];
        for (uint256 i = 0; i < copyrightList.length; i++) {
            if (copyrightList[i] == copyrightId) {
                copyrightList[i] = copyrightList[copyrightList.length - 1];
                copyrightList.pop();
                break;
            }
        }
    }

    function changeAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "New admin cannot be zero address");
        admin = newAdmin;
    }

    function getAdmin() external view returns (address) {
        return admin;
    }
}
