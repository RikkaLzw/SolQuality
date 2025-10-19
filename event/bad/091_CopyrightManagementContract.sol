
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
        uint256 expirationDate;
        bool isActive;
    }

    mapping(uint256 => Copyright) public copyrights;
    mapping(uint256 => License) public licenses;
    mapping(address => uint256[]) public ownerCopyrights;
    mapping(address => uint256[]) public userLicenses;

    uint256 public nextCopyrightId = 1;
    uint256 public nextLicenseId = 1;
    address public admin;
    uint256 public platformFee = 100;

    error InvalidInput();
    error NotAuthorized();
    error AlreadyExists();
    error NotFound();

    event CopyrightRegistered(uint256 copyrightId, address owner, string title);
    event LicensePurchased(uint256 licenseId, address licensee, uint256 copyrightId);
    event CopyrightTransferred(uint256 copyrightId, address from, address to);

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    modifier onlyCopyrightOwner(uint256 _copyrightId) {
        require(copyrights[_copyrightId].owner == msg.sender);
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function registerCopyright(
        string memory _title,
        string memory _description,
        uint256 _licensePrice
    ) external {
        require(bytes(_title).length > 0);
        require(_licensePrice > 0);

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

    function purchaseLicense(uint256 _copyrightId, uint256 _duration) external payable {
        require(copyrights[_copyrightId].isActive);
        require(_duration > 0);
        require(msg.value >= copyrights[_copyrightId].licensePrice);

        uint256 licenseId = nextLicenseId++;
        uint256 expirationDate = block.timestamp + _duration;

        licenses[licenseId] = License({
            licensee: msg.sender,
            copyrightId: _copyrightId,
            expirationDate: expirationDate,
            isActive: true
        });

        userLicenses[msg.sender].push(licenseId);

        uint256 fee = (msg.value * platformFee) / 10000;
        uint256 ownerPayment = msg.value - fee;

        payable(copyrights[_copyrightId].owner).transfer(ownerPayment);
        payable(admin).transfer(fee);

        emit LicensePurchased(licenseId, msg.sender, _copyrightId);
    }

    function transferCopyright(uint256 _copyrightId, address _newOwner)
        external
        onlyCopyrightOwner(_copyrightId)
    {
        require(_newOwner != address(0));
        require(copyrights[_copyrightId].isActive);

        address oldOwner = copyrights[_copyrightId].owner;
        copyrights[_copyrightId].owner = _newOwner;


        uint256[] storage oldOwnerList = ownerCopyrights[oldOwner];
        for (uint256 i = 0; i < oldOwnerList.length; i++) {
            if (oldOwnerList[i] == _copyrightId) {
                oldOwnerList[i] = oldOwnerList[oldOwnerList.length - 1];
                oldOwnerList.pop();
                break;
            }
        }


        ownerCopyrights[_newOwner].push(_copyrightId);

        emit CopyrightTransferred(_copyrightId, oldOwner, _newOwner);
    }

    function updateLicensePrice(uint256 _copyrightId, uint256 _newPrice)
        external
        onlyCopyrightOwner(_copyrightId)
    {
        require(_newPrice > 0);
        require(copyrights[_copyrightId].isActive);

        copyrights[_copyrightId].licensePrice = _newPrice;

    }

    function deactivateCopyright(uint256 _copyrightId)
        external
        onlyCopyrightOwner(_copyrightId)
    {
        require(copyrights[_copyrightId].isActive);

        copyrights[_copyrightId].isActive = false;

    }

    function revokeLicense(uint256 _licenseId) external {
        require(licenses[_licenseId].isActive);

        uint256 copyrightId = licenses[_licenseId].copyrightId;
        require(copyrights[copyrightId].owner == msg.sender);

        licenses[_licenseId].isActive = false;

    }

    function updatePlatformFee(uint256 _newFee) external onlyAdmin {
        require(_newFee <= 1000);

        platformFee = _newFee;

    }

    function isLicenseValid(uint256 _licenseId) external view returns (bool) {
        License memory license = licenses[_licenseId];
        return license.isActive &&
               license.expirationDate > block.timestamp &&
               copyrights[license.copyrightId].isActive;
    }

    function getCopyrightsByOwner(address _owner) external view returns (uint256[] memory) {
        return ownerCopyrights[_owner];
    }

    function getLicensesByUser(address _user) external view returns (uint256[] memory) {
        return userLicenses[_user];
    }

    function withdrawFees() external onlyAdmin {
        require(address(this).balance > 0);

        payable(admin).transfer(address(this).balance);

    }
}
