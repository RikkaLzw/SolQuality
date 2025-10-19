
pragma solidity ^0.8.0;

contract OracleDataContract {
    struct PriceData {
        uint256 price;
        uint64 timestamp;
        uint32 decimals;
        bool isValid;
    }

    struct DataFeed {
        bytes32 feedId;
        string description;
        address oracle;
        uint64 lastUpdate;
        bool isActive;
    }

    mapping(bytes32 => PriceData) private priceFeeds;
    mapping(bytes32 => DataFeed) private dataFeeds;
    mapping(address => bool) private authorizedOracles;

    address private owner;
    uint8 private constant MAX_DECIMALS = 18;
    uint32 private constant STALE_THRESHOLD = 3600;

    event PriceUpdated(bytes32 indexed feedId, uint256 price, uint64 timestamp);
    event OracleAuthorized(address indexed oracle);
    event OracleRevoked(address indexed oracle);
    event DataFeedCreated(bytes32 indexed feedId, string description);
    event DataFeedDeactivated(bytes32 indexed feedId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyAuthorizedOracle() {
        require(authorizedOracles[msg.sender], "Only authorized oracles can update data");
        _;
    }

    modifier validFeedId(bytes32 feedId) {
        require(feedId != bytes32(0), "Invalid feed ID");
        require(dataFeeds[feedId].isActive, "Data feed is not active");
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedOracles[msg.sender] = true;
    }

    function createDataFeed(
        bytes32 feedId,
        string calldata description,
        address oracle,
        uint32 decimals
    ) external onlyOwner {
        require(feedId != bytes32(0), "Invalid feed ID");
        require(oracle != address(0), "Invalid oracle address");
        require(decimals <= MAX_DECIMALS, "Decimals too high");
        require(!dataFeeds[feedId].isActive, "Data feed already exists");

        dataFeeds[feedId] = DataFeed({
            feedId: feedId,
            description: description,
            oracle: oracle,
            lastUpdate: 0,
            isActive: true
        });

        authorizedOracles[oracle] = true;

        emit DataFeedCreated(feedId, description);
        emit OracleAuthorized(oracle);
    }

    function updatePrice(
        bytes32 feedId,
        uint256 price,
        uint32 decimals
    ) external onlyAuthorizedOracle validFeedId(feedId) {
        require(price > 0, "Price must be greater than zero");
        require(decimals <= MAX_DECIMALS, "Decimals too high");

        uint64 currentTimestamp = uint64(block.timestamp);

        priceFeeds[feedId] = PriceData({
            price: price,
            timestamp: currentTimestamp,
            decimals: decimals,
            isValid: true
        });

        dataFeeds[feedId].lastUpdate = currentTimestamp;

        emit PriceUpdated(feedId, price, currentTimestamp);
    }

    function getPrice(bytes32 feedId) external view validFeedId(feedId) returns (
        uint256 price,
        uint64 timestamp,
        uint32 decimals,
        bool isValid
    ) {
        PriceData memory data = priceFeeds[feedId];
        require(data.isValid, "No valid price data available");

        return (data.price, data.timestamp, data.decimals, data.isValid);
    }

    function getLatestPrice(bytes32 feedId) external view validFeedId(feedId) returns (uint256) {
        PriceData memory data = priceFeeds[feedId];
        require(data.isValid, "No valid price data available");
        require(uint64(block.timestamp) - data.timestamp <= STALE_THRESHOLD, "Price data is stale");

        return data.price;
    }

    function isPriceStale(bytes32 feedId) external view validFeedId(feedId) returns (bool) {
        PriceData memory data = priceFeeds[feedId];
        if (!data.isValid) return true;

        return uint64(block.timestamp) - data.timestamp > STALE_THRESHOLD;
    }

    function getDataFeedInfo(bytes32 feedId) external view returns (
        string memory description,
        address oracle,
        uint64 lastUpdate,
        bool isActive
    ) {
        DataFeed memory feed = dataFeeds[feedId];
        return (feed.description, feed.oracle, feed.lastUpdate, feed.isActive);
    }

    function authorizeOracle(address oracle) external onlyOwner {
        require(oracle != address(0), "Invalid oracle address");
        authorizedOracles[oracle] = true;
        emit OracleAuthorized(oracle);
    }

    function revokeOracle(address oracle) external onlyOwner {
        require(oracle != owner, "Cannot revoke owner");
        authorizedOracles[oracle] = false;
        emit OracleRevoked(oracle);
    }

    function deactivateDataFeed(bytes32 feedId) external onlyOwner {
        require(dataFeeds[feedId].isActive, "Data feed is already inactive");
        dataFeeds[feedId].isActive = false;
        emit DataFeedDeactivated(feedId);
    }

    function isOracleAuthorized(address oracle) external view returns (bool) {
        return authorizedOracles[oracle];
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner address");
        owner = newOwner;
        authorizedOracles[newOwner] = true;
    }

    function getOwner() external view returns (address) {
        return owner;
    }
}
