
pragma solidity ^0.8.0;

contract CopyrightManagement {
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
    mapping(uint256 => License[]) public licenses;
    mapping(address => uint256[]) public ownerCopyrights;
    mapping(address => uint256[]) public licenseeRecords;

    uint256 public nextCopyrightId;
    uint256 public nextLicenseId;
    address public admin;
    uint256 public registrationFee;


    event CopyrightRegistered(uint256 copyrightId, address owner, string title);
    event LicenseGranted(uint256 licenseId, uint256 copyrightId, address licensee);
    event CopyrightTransferred(uint256 copyrightId, address from, address to);
    event LicenseRevoked(uint256 licenseId);


    error InvalidInput();
    error NotAuthorized();
    error Failed();

    constructor(uint256 _registrationFee) {
        admin = msg.sender;
        registrationFee = _registrationFee;
        nextCopyrightId = 1;
        nextLicenseId = 1;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    modifier onlyCopyrightOwner(uint256 _copyrightId) {
        require(copyrights[_copyrightId].owner == msg.sender);
        _;
    }

    function registerCopyright(
        string memory _title,
        string memory _description,
        uint256 _licensePrice
    ) external payable {
        require(msg.value >= registrationFee);
        require(bytes(_title).length > 0);

        uint256 copyrightId = nextCopyrightId;

        copyrights[copyrightId] = Copyright({
            owner: msg.sender,
            title: _title,
            description: _description,
            registrationDate: block.timestamp,
            isActive: true,
            licensePrice: _licensePrice
        });

        ownerCopyrights[msg.sender].push(copyrightId);
        nextCopyrightId++;


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

        emit CopyrightTransferred(_copyrightId, oldOwner, _newOwner);
    }

    function grantLicense(uint256 _copyrightId, address _licensee, uint256 _duration)
        external
        payable
        onlyCopyrightOwner(_copyrightId)
    {
        require(copyrights[_copyrightId].isActive);
        require(_licensee != address(0));
        require(msg.value >= copyrights[_copyrightId].licensePrice);

        uint256 licenseId = nextLicenseId;

        License memory newLicense = License({
            licensee: _licensee,
            copyrightId: _copyrightId,
            expirationDate: block.timestamp + _duration,
            isActive: true
        });

        licenses[licenseId].push(newLicense);
        licenseeRecords[_licensee].push(licenseId);
        nextLicenseId++;

        emit LicenseGranted(licenseId, _copyrightId, _licensee);
    }

    function revokeLicense(uint256 _licenseId) external {
        require(_licenseId < nextLicenseId);

        bool found = false;
        for (uint256 i = 0; i < licenses[_licenseId].length; i++) {
            License storage license = licenses[_licenseId][i];
            uint256 copyrightId = license.copyrightId;

            if (copyrights[copyrightId].owner == msg.sender && license.isActive) {
                license.isActive = false;
                found = true;
                break;
            }
        }

        require(found);

        emit LicenseRevoked(_licenseId);
    }

    function deactivateCopyright(uint256 _copyrightId)
        external
        onlyCopyrightOwner(_copyrightId)
    {
        require(copyrights[_copyrightId].isActive);


        copyrights[_copyrightId].isActive = false;


        for (uint256 i = 1; i < nextLicenseId; i++) {
            for (uint256 j = 0; j < licenses[i].length; j++) {
                if (licenses[i][j].copyrightId == _copyrightId) {
                    licenses[i][j].isActive = false;
                }
            }
        }
    }

    function updateLicensePrice(uint256 _copyrightId, uint256 _newPrice)
        external
        onlyCopyrightOwner(_copyrightId)
    {
        require(copyrights[_copyrightId].isActive);


        copyrights[_copyrightId].licensePrice = _newPrice;
    }

    function setRegistrationFee(uint256 _newFee) external onlyAdmin {

        registrationFee = _newFee;
    }

    function isLicenseValid(uint256 _licenseId, address _licensee)
        external
        view
        returns (bool)
    {
        require(_licenseId < nextLicenseId);

        for (uint256 i = 0; i < licenses[_licenseId].length; i++) {
            License memory license = licenses[_licenseId][i];
            if (license.licensee == _licensee &&
                license.isActive &&
                license.expirationDate > block.timestamp) {
                return true;
            }
        }
        return false;
    }

    function getCopyrightDetails(uint256 _copyrightId)
        external
        view
        returns (
            address owner,
            string memory title,
            string memory description,
            uint256 registrationDate,
            bool isActive,
            uint256 licensePrice
        )
    {
        require(_copyrightId < nextCopyrightId);

        Copyright memory copyright = copyrights[_copyrightId];
        return (
            copyright.owner,
            copyright.title,
            copyright.description,
            copyright.registrationDate,
            copyright.isActive,
            copyright.licensePrice
        );
    }

    function getOwnerCopyrights(address _owner)
        external
        view
        returns (uint256[] memory)
    {
        return ownerCopyrights[_owner];
    }

    function getLicenseeRecords(address _licensee)
        external
        view
        returns (uint256[] memory)
    {
        return licenseeRecords[_licensee];
    }

    function withdrawFees() external onlyAdmin {
        uint256 balance = address(this).balance;
        require(balance > 0);


        require(payable(admin).send(balance));
    }


    function emergencyStop(uint256 _copyrightId) external onlyAdmin {
        if (!copyrights[_copyrightId].isActive) {
            revert Failed();
        }

        copyrights[_copyrightId].isActive = false;
    }
}
