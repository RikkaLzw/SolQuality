
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract OptimizedPriceOracle is Ownable, ReentrancyGuard, Pausable {


    struct PriceData {
        uint128 price;
        uint64 timestamp;
        uint64 roundId;
    }

    struct OracleConfig {
        uint32 heartbeat;
        uint32 deviationThreshold;
        uint16 minAnswers;
        bool isActive;
    }


    mapping(bytes32 => PriceData) private priceFeeds;
    mapping(bytes32 => OracleConfig) private feedConfigs;
    mapping(address => bool) private authorizedOracles;
    mapping(bytes32 => uint256) private lastUpdateBlocks;


    mapping(bytes32 => uint256) private cachedPrices;
    mapping(bytes32 => uint256) private cacheTimestamps;
    uint256 private constant CACHE_DURATION = 300;


    event PriceUpdated(bytes32 indexed feedId, uint256 price, uint256 timestamp, uint256 roundId);
    event OracleAuthorized(address indexed oracle);
    event OracleRevoked(address indexed oracle);
    event FeedConfigured(bytes32 indexed feedId, uint32 heartbeat, uint32 deviationThreshold);


    error UnauthorizedOracle();
    error InvalidPrice();
    error StalePrice();
    error InvalidFeedId();
    error ConfigurationError();

    modifier onlyAuthorizedOracle() {
        if (!authorizedOracles[msg.sender]) revert UnauthorizedOracle();
        _;
    }

    modifier validFeedId(bytes32 feedId) {
        if (feedId == bytes32(0)) revert InvalidFeedId();
        _;
    }

    constructor() {
        authorizedOracles[msg.sender] = true;
    }


    function updatePrice(
        bytes32 feedId,
        uint128 price,
        uint64 roundId
    ) external onlyAuthorizedOracle whenNotPaused validFeedId(feedId) {
        if (price == 0) revert InvalidPrice();

        uint64 currentTimestamp = uint64(block.timestamp);


        PriceData storage currentData = priceFeeds[feedId];
        OracleConfig memory config = feedConfigs[feedId];


        if (config.deviationThreshold > 0 && currentData.price > 0) {
            uint256 deviation = _calculateDeviation(currentData.price, price);
            if (deviation > config.deviationThreshold) {

            }
        }


        currentData.price = price;
        currentData.timestamp = currentTimestamp;
        currentData.roundId = roundId;


        cachedPrices[feedId] = price;
        cacheTimestamps[feedId] = currentTimestamp;


        lastUpdateBlocks[feedId] = block.number;

        emit PriceUpdated(feedId, price, currentTimestamp, roundId);
    }


    function getLatestPrice(bytes32 feedId)
        external
        view
        validFeedId(feedId)
        returns (uint256 price, uint256 timestamp)
    {

        uint256 cacheTime = cacheTimestamps[feedId];
        if (block.timestamp - cacheTime <= CACHE_DURATION) {
            return (cachedPrices[feedId], cacheTime);
        }


        PriceData memory data = priceFeeds[feedId];
        if (data.timestamp == 0) revert InvalidFeedId();

        return (data.price, data.timestamp);
    }


    function getPriceData(bytes32 feedId)
        external
        view
        validFeedId(feedId)
        returns (uint256 price, uint256 timestamp, uint256 roundId)
    {
        PriceData memory data = priceFeeds[feedId];
        OracleConfig memory config = feedConfigs[feedId];

        if (data.timestamp == 0) revert InvalidFeedId();


        if (config.heartbeat > 0 && block.timestamp - data.timestamp > config.heartbeat) {
            revert StalePrice();
        }

        return (data.price, data.timestamp, data.roundId);
    }


    function batchUpdatePrices(
        bytes32[] calldata feedIds,
        uint128[] calldata prices,
        uint64[] calldata roundIds
    ) external onlyAuthorizedOracle whenNotPaused {
        uint256 length = feedIds.length;
        if (length != prices.length || length != roundIds.length) revert ConfigurationError();

        uint64 currentTimestamp = uint64(block.timestamp);

        for (uint256 i = 0; i < length;) {
            bytes32 feedId = feedIds[i];
            uint128 price = prices[i];

            if (feedId != bytes32(0) && price > 0) {
                PriceData storage data = priceFeeds[feedId];
                data.price = price;
                data.timestamp = currentTimestamp;
                data.roundId = roundIds[i];


                cachedPrices[feedId] = price;
                cacheTimestamps[feedId] = currentTimestamp;

                emit PriceUpdated(feedId, price, currentTimestamp, roundIds[i]);
            }

            unchecked { ++i; }
        }
    }


    function configureFeed(
        bytes32 feedId,
        uint32 heartbeat,
        uint32 deviationThreshold,
        uint16 minAnswers
    ) external onlyOwner validFeedId(feedId) {
        feedConfigs[feedId] = OracleConfig({
            heartbeat: heartbeat,
            deviationThreshold: deviationThreshold,
            minAnswers: minAnswers,
            isActive: true
        });

        emit FeedConfigured(feedId, heartbeat, deviationThreshold);
    }


    function authorizeOracle(address oracle) external onlyOwner {
        if (oracle == address(0)) revert ConfigurationError();
        authorizedOracles[oracle] = true;
        emit OracleAuthorized(oracle);
    }


    function revokeOracle(address oracle) external onlyOwner {
        authorizedOracles[oracle] = false;
        emit OracleRevoked(oracle);
    }


    function isStale(bytes32 feedId) external view returns (bool isStale) {
        PriceData memory data = priceFeeds[feedId];
        OracleConfig memory config = feedConfigs[feedId];

        if (data.timestamp == 0 || config.heartbeat == 0) return true;
        return block.timestamp - data.timestamp > config.heartbeat;
    }


    function getFeedConfig(bytes32 feedId) external view returns (OracleConfig memory config) {
        return feedConfigs[feedId];
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
    }


    function _calculateDeviation(uint128 oldPrice, uint128 newPrice) private pure returns (uint256 deviation) {
        if (oldPrice == 0) return 0;

        uint256 diff = oldPrice > newPrice ? oldPrice - newPrice : newPrice - oldPrice;
        return (diff * 10000) / oldPrice;
    }
}
