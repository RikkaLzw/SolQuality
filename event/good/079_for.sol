
pragma solidity ^0.8.0;


contract PriceOracle {
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint256 roundId;
        bool isValid;
    }

    struct DataFeed {
        string description;
        uint8 decimals;
        bool isActive;
        address aggregator;
    }

    mapping(bytes32 => PriceData) private latestPriceData;
    mapping(bytes32 => DataFeed) private dataFeeds;
    mapping(address => bool) private authorizedUpdaters;
    mapping(bytes32 => mapping(uint256 => PriceData)) private historicalData;
    mapping(bytes32 => uint256) private roundCounters;

    address private owner;
    uint256 private constant STALENESS_THRESHOLD = 3600;
    uint256 private constant MIN_UPDATE_INTERVAL = 60;

    event PriceUpdated(
        bytes32 indexed feedId,
        uint256 indexed roundId,
        uint256 price,
        uint256 timestamp,
        address indexed updater
    );

    event DataFeedAdded(
        bytes32 indexed feedId,
        string description,
        uint8 decimals,
        address indexed aggregator
    );

    event DataFeedStatusChanged(
        bytes32 indexed feedId,
        bool isActive
    );

    event UpdaterAuthorized(
        address indexed updater,
        bool authorized
    );

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "PriceOracle: caller is not the owner");
        _;
    }

    modifier onlyAuthorizedUpdater() {
        require(authorizedUpdaters[msg.sender], "PriceOracle: caller is not authorized to update prices");
        _;
    }

    modifier validFeedId(bytes32 feedId) {
        require(dataFeeds[feedId].isActive, "PriceOracle: data feed is not active or does not exist");
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedUpdaters[msg.sender] = true;
        emit UpdaterAuthorized(msg.sender, true);
    }


    function addDataFeed(
        bytes32 feedId,
        string memory description,
        uint8 decimals,
        address aggregator
    ) external onlyOwner {
        require(feedId != bytes32(0), "PriceOracle: feed ID cannot be zero");
        require(bytes(description).length > 0, "PriceOracle: description cannot be empty");
        require(!dataFeeds[feedId].isActive, "PriceOracle: data feed already exists and is active");

        dataFeeds[feedId] = DataFeed({
            description: description,
            decimals: decimals,
            isActive: true,
            aggregator: aggregator
        });

        emit DataFeedAdded(feedId, description, decimals, aggregator);
    }


    function updatePrice(bytes32 feedId, uint256 price) external onlyAuthorizedUpdater validFeedId(feedId) {
        require(price > 0, "PriceOracle: price must be greater than zero");

        PriceData memory currentData = latestPriceData[feedId];
        require(
            block.timestamp >= currentData.timestamp + MIN_UPDATE_INTERVAL,
            "PriceOracle: update interval too short"
        );

        uint256 newRoundId = roundCounters[feedId] + 1;
        roundCounters[feedId] = newRoundId;

        PriceData memory newPriceData = PriceData({
            price: price,
            timestamp: block.timestamp,
            roundId: newRoundId,
            isValid: true
        });

        latestPriceData[feedId] = newPriceData;
        historicalData[feedId][newRoundId] = newPriceData;

        emit PriceUpdated(feedId, newRoundId, price, block.timestamp, msg.sender);
    }


    function getLatestPrice(bytes32 feedId) external view validFeedId(feedId) returns (
        uint256 price,
        uint256 timestamp,
        uint256 roundId
    ) {
        PriceData memory data = latestPriceData[feedId];
        require(data.isValid, "PriceOracle: no valid price data available");
        require(
            block.timestamp <= data.timestamp + STALENESS_THRESHOLD,
            "PriceOracle: price data is stale"
        );

        return (data.price, data.timestamp, data.roundId);
    }


    function getHistoricalPrice(bytes32 feedId, uint256 roundId) external view validFeedId(feedId) returns (
        uint256 price,
        uint256 timestamp
    ) {
        require(roundId > 0, "PriceOracle: round ID must be greater than zero");
        PriceData memory data = historicalData[feedId][roundId];
        require(data.isValid, "PriceOracle: no data available for specified round");

        return (data.price, data.timestamp);
    }


    function getDataFeedInfo(bytes32 feedId) external view returns (
        string memory description,
        uint8 decimals,
        bool isActive,
        address aggregator
    ) {
        DataFeed memory feed = dataFeeds[feedId];
        require(bytes(feed.description).length > 0, "PriceOracle: data feed does not exist");

        return (feed.description, feed.decimals, feed.isActive, feed.aggregator);
    }


    function setDataFeedStatus(bytes32 feedId, bool isActive) external onlyOwner {
        require(bytes(dataFeeds[feedId].description).length > 0, "PriceOracle: data feed does not exist");

        dataFeeds[feedId].isActive = isActive;
        emit DataFeedStatusChanged(feedId, isActive);
    }


    function setUpdaterAuthorization(address updater, bool authorized) external onlyOwner {
        require(updater != address(0), "PriceOracle: updater address cannot be zero");
        require(updater != owner || authorized, "PriceOracle: cannot deauthorize owner");

        authorizedUpdaters[updater] = authorized;
        emit UpdaterAuthorized(updater, authorized);
    }


    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "PriceOracle: new owner cannot be zero address");
        require(newOwner != owner, "PriceOracle: new owner must be different from current owner");

        address previousOwner = owner;
        owner = newOwner;
        authorizedUpdaters[newOwner] = true;

        emit OwnershipTransferred(previousOwner, newOwner);
        emit UpdaterAuthorized(newOwner, true);
    }


    function isAuthorizedUpdater(address updater) external view returns (bool) {
        return authorizedUpdaters[updater];
    }


    function getOwner() external view returns (address) {
        return owner;
    }


    function getCurrentRoundId(bytes32 feedId) external view returns (uint256) {
        return roundCounters[feedId];
    }
}
