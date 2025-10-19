
pragma solidity ^0.8.0;

contract CopyrightManagementContract {
    struct Copyright {
        string title;
        string description;
        address owner;
        uint256 registrationDate;
        bool isActive;
        uint256 royaltyPercentage;
    }

    struct License {
        uint256 copyrightId;
        address licensee;
        uint256 startDate;
        uint256 endDate;
        uint256 fee;
        bool isActive;
    }

    mapping(uint256 => Copyright) public copyrights;
    mapping(uint256 => License) public licenses;
    mapping(address => uint256[]) public ownerCopyrights;
    mapping(address => uint256[]) public licensesByUser;

    uint256 public nextCopyrightId = 1;
    uint256 public nextLicenseId = 1;
    address public admin;
    uint256 public registrationFee = 0.01 ether;

    error InvalidInput();
    error NotAuthorized();
    error InsufficientFunds();
    error AlreadyExists();

    event CopyrightRegistered(uint256 copyrightId, address owner, string title);
    event LicenseGranted(uint256 licenseId, uint256 copyrightId, address licensee);
    event RoyaltyPaid(uint256 copyrightId, address payer, uint256 amount);

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
        uint256 _royaltyPercentage
    ) external payable {
        require(msg.value >= registrationFee);
        require(bytes(_title).length > 0);
        require(_royaltyPercentage <= 100);

        uint256 copyrightId = nextCopyrightId++;

        copyrights[copyrightId] = Copyright({
            title: _title,
            description: _description,
            owner: msg.sender,
            registrationDate: block.timestamp,
            isActive: true,
            royaltyPercentage: _royaltyPercentage
        });

        ownerCopyrights[msg.sender].push(copyrightId);

        emit CopyrightRegistered(copyrightId, msg.sender, _title);
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
    }

    function grantLicense(
        uint256 _copyrightId,
        address _licensee,
        uint256 _duration,
        uint256 _fee
    ) external onlyCopyrightOwner(_copyrightId) {
        require(_licensee != address(0));
        require(_duration > 0);
        require(copyrights[_copyrightId].isActive);

        uint256 licenseId = nextLicenseId++;

        licenses[licenseId] = License({
            copyrightId: _copyrightId,
            licensee: _licensee,
            startDate: block.timestamp,
            endDate: block.timestamp + _duration,
            fee: _fee,
            isActive: true
        });

        licensesByUser[_licensee].push(licenseId);

        emit LicenseGranted(licenseId, _copyrightId, _licensee);
    }

    function payRoyalty(uint256 _copyrightId) external payable {
        require(copyrights[_copyrightId].isActive);
        require(msg.value > 0);

        Copyright storage copyright = copyrights[_copyrightId];
        uint256 royaltyAmount = (msg.value * copyright.royaltyPercentage) / 100;
        uint256 remainingAmount = msg.value - royaltyAmount;

        payable(copyright.owner).transfer(royaltyAmount);

        if (remainingAmount > 0) {
            payable(msg.sender).transfer(remainingAmount);
        }

        emit RoyaltyPaid(_copyrightId, msg.sender, royaltyAmount);
    }

    function revokeLicense(uint256 _licenseId) external {
        License storage license = licenses[_licenseId];
        require(copyrights[license.copyrightId].owner == msg.sender);
        require(license.isActive);

        license.isActive = false;
    }

    function updateRoyaltyPercentage(uint256 _copyrightId, uint256 _newPercentage)
        external
        onlyCopyrightOwner(_copyrightId)
    {
        require(_newPercentage <= 100);
        require(copyrights[_copyrightId].isActive);

        copyrights[_copyrightId].royaltyPercentage = _newPercentage;
    }

    function deactivateCopyright(uint256 _copyrightId)
        external
        onlyCopyrightOwner(_copyrightId)
    {
        require(copyrights[_copyrightId].isActive);

        copyrights[_copyrightId].isActive = false;
    }

    function updateRegistrationFee(uint256 _newFee) external onlyAdmin {
        require(_newFee > 0);

        registrationFee = _newFee;
    }

    function withdrawFees() external onlyAdmin {
        require(address(this).balance > 0);

        payable(admin).transfer(address(this).balance);
    }

    function getCopyrightsByOwner(address _owner)
        external
        view
        returns (uint256[] memory)
    {
        return ownerCopyrights[_owner];
    }

    function getLicensesByUser(address _user)
        external
        view
        returns (uint256[] memory)
    {
        return licensesByUser[_user];
    }

    function isLicenseValid(uint256 _licenseId) external view returns (bool) {
        License storage license = licenses[_licenseId];
        return license.isActive &&
               block.timestamp >= license.startDate &&
               block.timestamp <= license.endDate;
    }

    function getCopyrightInfo(uint256 _copyrightId)
        external
        view
        returns (
            string memory title,
            string memory description,
            address owner,
            uint256 registrationDate,
            bool isActive,
            uint256 royaltyPercentage
        )
    {
        Copyright storage copyright = copyrights[_copyrightId];
        return (
            copyright.title,
            copyright.description,
            copyright.owner,
            copyright.registrationDate,
            copyright.isActive,
            copyright.royaltyPercentage
        );
    }
}
