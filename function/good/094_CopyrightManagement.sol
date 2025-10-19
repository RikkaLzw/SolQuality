
pragma solidity ^0.8.0;

contract CopyrightManagement {
    struct Copyright {
        address owner;
        string title;
        string description;
        uint256 registrationTime;
        bool isActive;
    }

    mapping(uint256 => Copyright) public copyrights;
    mapping(address => uint256[]) public ownerCopyrights;
    mapping(uint256 => mapping(address => bool)) public licenses;

    uint256 private nextCopyrightId = 1;

    event CopyrightRegistered(uint256 indexed copyrightId, address indexed owner, string title);
    event CopyrightTransferred(uint256 indexed copyrightId, address indexed from, address indexed to);
    event LicenseGranted(uint256 indexed copyrightId, address indexed licensee);
    event LicenseRevoked(uint256 indexed copyrightId, address indexed licensee);

    modifier onlyOwner(uint256 copyrightId) {
        require(copyrights[copyrightId].owner == msg.sender, "Not copyright owner");
        _;
    }

    modifier copyrightExists(uint256 copyrightId) {
        require(copyrights[copyrightId].owner != address(0), "Copyright does not exist");
        _;
    }

    modifier isActive(uint256 copyrightId) {
        require(copyrights[copyrightId].isActive, "Copyright is not active");
        _;
    }

    function registerCopyright(string memory title, string memory description) external returns (uint256) {
        require(bytes(title).length > 0, "Title cannot be empty");

        uint256 copyrightId = nextCopyrightId;
        nextCopyrightId++;

        copyrights[copyrightId] = Copyright({
            owner: msg.sender,
            title: title,
            description: description,
            registrationTime: block.timestamp,
            isActive: true
        });

        ownerCopyrights[msg.sender].push(copyrightId);

        emit CopyrightRegistered(copyrightId, msg.sender, title);
        return copyrightId;
    }

    function transferCopyright(uint256 copyrightId, address newOwner)
        external
        onlyOwner(copyrightId)
        copyrightExists(copyrightId)
        isActive(copyrightId)
    {
        require(newOwner != address(0), "Invalid new owner address");
        require(newOwner != msg.sender, "Cannot transfer to yourself");

        address oldOwner = copyrights[copyrightId].owner;
        copyrights[copyrightId].owner = newOwner;

        _removeFromOwnerList(oldOwner, copyrightId);
        ownerCopyrights[newOwner].push(copyrightId);

        emit CopyrightTransferred(copyrightId, oldOwner, newOwner);
    }

    function grantLicense(uint256 copyrightId, address licensee)
        external
        onlyOwner(copyrightId)
        copyrightExists(copyrightId)
        isActive(copyrightId)
    {
        require(licensee != address(0), "Invalid licensee address");
        require(licensee != msg.sender, "Cannot grant license to yourself");
        require(!licenses[copyrightId][licensee], "License already granted");

        licenses[copyrightId][licensee] = true;
        emit LicenseGranted(copyrightId, licensee);
    }

    function revokeLicense(uint256 copyrightId, address licensee)
        external
        onlyOwner(copyrightId)
        copyrightExists(copyrightId)
    {
        require(licenses[copyrightId][licensee], "License not granted");

        licenses[copyrightId][licensee] = false;
        emit LicenseRevoked(copyrightId, licensee);
    }

    function deactivateCopyright(uint256 copyrightId)
        external
        onlyOwner(copyrightId)
        copyrightExists(copyrightId)
        isActive(copyrightId)
    {
        copyrights[copyrightId].isActive = false;
    }

    function getCopyright(uint256 copyrightId)
        external
        view
        copyrightExists(copyrightId)
        returns (address, string memory, string memory, uint256, bool)
    {
        Copyright memory copyright = copyrights[copyrightId];
        return (
            copyright.owner,
            copyright.title,
            copyright.description,
            copyright.registrationTime,
            copyright.isActive
        );
    }

    function hasLicense(uint256 copyrightId, address licensee)
        external
        view
        copyrightExists(copyrightId)
        returns (bool)
    {
        return licenses[copyrightId][licensee];
    }

    function getOwnerCopyrights(address owner) external view returns (uint256[] memory) {
        return ownerCopyrights[owner];
    }

    function getTotalCopyrights() external view returns (uint256) {
        return nextCopyrightId - 1;
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
}
