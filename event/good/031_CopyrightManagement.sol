
pragma solidity ^0.8.0;

contract CopyrightManagement {
    struct Copyright {
        string title;
        string description;
        address owner;
        uint256 registrationDate;
        bool isActive;
        string ipfsHash;
        uint256 royaltyPercentage;
    }

    struct License {
        uint256 copyrightId;
        address licensee;
        uint256 startDate;
        uint256 endDate;
        uint256 fee;
        bool isActive;
        string licenseType;
    }

    mapping(uint256 => Copyright) public copyrights;
    mapping(uint256 => License) public licenses;
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
        uint256 fee
    );

    event LicenseRevoked(
        uint256 indexed licenseId,
        uint256 indexed copyrightId,
        address indexed licensee
    );

    event RoyaltyPaid(
        uint256 indexed copyrightId,
        address indexed payer,
        address indexed recipient,
        uint256 amount
    );

    event CopyrightDeactivated(
        uint256 indexed copyrightId,
        address indexed owner
    );

    event RegistrationFeeUpdated(
        uint256 previousFee,
        uint256 newFee
    );

    modifier onlyAdmin() {
        require(msg.sender == admin, "CopyrightManagement: Only admin can perform this action");
        _;
    }

    modifier onlyCopyrightOwner(uint256 _copyrightId) {
        require(_copyrightId > 0 && _copyrightId < nextCopyrightId, "CopyrightManagement: Invalid copyright ID");
        require(copyrights[_copyrightId].owner == msg.sender, "CopyrightManagement: Only copyright owner can perform this action");
        _;
    }

    modifier copyrightExists(uint256 _copyrightId) {
        require(_copyrightId > 0 && _copyrightId < nextCopyrightId, "CopyrightManagement: Copyright does not exist");
        require(copyrights[_copyrightId].isActive, "CopyrightManagement: Copyright is not active");
        _;
    }

    modifier licenseExists(uint256 _licenseId) {
        require(_licenseId > 0 && _licenseId < nextLicenseId, "CopyrightManagement: License does not exist");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function registerCopyright(
        string memory _title,
        string memory _description,
        string memory _ipfsHash,
        uint256 _royaltyPercentage
    ) external payable returns (uint256) {
        require(msg.value >= registrationFee, "CopyrightManagement: Insufficient registration fee");
        require(bytes(_title).length > 0, "CopyrightManagement: Title cannot be empty");
        require(bytes(_description).length > 0, "CopyrightManagement: Description cannot be empty");
        require(bytes(_ipfsHash).length > 0, "CopyrightManagement: IPFS hash cannot be empty");
        require(_royaltyPercentage <= 100, "CopyrightManagement: Royalty percentage cannot exceed 100%");

        uint256 copyrightId = nextCopyrightId++;

        copyrights[copyrightId] = Copyright({
            title: _title,
            description: _description,
            owner: msg.sender,
            registrationDate: block.timestamp,
            isActive: true,
            ipfsHash: _ipfsHash,
            royaltyPercentage: _royaltyPercentage
        });

        ownerCopyrights[msg.sender].push(copyrightId);

        emit CopyrightRegistered(copyrightId, msg.sender, _title, block.timestamp);

        return copyrightId;
    }

    function transferCopyright(uint256 _copyrightId, address _newOwner)
        external
        onlyCopyrightOwner(_copyrightId)
        copyrightExists(_copyrightId)
    {
        require(_newOwner != address(0), "CopyrightManagement: New owner cannot be zero address");
        require(_newOwner != msg.sender, "CopyrightManagement: Cannot transfer to yourself");

        address previousOwner = copyrights[_copyrightId].owner;
        copyrights[_copyrightId].owner = _newOwner;


        uint256[] storage prevOwnerCopyrights = ownerCopyrights[previousOwner];
        for (uint256 i = 0; i < prevOwnerCopyrights.length; i++) {
            if (prevOwnerCopyrights[i] == _copyrightId) {
                prevOwnerCopyrights[i] = prevOwnerCopyrights[prevOwnerCopyrights.length - 1];
                prevOwnerCopyrights.pop();
                break;
            }
        }


        ownerCopyrights[_newOwner].push(_copyrightId);

        emit CopyrightTransferred(_copyrightId, previousOwner, _newOwner);
    }

    function grantLicense(
        uint256 _copyrightId,
        address _licensee,
        uint256 _duration,
        uint256 _fee,
        string memory _licenseType
    ) external onlyCopyrightOwner(_copyrightId) copyrightExists(_copyrightId) returns (uint256) {
        require(_licensee != address(0), "CopyrightManagement: Licensee cannot be zero address");
        require(_licensee != msg.sender, "CopyrightManagement: Cannot license to yourself");
        require(_duration > 0, "CopyrightManagement: License duration must be greater than zero");
        require(bytes(_licenseType).length > 0, "CopyrightManagement: License type cannot be empty");

        uint256 licenseId = nextLicenseId++;
        uint256 startDate = block.timestamp;
        uint256 endDate = startDate + _duration;

        licenses[licenseId] = License({
            copyrightId: _copyrightId,
            licensee: _licensee,
            startDate: startDate,
            endDate: endDate,
            fee: _fee,
            isActive: true,
            licenseType: _licenseType
        });

        licenseeLicenses[_licensee].push(licenseId);

        emit LicenseGranted(licenseId, _copyrightId, _licensee, startDate, endDate, _fee);

        return licenseId;
    }

    function revokeLicense(uint256 _licenseId)
        external
        licenseExists(_licenseId)
    {
        License storage license = licenses[_licenseId];
        require(license.isActive, "CopyrightManagement: License is already inactive");

        uint256 copyrightId = license.copyrightId;
        require(copyrights[copyrightId].owner == msg.sender, "CopyrightManagement: Only copyright owner can revoke license");

        license.isActive = false;

        emit LicenseRevoked(_licenseId, copyrightId, license.licensee);
    }

    function payRoyalty(uint256 _copyrightId)
        external
        payable
        copyrightExists(_copyrightId)
    {
        require(msg.value > 0, "CopyrightManagement: Royalty amount must be greater than zero");

        Copyright storage copyright = copyrights[_copyrightId];
        address owner = copyright.owner;
        uint256 royaltyAmount = (msg.value * copyright.royaltyPercentage) / 100;

        if (royaltyAmount > 0) {
            (bool success, ) = payable(owner).call{value: royaltyAmount}("");
            require(success, "CopyrightManagement: Failed to send royalty payment");

            emit RoyaltyPaid(_copyrightId, msg.sender, owner, royaltyAmount);
        }


        uint256 excess = msg.value - royaltyAmount;
        if (excess > 0) {
            (bool refundSuccess, ) = payable(msg.sender).call{value: excess}("");
            require(refundSuccess, "CopyrightManagement: Failed to refund excess payment");
        }
    }

    function deactivateCopyright(uint256 _copyrightId)
        external
        onlyCopyrightOwner(_copyrightId)
        copyrightExists(_copyrightId)
    {
        copyrights[_copyrightId].isActive = false;
        emit CopyrightDeactivated(_copyrightId, msg.sender);
    }

    function updateRegistrationFee(uint256 _newFee) external onlyAdmin {
        uint256 previousFee = registrationFee;
        registrationFee = _newFee;
        emit RegistrationFeeUpdated(previousFee, _newFee);
    }

    function isLicenseValid(uint256 _licenseId) external view returns (bool) {
        if (_licenseId == 0 || _licenseId >= nextLicenseId) {
            return false;
        }

        License storage license = licenses[_licenseId];
        return license.isActive &&
               block.timestamp >= license.startDate &&
               block.timestamp <= license.endDate;
    }

    function getCopyrightsByOwner(address _owner) external view returns (uint256[] memory) {
        return ownerCopyrights[_owner];
    }

    function getLicensesByLicensee(address _licensee) external view returns (uint256[] memory) {
        return licenseeLicenses[_licensee];
    }

    function withdrawFees() external onlyAdmin {
        uint256 balance = address(this).balance;
        require(balance > 0, "CopyrightManagement: No fees to withdraw");

        (bool success, ) = payable(admin).call{value: balance}("");
        require(success, "CopyrightManagement: Failed to withdraw fees");
    }

    receive() external payable {
        revert("CopyrightManagement: Direct payments not accepted");
    }
}
