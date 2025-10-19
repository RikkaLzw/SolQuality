
pragma solidity ^0.8.0;

contract RealEstateRegistryContract {
    address public owner;
    uint256 public propertyCounter;

    struct Property {
        uint256 id;
        string propertyAddress;
        string propertyType;
        uint256 area;
        uint256 price;
        address currentOwner;
        bool isRegistered;
        uint256 registrationDate;
        string description;
        bool isForSale;
    }

    struct Transaction {
        uint256 propertyId;
        address from;
        address to;
        uint256 price;
        uint256 timestamp;
        string transactionType;
    }

    mapping(uint256 => Property) public properties;
    mapping(address => uint256[]) public ownerProperties;
    mapping(uint256 => Transaction[]) public propertyTransactions;
    mapping(address => bool) public authorizedAgents;

    event PropertyRegistered(uint256 indexed propertyId, address indexed owner);
    event PropertyTransferred(uint256 indexed propertyId, address indexed from, address indexed to);
    event PropertyStatusChanged(uint256 indexed propertyId, bool isForSale);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not contract owner");
        _;
    }

    modifier onlyPropertyOwner(uint256 _propertyId) {
        require(properties[_propertyId].currentOwner == msg.sender, "Not property owner");
        _;
    }

    modifier propertyExists(uint256 _propertyId) {
        require(properties[_propertyId].isRegistered, "Property does not exist");
        _;
    }

    constructor() {
        owner = msg.sender;
        propertyCounter = 0;
    }




    function registerPropertyAndSetupOwnershipAndMarketStatus(
        string memory _propertyAddress,
        string memory _propertyType,
        uint256 _area,
        uint256 _price,
        string memory _description,
        bool _isForSale,
        address _newOwner,
        string memory _additionalNotes
    ) public {
        propertyCounter++;


        properties[propertyCounter] = Property({
            id: propertyCounter,
            propertyAddress: _propertyAddress,
            propertyType: _propertyType,
            area: _area,
            price: _price,
            currentOwner: _newOwner,
            isRegistered: true,
            registrationDate: block.timestamp,
            description: _description,
            isForSale: _isForSale
        });


        ownerProperties[_newOwner].push(propertyCounter);


        propertyTransactions[propertyCounter].push(Transaction({
            propertyId: propertyCounter,
            from: address(0),
            to: _newOwner,
            price: _price,
            timestamp: block.timestamp,
            transactionType: "REGISTRATION"
        }));


        if (_newOwner != msg.sender) {
            authorizedAgents[msg.sender] = true;
        }

        emit PropertyRegistered(propertyCounter, _newOwner);
        emit PropertyStatusChanged(propertyCounter, _isForSale);
    }



    function complexPropertyTransferWithValidationAndHistoryUpdate(
        uint256 _propertyId,
        address _newOwner,
        uint256 _newPrice
    ) public propertyExists(_propertyId) {
        Property storage property = properties[_propertyId];

        if (property.currentOwner == msg.sender || authorizedAgents[msg.sender]) {
            if (property.isForSale) {
                if (_newOwner != address(0)) {
                    if (_newPrice > 0) {
                        if (property.currentOwner != _newOwner) {

                            address previousOwner = property.currentOwner;


                            uint256[] storage prevOwnerProps = ownerProperties[previousOwner];
                            for (uint256 i = 0; i < prevOwnerProps.length; i++) {
                                if (prevOwnerProps[i] == _propertyId) {
                                    if (i < prevOwnerProps.length - 1) {
                                        prevOwnerProps[i] = prevOwnerProps[prevOwnerProps.length - 1];
                                    }
                                    prevOwnerProps.pop();
                                    break;
                                }
                            }


                            property.currentOwner = _newOwner;
                            property.price = _newPrice;
                            property.isForSale = false;


                            ownerProperties[_newOwner].push(_propertyId);


                            propertyTransactions[_propertyId].push(Transaction({
                                propertyId: _propertyId,
                                from: previousOwner,
                                to: _newOwner,
                                price: _newPrice,
                                timestamp: block.timestamp,
                                transactionType: "TRANSFER"
                            }));

                            emit PropertyTransferred(_propertyId, previousOwner, _newOwner);
                            emit PropertyStatusChanged(_propertyId, false);
                        } else {
                            revert("Cannot transfer to same owner");
                        }
                    } else {
                        revert("Price must be greater than 0");
                    }
                } else {
                    revert("Invalid new owner address");
                }
            } else {
                revert("Property is not for sale");
            }
        } else {
            revert("Not authorized to transfer this property");
        }
    }


    function getPropertyCompleteInformation(uint256 _propertyId)
        public
        view
        propertyExists(_propertyId)
        returns (
            uint256,
            string memory,
            string memory,
            uint256,
            uint256,
            address,
            bool,
            uint256,
            string memory,
            bool,
            uint256
        )
    {
        Property memory property = properties[_propertyId];
        uint256 transactionCount = propertyTransactions[_propertyId].length;

        return (
            property.id,
            property.propertyAddress,
            property.propertyType,
            property.area,
            property.price,
            property.currentOwner,
            property.isRegistered,
            property.registrationDate,
            property.description,
            property.isForSale,
            transactionCount
        );
    }

    function setPropertyForSale(uint256 _propertyId, uint256 _newPrice)
        public
        onlyPropertyOwner(_propertyId)
        propertyExists(_propertyId)
    {
        properties[_propertyId].isForSale = true;
        properties[_propertyId].price = _newPrice;
        emit PropertyStatusChanged(_propertyId, true);
    }

    function removePropertyFromSale(uint256 _propertyId)
        public
        onlyPropertyOwner(_propertyId)
        propertyExists(_propertyId)
    {
        properties[_propertyId].isForSale = false;
        emit PropertyStatusChanged(_propertyId, false);
    }

    function getOwnerProperties(address _owner) public view returns (uint256[] memory) {
        return ownerProperties[_owner];
    }

    function getPropertyTransactionHistory(uint256 _propertyId)
        public
        view
        propertyExists(_propertyId)
        returns (Transaction[] memory)
    {
        return propertyTransactions[_propertyId];
    }

    function authorizeAgent(address _agent) public onlyOwner {
        authorizedAgents[_agent] = true;
    }

    function revokeAgent(address _agent) public onlyOwner {
        authorizedAgents[_agent] = false;
    }

    function getTotalProperties() public view returns (uint256) {
        return propertyCounter;
    }
}
