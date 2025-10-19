
pragma solidity ^0.8.0;

contract CopyrightManagementContract {
    address public owner;
    uint256 public totalWorks;

    struct CopyrightWork {
        string title;
        string creator;
        uint256 creationDate;
        bool isActive;
        address copyrightHolder;
        uint256 licensePrice;
    }

    mapping(uint256 => CopyrightWork) public works;
    mapping(uint256 => mapping(address => bool)) public licenses;
    mapping(address => uint256[]) public creatorWorks;


    event WorkRegistered(uint256 workId, string title, address creator);
    event LicensePurchased(uint256 workId, address licensee, uint256 price);
    event OwnershipTransferred(uint256 workId, address newOwner);
    event WorkDeactivated(uint256 workId);


    error InvalidOperation();
    error AccessDenied();
    error InvalidInput();

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyWorkOwner(uint256 _workId) {
        require(works[_workId].copyrightHolder == msg.sender);
        _;
    }

    modifier workExists(uint256 _workId) {
        require(_workId > 0 && _workId <= totalWorks);
        _;
    }

    constructor() {
        owner = msg.sender;
        totalWorks = 0;
    }

    function registerWork(
        string memory _title,
        string memory _creator,
        uint256 _licensePrice
    ) external {
        require(bytes(_title).length > 0);
        require(bytes(_creator).length > 0);

        totalWorks++;

        works[totalWorks] = CopyrightWork({
            title: _title,
            creator: _creator,
            creationDate: block.timestamp,
            isActive: true,
            copyrightHolder: msg.sender,
            licensePrice: _licensePrice
        });

        creatorWorks[msg.sender].push(totalWorks);

        emit WorkRegistered(totalWorks, _title, msg.sender);

    }

    function purchaseLicense(uint256 _workId)
        external
        payable
        workExists(_workId)
    {
        CopyrightWork storage work = works[_workId];
        require(work.isActive);
        require(msg.value >= work.licensePrice);
        require(!licenses[_workId][msg.sender]);

        licenses[_workId][msg.sender] = true;

        payable(work.copyrightHolder).transfer(msg.value);

        emit LicensePurchased(_workId, msg.sender, msg.value);

    }

    function transferOwnership(uint256 _workId, address _newOwner)
        external
        workExists(_workId)
        onlyWorkOwner(_workId)
    {
        require(_newOwner != address(0));

        CopyrightWork storage work = works[_workId];
        address oldOwner = work.copyrightHolder;
        work.copyrightHolder = _newOwner;


        uint256[] storage oldOwnerWorks = creatorWorks[oldOwner];
        for (uint256 i = 0; i < oldOwnerWorks.length; i++) {
            if (oldOwnerWorks[i] == _workId) {
                oldOwnerWorks[i] = oldOwnerWorks[oldOwnerWorks.length - 1];
                oldOwnerWorks.pop();
                break;
            }
        }


        creatorWorks[_newOwner].push(_workId);

        emit OwnershipTransferred(_workId, _newOwner);

    }

    function deactivateWork(uint256 _workId)
        external
        workExists(_workId)
        onlyWorkOwner(_workId)
    {
        CopyrightWork storage work = works[_workId];
        require(work.isActive);

        work.isActive = false;

        emit WorkDeactivated(_workId);

    }

    function updateLicensePrice(uint256 _workId, uint256 _newPrice)
        external
        workExists(_workId)
        onlyWorkOwner(_workId)
    {
        require(_newPrice > 0);

        works[_workId].licensePrice = _newPrice;

    }

    function hasLicense(uint256 _workId, address _licensee)
        external
        view
        workExists(_workId)
        returns (bool)
    {
        return licenses[_workId][_licensee];
    }

    function getWorksByCreator(address _creator)
        external
        view
        returns (uint256[] memory)
    {
        return creatorWorks[_creator];
    }

    function getWorkDetails(uint256 _workId)
        external
        view
        workExists(_workId)
        returns (
            string memory title,
            string memory creator,
            uint256 creationDate,
            bool isActive,
            address copyrightHolder,
            uint256 licensePrice
        )
    {
        CopyrightWork storage work = works[_workId];
        return (
            work.title,
            work.creator,
            work.creationDate,
            work.isActive,
            work.copyrightHolder,
            work.licensePrice
        );
    }

    function emergencyWithdraw() external onlyOwner {
        require(address(this).balance > 0);
        payable(owner).transfer(address(this).balance);

    }

    function changeContractOwner(address _newOwner) external onlyOwner {
        require(_newOwner != address(0));

        owner = _newOwner;

    }


    function validateWorkData(string memory _title, string memory _creator)
        public
        pure
        returns (bool)
    {
        if (bytes(_title).length == 0) {
            return false;
        }
        if (bytes(_creator).length == 0) {
            return false;
        }
        return true;
    }

    receive() external payable {

    }
}
