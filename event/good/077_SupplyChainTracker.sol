
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
        bool exists;
    }


    struct TrackingRecord {
        uint256 productId;
        address actor;
        ProductState previousState;
        ProductState newState;
        string location;
        string notes;
        uint256 timestamp;
    }


    mapping(uint256 => Product) public products;
    mapping(uint256 => TrackingRecord[]) public productHistory;
    mapping(address => bool) public authorizedActors;

    uint256 public nextProductId;
    address public owner;


    event ProductCreated(
        uint256 indexed productId,
        string name,
        address indexed manufacturer,
        uint256 timestamp
    );

    event ProductStateChanged(
        uint256 indexed productId,
        address indexed actor,
        ProductState indexed previousState,
        ProductState newState,
        string location,
        uint256 timestamp
    );

    event OwnershipTransferred(
        uint256 indexed productId,
        address indexed previousOwner,
        address indexed newOwner,
        uint256 timestamp
    );

    event ActorAuthorized(
        address indexed actor,
        address indexed authorizer,
        uint256 timestamp
    );

    event ActorRevoked(
        address indexed actor,
        address indexed revoker,
        uint256 timestamp
    );

    event ProductRecalled(
        uint256 indexed productId,
        address indexed recaller,
        string reason,
        uint256 timestamp
    );


    modifier onlyOwner() {
        require(msg.sender == owner, "Only contract owner can perform this action");
        _;
    }

    modifier onlyAuthorized() {
        require(
            authorizedActors[msg.sender] || msg.sender == owner,
            "Only authorized actors can perform this action"
        );
        _;
    }

    modifier productExists(uint256 _productId) {
        require(products[_productId].exists, "Product does not exist");
        _;
    }

    modifier onlyProductOwner(uint256 _productId) {
        require(
            products[_productId].currentOwner == msg.sender,
            "Only product owner can perform this action"
        );
        _;
    }

    modifier validStateTransition(uint256 _productId, ProductState _newState) {
        ProductState currentState = products[_productId].state;

        if (currentState == ProductState.Recalled) {
            revert("Cannot change state of recalled product");
        }

        if (_newState == ProductState.Created) {
            revert("Cannot transition back to Created state");
        }

        if (currentState == ProductState.Delivered && _newState == ProductState.InTransit) {
            revert("Cannot transition from Delivered back to InTransit");
        }

        if (currentState == ProductState.Verified && _newState != ProductState.Recalled) {
            revert("Verified products can only be recalled");
        }

        _;
    }


    constructor() {
        owner = msg.sender;
        nextProductId = 1;
        authorizedActors[msg.sender] = true;
    }


    function createProduct(
        string memory _name,
        string memory _description,
        address _manufacturer
    ) external onlyAuthorized returns (uint256) {
        require(bytes(_name).length > 0, "Product name cannot be empty");
        require(_manufacturer != address(0), "Invalid manufacturer address");

        uint256 productId = nextProductId++;

        products[productId] = Product({
            id: productId,
            name: _name,
            description: _description,
            manufacturer: _manufacturer,
            currentOwner: _manufacturer,
            state: ProductState.Created,
            createdAt: block.timestamp,
            lastUpdated: block.timestamp,
            exists: true
        });


        productHistory[productId].push(TrackingRecord({
            productId: productId,
            actor: msg.sender,
            previousState: ProductState.Created,
            newState: ProductState.Created,
            location: "Manufacturing Facility",
            notes: "Product created",
            timestamp: block.timestamp
        }));

        emit ProductCreated(productId, _name, _manufacturer, block.timestamp);

        return productId;
    }


    function updateProductState(
        uint256 _productId,
        ProductState _newState,
        string memory _location,
        string memory _notes
    ) external
        onlyAuthorized
        productExists(_productId)
        validStateTransition(_productId, _newState)
    {
        require(bytes(_location).length > 0, "Location cannot be empty");

        Product storage product = products[_productId];
        ProductState previousState = product.state;

        product.state = _newState;
        product.lastUpdated = block.timestamp;


        productHistory[_productId].push(TrackingRecord({
            productId: _productId,
            actor: msg.sender,
            previousState: previousState,
            newState: _newState,
            location: _location,
            notes: _notes,
            timestamp: block.timestamp
        }));

        emit ProductStateChanged(
            _productId,
            msg.sender,
            previousState,
            _newState,
            _location,
            block.timestamp
        );
    }


    function transferOwnership(
        uint256 _productId,
        address _newOwner
    ) external
        productExists(_productId)
        onlyProductOwner(_productId)
    {
        require(_newOwner != address(0), "Invalid new owner address");
        require(_newOwner != products[_productId].currentOwner, "New owner must be different from current owner");
        require(products[_productId].state != ProductState.Recalled, "Cannot transfer ownership of recalled product");

        address previousOwner = products[_productId].currentOwner;
        products[_productId].currentOwner = _newOwner;
        products[_productId].lastUpdated = block.timestamp;

        emit OwnershipTransferred(_productId, previousOwner, _newOwner, block.timestamp);
    }


    function recallProduct(
        uint256 _productId,
        string memory _reason
    ) external
        onlyAuthorized
        productExists(_productId)
    {
        require(bytes(_reason).length > 0, "Recall reason cannot be empty");
        require(products[_productId].state != ProductState.Recalled, "Product is already recalled");

        Product storage product = products[_productId];
        ProductState previousState = product.state;

        product.state = ProductState.Recalled;
        product.lastUpdated = block.timestamp;


        productHistory[_productId].push(TrackingRecord({
            productId: _productId,
            actor: msg.sender,
            previousState: previousState,
            newState: ProductState.Recalled,
            location: "Recalled",
            notes: _reason,
            timestamp: block.timestamp
        }));

        emit ProductRecalled(_productId, msg.sender, _reason, block.timestamp);
        emit ProductStateChanged(
            _productId,
            msg.sender,
            previousState,
            ProductState.Recalled,
            "Recalled",
            block.timestamp
        );
    }


    function authorizeActor(address _actor) external onlyOwner {
        require(_actor != address(0), "Invalid actor address");
        require(!authorizedActors[_actor], "Actor is already authorized");

        authorizedActors[_actor] = true;
        emit ActorAuthorized(_actor, msg.sender, block.timestamp);
    }


    function revokeActor(address _actor) external onlyOwner {
        require(_actor != address(0), "Invalid actor address");
        require(_actor != owner, "Cannot revoke owner authorization");
        require(authorizedActors[_actor], "Actor is not authorized");

        authorizedActors[_actor] = false;
        emit ActorRevoked(_actor, msg.sender, block.timestamp);
    }


    function getProduct(uint256 _productId) external view productExists(_productId) returns (
        uint256 id,
        string memory name,
        string memory description,
        address manufacturer,
        address currentOwner,
        ProductState state,
        uint256 createdAt,
        uint256 lastUpdated
    ) {
        Product memory product = products[_productId];
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


    function getProductHistoryLength(uint256 _productId) external view productExists(_productId) returns (uint256) {
        return productHistory[_productId].length;
    }


    function getTrackingRecord(uint256 _productId, uint256 _index) external view productExists(_productId) returns (
        uint256 productId,
        address actor,
        ProductState previousState,
        ProductState newState,
        string memory location,
        string memory notes,
        uint256 timestamp
    ) {
        require(_index < productHistory[_productId].length, "Invalid tracking record index");

        TrackingRecord memory record = productHistory[_productId][_index];
        return (
            record.productId,
            record.actor,
            record.previousState,
            record.newState,
            record.location,
            record.notes,
            record.timestamp
        );
    }


    function isAuthorized(address _actor) external view returns (bool) {
        return authorizedActors[_actor];
    }
}
