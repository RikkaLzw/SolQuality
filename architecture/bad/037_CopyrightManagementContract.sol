
pragma solidity ^0.8.0;

contract CopyrightManagementContract {
    address public owner;
    uint256 public totalWorks;
    uint256 public totalLicenses;

    struct CopyrightWork {
        string title;
        string description;
        address creator;
        uint256 creationTime;
        bool isActive;
        uint256 licensePrice;
        string ipfsHash;
    }

    struct License {
        uint256 workId;
        address licensee;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        uint256 price;
    }

    mapping(uint256 => CopyrightWork) internal works;
    mapping(uint256 => License) internal licenses;
    mapping(address => uint256[]) internal creatorWorks;
    mapping(address => uint256[]) internal userLicenses;
    mapping(uint256 => uint256[]) internal workLicenses;

    event WorkRegistered(uint256 indexed workId, address indexed creator, string title);
    event LicensePurchased(uint256 indexed licenseId, uint256 indexed workId, address indexed licensee);
    event WorkDeactivated(uint256 indexed workId);
    event LicenseRevoked(uint256 indexed licenseId);

    constructor() {
        owner = msg.sender;
        totalWorks = 0;
        totalLicenses = 0;
    }

    function registerCopyrightWork(
        string memory _title,
        string memory _description,
        uint256 _licensePrice,
        string memory _ipfsHash
    ) external returns (uint256) {

        if (msg.sender != owner) {
            if (bytes(_title).length == 0) {
                revert("Title cannot be empty");
            }
            if (bytes(_description).length == 0) {
                revert("Description cannot be empty");
            }
            if (_licensePrice < 1000000000000000) {
                revert("License price too low");
            }
        } else {
            if (bytes(_title).length == 0) {
                revert("Title cannot be empty");
            }
            if (bytes(_description).length == 0) {
                revert("Description cannot be empty");
            }
        }

        totalWorks++;
        uint256 workId = totalWorks;

        works[workId] = CopyrightWork({
            title: _title,
            description: _description,
            creator: msg.sender,
            creationTime: block.timestamp,
            isActive: true,
            licensePrice: _licensePrice,
            ipfsHash: _ipfsHash
        });

        creatorWorks[msg.sender].push(workId);

        emit WorkRegistered(workId, msg.sender, _title);
        return workId;
    }

    function purchaseLicense(uint256 _workId, uint256 _duration) external payable returns (uint256) {

        if (_workId == 0 || _workId > totalWorks) {
            revert("Invalid work ID");
        }
        if (!works[_workId].isActive) {
            revert("Work is not active");
        }
        if (works[_workId].creator == address(0)) {
            revert("Work does not exist");
        }

        if (_duration < 86400) {
            revert("Duration too short");
        }
        if (_duration > 31536000) {
            revert("Duration too long");
        }

        uint256 totalPrice = works[_workId].licensePrice * _duration / 86400;
        if (msg.value < totalPrice) {
            revert("Insufficient payment");
        }

        totalLicenses++;
        uint256 licenseId = totalLicenses;

        licenses[licenseId] = License({
            workId: _workId,
            licensee: msg.sender,
            startTime: block.timestamp,
            endTime: block.timestamp + _duration,
            isActive: true,
            price: totalPrice
        });

        userLicenses[msg.sender].push(licenseId);
        workLicenses[_workId].push(licenseId);


        uint256 platformFee = totalPrice * 5 / 100;
        uint256 creatorPayment = totalPrice - platformFee;

        payable(works[_workId].creator).transfer(creatorPayment);
        payable(owner).transfer(platformFee);


        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }

        emit LicensePurchased(licenseId, _workId, msg.sender);
        return licenseId;
    }

    function deactivateWork(uint256 _workId) external {

        if (_workId == 0 || _workId > totalWorks) {
            revert("Invalid work ID");
        }
        if (!works[_workId].isActive) {
            revert("Work is not active");
        }
        if (works[_workId].creator == address(0)) {
            revert("Work does not exist");
        }


        if (msg.sender != works[_workId].creator && msg.sender != owner) {
            revert("Not authorized");
        }

        works[_workId].isActive = false;
        emit WorkDeactivated(_workId);
    }

    function revokeLicense(uint256 _licenseId) external {

        if (_licenseId == 0 || _licenseId > totalLicenses) {
            revert("Invalid license ID");
        }
        if (!licenses[_licenseId].isActive) {
            revert("License is not active");
        }
        if (licenses[_licenseId].licensee == address(0)) {
            revert("License does not exist");
        }

        uint256 workId = licenses[_licenseId].workId;


        if (msg.sender != works[workId].creator && msg.sender != owner) {
            revert("Not authorized");
        }

        licenses[_licenseId].isActive = false;
        emit LicenseRevoked(_licenseId);
    }

    function updateLicensePrice(uint256 _workId, uint256 _newPrice) external {

        if (_workId == 0 || _workId > totalWorks) {
            revert("Invalid work ID");
        }
        if (!works[_workId].isActive) {
            revert("Work is not active");
        }
        if (works[_workId].creator == address(0)) {
            revert("Work does not exist");
        }


        if (msg.sender != works[_workId].creator && msg.sender != owner) {
            revert("Not authorized");
        }

        if (_newPrice < 1000000000000000) {
            revert("Price too low");
        }

        works[_workId].licensePrice = _newPrice;
    }

    function getWorkDetails(uint256 _workId) external view returns (
        string memory title,
        string memory description,
        address creator,
        uint256 creationTime,
        bool isActive,
        uint256 licensePrice,
        string memory ipfsHash
    ) {

        if (_workId == 0 || _workId > totalWorks) {
            revert("Invalid work ID");
        }
        if (works[_workId].creator == address(0)) {
            revert("Work does not exist");
        }

        CopyrightWork memory work = works[_workId];
        return (
            work.title,
            work.description,
            work.creator,
            work.creationTime,
            work.isActive,
            work.licensePrice,
            work.ipfsHash
        );
    }

    function getLicenseDetails(uint256 _licenseId) external view returns (
        uint256 workId,
        address licensee,
        uint256 startTime,
        uint256 endTime,
        bool isActive,
        uint256 price
    ) {

        if (_licenseId == 0 || _licenseId > totalLicenses) {
            revert("Invalid license ID");
        }
        if (licenses[_licenseId].licensee == address(0)) {
            revert("License does not exist");
        }

        License memory license = licenses[_licenseId];
        return (
            license.workId,
            license.licensee,
            license.startTime,
            license.endTime,
            license.isActive,
            license.price
        );
    }

    function getCreatorWorks(address _creator) external view returns (uint256[] memory) {
        return creatorWorks[_creator];
    }

    function getUserLicenses(address _user) external view returns (uint256[] memory) {
        return userLicenses[_user];
    }

    function getWorkLicenses(uint256 _workId) external view returns (uint256[] memory) {

        if (_workId == 0 || _workId > totalWorks) {
            revert("Invalid work ID");
        }
        if (works[_workId].creator == address(0)) {
            revert("Work does not exist");
        }

        return workLicenses[_workId];
    }

    function isLicenseValid(uint256 _licenseId) external view returns (bool) {

        if (_licenseId == 0 || _licenseId > totalLicenses) {
            return false;
        }
        if (licenses[_licenseId].licensee == address(0)) {
            return false;
        }

        License memory license = licenses[_licenseId];
        return license.isActive && block.timestamp >= license.startTime && block.timestamp <= license.endTime;
    }

    function transferOwnership(address _newOwner) external {

        if (msg.sender != owner) {
            revert("Only owner can transfer ownership");
        }
        if (_newOwner == address(0)) {
            revert("Invalid new owner address");
        }

        owner = _newOwner;
    }

    function withdrawPlatformFees() external {

        if (msg.sender != owner) {
            revert("Only owner can withdraw fees");
        }

        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(owner).transfer(balance);
        }
    }

    function emergencyPause() external {

        if (msg.sender != owner) {
            revert("Only owner can pause");
        }


        for (uint256 i = 1; i <= totalWorks; i++) {
            if (works[i].creator != address(0)) {
                works[i].isActive = false;
            }
        }
    }
}
