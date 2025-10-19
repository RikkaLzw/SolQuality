
pragma solidity ^0.8.0;

contract CopyrightManagementContract {
    struct Copyright {
        address owner;
        string title;
        string description;
        uint256 registrationDate;
        bool isActive;
        uint256 licensePrice;
    }

    struct License {
        address licensee;
        uint256 copyrightId;
        uint256 startDate;
        uint256 endDate;
        bool isActive;
    }

    mapping(uint256 => Copyright) public copyrights;
    mapping(uint256 => License[]) public licenses;
    mapping(address => uint256[]) public ownerCopyrights;
    mapping(address => uint256[]) public licenseeLicenses;

    uint256 public nextCopyrightId = 1;
    uint256 public registrationFee = 0.01 ether;
    address public admin;

    error InvalidInput();
    error NotAuthorized();
    error InsufficientFunds();
    error NotFound();

    event CopyrightRegistered(uint256 copyrightId, address owner, string title);
    event LicenseGranted(uint256 copyrightId, address licensee, uint256 startDate, uint256 endDate);
    event CopyrightTransferred(uint256 copyrightId, address from, address to);

    constructor() {
        admin = msg.sender;
    }

    function registerCopyright(
        string memory _title,
        string memory _description,
        uint256 _licensePrice
    ) external payable {
        require(msg.value >= registrationFee);
        require(bytes(_title).length > 0);

        uint256 copyrightId = nextCopyrightId++;

        copyrights[copyrightId] = Copyright({
            owner: msg.sender,
            title: _title,
            description: _description,
            registrationDate: block.timestamp,
            isActive: true,
            licensePrice: _licensePrice
        });

        ownerCopyrights[msg.sender].push(copyrightId);

        emit CopyrightRegistered(copyrightId, msg.sender, _title);
    }

    function grantLicense(
        uint256 _copyrightId,
        address _licensee,
        uint256 _duration
    ) external payable {
        Copyright storage copyright = copyrights[_copyrightId];
        require(copyright.owner == msg.sender);
        require(copyright.isActive);
        require(_licensee != address(0));
        require(msg.value >= copyright.licensePrice);

        uint256 startDate = block.timestamp;
        uint256 endDate = startDate + _duration;

        License memory newLicense = License({
            licensee: _licensee,
            copyrightId: _copyrightId,
            startDate: startDate,
            endDate: endDate,
            isActive: true
        });

        licenses[_copyrightId].push(newLicense);
        licenseeLicenses[_licensee].push(_copyrightId);

        emit LicenseGranted(_copyrightId, _licensee, startDate, endDate);
    }

    function transferCopyright(uint256 _copyrightId, address _newOwner) external {
        Copyright storage copyright = copyrights[_copyrightId];
        require(copyright.owner == msg.sender);
        require(_newOwner != address(0));
        require(copyright.isActive);

        address oldOwner = copyright.owner;
        copyright.owner = _newOwner;


        uint256[] storage oldOwnerCopyrights = ownerCopyrights[oldOwner];
        for (uint256 i = 0; i < oldOwnerCopyrights.length; i++) {
            if (oldOwnerCopyrights[i] == _copyrightId) {
                oldOwnerCopyrights[i] = oldOwnerCopyrights[oldOwnerCopyrights.length - 1];
                oldOwnerCopyrights.pop();
                break;
            }
        }


        ownerCopyrights[_newOwner].push(_copyrightId);

        emit CopyrightTransferred(_copyrightId, oldOwner, _newOwner);
    }

    function updateLicensePrice(uint256 _copyrightId, uint256 _newPrice) external {
        Copyright storage copyright = copyrights[_copyrightId];
        require(copyright.owner == msg.sender);
        require(copyright.isActive);

        copyright.licensePrice = _newPrice;

    }

    function deactivateCopyright(uint256 _copyrightId) external {
        Copyright storage copyright = copyrights[_copyrightId];
        require(copyright.owner == msg.sender);
        require(copyright.isActive);

        copyright.isActive = false;

    }

    function revokeLicense(uint256 _copyrightId, uint256 _licenseIndex) external {
        Copyright storage copyright = copyrights[_copyrightId];
        require(copyright.owner == msg.sender);
        require(_licenseIndex < licenses[_copyrightId].length);

        licenses[_copyrightId][_licenseIndex].isActive = false;

    }

    function updateRegistrationFee(uint256 _newFee) external {
        require(msg.sender == admin);

        registrationFee = _newFee;

    }

    function withdrawFunds() external {
        require(msg.sender == admin);

        uint256 balance = address(this).balance;
        require(balance > 0);

        payable(admin).transfer(balance);

    }

    function getCopyright(uint256 _copyrightId) external view returns (Copyright memory) {
        require(_copyrightId > 0 && _copyrightId < nextCopyrightId);
        return copyrights[_copyrightId];
    }

    function getLicenses(uint256 _copyrightId) external view returns (License[] memory) {
        return licenses[_copyrightId];
    }

    function getOwnerCopyrights(address _owner) external view returns (uint256[] memory) {
        return ownerCopyrights[_owner];
    }

    function getLicenseeLicenses(address _licensee) external view returns (uint256[] memory) {
        return licenseeLicenses[_licensee];
    }

    function isLicenseValid(uint256 _copyrightId, address _licensee) external view returns (bool) {
        License[] memory copyrightLicenses = licenses[_copyrightId];

        for (uint256 i = 0; i < copyrightLicenses.length; i++) {
            if (copyrightLicenses[i].licensee == _licensee &&
                copyrightLicenses[i].isActive &&
                block.timestamp >= copyrightLicenses[i].startDate &&
                block.timestamp <= copyrightLicenses[i].endDate) {
                return true;
            }
        }

        return false;
    }
}
