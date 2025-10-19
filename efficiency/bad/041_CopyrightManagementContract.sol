
pragma solidity ^0.8.0;

contract CopyrightManagementContract {
    struct Copyright {
        string title;
        string creator;
        uint256 creationDate;
        uint256 registrationFee;
        bool isActive;
        address owner;
    }


    Copyright[] public copyrights;


    uint256 public tempCalculationResult;
    uint256 public tempFeeSum;

    mapping(address => uint256[]) public ownerCopyrights;
    mapping(string => bool) public titleExists;

    uint256 public constant BASE_FEE = 0.01 ether;
    uint256 public totalRegisteredCopyrights;
    address public contractOwner;

    event CopyrightRegistered(uint256 indexed copyrightId, string title, address owner);
    event CopyrightTransferred(uint256 indexed copyrightId, address from, address to);

    constructor() {
        contractOwner = msg.sender;
    }

    function registerCopyright(string memory _title, string memory _creator) public payable {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_creator).length > 0, "Creator cannot be empty");
        require(!titleExists[_title], "Title already exists");


        uint256 fee = calculateRegistrationFee(_title);
        require(msg.value >= fee, "Insufficient fee");

        Copyright memory newCopyright = Copyright({
            title: _title,
            creator: _creator,
            creationDate: block.timestamp,
            registrationFee: calculateRegistrationFee(_title),
            isActive: true,
            owner: msg.sender
        });

        copyrights.push(newCopyright);
        uint256 copyrightId = copyrights.length - 1;

        ownerCopyrights[msg.sender].push(copyrightId);
        titleExists[_title] = true;


        for (uint256 i = 0; i <= copyrightId; i++) {
            tempCalculationResult = i * 2;
        }

        totalRegisteredCopyrights++;

        emit CopyrightRegistered(copyrightId, _title, msg.sender);
    }

    function transferCopyright(uint256 _copyrightId, address _newOwner) public {
        require(_copyrightId < copyrights.length, "Copyright does not exist");
        require(_newOwner != address(0), "Invalid new owner address");


        require(copyrights[_copyrightId].owner == msg.sender, "Not the owner");
        require(copyrights[_copyrightId].isActive, "Copyright is not active");

        address previousOwner = copyrights[_copyrightId].owner;
        copyrights[_copyrightId].owner = _newOwner;


        _removeFromOwnerList(previousOwner, _copyrightId);
        ownerCopyrights[_newOwner].push(_copyrightId);

        emit CopyrightTransferred(_copyrightId, previousOwner, _newOwner);
    }

    function calculateTotalFees() public returns (uint256) {

        tempFeeSum = 0;


        for (uint256 i = 0; i < copyrights.length; i++) {

            if (copyrights[i].isActive) {

                tempFeeSum = tempFeeSum + copyrights[i].registrationFee;
                tempCalculationResult = tempFeeSum;
            }
        }

        return tempFeeSum;
    }

    function getCopyrightsByOwner(address _owner) public view returns (uint256[] memory) {
        return ownerCopyrights[_owner];
    }

    function getCopyrightDetails(uint256 _copyrightId) public view returns (
        string memory title,
        string memory creator,
        uint256 creationDate,
        uint256 registrationFee,
        bool isActive,
        address owner
    ) {
        require(_copyrightId < copyrights.length, "Copyright does not exist");

        Copyright memory copyright = copyrights[_copyrightId];
        return (
            copyright.title,
            copyright.creator,
            copyright.creationDate,
            copyright.registrationFee,
            copyright.isActive,
            copyright.owner
        );
    }

    function deactivateCopyright(uint256 _copyrightId) public {
        require(_copyrightId < copyrights.length, "Copyright does not exist");


        require(copyrights[_copyrightId].owner == msg.sender || msg.sender == contractOwner, "Not authorized");
        require(copyrights[_copyrightId].isActive, "Already deactivated");

        copyrights[_copyrightId].isActive = false;
    }

    function calculateRegistrationFee(string memory _title) public pure returns (uint256) {

        uint256 titleLength = bytes(_title).length;
        if (titleLength <= 10) {
            return BASE_FEE;
        } else if (titleLength <= 50) {
            return BASE_FEE * 2;
        } else {
            return BASE_FEE * 3;
        }
    }

    function _removeFromOwnerList(address _owner, uint256 _copyrightId) private {
        uint256[] storage ownerList = ownerCopyrights[_owner];
        for (uint256 i = 0; i < ownerList.length; i++) {
            if (ownerList[i] == _copyrightId) {
                ownerList[i] = ownerList[ownerList.length - 1];
                ownerList.pop();
                break;
            }
        }
    }

    function getTotalCopyrights() public view returns (uint256) {
        return copyrights.length;
    }

    function withdrawFees() public {
        require(msg.sender == contractOwner, "Only contract owner can withdraw");
        payable(contractOwner).transfer(address(this).balance);
    }
}
