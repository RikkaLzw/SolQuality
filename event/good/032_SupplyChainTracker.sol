
pragma solidity ^0.8.0;

contract SupplyChainTracker {

    enum ProductState {
        Created,
        InTransit,
        Delivered,
        Verified,
        Recalled
    }


    struct Product {
        uint256 id;
        string name;
        string description;
        address manufacturer;
        address currentOwner;
        ProductState state;
        uint256 createdAt;
        uint256 lastUpdated;
        string[] locationHistory;
        address[] ownerHistory;
    }


    mapping(uint256 => Product) public products;


    mapping(address => bool) public authorizedParticipants;


    address public owner;


    uint256 public productCounter;


    event ProductCreated(
        uint256 indexed productId,
        string indexed name,
        address indexed manufacturer,
        uint256 timestamp
    );

    event ProductStateChanged(
        uint256 indexed productId,
        ProductState indexed oldState,
        ProductState indexed newState,
        address changedBy,
        uint256 timestamp
    );

    event OwnershipTransferred(
        uint256 indexed productId,
        address indexed previousOwner,
        address indexed newOwner,
        uint256 timestamp
    );

    event LocationUpdated(
        uint256 indexed productId,
        string location,
        address indexed updatedBy,
        uint256 timestamp
    );

    event ParticipantAuthorized(
        address indexed participant,
        address indexed authorizedBy,
        uint256 timestamp
    );

    event ParticipantRevoked(
        address indexed participant,
        address indexed revokedBy,
        uint256 timestamp
    );

    event ProductRecalled(
        uint256 indexed productId,
        address indexed recalledBy,
        string reason,
        uint256 timestamp
    );


    modifier onlyOwner() {
        require(msg.sender == owner, "Only contract owner can perform this action");
        _;
    }

    modifier onlyAuthorized() {
        require(
            authorizedParticipants[msg.sender] || msg.sender == owner,
            "Only authorized participants can perform this action"
        );
        _;
    }

    modifier productExists(uint256 _productId) {
        require(_productId > 0 && _productId <= productCounter, "Product does not exist");
        _;
    }

    modifier onlyProductOwner(uint256 _productId) {
        require(
            products[_productId].currentOwner == msg.sender,
            "Only current product owner can perform this action"
        );
        _;
    }

    modifier validStateTransition(uint256 _productId, ProductState _newState) {
        ProductState currentState = products[_productId].state;

        if (currentState == ProductState.Created) {
            require(
                _newState == ProductState.InTransit || _newState == ProductState.Recalled,
                "Invalid state transition from Created"
            );
        } else if (currentState == ProductState.InTransit) {
            require(
                _newState == ProductState.Delivered || _newState == ProductState.Recalled,
                "Invalid state transition from InTransit"
            );
        } else if (currentState == ProductState.Delivered) {
            require(
                _newState == ProductState.Verified || _newState == ProductState.Recalled,
                "Invalid state transition from Delivered"
            );
        } else if (currentState == ProductState.Verified) {
            require(
                _newState == ProductState.Recalled,
                "Invalid state transition from Verified"
            );
        } else if (currentState == ProductState.Recalled) {
            revert("Cannot change state of recalled product");
        }
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedParticipants[msg.sender] = true;
    }


    function createProduct(
        string memory _name,
        string memory _description
    ) external onlyAuthorized returns (uint256) {
        require(bytes(_name).length > 0, "Product name cannot be empty");
        require(bytes(_description).length > 0, "Product description cannot be empty");

        productCounter++;
        uint256 productId = productCounter;

        Product storage newProduct = products[productId];
        newProduct.id = productId;
        newProduct.name = _name;
        newProduct.description = _description;
        newProduct.manufacturer = msg.sender;
        newProduct.currentOwner = msg.sender;
        newProduct.state = ProductState.Created;
        newProduct.createdAt = block.timestamp;
        newProduct.lastUpdated = block.timestamp;


        newProduct.ownerHistory.push(msg.sender);

        emit ProductCreated(productId, _name, msg.sender, block.timestamp);

        return productId;
    }


    function transferOwnership(
        uint256 _productId,
        address _newOwner
    ) external productExists(_productId) onlyProductOwner(_productId) {
        require(_newOwner != address(0), "New owner cannot be zero address");
        require(_newOwner != products[_productId].currentOwner, "New owner must be different from current owner");
        require(authorizedParticipants[_newOwner], "New owner must be authorized participant");

        Product storage product = products[_productId];
        address previousOwner = product.currentOwner;

        product.currentOwner = _newOwner;
        product.lastUpdated = block.timestamp;
        product.ownerHistory.push(_newOwner);

        emit OwnershipTransferred(_productId, previousOwner, _newOwner, block.timestamp);
    }


    function updateProductState(
        uint256 _productId,
        ProductState _newState
    ) external
        productExists(_productId)
        onlyProductOwner(_productId)
        validStateTransition(_productId, _newState)
    {
        Product storage product = products[_productId];
        ProductState oldState = product.state;

        product.state = _newState;
        product.lastUpdated = block.timestamp;

        emit ProductStateChanged(_productId, oldState, _newState, msg.sender, block.timestamp);
    }


    function updateLocation(
        uint256 _productId,
        string memory _location
    ) external productExists(_productId) onlyProductOwner(_productId) {
        require(bytes(_location).length > 0, "Location cannot be empty");

        Product storage product = products[_productId];
        product.locationHistory.push(_location);
        product.lastUpdated = block.timestamp;

        emit LocationUpdated(_productId, _location, msg.sender, block.timestamp);
    }


    function recallProduct(
        uint256 _productId,
        string memory _reason
    ) external productExists(_productId) onlyAuthorized {
        require(bytes(_reason).length > 0, "Recall reason cannot be empty");

        Product storage product = products[_productId];

        if (product.state == ProductState.Recalled) {
            revert("Product is already recalled");
        }

        ProductState oldState = product.state;
        product.state = ProductState.Recalled;
        product.lastUpdated = block.timestamp;

        emit ProductStateChanged(_productId, oldState, ProductState.Recalled, msg.sender, block.timestamp);
        emit ProductRecalled(_productId, msg.sender, _reason, block.timestamp);
    }


    function authorizeParticipant(address _participant) external onlyOwner {
        require(_participant != address(0), "Participant address cannot be zero");
        require(!authorizedParticipants[_participant], "Participant is already authorized");

        authorizedParticipants[_participant] = true;

        emit ParticipantAuthorized(_participant, msg.sender, block.timestamp);
    }


    function revokeParticipant(address _participant) external onlyOwner {
        require(_participant != address(0), "Participant address cannot be zero");
        require(_participant != owner, "Cannot revoke owner authorization");
        require(authorizedParticipants[_participant], "Participant is not authorized");

        authorizedParticipants[_participant] = false;

        emit ParticipantRevoked(_participant, msg.sender, block.timestamp);
    }


    function getProduct(uint256 _productId)
        external
        view
        productExists(_productId)
        returns (
            uint256 id,
            string memory name,
            string memory description,
            address manufacturer,
            address currentOwner,
            ProductState state,
            uint256 createdAt,
            uint256 lastUpdated
        )
    {
        Product storage product = products[_productId];
        return (
            product.id,
            product.name,
            product.description,
            product.manufacturer,
            product.currentOwner,
            product.state,
            product.createdAt,
            product.lastUpdated
        );
    }


    function getLocationHistory(uint256 _productId)
        external
        view
        productExists(_productId)
        returns (string[] memory)
    {
        return products[_productId].locationHistory;
    }


    function getOwnerHistory(uint256 _productId)
        external
        view
        productExists(_productId)
        returns (address[] memory)
    {
        return products[_productId].ownerHistory;
    }


    function transferContractOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "New owner cannot be zero address");
        require(_newOwner != owner, "New owner must be different from current owner");

        owner = _newOwner;
        authorizedParticipants[_newOwner] = true;
    }
}
