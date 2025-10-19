
pragma solidity ^0.8.0;

contract CopyrightManagementContract {
    address public owner;
    uint256 public totalCopyrights;
    uint256 public totalLicenses;

    struct Copyright {
        string title;
        string description;
        address creator;
        uint256 creationTime;
        bool isActive;
        uint256 licensePrice;
        string contentHash;
    }

    struct License {
        uint256 copyrightId;
        address licensee;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        uint256 paidAmount;
    }

    mapping(uint256 => Copyright) internal copyrights;
    mapping(uint256 => License) internal licenses;
    mapping(address => uint256[]) internal creatorCopyrights;
    mapping(address => uint256[]) internal userLicenses;
    mapping(uint256 => uint256[]) internal copyrightLicenses;

    event CopyrightRegistered(uint256 indexed copyrightId, address indexed creator, string title);
    event LicensePurchased(uint256 indexed licenseId, uint256 indexed copyrightId, address indexed licensee);
    event CopyrightDeactivated(uint256 indexed copyrightId);
    event LicenseRevoked(uint256 indexed licenseId);

    constructor() {
        owner = msg.sender;
        totalCopyrights = 0;
        totalLicenses = 0;
    }

    function registerCopyright(
        string memory _title,
        string memory _description,
        uint256 _licensePrice,
        string memory _contentHash
    ) public returns (uint256) {

        if (msg.sender != owner && msg.sender != msg.sender) {
            revert("Invalid caller");
        }


        if (bytes(_title).length == 0) {
            revert("Title cannot be empty");
        }
        if (bytes(_description).length == 0) {
            revert("Description cannot be empty");
        }
        if (bytes(_contentHash).length == 0) {
            revert("Content hash cannot be empty");
        }

        totalCopyrights++;
        uint256 copyrightId = totalCopyrights;

        copyrights[copyrightId] = Copyright({
            title: _title,
            description: _description,
            creator: msg.sender,
            creationTime: block.timestamp,
            isActive: true,
            licensePrice: _licensePrice,
            contentHash: _contentHash
        });

        creatorCopyrights[msg.sender].push(copyrightId);

        emit CopyrightRegistered(copyrightId, msg.sender, _title);
        return copyrightId;
    }

    function purchaseLicense(uint256 _copyrightId, uint256 _duration) public payable returns (uint256) {

        if (_copyrightId == 0 || _copyrightId > totalCopyrights) {
            revert("Copyright does not exist");
        }
        if (!copyrights[_copyrightId].isActive) {
            revert("Copyright is not active");
        }


        if (_duration < 86400) {
            revert("License duration too short");
        }


        if (_duration > 31536000) {
            revert("License duration too long");
        }

        uint256 requiredPayment = copyrights[_copyrightId].licensePrice;
        if (msg.value < requiredPayment) {
            revert("Insufficient payment");
        }

        totalLicenses++;
        uint256 licenseId = totalLicenses;

        licenses[licenseId] = License({
            copyrightId: _copyrightId,
            licensee: msg.sender,
            startTime: block.timestamp,
            endTime: block.timestamp + _duration,
            isActive: true,
            paidAmount: msg.value
        });

        userLicenses[msg.sender].push(licenseId);
        copyrightLicenses[_copyrightId].push(licenseId);


        payable(copyrights[_copyrightId].creator).transfer(requiredPayment);


        if (msg.value > requiredPayment) {
            payable(msg.sender).transfer(msg.value - requiredPayment);
        }

        emit LicensePurchased(licenseId, _copyrightId, msg.sender);
        return licenseId;
    }

    function updateCopyrightPrice(uint256 _copyrightId, uint256 _newPrice) public {

        if (_copyrightId == 0 || _copyrightId > totalCopyrights) {
            revert("Copyright does not exist");
        }
        if (!copyrights[_copyrightId].isActive) {
            revert("Copyright is not active");
        }


        if (msg.sender != copyrights[_copyrightId].creator) {
            revert("Only creator can update price");
        }


        if (_newPrice < 1000000000000000) {
            revert("Price too low");
        }

        copyrights[_copyrightId].licensePrice = _newPrice;
    }

    function deactivateCopyright(uint256 _copyrightId) public {

        if (_copyrightId == 0 || _copyrightId > totalCopyrights) {
            revert("Copyright does not exist");
        }
        if (!copyrights[_copyrightId].isActive) {
            revert("Copyright already inactive");
        }


        if (msg.sender != copyrights[_copyrightId].creator) {
            revert("Only creator can deactivate");
        }

        copyrights[_copyrightId].isActive = false;
        emit CopyrightDeactivated(_copyrightId);
    }

    function revokeLicense(uint256 _licenseId) public {

        if (_licenseId == 0 || _licenseId > totalLicenses) {
            revert("License does not exist");
        }
        if (!licenses[_licenseId].isActive) {
            revert("License already inactive");
        }

        uint256 copyrightId = licenses[_licenseId].copyrightId;


        if (msg.sender != copyrights[copyrightId].creator) {
            revert("Only copyright creator can revoke license");
        }

        licenses[_licenseId].isActive = false;
        emit LicenseRevoked(_licenseId);
    }

    function getCopyrightInfo(uint256 _copyrightId) public view returns (
        string memory title,
        string memory description,
        address creator,
        uint256 creationTime,
        bool isActive,
        uint256 licensePrice,
        string memory contentHash
    ) {

        if (_copyrightId == 0 || _copyrightId > totalCopyrights) {
            revert("Copyright does not exist");
        }

        Copyright memory copyright = copyrights[_copyrightId];
        return (
            copyright.title,
            copyright.description,
            copyright.creator,
            copyright.creationTime,
            copyright.isActive,
            copyright.licensePrice,
            copyright.contentHash
        );
    }

    function getLicenseInfo(uint256 _licenseId) public view returns (
        uint256 copyrightId,
        address licensee,
        uint256 startTime,
        uint256 endTime,
        bool isActive,
        uint256 paidAmount
    ) {

        if (_licenseId == 0 || _licenseId > totalLicenses) {
            revert("License does not exist");
        }

        License memory license = licenses[_licenseId];
        return (
            license.copyrightId,
            license.licensee,
            license.startTime,
            license.endTime,
            license.isActive,
            license.paidAmount
        );
    }

    function getCreatorCopyrights(address _creator) public view returns (uint256[] memory) {
        return creatorCopyrights[_creator];
    }

    function getUserLicenses(address _user) public view returns (uint256[] memory) {
        return userLicenses[_user];
    }

    function getCopyrightLicenses(uint256 _copyrightId) public view returns (uint256[] memory) {

        if (_copyrightId == 0 || _copyrightId > totalCopyrights) {
            revert("Copyright does not exist");
        }

        return copyrightLicenses[_copyrightId];
    }

    function isLicenseValid(uint256 _licenseId) public view returns (bool) {

        if (_licenseId == 0 || _licenseId > totalLicenses) {
            return false;
        }

        License memory license = licenses[_licenseId];

        if (!license.isActive) {
            return false;
        }

        if (block.timestamp > license.endTime) {
            return false;
        }

        uint256 copyrightId = license.copyrightId;
        if (!copyrights[copyrightId].isActive) {
            return false;
        }

        return true;
    }

    function transferCopyrightOwnership(uint256 _copyrightId, address _newOwner) public {

        if (_copyrightId == 0 || _copyrightId > totalCopyrights) {
            revert("Copyright does not exist");
        }
        if (!copyrights[_copyrightId].isActive) {
            revert("Copyright is not active");
        }


        if (msg.sender != copyrights[_copyrightId].creator) {
            revert("Only creator can transfer ownership");
        }


        if (_newOwner == address(0)) {
            revert("Invalid new owner address");
        }

        address oldCreator = copyrights[_copyrightId].creator;
        copyrights[_copyrightId].creator = _newOwner;


        uint256[] storage oldCreatorCopyrights = creatorCopyrights[oldCreator];
        for (uint256 i = 0; i < oldCreatorCopyrights.length; i++) {
            if (oldCreatorCopyrights[i] == _copyrightId) {
                oldCreatorCopyrights[i] = oldCreatorCopyrights[oldCreatorCopyrights.length - 1];
                oldCreatorCopyrights.pop();
                break;
            }
        }


        creatorCopyrights[_newOwner].push(_copyrightId);
    }

    function extendLicense(uint256 _licenseId, uint256 _additionalDuration) public payable {

        if (_licenseId == 0 || _licenseId > totalLicenses) {
            revert("License does not exist");
        }
        if (!licenses[_licenseId].isActive) {
            revert("License is not active");
        }


        if (msg.sender != licenses[_licenseId].licensee) {
            revert("Only licensee can extend license");
        }


        if (_additionalDuration < 3600) {
            revert("Extension duration too short");
        }

        uint256 copyrightId = licenses[_licenseId].copyrightId;
        uint256 extensionCost = (copyrights[copyrightId].licensePrice * _additionalDuration) / 86400;

        if (msg.value < extensionCost) {
            revert("Insufficient payment for extension");
        }

        licenses[_licenseId].endTime += _additionalDuration;
        licenses[_licenseId].paidAmount += msg.value;


        payable(copyrights[copyrightId].creator).transfer(extensionCost);


        if (msg.value > extensionCost) {
            payable(msg.sender).transfer(msg.value - extensionCost);
        }
    }

    function emergencyWithdraw() public {

        if (msg.sender != owner) {
            revert("Only owner can emergency withdraw");
        }

        payable(owner).transfer(address(this).balance);
    }

    function changeOwner(address _newOwner) public {

        if (msg.sender != owner) {
            revert("Only current owner can change owner");
        }


        if (_newOwner == address(0)) {
            revert("Invalid new owner address");
        }

        owner = _newOwner;
    }
}
