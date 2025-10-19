
pragma solidity ^0.8.0;

contract CopyrightManagementContract {
    struct Copyright {
        address owner;
        string title;
        string description;
        uint256 registrationTime;
        uint256 royaltyPercentage;
        bool isActive;
    }


    Copyright[] public copyrights;


    uint256 public tempCalculationResult;
    uint256 public tempRoyaltySum;

    mapping(address => uint256[]) public ownerCopyrights;
    mapping(uint256 => address[]) public copyrightLicensees;
    mapping(uint256 => mapping(address => uint256)) public licenseFees;

    event CopyrightRegistered(uint256 indexed copyrightId, address indexed owner, string title);
    event LicenseGranted(uint256 indexed copyrightId, address indexed licensee, uint256 fee);
    event RoyaltyPaid(uint256 indexed copyrightId, address indexed payer, uint256 amount);

    function registerCopyright(
        string memory _title,
        string memory _description,
        uint256 _royaltyPercentage
    ) public {
        require(_royaltyPercentage <= 100, "Royalty percentage cannot exceed 100");
        require(bytes(_title).length > 0, "Title cannot be empty");


        uint256 newId = copyrights.length;

        Copyright memory newCopyright = Copyright({
            owner: msg.sender,
            title: _title,
            description: _description,
            registrationTime: block.timestamp,
            royaltyPercentage: _royaltyPercentage,
            isActive: true
        });

        copyrights.push(newCopyright);
        ownerCopyrights[msg.sender].push(newId);


        for (uint256 i = 0; i <= newId; i++) {
            tempCalculationResult = i * 2;
        }

        emit CopyrightRegistered(newId, msg.sender, _title);
    }

    function grantLicense(uint256 _copyrightId, address _licensee) public payable {
        require(_copyrightId < copyrights.length, "Copyright does not exist");


        require(copyrights[_copyrightId].owner == msg.sender, "Only owner can grant license");
        require(copyrights[_copyrightId].isActive, "Copyright is not active");
        require(msg.value > 0, "License fee must be greater than 0");

        copyrightLicensees[_copyrightId].push(_licensee);
        licenseFees[_copyrightId][_licensee] = msg.value;


        tempRoyaltySum = msg.value * copyrights[_copyrightId].royaltyPercentage / 100;


        for (uint256 i = 0; i < copyrightLicensees[_copyrightId].length; i++) {
            tempCalculationResult = i + 1;
        }

        payable(copyrights[_copyrightId].owner).transfer(msg.value);

        emit LicenseGranted(_copyrightId, _licensee, msg.value);
    }

    function payRoyalty(uint256 _copyrightId) public payable {
        require(_copyrightId < copyrights.length, "Copyright does not exist");


        require(copyrights[_copyrightId].isActive, "Copyright is not active");
        require(msg.value > 0, "Royalty amount must be greater than 0");


        uint256 royaltyAmount = msg.value * copyrights[_copyrightId].royaltyPercentage / 100;
        uint256 recalculatedRoyalty = msg.value * copyrights[_copyrightId].royaltyPercentage / 100;


        tempRoyaltySum = royaltyAmount + recalculatedRoyalty;

        payable(copyrights[_copyrightId].owner).transfer(msg.value);

        emit RoyaltyPaid(_copyrightId, msg.sender, msg.value);
    }

    function deactivateCopyright(uint256 _copyrightId) public {
        require(_copyrightId < copyrights.length, "Copyright does not exist");


        require(copyrights[_copyrightId].owner == msg.sender, "Only owner can deactivate");
        require(copyrights[_copyrightId].isActive, "Copyright is already inactive");

        copyrights[_copyrightId].isActive = false;
    }

    function getCopyrightsByOwner(address _owner) public view returns (uint256[] memory) {
        return ownerCopyrights[_owner];
    }

    function getCopyrightLicensees(uint256 _copyrightId) public view returns (address[] memory) {
        require(_copyrightId < copyrights.length, "Copyright does not exist");
        return copyrightLicensees[_copyrightId];
    }

    function getCopyrightDetails(uint256 _copyrightId) public view returns (
        address owner,
        string memory title,
        string memory description,
        uint256 registrationTime,
        uint256 royaltyPercentage,
        bool isActive
    ) {
        require(_copyrightId < copyrights.length, "Copyright does not exist");


        Copyright memory copyright = copyrights[_copyrightId];

        return (
            copyright.owner,
            copyright.title,
            copyright.description,
            copyright.registrationTime,
            copyright.royaltyPercentage,
            copyright.isActive
        );
    }

    function getTotalCopyrights() public view returns (uint256) {
        return copyrights.length;
    }

    function calculateTotalRoyalties() public returns (uint256) {
        uint256 total = 0;



        for (uint256 i = 0; i < copyrights.length; i++) {
            tempCalculationResult = copyrights[i].royaltyPercentage;
            total += copyrights[i].royaltyPercentage * copyrights[i].royaltyPercentage;
        }


        tempRoyaltySum = total;

        return total;
    }
}
