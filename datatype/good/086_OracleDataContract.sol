
pragma solidity ^0.8.0;

contract OracleDataContract {
    struct PriceData {
        uint256 price;
        uint32 timestamp;
        uint8 decimals;
        bool isValid;
    }

    struct DataFeed {
        bytes32 feedId;
        string description;
        address oracle;
        uint32 heartbeat;
        bool isActive;
    }

    mapping(bytes32 => PriceData) private priceFeeds;
    mapping(bytes32 => DataFeed) private dataFeeds;
    mapping(address => bool) private authorizedOracles;

    address private owner;
    uint8 private constant MAX_DECIMALS = 18;
    uint32 private constant MAX_HEARTBEAT = 86400;

    event PriceUpdated(bytes32 indexed feedId, uint256 price, uint32 timestamp);
    event DataFeedAdded(bytes32 indexed feedId, string description, address oracle);
    event DataFeedRemoved(bytes32 indexed feedId);
    event OracleAuthorized(address indexed oracle);
    event OracleRevoked(address indexed oracle);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyAuthorizedOracle() {
        require(authorizedOracles[msg.sender], "Only authorized oracle can call this function");
        _;
    }

    modifier validFeedId(bytes32 feedId) {
        require(feedId != bytes32(0), "Invalid feed ID");
        require(dataFeeds[feedId].isActive, "Data feed not active");
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedOracles[msg.sender] = true;
    }

    function addDataFeed(
        bytes32 feedId,
        string calldata description,
        address oracle,
        uint32 heartbeat,
        uint8 decimals
    ) external onlyOwner {
        require(feedId != bytes32(0), "Invalid feed ID");
        require(oracle != address(0), "Invalid oracle address");
        require(heartbeat > 0 && heartbeat <= MAX_HEARTBEAT, "Invalid heartbeat");
        require(decimals <= MAX_DECIMALS, "Invalid decimals");
        require(!dataFeeds[feedId].isActive, "Data feed already exists");

        dataFeeds[feedId] = DataFeed({
            feedId: feedId,
            description: description,
            oracle: oracle,
            heartbeat: heartbeat,
            isActive: true
        });

        priceFeeds[feedId] = PriceData({
            price: 0,
            timestamp: 0,
            decimals: decimals,
            isValid: false
        });

        emit DataFeedAdded(feedId, description, oracle);
    }

    function removeDataFeed(bytes32 feedId) external onlyOwner validFeedId(feedId) {
        dataFeeds[feedId].isActive = false;
        priceFeeds[feedId].isValid = false;

        emit DataFeedRemoved(feedId);
    }

    function updatePrice(
        bytes32 feedId,
        uint256 price
    ) external onlyAuthorizedOracle validFeedId(feedId) {
        require(price > 0, "Price must be greater than zero");

        DataFeed memory feed = dataFeeds[feedId];
        require(msg.sender == feed.oracle || msg.sender == owner, "Unauthorized oracle for this feed");

        uint32 currentTimestamp = uint32(block.timestamp);

        priceFeeds[feedId] = PriceData({
            price: price,
            timestamp: currentTimestamp,
            decimals: priceFeeds[feedId].decimals,
            isValid: true
        });

        emit PriceUpdated(feedId, price, currentTimestamp);
    }

    function getLatestPrice(bytes32 feedId) external view validFeedId(feedId) returns (
        uint256 price,
        uint32 timestamp,
        uint8 decimals,
        bool isValid
    ) {
        PriceData memory data = priceFeeds[feedId];
        return (data.price, data.timestamp, data.decimals, data.isValid);
    }

    function isPriceStale(bytes32 feedId) external view validFeedId(feedId) returns (bool) {
        PriceData memory priceData = priceFeeds[feedId];
        DataFeed memory feedData = dataFeeds[feedId];

        if (!priceData.isValid) {
            return true;
        }

        return (uint32(block.timestamp) - priceData.timestamp) > feedData.heartbeat;
    }

    function getDataFeedInfo(bytes32 feedId) external view returns (
        string memory description,
        address oracle,
        uint32 heartbeat,
        bool isActive
    ) {
        DataFeed memory feed = dataFeeds[feedId];
        return (feed.description, feed.oracle, feed.heartbeat, feed.isActive);
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
