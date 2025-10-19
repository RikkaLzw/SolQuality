
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
        address updater;
        uint256 heartbeat;
        PriceData latestData;
    }

    mapping(bytes32 => DataFeed) public dataFeeds;
    mapping(bytes32 => mapping(uint256 => PriceData)) public historicalData;
    mapping(address => bool) public authorizedUpdaters;

    address public owner;
    uint256 public constant MAX_HEARTBEAT = 86400;
    uint256 public constant MIN_HEARTBEAT = 60;

    event DataFeedCreated(
        bytes32 indexed feedId,
        string description,
        uint8 decimals,
        address indexed updater,
        uint256 heartbeat
    );

    event PriceUpdated(
        bytes32 indexed feedId,
        uint256 indexed roundId,
        uint256 price,
        uint256 timestamp,
        address indexed updater
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
        if (msg.sender != owner) {
            revert("PriceOracle: caller is not the owner");
        }
        _;
    }

    modifier onlyAuthorizedUpdater() {
        if (!authorizedUpdaters[msg.sender]) {
            revert("PriceOracle: caller is not an authorized updater");
        }
        _;
    }

    modifier validFeedId(bytes32 feedId) {
        if (feedId == bytes32(0)) {
            revert("PriceOracle: invalid feed ID");
        }
        _;
    }

    modifier feedExists(bytes32 feedId) {
        if (dataFeeds[feedId].updater == address(0)) {
            revert("PriceOracle: data feed does not exist");
        }
        _;
    }

    modifier feedActive(bytes32 feedId) {
        if (!dataFeeds[feedId].isActive) {
            revert("PriceOracle: data feed is not active");
        }
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedUpdaters[msg.sender] = true;
        emit UpdaterAuthorized(msg.sender, true);
    }

    function createDataFeed(
        bytes32 feedId,
        string memory description,
        uint8 decimals,
        address updater,
        uint256 heartbeat
    ) external onlyOwner validFeedId(feedId) {
        if (dataFeeds[feedId].updater != address(0)) {
            revert("PriceOracle: data feed already exists");
        }
        if (updater == address(0)) {
            revert("PriceOracle: invalid updater address");
        }
        if (bytes(description).length == 0) {
            revert("PriceOracle: description cannot be empty");
        }
        if (heartbeat < MIN_HEARTBEAT || heartbeat > MAX_HEARTBEAT) {
            revert("PriceOracle: invalid heartbeat duration");
        }

        dataFeeds[feedId] = DataFeed({
            description: description,
            decimals: decimals,
            isActive: true,
            updater: updater,
            heartbeat: heartbeat,
            latestData: PriceData({
                price: 0,
                timestamp: 0,
                roundId: 0,
                isValid: false
            })
        });

        emit DataFeedCreated(feedId, description, decimals, updater, heartbeat);
    }

    function updatePrice(
        bytes32 feedId,
        uint256 price
    ) external onlyAuthorizedUpdater feedExists(feedId) feedActive(feedId) {
        DataFeed storage feed = dataFeeds[feedId];

        if (msg.sender != feed.updater && msg.sender != owner) {
            revert("PriceOracle: not authorized to update this feed");
        }
        if (price == 0) {
            revert("PriceOracle: price cannot be zero");
        }

        uint256 newRoundId = feed.latestData.roundId + 1;
        uint256 currentTimestamp = block.timestamp;

        PriceData memory newData = PriceData({
            price: price,
            timestamp: currentTimestamp,
            roundId: newRoundId,
            isValid: true
        });

        feed.latestData = newData;
        historicalData[feedId][newRoundId] = newData;

        emit PriceUpdated(feedId, newRoundId, price, currentTimestamp, msg.sender);
    }

    function getLatestPrice(bytes32 feedId)
        external
        view
        feedExists(feedId)
        returns (uint256 price, uint256 timestamp, uint256 roundId)
    {
        PriceData memory data = dataFeeds[feedId].latestData;

        if (!data.isValid) {
            revert("PriceOracle: no valid price data available");
        }


        if (block.timestamp - data.timestamp > dataFeeds[feedId].heartbeat) {
            revert("PriceOracle: price data is stale");
        }

        return (data.price, data.timestamp, data.roundId);
    }

    function getHistoricalPrice(bytes32 feedId, uint256 roundId)
        external
        view
        feedExists(feedId)
        returns (uint256 price, uint256 timestamp, bool isValid)
    {
        PriceData memory data = historicalData[feedId][roundId];

        if (roundId == 0 || !data.isValid) {
            revert("PriceOracle: historical data not found for specified round");
        }

        return (data.price, data.timestamp, data.isValid);
    }

    function setDataFeedStatus(bytes32 feedId, bool isActive)
        external
        onlyOwner
        feedExists(feedId)
    {
        dataFeeds[feedId].isActive = isActive;
        emit DataFeedStatusChanged(feedId, isActive);
    }

    function authorizeUpdater(address updater, bool authorized) external onlyOwner {
        if (updater == address(0)) {
            revert("PriceOracle: invalid updater address");
        }

        authorizedUpdaters[updater] = authorized;
        emit UpdaterAuthorized(updater, authorized);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) {
            revert("PriceOracle: new owner cannot be zero address");
        }

        address previousOwner = owner;
        owner = newOwner;
        authorizedUpdaters[newOwner] = true;

        emit OwnershipTransferred(previousOwner, newOwner);
        emit UpdaterAuthorized(newOwner, true);
    }

    function getDataFeedInfo(bytes32 feedId)
        external
        view
        feedExists(feedId)
        returns (
            string memory description,
            uint8 decimals,
            bool isActive,
            address updater,
            uint256 heartbeat,
            uint256 latestPrice,
            uint256 latestTimestamp,
            uint256 latestRoundId
        )
    {
        DataFeed memory feed = dataFeeds[feedId];
        return (
            feed.description,
            feed.decimals,
            feed.isActive,
            feed.updater,
            feed.heartbeat,
            feed.latestData.price,
            feed.latestData.timestamp,
            feed.latestData.roundId
        );
    }

    function isPriceStale(bytes32 feedId) external view feedExists(feedId) returns (bool) {
        PriceData memory data = dataFeeds[feedId].latestData;

        if (!data.isValid) {
            return true;
        }

        return block.timestamp - data.timestamp > dataFeeds[feedId].heartbeat;
    }
}
