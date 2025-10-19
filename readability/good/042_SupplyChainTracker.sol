
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
        ProductStatus currentStatus;
        address currentOwner;
        bool isActive;
    }


    struct Transaction {
        uint256 transactionId;
        uint256 productId;
        address fromParticipant;
        address toParticipant;
        uint256 transactionTime;
        string location;
        string additionalInfo;
    }


    address public contractOwner;


    uint256 public participantCounter;
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
        uint256 registrationTime
    );

    event ProductCreated(
        uint256 indexed productId,
        string productName,
        address indexed manufacturer,
        uint256 manufacturingDate
    );

    event ProductTransferred(
        uint256 indexed productId,
        address indexed fromParticipant,
        address indexed toParticipant,
        uint256 transactionTime,
        string location
    );

    event ProductStatusUpdated(
        uint256 indexed productId,
        ProductStatus newStatus,
        uint256 updateTime
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
        require(products[_productId].currentOwner == msg.sender, "Only product owner can perform this action");
        _;
    }

    modifier productExists(uint256 _productId) {
        require(products[_productId].isActive, "Product does not exist or is inactive");
        _;
    }


    constructor() {
        contractOwner = msg.sender;
        participantCounter = 0;
        productCounter = 0;
        transactionCounter = 0;
    }


    function registerParticipant(
        string memory _participantName,
        ParticipantRole _role
    ) external {
        require(bytes(_participantName).length > 0, "Participant name cannot be empty");
        require(!participants[msg.sender].isActive, "Participant already registered");

        participants[msg.sender] = Participant({
            participantAddress: msg.sender,
            participantName: _participantName,
            role: _role,
            isActive: true,
            registrationTime: block.timestamp
        });

        participantCounter++;

        emit ParticipantRegistered(
            msg.sender,
            _participantName,
            _role,
            block.timestamp
        );
    }


    function createProduct(
        string memory _productName,
        string memory _productDescription
    ) external onlyRegisteredParticipant returns (uint256) {
        require(bytes(_productName).length > 0, "Product name cannot be empty");
        require(
            participants[msg.sender].role == ParticipantRole.Manufacturer,
            "Only manufacturers can create products"
        );

        productCounter++;
        uint256 newProductId = productCounter;

        products[newProductId] = Product({
            productId: newProductId,
            productName: _productName,
            productDescription: _productDescription,
            manufacturer: msg.sender,
            manufacturingDate: block.timestamp,
            currentStatus: ProductStatus.Created,
            currentOwner: msg.sender,
            isActive: true
        });

        participantProducts[msg.sender].push(newProductId);

        emit ProductCreated(
            newProductId,
            _productName,
            msg.sender,
            block.timestamp
        );

        return newProductId;
    }


    function transferProduct(
        uint256 _productId,
        address _toParticipant,
        string memory _location,
        string memory _additionalInfo
    ) external
        onlyRegisteredParticipant
        onlyProductOwner(_productId)
        productExists(_productId)
    {
        require(participants[_toParticipant].isActive, "Recipient is not a registered participant");
        require(_toParticipant != msg.sender, "Cannot transfer to yourself");
        require(bytes(_location).length > 0, "Location cannot be empty");


        transactionCounter++;
        uint256 newTransactionId = transactionCounter;

        transactions[newTransactionId] = Transaction({
            transactionId: newTransactionId,
            productId: _productId,
            fromParticipant: msg.sender,
            toParticipant: _toParticipant,
            transactionTime: block.timestamp,
            location: _location,
            additionalInfo: _additionalInfo
        });


        products[_productId].currentOwner = _toParticipant;
        products[_productId].currentStatus = ProductStatus.InTransit;


        productTransactionHistory[_productId].push(newTransactionId);


        participantProducts[_toParticipant].push(_productId);

        emit ProductTransferred(
            _productId,
            msg.sender,
            _toParticipant,
            block.timestamp,
            _location
        );

        emit ProductStatusUpdated(
            _productId,
            ProductStatus.InTransit,
            block.timestamp
        );
    }


    function updateProductStatus(
        uint256 _productId,
        ProductStatus _newStatus
    ) external
        onlyRegisteredParticipant
        onlyProductOwner(_productId)
        productExists(_productId)
    {
        require(_newStatus != products[_productId].currentStatus, "Status is already set to this value");

        products[_productId].currentStatus = _newStatus;

        emit ProductStatusUpdated(
            _productId,
            _newStatus,
            block.timestamp
        );
    }


    function getProductDetails(uint256 _productId)
        external
        view
        productExists(_productId)
        returns (
            uint256 productId,
            string memory productName,
            string memory productDescription,
            address manufacturer,
            uint256 manufacturingDate,
            ProductStatus currentStatus,
            address currentOwner
        )
    {
        Product memory product = products[_productId];
        return (
            product.productId,
            product.productName,
            product.productDescription,
            product.manufacturer,
            product.manufacturingDate,
            product.currentStatus,
            product.currentOwner
        );
    }


    function getProductTransactionHistory(uint256 _productId)
        external
        view
        productExists(_productId)
        returns (uint256[] memory)
    {
        return productTransactionHistory[_productId];
    }


    function getTransactionDetails(uint256 _transactionId)
        external
        view
        returns (
            uint256 transactionId,
            uint256 productId,
            address fromParticipant,
            address toParticipant,
            uint256 transactionTime,
            string memory location,
            string memory additionalInfo
        )
    {
        require(_transactionId > 0 && _transactionId <= transactionCounter, "Transaction does not exist");

        Transaction memory transaction = transactions[_transactionId];
        return (
            transaction.transactionId,
            transaction.productId,
            transaction.fromParticipant,
            transaction.toParticipant,
            transaction.transactionTime,
            transaction.location,
            transaction.additionalInfo
        );
    }


    function getParticipantInfo(address _participantAddress)
        external
        view
        returns (
            address participantAddress,
            string memory participantName,
            ParticipantRole role,
            bool isActive,
            uint256 registrationTime
        )
    {
        require(participants[_participantAddress].isActive, "Participant does not exist or is inactive");

        Participant memory participant = participants[_participantAddress];
        return (
            participant.participantAddress,
            participant.participantName,
            participant.role,
            participant.isActive,
            participant.registrationTime
        );
    }


    function getParticipantProducts(address _participantAddress)
        external
        view
        returns (uint256[] memory)
    {
        require(participants[_participantAddress].isActive, "Participant does not exist or is inactive");
        return participantProducts[_participantAddress];
    }


    function deactivateParticipant(address _participantAddress)
        external
        onlyOwner
    {
        require(participants[_participantAddress].isActive, "Participant is already inactive");
        participants[_participantAddress].isActive = false;
    }


    function deactivateProduct(uint256 _productId)
        external
        onlyOwner
        productExists(_productId)
    {
        products[_productId].isActive = false;
    }


    function getContractStats()
        external
        view
        returns (
            uint256 totalParticipants,
            uint256 totalProducts,
            uint256 totalTransactions
        )
    {
        return (participantCounter, productCounter, transactionCounter);
    }
}
