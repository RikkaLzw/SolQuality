
pragma solidity ^0.8.0;

contract RealEstateRegistryContract {


    address public owner;
    uint256 public totalProperties;
    uint256 public registrationFee;


    struct PropertyInfo {
        uint256 propertyId;
        string propertyAddress;
        string propertyType;
        uint256 propertyValue;
        address currentOwner;
        address previousOwner;
        uint256 registrationDate;
        bool isActive;
        string description;
        uint256 area;
    }


    struct TransactionRecord {
        uint256 transactionId;
        uint256 propertyId;
        address from;
        address to;
        uint256 transactionDate;
        uint256 transactionValue;
        string transactionType;
    }


    mapping(uint256 => PropertyInfo) public properties;
    mapping(address => uint256[]) public ownerProperties;
    mapping(uint256 => TransactionRecord[]) public propertyTransactions;
    mapping(address => bool) public authorizedAgents;


    event PropertyRegistered(uint256 indexed propertyId, address indexed owner, string propertyAddress);
    event PropertyTransferred(uint256 indexed propertyId, address indexed from, address indexed to);
    event AgentAuthorized(address indexed agent);
    event AgentRevoked(address indexed agent);

    constructor() {
        owner = msg.sender;
        totalProperties = 0;
        registrationFee = 0.01 ether;
    }


    function registerProperty(
        string memory _address,
        string memory _propertyType,
        uint256 _value,
        string memory _description,
        uint256 _area
    ) public payable {

        require(msg.sender == owner || authorizedAgents[msg.sender], "Not authorized");
        require(msg.value >= 0.01 ether, "Insufficient registration fee");
        require(bytes(_address).length > 0, "Address cannot be empty");
        require(_value > 0, "Value must be greater than 0");
        require(_area > 0, "Area must be greater than 0");

        totalProperties++;
        uint256 newPropertyId = totalProperties;

        properties[newPropertyId] = PropertyInfo({
            propertyId: newPropertyId,
            propertyAddress: _address,
            propertyType: _propertyType,
            propertyValue: _value,
            currentOwner: msg.sender,
            previousOwner: address(0),
            registrationDate: block.timestamp,
            isActive: true,
            description: _description,
            area: _area
        });

        ownerProperties[msg.sender].push(newPropertyId);


        TransactionRecord memory newTransaction = TransactionRecord({
            transactionId: propertyTransactions[newPropertyId].length + 1,
            propertyId: newPropertyId,
            from: address(0),
            to: msg.sender,
            transactionDate: block.timestamp,
            transactionValue: _value,
            transactionType: "Registration"
        });

        propertyTransactions[newPropertyId].push(newTransaction);

        emit PropertyRegistered(newPropertyId, msg.sender, _address);
    }


    function transferProperty(uint256 _propertyId, address _newOwner) public {

        require(msg.sender == owner || authorizedAgents[msg.sender], "Not authorized");
        require(_newOwner != address(0), "Invalid new owner address");
        require(properties[_propertyId].isActive, "Property is not active");
        require(properties[_propertyId].currentOwner != address(0), "Property does not exist");
        require(properties[_propertyId].currentOwner != _newOwner, "Cannot transfer to same owner");

        address previousOwner = properties[_propertyId].currentOwner;


        properties[_propertyId].previousOwner = previousOwner;
        properties[_propertyId].currentOwner = _newOwner;


        uint256[] storage oldOwnerProperties = ownerProperties[previousOwner];
        for (uint256 i = 0; i < oldOwnerProperties.length; i++) {
            if (oldOwnerProperties[i] == _propertyId) {
                oldOwnerProperties[i] = oldOwnerProperties[oldOwnerProperties.length - 1];
                oldOwnerProperties.pop();
                break;
            }
        }

        ownerProperties[_newOwner].push(_propertyId);


        TransactionRecord memory newTransaction = TransactionRecord({
            transactionId: propertyTransactions[_propertyId].length + 1,
            propertyId: _propertyId,
            from: previousOwner,
            to: _newOwner,
            transactionDate: block.timestamp,
            transactionValue: properties[_propertyId].propertyValue,
            transactionType: "Transfer"
        });

        propertyTransactions[_propertyId].push(newTransaction);

        emit PropertyTransferred(_propertyId, previousOwner, _newOwner);
    }


    function updatePropertyInfo(
        uint256 _propertyId,
        string memory _newAddress,
        uint256 _newValue,
        string memory _newDescription,
        uint256 _newArea
    ) public {

        require(msg.sender == owner || authorizedAgents[msg.sender], "Not authorized");
        require(properties[_propertyId].isActive, "Property is not active");
        require(properties[_propertyId].currentOwner != address(0), "Property does not exist");
        require(bytes(_newAddress).length > 0, "Address cannot be empty");
        require(_newValue > 0, "Value must be greater than 0");
        require(_newArea > 0, "Area must be greater than 0");

        properties[_propertyId].propertyAddress = _newAddress;
        properties[_propertyId].propertyValue = _newValue;
        properties[_propertyId].description = _newDescription;
        properties[_propertyId].area = _newArea;


        TransactionRecord memory newTransaction = TransactionRecord({
            transactionId: propertyTransactions[_propertyId].length + 1,
            propertyId: _propertyId,
            from: properties[_propertyId].currentOwner,
            to: properties[_propertyId].currentOwner,
            transactionDate: block.timestamp,
            transactionValue: _newValue,
            transactionType: "Update"
        });

        propertyTransactions[_propertyId].push(newTransaction);
    }


    function authorizeAgent(address _agent) public {
        require(msg.sender == owner, "Only owner can authorize agents");
        require(_agent != address(0), "Invalid agent address");
        require(!authorizedAgents[_agent], "Agent already authorized");

        authorizedAgents[_agent] = true;
        emit AgentAuthorized(_agent);
    }


    function revokeAgent(address _agent) public {
        require(msg.sender == owner, "Only owner can revoke agents");
        require(authorizedAgents[_agent], "Agent not authorized");

        authorizedAgents[_agent] = false;
        emit AgentRevoked(_agent);
    }


    function deactivateProperty(uint256 _propertyId) public {

        require(msg.sender == owner || authorizedAgents[msg.sender], "Not authorized");
        require(properties[_propertyId].isActive, "Property is not active");
        require(properties[_propertyId].currentOwner != address(0), "Property does not exist");

        properties[_propertyId].isActive = false;


        TransactionRecord memory newTransaction = TransactionRecord({
            transactionId: propertyTransactions[_propertyId].length + 1,
            propertyId: _propertyId,
            from: properties[_propertyId].currentOwner,
            to: address(0),
            transactionDate: block.timestamp,
            transactionValue: 0,
            transactionType: "Deactivation"
        });

        propertyTransactions[_propertyId].push(newTransaction);
    }


    function activateProperty(uint256 _propertyId) public {

        require(msg.sender == owner || authorizedAgents[msg.sender], "Not authorized");
        require(!properties[_propertyId].isActive, "Property is already active");
        require(properties[_propertyId].currentOwner != address(0), "Property does not exist");

        properties[_propertyId].isActive = true;


        TransactionRecord memory newTransaction = TransactionRecord({
            transactionId: propertyTransactions[_propertyId].length + 1,
            propertyId: _propertyId,
            from: address(0),
            to: properties[_propertyId].currentOwner,
            transactionDate: block.timestamp,
            transactionValue: 0,
            transactionType: "Activation"
        });

        propertyTransactions[_propertyId].push(newTransaction);
    }


    function batchTransferProperties(uint256[] memory _propertyIds, address _newOwner) public {

        require(msg.sender == owner || authorizedAgents[msg.sender], "Not authorized");
        require(_newOwner != address(0), "Invalid new owner address");
        require(_propertyIds.length > 0, "No properties to transfer");
        require(_propertyIds.length <= 10, "Too many properties");

        for (uint256 i = 0; i < _propertyIds.length; i++) {
            uint256 propertyId = _propertyIds[i];

            require(properties[propertyId].isActive, "Property is not active");
            require(properties[propertyId].currentOwner != address(0), "Property does not exist");
            require(properties[propertyId].currentOwner != _newOwner, "Cannot transfer to same owner");

            address previousOwner = properties[propertyId].currentOwner;


            properties[propertyId].previousOwner = previousOwner;
            properties[propertyId].currentOwner = _newOwner;


            uint256[] storage oldOwnerProperties = ownerProperties[previousOwner];
            for (uint256 j = 0; j < oldOwnerProperties.length; j++) {
                if (oldOwnerProperties[j] == propertyId) {
                    oldOwnerProperties[j] = oldOwnerProperties[oldOwnerProperties.length - 1];
                    oldOwnerProperties.pop();
                    break;
                }
            }

            ownerProperties[_newOwner].push(propertyId);


            TransactionRecord memory newTransaction = TransactionRecord({
                transactionId: propertyTransactions[propertyId].length + 1,
                propertyId: propertyId,
                from: previousOwner,
                to: _newOwner,
                transactionDate: block.timestamp,
                transactionValue: properties[propertyId].propertyValue,
                transactionType: "Batch Transfer"
            });

            propertyTransactions[propertyId].push(newTransaction);

            emit PropertyTransferred(propertyId, previousOwner, _newOwner);
        }
    }


    function setRegistrationFee(uint256 _newFee) public {
        require(msg.sender == owner, "Only owner can set fee");
        require(_newFee > 0, "Fee must be greater than 0");

        registrationFee = _newFee;
    }


    function withdrawBalance() public {
        require(msg.sender == owner, "Only owner can withdraw");
        require(address(this).balance > 0, "No balance to withdraw");

        payable(owner).transfer(address(this).balance);
    }


    function getPropertyInfo(uint256 _propertyId) public view returns (PropertyInfo memory) {
        require(properties[_propertyId].currentOwner != address(0), "Property does not exist");
        return properties[_propertyId];
    }


    function getOwnerProperties(address _owner) public view returns (uint256[] memory) {
        return ownerProperties[_owner];
    }


    function getPropertyTransactions(uint256 _propertyId) public view returns (TransactionRecord[] memory) {
        require(properties[_propertyId].currentOwner != address(0), "Property does not exist");
        return propertyTransactions[_propertyId];
    }


    function getTotalProperties() public view returns (uint256) {
        return totalProperties;
    }


    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }


    function verifyOwnership(uint256 _propertyId, address _owner) public view returns (bool) {
        require(properties[_propertyId].currentOwner != address(0), "Property does not exist");
        return properties[_propertyId].currentOwner == _owner;
    }


    function isAuthorizedAgent(address _agent) public view returns (bool) {
        return authorizedAgents[_agent];
    }


    function getTotalPropertyValue(address _owner) public view returns (uint256) {
        uint256[] memory ownerProps = ownerProperties[_owner];
        uint256 totalValue = 0;

        for (uint256 i = 0; i < ownerProps.length; i++) {
            if (properties[ownerProps[i]].isActive) {
                totalValue += properties[ownerProps[i]].propertyValue;
            }
        }

        return totalValue;
    }
}
