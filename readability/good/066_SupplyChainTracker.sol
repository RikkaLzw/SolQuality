
pragma solidity ^0.8.0;


contract SupplyChainTracker {


    enum ProductStatus {
        Created,
        InTransit,
        Delivered,
        Received,
        Completed
    }


    enum ParticipantRole {
        Manufacturer,
        Supplier,
        Distributor,
        Retailer,
        Consumer
    }


    struct Participant {
        address participantAddress;
        string participantName;
        string contactInfo;
        ParticipantRole role;
        bool isActive;
        uint256 registrationTime;
    }


    struct Product {
        uint256 productId;
        string productName;
        string productDescription;
        address manufacturer;
        uint256 manufacturingDate;
        uint256 expiryDate;
        ProductStatus currentStatus;
        address currentOwner;
        bool exists;
    }


    struct Transaction {
        uint256 transactionId;
        uint256 productId;
        address fromParticipant;
        address toParticipant;
        uint256 timestamp;
        string location;
        string transactionType;
        string additionalInfo;
    }


    address public contractOwner;


    uint256 public productCounter;


    uint256 public transactionCounter;


    mapping(address => Participant) public participants;


    mapping(uint256 => Product) public products;


    mapping(uint256 => Transaction) public transactions;


    mapping(uint256 => uint256[]) public productTransactionHistory;


    mapping(address => uint256[]) public participantProducts;


    event ParticipantRegistered(
        address indexed participantAddress,
        string participantName,
        ParticipantRole role,
        uint256 timestamp
    );

    event ProductCreated(
        uint256 indexed productId,
        string productName,
        address indexed manufacturer,
        uint256 timestamp
    );

    event ProductTransferred(
        uint256 indexed productId,
        address indexed fromParticipant,
        address indexed toParticipant,
        uint256 transactionId,
        uint256 timestamp
    );

    event ProductStatusUpdated(
        uint256 indexed productId,
        ProductStatus newStatus,
        uint256 timestamp
    );


    modifier onlyOwner() {
        require(msg.sender == contractOwner, "Only contract owner can perform this action");
        _;
    }


    modifier onlyRegisteredParticipant() {
        require(participants[msg.sender].isActive, "Only registered participants can perform this action");
        _;
    }


    modifier onlyProductOwner(uint256 _productId) {
        require(products[_productId].exists, "Product does not exist");
        require(products[_productId].currentOwner == msg.sender, "Only product owner can perform this action");
        _;
    }


    modifier productExists(uint256 _productId) {
        require(products[_productId].exists, "Product does not exist");
        _;
    }


    constructor() {
        contractOwner = msg.sender;
        productCounter = 0;
        transactionCounter = 0;
    }


    function registerParticipant(
        string memory _participantName,
        string memory _contactInfo,
        ParticipantRole _role
    ) external {
        require(bytes(_participantName).length > 0, "Participant name cannot be empty");
        require(!participants[msg.sender].isActive, "Participant already registered");

        participants[msg.sender] = Participant({
            participantAddress: msg.sender,
            participantName: _participantName,
            contactInfo: _contactInfo,
            role: _role,
            isActive: true,
            registrationTime: block.timestamp
        });

        emit ParticipantRegistered(msg.sender, _participantName, _role, block.timestamp);
    }


    function createProduct(
        string memory _productName,
        string memory _productDescription,
        uint256 _expiryDate
    ) external onlyRegisteredParticipant returns (uint256) {
        require(participants[msg.sender].role == ParticipantRole.Manufacturer, "Only manufacturers can create products");
        require(bytes(_productName).length > 0, "Product name cannot be empty");
        require(_expiryDate > block.timestamp, "Expiry date must be in the future");

        productCounter++;
        uint256 newProductId = productCounter;

        products[newProductId] = Product({
            productId: newProductId,
            productName: _productName,
            productDescription: _productDescription,
            manufacturer: msg.sender,
            manufacturingDate: block.timestamp,
            expiryDate: _expiryDate,
            currentStatus: ProductStatus.Created,
            currentOwner: msg.sender,
            exists: true
        });


        participantProducts[msg.sender].push(newProductId);

        emit ProductCreated(newProductId, _productName, msg.sender, block.timestamp);

        return newProductId;
    }


    function transferProduct(
        uint256 _productId,
        address _toParticipant,
        string memory _location,
        string memory _transactionType,
        string memory _additionalInfo
    ) external onlyProductOwner(_productId) {
        require(participants[_toParticipant].isActive, "Recipient must be a registered participant");
        require(_toParticipant != msg.sender, "Cannot transfer to yourself");


        transactionCounter++;
        uint256 newTransactionId = transactionCounter;

        transactions[newTransactionId] = Transaction({
            transactionId: newTransactionId,
            productId: _productId,
            fromParticipant: msg.sender,
            toParticipant: _toParticipant,
            timestamp: block.timestamp,
            location: _location,
            transactionType: _transactionType,
            additionalInfo: _additionalInfo
        });


        products[_productId].currentOwner = _toParticipant;
        products[_productId].currentStatus = ProductStatus.InTransit;


        productTransactionHistory[_productId].push(newTransactionId);


        _removeProductFromParticipant(msg.sender, _productId);


        participantProducts[_toParticipant].push(_productId);

        emit ProductTransferred(_productId, msg.sender, _toParticipant, newTransactionId, block.timestamp);
    }


    function updateProductStatus(
        uint256 _productId,
        ProductStatus _newStatus
    ) external onlyProductOwner(_productId) {
        require(_newStatus != products[_productId].currentStatus, "Status is already set to this value");

        products[_productId].currentStatus = _newStatus;

        emit ProductStatusUpdated(_productId, _newStatus, block.timestamp);
    }


    function getProductTransactionHistory(uint256 _productId)
        external
        view
        productExists(_productId)
        returns (uint256[] memory) {
        return productTransactionHistory[_productId];
    }


    function getParticipantProducts(address _participant)
        external
        view
        returns (uint256[] memory) {
        require(participants[_participant].isActive, "Participant is not registered");
        return participantProducts[_participant];
    }


    function verifyProductAuthenticity(uint256 _productId)
        external
        view
        returns (bool) {
        return products[_productId].exists;
    }


    function isProductExpired(uint256 _productId)
        external
        view
        productExists(_productId)
        returns (bool) {
        return block.timestamp > products[_productId].expiryDate;
    }


    function getProductDetails(uint256 _productId)
        external
        view
        productExists(_productId)
        returns (
            string memory productName,
            string memory productDescription,
            address manufacturer,
            uint256 manufacturingDate,
            uint256 expiryDate,
            ProductStatus currentStatus,
            address currentOwner
        ) {
        Product memory product = products[_productId];
        return (
            product.productName,
            product.productDescription,
            product.manufacturer,
            product.manufacturingDate,
            product.expiryDate,
            product.currentStatus,
            product.currentOwner
        );
    }


    function getTransactionDetails(uint256 _transactionId)
        external
        view
        returns (
            uint256 productId,
            address fromParticipant,
            address toParticipant,
            uint256 timestamp,
            string memory location,
            string memory transactionType,
            string memory additionalInfo
        ) {
        require(_transactionId > 0 && _transactionId <= transactionCounter, "Transaction does not exist");

        Transaction memory transaction = transactions[_transactionId];
        return (
            transaction.productId,
            transaction.fromParticipant,
            transaction.toParticipant,
            transaction.timestamp,
            transaction.location,
            transaction.transactionType,
            transaction.additionalInfo
        );
    }


    function deactivateParticipant(address _participant) external onlyOwner {
        require(participants[_participant].isActive, "Participant is not active");
        participants[_participant].isActive = false;
    }


    function activateParticipant(address _participant) external onlyOwner {
        require(!participants[_participant].isActive, "Participant is already active");
        require(participants[_participant].participantAddress != address(0), "Participant does not exist");
        participants[_participant].isActive = true;
    }


    function _removeProductFromParticipant(address _participant, uint256 _productId) internal {
        uint256[] storage productList = participantProducts[_participant];
        for (uint256 i = 0; i < productList.length; i++) {
            if (productList[i] == _productId) {
                productList[i] = productList[productList.length - 1];
                productList.pop();
                break;
            }
        }
    }


    function getContractStats()
        external
        view
        returns (uint256 totalProducts, uint256 totalTransactions) {
        return (productCounter, transactionCounter);
    }
}
