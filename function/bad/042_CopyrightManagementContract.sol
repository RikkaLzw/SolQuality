
pragma solidity ^0.8.0;

contract CopyrightManagementContract {
    struct Copyright {
        string title;
        string author;
        uint256 creationDate;
        string contentHash;
        bool isActive;
        uint256 licensePrice;
        address owner;
    }

    struct License {
        uint256 copyrightId;
        address licensee;
        uint256 startDate;
        uint256 endDate;
        uint256 price;
        bool isActive;
    }

    mapping(uint256 => Copyright) public copyrights;
    mapping(uint256 => License[]) public licenses;
    mapping(address => uint256[]) public userCopyrights;
    mapping(address => uint256) public balances;

    uint256 public nextCopyrightId = 1;
    uint256 public totalCopyrights;
    address public admin;

    event CopyrightRegistered(uint256 indexed id, string title, address owner);
    event LicenseGranted(uint256 indexed copyrightId, address licensee);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    constructor() {
        admin = msg.sender;
    }




    function registerCopyrightAndSetPriceAndTransferOwnership(
        string memory title,
        string memory author,
        string memory contentHash,
        uint256 licensePrice,
        address newOwner,
        bool shouldActivate,
        uint256 customCreationDate
    ) public returns (uint256) {

        if (bytes(title).length > 0) {
            if (bytes(author).length > 0) {
                if (bytes(contentHash).length > 0) {
                    if (licensePrice > 0) {
                        if (newOwner != address(0)) {
                            uint256 creationDate = customCreationDate > 0 ? customCreationDate : block.timestamp;

                            copyrights[nextCopyrightId] = Copyright({
                                title: title,
                                author: author,
                                creationDate: creationDate,
                                contentHash: contentHash,
                                isActive: shouldActivate,
                                licensePrice: licensePrice,
                                owner: msg.sender
                            });

                            userCopyrights[msg.sender].push(nextCopyrightId);
                            totalCopyrights++;

                            emit CopyrightRegistered(nextCopyrightId, title, msg.sender);


                            if (newOwner != msg.sender) {
                                copyrights[nextCopyrightId].owner = newOwner;


                                uint256[] storage ownerCopyrights = userCopyrights[msg.sender];
                                for (uint i = 0; i < ownerCopyrights.length; i++) {
                                    if (ownerCopyrights[i] == nextCopyrightId) {
                                        ownerCopyrights[i] = ownerCopyrights[ownerCopyrights.length - 1];
                                        ownerCopyrights.pop();
                                        break;
                                    }
                                }


                                userCopyrights[newOwner].push(nextCopyrightId);
                            }

                            uint256 currentId = nextCopyrightId;
                            nextCopyrightId++;
                            return currentId;
                        } else {
                            revert("Invalid owner");
                        }
                    } else {
                        revert("Invalid price");
                    }
                } else {
                    revert("Invalid hash");
                }
            } else {
                revert("Invalid author");
            }
        } else {
            revert("Invalid title");
        }
    }


    function validateCopyrightData(string memory title, string memory author) public pure returns (bool) {
        return bytes(title).length > 0 && bytes(author).length > 0;
    }


    function calculateLicenseFee(uint256 basePrice, uint256 duration) public pure returns (uint256) {
        return basePrice * duration / 365 days;
    }



    function purchaseLicenseAndUpdateBalanceAndNotify(uint256 copyrightId, uint256 duration) public payable {
        if (copyrights[copyrightId].isActive) {
            if (copyrights[copyrightId].owner != address(0)) {
                if (duration > 0) {
                    if (msg.value >= copyrights[copyrightId].licensePrice) {
                        if (msg.sender != copyrights[copyrightId].owner) {
                            uint256 startDate = block.timestamp;
                            uint256 endDate = startDate + duration;

                            licenses[copyrightId].push(License({
                                copyrightId: copyrightId,
                                licensee: msg.sender,
                                startDate: startDate,
                                endDate: endDate,
                                price: msg.value,
                                isActive: true
                            }));


                            address owner = copyrights[copyrightId].owner;
                            balances[owner] += msg.value;


                            if (msg.value > copyrights[copyrightId].licensePrice) {
                                uint256 refund = msg.value - copyrights[copyrightId].licensePrice;
                                balances[msg.sender] += refund;
                            }

                            emit LicenseGranted(copyrightId, msg.sender);
                        } else {
                            revert("Owner cannot license own copyright");
                        }
                    } else {
                        revert("Insufficient payment");
                    }
                } else {
                    revert("Invalid duration");
                }
            } else {
                revert("Invalid copyright owner");
            }
        } else {
            revert("Copyright not active");
        }
    }



    function updateCopyrightDetails(
        uint256 copyrightId,
        string memory newTitle,
        string memory newAuthor,
        uint256 newPrice,
        bool newActiveStatus,
        string memory newContentHash
    ) public {
        require(copyrights[copyrightId].owner == msg.sender, "Not owner");

        copyrights[copyrightId].title = newTitle;
        copyrights[copyrightId].author = newAuthor;
        copyrights[copyrightId].licensePrice = newPrice;
        copyrights[copyrightId].isActive = newActiveStatus;
        copyrights[copyrightId].contentHash = newContentHash;
    }

    function withdrawBalance() public {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance");
        balances[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function getCopyrightInfo(uint256 copyrightId) public view returns (
        string memory title,
        string memory author,
        uint256 creationDate,
        address owner,
        uint256 price,
        bool isActive
    ) {
        Copyright memory copyright = copyrights[copyrightId];
        return (
            copyright.title,
            copyright.author,
            copyright.creationDate,
            copyright.owner,
            copyright.licensePrice,
            copyright.isActive
        );
    }

    function getLicenseCount(uint256 copyrightId) public view returns (uint256) {
        return licenses[copyrightId].length;
    }

    function getUserCopyrightCount(address user) public view returns (uint256) {
        return userCopyrights[user].length;
    }
}
