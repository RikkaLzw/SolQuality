
pragma solidity ^0.8.0;

contract OracleDataContract {

    address public owner;


    mapping(address => bool) public authorizedOracles;


    struct DataFeed {
        uint256 value;
        uint64 timestamp;
        uint32 decimals;
        bool isActive;
    }


    mapping(bytes32 => DataFeed) public priceFeeds;


    mapping(bytes32 => string) public feedDescriptions;


    event OracleAuthorized(address indexed oracle);
    event OracleRevoked(address indexed oracle);
    event DataUpdated(bytes32 indexed feedId, uint256 value, uint64 timestamp);
    event FeedCreated(bytes32 indexed feedId, string description);
    event FeedDeactivated(bytes32 indexed feedId);


    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyAuthorizedOracle() {
        require(authorizedOracles[msg.sender], "Only authorized oracles can call this function");
        _;
    }

    modifier validFeedId(bytes32 feedId) {
        require(feedId != bytes32(0), "Invalid feed ID");
        _;
    }

    constructor() {
        owner = msg.sender;
    }


    function authorizeOracle(address oracle) external onlyOwner {
        require(oracle != address(0), "Invalid oracle address");
        require(!authorizedOracles[oracle], "Oracle already authorized");

        authorizedOracles[oracle] = true;
        emit OracleAuthorized(oracle);
    }

    function revokeOracle(address oracle) external onlyOwner {
        require(authorizedOracles[oracle], "Oracle not authorized");

        authorizedOracles[oracle] = false;
        emit OracleRevoked(oracle);
    }


    function createFeed(bytes32 feedId, string calldata description, uint32 decimals) external onlyOwner validFeedId(feedId) {
        require(!priceFeeds[feedId].isActive, "Feed already exists");
        require(bytes(description).length > 0, "Description cannot be empty");
        require(decimals <= 18, "Decimals too high");

        priceFeeds[feedId] = DataFeed({
            value: 0,
            timestamp: 0,
            decimals: decimals,
            isActive: true
        });

        feedDescriptions[feedId] = description;
        emit FeedCreated(feedId, description);
    }

    function deactivateFeed(bytes32 feedId) external onlyOwner validFeedId(feedId) {
        require(priceFeeds[feedId].isActive, "Feed not active");

        priceFeeds[feedId].isActive = false;
        emit FeedDeactivated(feedId);
    }


    function updateData(bytes32 feedId, uint256 value) external onlyAuthorizedOracle validFeedId(feedId) {
        require(priceFeeds[feedId].isActive, "Feed not active");
        require(value > 0, "Value must be greater than zero");

        uint64 currentTimestamp = uint64(block.timestamp);
        require(currentTimestamp > priceFeeds[feedId].timestamp, "Timestamp must be newer");

        priceFeeds[feedId].value = value;
        priceFeeds[feedId].timestamp = currentTimestamp;

        emit DataUpdated(feedId, value, currentTimestamp);
    }


    function batchUpdateData(bytes32[] calldata feedIds, uint256[] calldata values) external onlyAuthorizedOracle {
        require(feedIds.length == values.length, "Arrays length mismatch");
        require(feedIds.length > 0, "Empty arrays");

        uint64 currentTimestamp = uint64(block.timestamp);

        for (uint8 i = 0; i < feedIds.length; i++) {
            bytes32 feedId = feedIds[i];
            uint256 value = values[i];

            require(feedId != bytes32(0), "Invalid feed ID");
            require(priceFeeds[feedId].isActive, "Feed not active");
            require(value > 0, "Value must be greater than zero");
            require(currentTimestamp > priceFeeds[feedId].timestamp, "Timestamp must be newer");

            priceFeeds[feedId].value = value;
            priceFeeds[feedId].timestamp = currentTimestamp;

            emit DataUpdated(feedId, value, currentTimestamp);
        }
    }


    function getLatestData(bytes32 feedId) external view validFeedId(feedId) returns (uint256 value, uint64 timestamp, uint32 decimals, bool isActive) {
        DataFeed memory feed = priceFeeds[feedId];
        return (feed.value, feed.timestamp, feed.decimals, feed.isActive);
    }

    function getDataAge(bytes32 feedId) external view validFeedId(feedId) returns (uint64 age) {
        require(priceFeeds[feedId].timestamp > 0, "No data available");
        return uint64(block.timestamp) - priceFeeds[feedId].timestamp;
    }

    function isDataFresh(bytes32 feedId, uint64 maxAge) external view validFeedId(feedId) returns (bool fresh) {
        if (priceFeeds[feedId].timestamp == 0) {
            return false;
        }
        return (uint64(block.timestamp) - priceFeeds[feedId].timestamp) <= maxAge;
    }


    function getFeedDescription(bytes32 feedId) external view validFeedId(feedId) returns (string memory) {
        return feedDescriptions[feedId];
    }

    function isOracleAuthorized(address oracle) external view returns (bool) {
        return authorizedOracles[oracle];
    }

    function isFeedActive(bytes32 feedId) external view validFeedId(feedId) returns (bool) {
        return priceFeeds[feedId].isActive;
    }


    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner address");
        require(newOwner != owner, "New owner is the same as current owner");

        owner = newOwner;
    }
}
