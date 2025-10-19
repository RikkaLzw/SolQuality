
pragma solidity ^0.8.0;

contract CopyrightManagement {
    struct Copyright {
        address owner;
        string title;
        string description;
        uint256 registrationTime;
        bool isActive;
        uint256 licensePrice;
    }

    mapping(uint256 => Copyright) public copyrights;
    mapping(uint256 => mapping(address => bool)) public licenses;
    mapping(address => uint256[]) public ownerCopyrights;

    uint256 public nextCopyrightId = 1;
    address public admin;

    error InvalidId();
    error NotOwner();
    error InsufficientPayment();
    error AlreadyLicensed();

    event CopyrightRegistered(uint256 id, address owner, string title);
    event LicensePurchased(uint256 copyrightId, address licensee);
    event CopyrightTransferred(uint256 copyrightId, address newOwner);

    constructor() {
        admin = msg.sender;
    }

    function registerCopyright(
        string memory _title,
        string memory _description,
        uint256 _licensePrice
    ) external returns (uint256) {
        require(bytes(_title).length > 0);
        require(_licensePrice > 0);

        uint256 copyrightId = nextCopyrightId++;

        copyrights[copyrightId] = Copyright({
            owner: msg.sender,
            title: _title,
            description: _description,
            registrationTime: block.timestamp,
            isActive: true,
            licensePrice: _licensePrice
        });

        ownerCopyrights[msg.sender].push(copyrightId);

        emit CopyrightRegistered(copyrightId, msg.sender, _title);

        return copyrightId;
    }

    function purchaseLicense(uint256 _copyrightId) external payable {
        require(_copyrightId > 0 && _copyrightId < nextCopyrightId);

        Copyright storage copyright = copyrights[_copyrightId];
        require(copyright.isActive);
        require(msg.value >= copyright.licensePrice);
        require(!licenses[_copyrightId][msg.sender]);

        licenses[_copyrightId][msg.sender] = true;

        payable(copyright.owner).transfer(msg.value);

        emit LicensePurchased(_copyrightId, msg.sender);
    }

    function transferCopyright(uint256 _copyrightId, address _newOwner) external {
        require(_copyrightId > 0 && _copyrightId < nextCopyrightId);
        require(_newOwner != address(0));

        Copyright storage copyright = copyrights[_copyrightId];
        require(msg.sender == copyright.owner);


        uint256[] storage oldOwnerCopyrights = ownerCopyrights[copyright.owner];
        for (uint256 i = 0; i < oldOwnerCopyrights.length; i++) {
            if (oldOwnerCopyrights[i] == _copyrightId) {
                oldOwnerCopyrights[i] = oldOwnerCopyrights[oldOwnerCopyrights.length - 1];
                oldOwnerCopyrights.pop();
                break;
            }
        }

        copyright.owner = _newOwner;
        ownerCopyrights[_newOwner].push(_copyrightId);

        emit CopyrightTransferred(_copyrightId, _newOwner);
    }

    function updateLicensePrice(uint256 _copyrightId, uint256 _newPrice) external {
        require(_copyrightId > 0 && _copyrightId < nextCopyrightId);
        require(_newPrice > 0);

        Copyright storage copyright = copyrights[_copyrightId];
        require(msg.sender == copyright.owner);

        copyright.licensePrice = _newPrice;

    }

    function deactivateCopyright(uint256 _copyrightId) external {
        require(_copyrightId > 0 && _copyrightId < nextCopyrightId);

        Copyright storage copyright = copyrights[_copyrightId];
        require(msg.sender == copyright.owner || msg.sender == admin);

        copyright.isActive = false;

    }

    function hasLicense(uint256 _copyrightId, address _licensee) external view returns (bool) {
        return licenses[_copyrightId][_licensee];
    }

    function getCopyrightDetails(uint256 _copyrightId) external view returns (
        address owner,
        string memory title,
        string memory description,
        uint256 registrationTime,
        bool isActive,
        uint256 licensePrice
    ) {
        require(_copyrightId > 0 && _copyrightId < nextCopyrightId);

        Copyright storage copyright = copyrights[_copyrightId];
        return (
            copyright.owner,
            copyright.title,
            copyright.description,
            copyright.registrationTime,
            copyright.isActive,
            copyright.licensePrice
        );
    }

    function getOwnerCopyrights(address _owner) external view returns (uint256[] memory) {
        return ownerCopyrights[_owner];
    }
}
