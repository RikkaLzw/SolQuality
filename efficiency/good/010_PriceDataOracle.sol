
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract PriceDataOracle is Ownable, ReentrancyGuard, Pausable {
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint256 blockNumber;
        bool isValid;
    }

    struct AggregatedPrice {
        uint256 price;
        uint256 confidence;
        uint256 lastUpdate;
    }


    struct OracleConfig {
        uint128 maxPriceAge;
        uint64 minConfidence;
        uint32 aggregationWindow;
        uint32 maxSources;
    }


    mapping(bytes32 => AggregatedPrice) public aggregatedPrices;
    mapping(bytes32 => mapping(address => PriceData)) public priceFeeds;
    mapping(address => bool) public authorizedOracles;
    mapping(bytes32 => address[]) public priceSources;

    OracleConfig public config;


    event PriceUpdated(bytes32 indexed symbol, uint256 price, uint256 confidence, address oracle);
    event OracleAuthorized(address indexed oracle);
    event OracleRevoked(address indexed oracle);
    event ConfigUpdated(uint128 maxPriceAge, uint64 minConfidence, uint32 aggregationWindow);


    error UnauthorizedOracle();
    error InvalidPrice();
    error PriceExpired();
    error InsufficientConfidence();
    error InvalidSymbol();

    modifier onlyAuthorizedOracle() {
        if (!authorizedOracles[msg.sender]) revert UnauthorizedOracle();
        _;
    }

    constructor(
        uint128 _maxPriceAge,
        uint64 _minConfidence,
        uint32 _aggregationWindow,
        uint32 _maxSources
    ) {
        config = OracleConfig({
            maxPriceAge: _maxPriceAge,
            minConfidence: _minConfidence,
            aggregationWindow: _aggregationWindow,
            maxSources: _maxSources
        });
    }

    function updatePrice(
        bytes32 symbol,
        uint256 price,
        uint256 confidence
    ) external onlyAuthorizedOracle whenNotPaused nonReentrant {
        if (symbol == bytes32(0)) revert InvalidSymbol();
        if (price == 0) revert InvalidPrice();


        OracleConfig memory _config = config;


        priceFeeds[symbol][msg.sender] = PriceData({
            price: price,
            timestamp: block.timestamp,
            blockNumber: block.number,
            isValid: true
        });


        address[] storage sources = priceSources[symbol];
        bool sourceExists = false;
        uint256 sourcesLength = sources.length;

        for (uint256 i = 0; i < sourcesLength;) {
            if (sources[i] == msg.sender) {
                sourceExists = true;
                break;
            }
            unchecked { ++i; }
        }

        if (!sourceExists && sourcesLength < _config.maxSources) {
            sources.push(msg.sender);
        }


        _aggregatePrices(symbol, _config);

        emit PriceUpdated(symbol, price, confidence, msg.sender);
    }

    function _aggregatePrices(bytes32 symbol, OracleConfig memory _config) private {
        address[] memory sources = priceSources[symbol];
        uint256 sourcesLength = sources.length;

        if (sourcesLength == 0) return;


        uint256[] memory validPrices = new uint256[](sourcesLength);
        uint256[] memory weights = new uint256[](sourcesLength);
        uint256 validCount = 0;
        uint256 totalWeight = 0;
        uint256 currentTime = block.timestamp;


        for (uint256 i = 0; i < sourcesLength;) {
            PriceData storage priceData = priceFeeds[symbol][sources[i]];

            if (priceData.isValid &&
                currentTime - priceData.timestamp <= _config.maxPriceAge) {

                validPrices[validCount] = priceData.price;
                weights[validCount] = _calculateWeight(currentTime - priceData.timestamp, _config.maxPriceAge);
                totalWeight += weights[validCount];
                unchecked { ++validCount; }
            }
            unchecked { ++i; }
        }

        if (validCount == 0) return;


        uint256 weightedSum = 0;
        for (uint256 i = 0; i < validCount;) {
            weightedSum += (validPrices[i] * weights[i]);
            unchecked { ++i; }
        }

        uint256 aggregatedPrice = weightedSum / totalWeight;
        uint256 confidence = _calculateConfidence(validCount, sourcesLength);


        if (confidence >= _config.minConfidence) {
            aggregatedPrices[symbol] = AggregatedPrice({
                price: aggregatedPrice,
                confidence: confidence,
                lastUpdate: currentTime
            });
        }
    }

    function _calculateWeight(uint256 age, uint256 maxAge) private pure returns (uint256) {

        return maxAge - age;
    }

    function _calculateConfidence(uint256 validSources, uint256 totalSources) private pure returns (uint256) {

        return (validSources * 100) / totalSources;
    }

    function getPrice(bytes32 symbol) external view returns (uint256 price, uint256 confidence, uint256 lastUpdate) {
        AggregatedPrice memory data = aggregatedPrices[symbol];

        if (data.lastUpdate == 0) revert InvalidSymbol();
        if (block.timestamp - data.lastUpdate > config.maxPriceAge) revert PriceExpired();
        if (data.confidence < config.minConfidence) revert InsufficientConfidence();

        return (data.price, data.confidence, data.lastUpdate);
    }

    function getPriceUnsafe(bytes32 symbol) external view returns (uint256 price, uint256 confidence, uint256 lastUpdate) {
        AggregatedPrice memory data = aggregatedPrices[symbol];
        return (data.price, data.confidence, data.lastUpdate);
    }

    function getMultiplePrices(bytes32[] calldata symbols) external view returns (
        uint256[] memory prices,
        uint256[] memory confidences,
        uint256[] memory lastUpdates
    ) {
        uint256 length = symbols.length;
        prices = new uint256[](length);
        confidences = new uint256[](length);
        lastUpdates = new uint256[](length);


        OracleConfig memory _config = config;
        uint256 currentTime = block.timestamp;

        for (uint256 i = 0; i < length;) {
            AggregatedPrice memory data = aggregatedPrices[symbols[i]];

            if (data.lastUpdate != 0 &&
                currentTime - data.lastUpdate <= _config.maxPriceAge &&
                data.confidence >= _config.minConfidence) {

                prices[i] = data.price;
                confidences[i] = data.confidence;
                lastUpdates[i] = data.lastUpdate;
            }

            unchecked { ++i; }
        }
    }


    function authorizeOracle(address oracle) external onlyOwner {
        authorizedOracles[oracle] = true;
        emit OracleAuthorized(oracle);
    }

    function revokeOracle(address oracle) external onlyOwner {
        authorizedOracles[oracle] = false;
        emit OracleRevoked(oracle);
    }

    function updateConfig(
        uint128 _maxPriceAge,
        uint64 _minConfidence,
        uint32 _aggregationWindow,
        uint32 _maxSources
    ) external onlyOwner {
        config = OracleConfig({
            maxPriceAge: _maxPriceAge,
            minConfidence: _minConfidence,
            aggregationWindow: _aggregationWindow,
            maxSources: _maxSources
        });

        emit ConfigUpdated(_maxPriceAge, _minConfidence, _aggregationWindow);
    }

    function invalidatePrice(bytes32 symbol, address oracle) external onlyOwner {
        priceFeeds[symbol][oracle].isValid = false;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }


    function getSourceCount(bytes32 symbol) external view returns (uint256) {
        return priceSources[symbol].length;
    }

    function getSources(bytes32 symbol) external view returns (address[] memory) {
        return priceSources[symbol];
    }

    function getSourcePrice(bytes32 symbol, address oracle) external view returns (PriceData memory) {
        return priceFeeds[symbol][oracle];
    }
}
