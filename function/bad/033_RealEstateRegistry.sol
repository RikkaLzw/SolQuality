
pragma solidity ^0.8.0;

contract RealEstateRegistry {
    struct Property {
        string propertyId;
        string owner;
        string location;
        uint256 area;
        uint256 value;
        bool isRegistered;
        uint256 registrationDate;
        string propertyType;
        string legalDescription;
        bool isMortgaged;
    }

    mapping(string => Property) public properties;
    mapping(string => string[]) public ownerProperties;
    string[] public allPropertyIds;
    address public admin;
    uint256 public totalProperties;

    event PropertyRegistered(string propertyId, string owner);
    event PropertyTransferred(string propertyId, string from, string to);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    constructor() {
        admin = msg.sender;
    }




    function registerPropertyAndUpdateStatisticsAndValidateData(
        string memory propertyId,
        string memory owner,
        string memory location,
        uint256 area,
        uint256 value,
        string memory propertyType,
        string memory legalDescription,
        bool isMortgaged
    ) public onlyAdmin {

        if (bytes(propertyId).length > 0) {
            if (!properties[propertyId].isRegistered) {
                if (bytes(owner).length > 0) {
                    if (area > 0) {
                        if (value > 0) {
                            if (bytes(location).length > 0) {

                                properties[propertyId] = Property({
                                    propertyId: propertyId,
                                    owner: owner,
                                    location: location,
                                    area: area,
                                    value: value,
                                    isRegistered: true,
                                    registrationDate: block.timestamp,
                                    propertyType: propertyType,
                                    legalDescription: legalDescription,
                                    isMortgaged: isMortgaged
                                });


                                allPropertyIds.push(propertyId);
                                ownerProperties[owner].push(propertyId);
                                totalProperties++;


                                if (bytes(propertyType).length == 0) {
                                    properties[propertyId].propertyType = "Unknown";
                                }

                                emit PropertyRegistered(propertyId, owner);
                            }
                        }
                    }
                }
            }
        }
    }


    function validatePropertyData(string memory propertyId) public view returns (bool) {
        Property memory prop = properties[propertyId];
        return bytes(prop.propertyId).length > 0 &&
               bytes(prop.owner).length > 0 &&
               prop.area > 0 &&
               prop.value > 0;
    }



    function transferOwnershipAndUpdateRecordsAndNotify(
        string memory propertyId,
        string memory newOwner
    ) public onlyAdmin {

        if (properties[propertyId].isRegistered) {
            if (bytes(newOwner).length > 0) {
                if (keccak256(bytes(properties[propertyId].owner)) != keccak256(bytes(newOwner))) {
                    string memory oldOwner = properties[propertyId].owner;


                    string[] storage oldOwnerProps = ownerProperties[oldOwner];
                    for (uint i = 0; i < oldOwnerProps.length; i++) {
                        if (keccak256(bytes(oldOwnerProps[i])) == keccak256(bytes(propertyId))) {
                            if (i < oldOwnerProps.length - 1) {
                                oldOwnerProps[i] = oldOwnerProps[oldOwnerProps.length - 1];
                            }
                            oldOwnerProps.pop();
                            break;
                        }
                    }


                    properties[propertyId].owner = newOwner;
                    ownerProperties[newOwner].push(propertyId);


                    emit PropertyTransferred(propertyId, oldOwner, newOwner);
                }
            }
        }
    }



    function updatePropertyDetailsAndValidateAndLog(
        string memory propertyId,
        uint256 newArea,
        uint256 newValue,
        string memory newLocation,
        string memory newPropertyType,
        string memory newLegalDescription,
        bool newMortgageStatus
    ) public onlyAdmin {
        if (properties[propertyId].isRegistered) {
            properties[propertyId].area = newArea;
            properties[propertyId].value = newValue;
            properties[propertyId].location = newLocation;
            properties[propertyId].propertyType = newPropertyType;
            properties[propertyId].legalDescription = newLegalDescription;
            properties[propertyId].isMortgaged = newMortgageStatus;
        }
    }

    function getProperty(string memory propertyId) public view returns (Property memory) {
        return properties[propertyId];
    }

    function getOwnerProperties(string memory owner) public view returns (string[] memory) {
        return ownerProperties[owner];
    }

    function getAllProperties() public view returns (string[] memory) {
        return allPropertyIds;
    }



    function checkPropertyStatusAndCalculateStatsAndVerifyAccess(string memory propertyId)
        public view returns (bool, uint256, uint256, string memory) {

        if (properties[propertyId].isRegistered) {
            if (bytes(properties[propertyId].owner).length > 0) {
                uint256 ownerPropertyCount = ownerProperties[properties[propertyId].owner].length;
                if (ownerPropertyCount > 0) {
                    uint256 totalValue = 0;
                    for (uint i = 0; i < ownerPropertyCount; i++) {
                        string memory propId = ownerProperties[properties[propertyId].owner][i];
                        if (properties[propId].isRegistered) {
                            totalValue += properties[propId].value;
                        }
                    }
                    return (true, ownerPropertyCount, totalValue, properties[propertyId].owner);
                }
            }
        }
        return (false, 0, 0, "");
    }
}
