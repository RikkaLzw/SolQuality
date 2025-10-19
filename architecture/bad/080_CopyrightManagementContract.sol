
pragma solidity ^0.8.0;

contract CopyrightManagementContract {


    address internal owner;
    uint256 internal totalWorks;
    uint256 internal totalLicenses;

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
        uint256 purchaseTime;
        uint256 expirationTime;
        bool isActive;
        string licenseType;
    }

    mapping(uint256 => CopyrightWork) internal copyrightWorks;
    mapping(uint256 => License) internal licenses;
    mapping(address => uint256[]) internal creatorWorks;
    mapping(address => uint256[]) internal userLicenses;
    mapping(uint256 => uint256[]) internal workLicenses;

    event WorkRegistered(uint256 indexed workId, address indexed creator, string title);
    event LicensePurchased(uint256 indexed licenseId, uint256 indexed workId, address indexed licensee);
    event WorkDeactivated(uint256 indexed workId);
    event PriceUpdated(uint256 indexed workId, uint256 newPrice);

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
    ) public {

        require(msg.sender != address(0), "Invalid sender");
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_licensePrice > 0, "Price must be greater than 0");

        totalWorks++;

        copyrightWorks[totalWorks] = CopyrightWork({
            title: _title,
            description: _description,
            creator: msg.sender,
            creationTime: block.timestamp,
            isActive: true,
            licensePrice: _licensePrice,
            ipfsHash: _ipfsHash
        });

        creatorWorks[msg.sender].push(totalWorks);

        emit WorkRegistered(totalWorks, msg.sender, _title);
    }

    function purchaseLicense(uint256 _workId, string memory _licenseType) public payable {

        require(_workId > 0 && _workId <= totalWorks, "Invalid work ID");
        require(copyrightWorks[_workId].isActive, "Work is not active");
        require(msg.value >= copyrightWorks[_workId].licensePrice, "Insufficient payment");
        require(bytes(_licenseType).length > 0, "License type cannot be empty");

        totalLicenses++;


        uint256 expirationTime = block.timestamp + 365 * 24 * 60 * 60;

        licenses[totalLicenses] = License({
            workId: _workId,
            licensee: msg.sender,
            purchaseTime: block.timestamp,
            expirationTime: expirationTime,
            isActive: true,
            licenseType: _licenseType
        });

        userLicenses[msg.sender].push(totalLicenses);
        workLicenses[_workId].push(totalLicenses);


        address creator = copyrightWorks[_workId].creator;
        uint256 creatorShare = (msg.value * 90) / 100;
        uint256 platformFee = msg.value - creatorShare;

        payable(creator).transfer(creatorShare);
        payable(owner).transfer(platformFee);

        emit LicensePurchased(totalLicenses, _workId, msg.sender);
    }

    function updateWorkPrice(uint256 _workId, uint256 _newPrice) public {

        require(_workId > 0 && _workId <= totalWorks, "Invalid work ID");
        require(copyrightWorks[_workId].creator == msg.sender, "Only creator can update price");
        require(_newPrice > 0, "Price must be greater than 0");

        copyrightWorks[_workId].licensePrice = _newPrice;

        emit PriceUpdated(_workId, _newPrice);
    }

    function deactivateWork(uint256 _workId) public {

        require(_workId > 0 && _workId <= totalWorks, "Invalid work ID");
        require(copyrightWorks[_workId].creator == msg.sender, "Only creator can deactivate");
        require(copyrightWorks[_workId].isActive, "Work is already inactive");

        copyrightWorks[_workId].isActive = false;

        emit WorkDeactivated(_workId);
    }

    function extendLicense(uint256 _licenseId) public payable {

        require(_licenseId > 0 && _licenseId <= totalLicenses, "Invalid license ID");
        require(licenses[_licenseId].licensee == msg.sender, "Only licensee can extend");
        require(licenses[_licenseId].isActive, "License is not active");

        uint256 workId = licenses[_licenseId].workId;
        require(copyrightWorks[workId].isActive, "Work is not active");
        require(msg.value >= copyrightWorks[workId].licensePrice, "Insufficient payment");


        licenses[_licenseId].expirationTime += 365 * 24 * 60 * 60;


        address creator = copyrightWorks[workId].creator;
        uint256 creatorShare = (msg.value * 90) / 100;
        uint256 platformFee = msg.value - creatorShare;

        payable(creator).transfer(creatorShare);
        payable(owner).transfer(platformFee);
    }

    function transferLicense(uint256 _licenseId, address _newLicensee) public {

        require(_licenseId > 0 && _licenseId <= totalLicenses, "Invalid license ID");
        require(licenses[_licenseId].licensee == msg.sender, "Only licensee can transfer");
        require(licenses[_licenseId].isActive, "License is not active");
        require(_newLicensee != address(0), "Invalid new licensee");
        require(block.timestamp < licenses[_licenseId].expirationTime, "License has expired");


        uint256[] storage oldLicenses = userLicenses[msg.sender];
        for (uint256 i = 0; i < oldLicenses.length; i++) {
            if (oldLicenses[i] == _licenseId) {
                oldLicenses[i] = oldLicenses[oldLicenses.length - 1];
                oldLicenses.pop();
                break;
            }
        }

        licenses[_licenseId].licensee = _newLicensee;
        userLicenses[_newLicensee].push(_licenseId);
    }

    function revokeLicense(uint256 _licenseId) public {

        require(_licenseId > 0 && _licenseId <= totalLicenses, "Invalid license ID");

        uint256 workId = licenses[_licenseId].workId;
        bool canRevoke = false;


        if (msg.sender == copyrightWorks[workId].creator) {
            canRevoke = true;
        }
        if (msg.sender == owner) {
            canRevoke = true;
        }

        require(canRevoke, "Not authorized to revoke license");
        require(licenses[_licenseId].isActive, "License is already inactive");

        licenses[_licenseId].isActive = false;
    }


    function getWorkDetails(uint256 _workId) public view returns (
        string memory title,
        string memory description,
        address creator,
        uint256 creationTime,
        bool isActive,
        uint256 licensePrice,
        string memory ipfsHash
    ) {

        require(_workId > 0 && _workId <= totalWorks, "Invalid work ID");

        CopyrightWork memory work = copyrightWorks[_workId];
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

    function getLicenseDetails(uint256 _licenseId) public view returns (
        uint256 workId,
        address licensee,
        uint256 purchaseTime,
        uint256 expirationTime,
        bool isActive,
        string memory licenseType
    ) {

        require(_licenseId > 0 && _licenseId <= totalLicenses, "Invalid license ID");

        License memory license = licenses[_licenseId];
        return (
            license.workId,
            license.licensee,
            license.purchaseTime,
            license.expirationTime,
            license.isActive,
            license.licenseType
        );
    }

    function getCreatorWorks(address _creator) public view returns (uint256[] memory) {
        return creatorWorks[_creator];
    }

    function getUserLicenses(address _user) public view returns (uint256[] memory) {
        return userLicenses[_user];
    }

    function getWorkLicenses(uint256 _workId) public view returns (uint256[] memory) {

        require(_workId > 0 && _workId <= totalWorks, "Invalid work ID");
        return workLicenses[_workId];
    }

    function checkLicenseValidity(uint256 _licenseId) public view returns (bool) {

        require(_licenseId > 0 && _licenseId <= totalLicenses, "Invalid license ID");

        License memory license = licenses[_licenseId];
        return license.isActive && block.timestamp < license.expirationTime;
    }

    function getTotalWorks() public view returns (uint256) {
        return totalWorks;
    }

    function getTotalLicenses() public view returns (uint256) {
        return totalLicenses;
    }

    function getContractOwner() public view returns (address) {
        return owner;
    }


    function emergencyWithdraw() public {

        require(msg.sender == owner, "Only owner can withdraw");

        payable(owner).transfer(address(this).balance);
    }

    function updateOwner(address _newOwner) public {

        require(msg.sender == owner, "Only current owner can update");
        require(_newOwner != address(0), "Invalid new owner");

        owner = _newOwner;
    }


    function batchRegisterWorks(
        string[] memory _titles,
        string[] memory _descriptions,
        uint256[] memory _prices,
        string[] memory _ipfsHashes
    ) public {
        require(_titles.length == _descriptions.length, "Arrays length mismatch");
        require(_titles.length == _prices.length, "Arrays length mismatch");
        require(_titles.length == _ipfsHashes.length, "Arrays length mismatch");

        for (uint256 i = 0; i < _titles.length; i++) {

            require(bytes(_titles[i]).length > 0, "Title cannot be empty");
            require(bytes(_descriptions[i]).length > 0, "Description cannot be empty");
            require(_prices[i] > 0, "Price must be greater than 0");

            totalWorks++;

            copyrightWorks[totalWorks] = CopyrightWork({
                title: _titles[i],
                description: _descriptions[i],
                creator: msg.sender,
                creationTime: block.timestamp,
                isActive: true,
                licensePrice: _prices[i],
                ipfsHash: _ipfsHashes[i]
            });

            creatorWorks[msg.sender].push(totalWorks);

            emit WorkRegistered(totalWorks, msg.sender, _titles[i]);
        }
    }

    receive() external payable {}

    fallback() external payable {}
}
