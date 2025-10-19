
pragma solidity ^0.8.0;

contract CopyrightManagementContract {
    struct Copyright {
        uint256 id;
        string title;
        string author;
        uint256 creationDate;
        uint256 registrationDate;
        uint256 isActive;
        bytes description;
        uint256 royaltyPercentage;
        string copyrightHash;
    }

    mapping(uint256 => Copyright) public copyrights;
    mapping(address => uint256[]) public ownerCopyrights;
    mapping(string => uint256) public titleToId;

    uint256 public nextCopyrightId;
    address public admin;
    uint256 public totalCopyrights;
    uint256 public contractActive;

    event CopyrightRegistered(uint256 indexed id, string title, address indexed owner);
    event CopyrightTransferred(uint256 indexed id, address indexed from, address indexed to);
    event RoyaltyPaid(uint256 indexed id, address indexed to, uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier copyrightExists(uint256 _id) {
        require(_id < nextCopyrightId, "Copyright does not exist");
        _;
    }

    modifier onlyActive() {
        require(uint256(contractActive) == uint256(1), "Contract is not active");
        _;
    }

    constructor() {
        admin = msg.sender;
        nextCopyrightId = uint256(1);
        totalCopyrights = uint256(0);
        contractActive = uint256(1);
    }

    function registerCopyright(
        string memory _title,
        string memory _author,
        bytes memory _description,
        uint256 _royaltyPercentage
    ) public onlyActive returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_author).length > 0, "Author cannot be empty");
        require(_royaltyPercentage <= uint256(100), "Royalty percentage cannot exceed 100");
        require(titleToId[_title] == uint256(0), "Title already exists");

        uint256 currentId = nextCopyrightId;

        copyrights[currentId] = Copyright({
            id: currentId,
            title: _title,
            author: _author,
            creationDate: uint256(block.timestamp),
            registrationDate: uint256(block.timestamp),
            isActive: uint256(1),
            description: _description,
            royaltyPercentage: _royaltyPercentage,
            copyrightHash: _generateHash(_title, _author)
        });

        ownerCopyrights[msg.sender].push(currentId);
        titleToId[_title] = currentId;

        nextCopyrightId = uint256(nextCopyrightId + uint256(1));
        totalCopyrights = uint256(totalCopyrights + uint256(1));

        emit CopyrightRegistered(currentId, _title, msg.sender);

        return currentId;
    }

    function transferCopyright(uint256 _id, address _to) public copyrightExists(_id) onlyActive {
        require(_to != address(0), "Cannot transfer to zero address");
        require(_isOwner(_id, msg.sender), "Only owner can transfer copyright");
        require(uint256(copyrights[_id].isActive) == uint256(1), "Copyright is not active");

        _removeFromOwner(_id, msg.sender);
        ownerCopyrights[_to].push(_id);

        emit CopyrightTransferred(_id, msg.sender, _to);
    }

    function payRoyalty(uint256 _id) public payable copyrightExists(_id) onlyActive {
        require(msg.value > 0, "Payment must be greater than 0");
        require(uint256(copyrights[_id].isActive) == uint256(1), "Copyright is not active");

        address owner = _getCopyrightOwner(_id);
        require(owner != address(0), "Copyright owner not found");

        uint256 royaltyAmount = uint256((msg.value * copyrights[_id].royaltyPercentage) / uint256(100));

        payable(owner).transfer(royaltyAmount);

        emit RoyaltyPaid(_id, owner, royaltyAmount);
    }

    function deactivateCopyright(uint256 _id) public copyrightExists(_id) {
        require(_isOwner(_id, msg.sender) || msg.sender == admin, "Only owner or admin can deactivate");
        copyrights[_id].isActive = uint256(0);
    }

    function activateCopyright(uint256 _id) public copyrightExists(_id) {
        require(_isOwner(_id, msg.sender) || msg.sender == admin, "Only owner or admin can activate");
        copyrights[_id].isActive = uint256(1);
    }

    function updateRoyaltyPercentage(uint256 _id, uint256 _newPercentage) public copyrightExists(_id) {
        require(_isOwner(_id, msg.sender), "Only owner can update royalty percentage");
        require(_newPercentage <= uint256(100), "Royalty percentage cannot exceed 100");
        copyrights[_id].royaltyPercentage = _newPercentage;
    }

    function getCopyright(uint256 _id) public view copyrightExists(_id) returns (
        uint256 id,
        string memory title,
        string memory author,
        uint256 creationDate,
        uint256 registrationDate,
        uint256 isActive,
        bytes memory description,
        uint256 royaltyPercentage,
        string memory copyrightHash
    ) {
        Copyright memory copyright = copyrights[_id];
        return (
            copyright.id,
            copyright.title,
            copyright.author,
            copyright.creationDate,
            copyright.registrationDate,
            copyright.isActive,
            copyright.description,
            copyright.royaltyPercentage,
            copyright.copyrightHash
        );
    }

    function getOwnerCopyrights(address _owner) public view returns (uint256[] memory) {
        return ownerCopyrights[_owner];
    }

    function isCopyrightActive(uint256 _id) public view copyrightExists(_id) returns (uint256) {
        return copyrights[_id].isActive;
    }

    function setContractActive(uint256 _active) public onlyAdmin {
        contractActive = _active;
    }

    function _isOwner(uint256 _id, address _user) internal view returns (bool) {
        uint256[] memory userCopyrights = ownerCopyrights[_user];
        for (uint256 i = uint256(0); i < userCopyrights.length; i = uint256(i + uint256(1))) {
            if (userCopyrights[i] == _id) {
                return true;
            }
        }
        return false;
    }

    function _getCopyrightOwner(uint256 _id) internal view returns (address) {
        for (uint256 i = uint256(0); i < nextCopyrightId; i = uint256(i + uint256(1))) {
            address[] memory allAddresses = _getAllAddresses();
            for (uint256 j = uint256(0); j < allAddresses.length; j = uint256(j + uint256(1))) {
                if (_isOwner(_id, allAddresses[j])) {
                    return allAddresses[j];
                }
            }
        }
        return address(0);
    }

    function _removeFromOwner(uint256 _id, address _owner) internal {
        uint256[] storage userCopyrights = ownerCopyrights[_owner];
        for (uint256 i = uint256(0); i < userCopyrights.length; i = uint256(i + uint256(1))) {
            if (userCopyrights[i] == _id) {
                userCopyrights[i] = userCopyrights[userCopyrights.length - uint256(1)];
                userCopyrights.pop();
                break;
            }
        }
    }

    function _generateHash(string memory _title, string memory _author) internal pure returns (string memory) {
        bytes memory combined = abi.encodePacked(_title, _author);
        return string(combined);
    }

    function _getAllAddresses() internal view returns (address[] memory) {
        address[] memory addresses = new address[](uint256(1));
        addresses[0] = admin;
        return addresses;
    }
}
