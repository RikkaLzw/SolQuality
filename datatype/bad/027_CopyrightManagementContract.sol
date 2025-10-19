
pragma solidity ^0.8.0;

contract CopyrightManagementContract {

    uint256 public totalCopyrights;
    uint256 public contractVersion;


    struct Copyright {
        string copyrightId;
        string workTitle;
        address owner;
        uint256 registrationTime;

        uint256 isActive;
        uint256 isTransferable;

        bytes workHash;
        bytes licenseTerms;
    }

    mapping(string => Copyright) public copyrights;
    mapping(address => string[]) public ownerCopyrights;


    string[] public allCopyrightIds;

    event CopyrightRegistered(string indexed copyrightId, address indexed owner, string workTitle);
    event CopyrightTransferred(string indexed copyrightId, address indexed from, address indexed to);
    event LicenseGranted(string indexed copyrightId, address indexed licensee, bytes licenseTerms);

    constructor() {

        contractVersion = uint256(1);
        totalCopyrights = uint256(0);
    }

    function registerCopyright(
        string memory _copyrightId,
        string memory _workTitle,
        bytes memory _workHash,
        bytes memory _licenseTerms
    ) public {
        require(bytes(_copyrightId).length > 0, "Copyright ID cannot be empty");
        require(bytes(_workTitle).length > 0, "Work title cannot be empty");
        require(_workHash.length > 0, "Work hash cannot be empty");


        require(copyrights[_copyrightId].owner == address(0), "Copyright already exists");


        uint256 currentTime = uint256(block.timestamp);

        copyrights[_copyrightId] = Copyright({
            copyrightId: _copyrightId,
            workTitle: _workTitle,
            owner: msg.sender,
            registrationTime: currentTime,

            isActive: uint256(1),
            isTransferable: uint256(1),
            workHash: _workHash,
            licenseTerms: _licenseTerms
        });

        ownerCopyrights[msg.sender].push(_copyrightId);
        allCopyrightIds.push(_copyrightId);


        totalCopyrights = totalCopyrights + uint256(1);

        emit CopyrightRegistered(_copyrightId, msg.sender, _workTitle);
    }

    function transferCopyright(string memory _copyrightId, address _newOwner) public {
        require(_newOwner != address(0), "Invalid new owner address");
        require(copyrights[_copyrightId].owner == msg.sender, "Only owner can transfer");

        require(copyrights[_copyrightId].isTransferable == uint256(1), "Copyright is not transferable");
        require(copyrights[_copyrightId].isActive == uint256(1), "Copyright is not active");

        address previousOwner = copyrights[_copyrightId].owner;
        copyrights[_copyrightId].owner = _newOwner;


        ownerCopyrights[_newOwner].push(_copyrightId);


        string[] storage ownerList = ownerCopyrights[previousOwner];
        for (uint256 i = 0; i < ownerList.length; i++) {
            if (keccak256(bytes(ownerList[i])) == keccak256(bytes(_copyrightId))) {
                ownerList[i] = ownerList[ownerList.length - 1];
                ownerList.pop();
                break;
            }
        }

        emit CopyrightTransferred(_copyrightId, previousOwner, _newOwner);
    }

    function grantLicense(
        string memory _copyrightId,
        address _licensee,
        bytes memory _licenseTerms
    ) public {
        require(copyrights[_copyrightId].owner == msg.sender, "Only owner can grant license");
        require(_licensee != address(0), "Invalid licensee address");

        require(copyrights[_copyrightId].isActive == uint256(1), "Copyright is not active");

        emit LicenseGranted(_copyrightId, _licensee, _licenseTerms);
    }

    function setCopyrightStatus(string memory _copyrightId, uint256 _isActive) public {
        require(copyrights[_copyrightId].owner == msg.sender, "Only owner can change status");

        require(_isActive <= uint256(1), "Invalid status value");

        copyrights[_copyrightId].isActive = _isActive;
    }

    function setTransferability(string memory _copyrightId, uint256 _isTransferable) public {
        require(copyrights[_copyrightId].owner == msg.sender, "Only owner can change transferability");

        require(_isTransferable <= uint256(1), "Invalid transferability value");

        copyrights[_copyrightId].isTransferable = _isTransferable;
    }

    function getCopyrightInfo(string memory _copyrightId) public view returns (
        string memory workTitle,
        address owner,
        uint256 registrationTime,
        uint256 isActive,
        uint256 isTransferable,
        bytes memory workHash,
        bytes memory licenseTerms
    ) {
        Copyright memory copyright = copyrights[_copyrightId];
        return (
            copyright.workTitle,
            copyright.owner,
            copyright.registrationTime,
            copyright.isActive,
            copyright.isTransferable,
            copyright.workHash,
            copyright.licenseTerms
        );
    }

    function getOwnerCopyrights(address _owner) public view returns (string[] memory) {
        return ownerCopyrights[_owner];
    }

    function getAllCopyrightIds() public view returns (string[] memory) {
        return allCopyrightIds;
    }


    function getTotalCopyrights() public view returns (uint256) {
        return uint256(totalCopyrights);
    }

    function getContractVersion() public view returns (uint256) {

        return uint256(contractVersion);
    }
}
