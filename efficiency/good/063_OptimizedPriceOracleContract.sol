
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract OptimizedPriceOracleContract is Ownable, ReentrancyGuard, Pausable {
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint256 confidence;
    }

    struct AggregatedPrice {
        uint256 weightedPrice;
        uint256 totalWeight;
        uint256 lastUpdate;
        bool isValid;
    }


    struct OracleInfo {
        address oracle;
        uint128 weight;
        uint128 lastUpdateTime;
        bool isActive;
    }


    mapping(bytes32 => PriceData) private priceFeeds;
    mapping(bytes32 => AggregatedPrice) private aggregatedPrices;
    mapping(address => bool) public authorizedOracles;
    mapping(bytes32 => OracleInfo[]) private oraclesBySymbol;


    mapping(bytes32 => uint256) private priceCache;
    mapping(bytes32 => uint256) private cacheTimestamp;

    bytes32[] public supportedSymbols;

    uint256 public constant CACHE_DURATION = 300;
    uint256 public constant MAX_PRICE_AGE = 3600;
    uint256 public constant MIN_ORACLES_REQUIRED = 3;
    uint256 public constant CONFIDENCE_THRESHOLD = 80;

    event PriceUpdated(bytes32 indexed symbol, uint256 price, uint256 timestamp, address oracle);
    event OracleAdded(address indexed oracle, bytes32 indexed symbol, uint256 weight);
    event OracleRemoved(address indexed oracle, bytes32 indexed symbol);
    event SymbolAdded(bytes32 indexed symbol);

    modifier onlyAuthorizedOracle() {
        require(authorizedOracles[msg.sender], "Unauthorized oracle");
        _;
    }

    modifier validSymbol(bytes32 symbol) {
        require(symbol != bytes32(0), "Invalid symbol");
        _;
    }

    constructor() {
        _transferOwnership(msg.sender);
    }

    function addOracle(
        address oracle,
        bytes32 symbol,
        uint128 weight
    ) external onlyOwner validSymbol(symbol) {
        require(oracle != address(0), "Invalid oracle address");
        require(weight > 0, "Weight must be positive");

        authorizedOracles[oracle] = true;


        if (!_symbolExists(symbol)) {
            supportedSymbols.push(symbol);
            emit SymbolAdded(symbol);
        }

        oraclesBySymbol[symbol].push(OracleInfo({
            oracle: oracle,
            weight: weight,
            lastUpdateTime: uint128(block.timestamp),
            isActive: true
        }));

        emit OracleAdded(oracle, symbol, weight);
    }

    function removeOracle(address oracle, bytes32 symbol) external onlyOwner {
        OracleInfo[] storage oracles = oraclesBySymbol[symbol];

        for (uint256 i = 0; i < oracles.length; i++) {
            if (oracles[i].oracle == oracle) {
                oracles[i].isActive = false;
                emit OracleRemoved(oracle, symbol);
                break;
            }
        }
    }

    function updatePrice(
        bytes32 symbol,
        uint256 price,
        uint256 confidence
    ) external onlyAuthorizedOracle whenNotPaused validSymbol(symbol) {
        require(price > 0, "Price must be positive");
        require(confidence <= 100, "Invalid confidence");
        require(confidence >= CONFIDENCE_THRESHOLD, "Confidence too low");

        bytes32 feedKey = keccak256(abi.encodePacked(symbol, msg.sender));


        priceFeeds[feedKey] = PriceData({
            price: price,
            timestamp: block.timestamp,
            confidence: confidence
        });


        _updateAggregatedPrice(symbol);


        delete priceCache[symbol];
        delete cacheTimestamp[symbol];

        emit PriceUpdated(symbol, price, block.timestamp, msg.sender);
    }

    function getPrice(bytes32 symbol) external view returns (uint256 price, uint256 timestamp) {

        if (_isCacheValid(symbol)) {
            return (priceCache[symbol], cacheTimestamp[symbol]);
        }

        AggregatedPrice memory aggPrice = aggregatedPrices[symbol];
        require(aggPrice.isValid, "No valid price data");
        require(block.timestamp - aggPrice.lastUpdate <= MAX_PRICE_AGE, "Price data too old");

        return (aggPrice.weightedPrice, aggPrice.lastUpdate);
    }

    function getPriceWithConfidence(bytes32 symbol)
        external
        view
        returns (uint256 price, uint256 timestamp, uint256 confidence)
    {
        (price, timestamp) = this.getPrice(symbol);


        uint256 totalConfidence;
        uint256 activeOracles;

        OracleInfo[] memory oracles = oraclesBySymbol[symbol];
        for (uint256 i = 0; i < oracles.length; i++) {
            if (oracles[i].isActive) {
                bytes32 feedKey = keccak256(abi.encodePacked(symbol, oracles[i].oracle));
                PriceData memory feed = priceFeeds[feedKey];

                if (block.timestamp - feed.timestamp <= MAX_PRICE_AGE) {
                    totalConfidence += feed.confidence;
                    activeOracles++;
                }
            }
        }

        confidence = activeOracles > 0 ? totalConfidence / activeOracles : 0;
    }

    function _updateAggregatedPrice(bytes32 symbol) private {
        OracleInfo[] memory oracles = oraclesBySymbol[symbol];
        uint256 weightedSum;
        uint256 totalWeight;
        uint256 validOracles;


        for (uint256 i = 0; i < oracles.length; i++) {
            if (!oracles[i].isActive) continue;

            bytes32 feedKey = keccak256(abi.encodePacked(symbol, oracles[i].oracle));
            PriceData memory feed = priceFeeds[feedKey];


            if (block.timestamp - feed.timestamp <= MAX_PRICE_AGE &&
                feed.confidence >= CONFIDENCE_THRESHOLD) {

                weightedSum += feed.price * oracles[i].weight;
                totalWeight += oracles[i].weight;
                validOracles++;
            }
        }

        if (validOracles >= MIN_ORACLES_REQUIRED && totalWeight > 0) {
            uint256 finalPrice = weightedSum / totalWeight;

            aggregatedPrices[symbol] = AggregatedPrice({
                weightedPrice: finalPrice,
                totalWeight: totalWeight,
                lastUpdate: block.timestamp,
                isValid: true
            });


            priceCache[symbol] = finalPrice;
            cacheTimestamp[symbol] = block.timestamp;
        } else {
            aggregatedPrices[symbol].isValid = false;
        }
    }

    function _isCacheValid(bytes32 symbol) private view returns (bool) {
        return cacheTimestamp[symbol] > 0 &&
               block.timestamp - cacheTimestamp[symbol] <= CACHE_DURATION;
    }

    function _symbolExists(bytes32 symbol) private view returns (bool) {
        for (uint256 i = 0; i < supportedSymbols.length; i++) {
            if (supportedSymbols[i] == symbol) {
                return true;
            }
        }
        return false;
    }


    function batchUpdatePrices(
        bytes32[] calldata symbols,
        uint256[] calldata prices,
        uint256[] calldata confidences
    ) external onlyAuthorizedOracle whenNotPaused {
        require(symbols.length == prices.length && prices.length == confidences.length, "Array length mismatch");

        for (uint256 i = 0; i < symbols.length; i++) {
            if (symbols[i] != bytes32(0) && prices[i] > 0 && confidences[i] >= CONFIDENCE_THRESHOLD) {
                bytes32 feedKey = keccak256(abi.encodePacked(symbols[i], msg.sender));

                priceFeeds[feedKey] = PriceData({
                    price: prices[i],
                    timestamp: block.timestamp,
                    confidence: confidences[i]
                });

                _updateAggregatedPrice(symbols[i]);

                delete priceCache[symbols[i]];
                delete cacheTimestamp[symbols[i]];

                emit PriceUpdated(symbols[i], prices[i], block.timestamp, msg.sender);
            }
        }
    }

    function getSupportedSymbols() external view returns (bytes32[] memory) {
        return supportedSymbols;
    }

    function getOracleCount(bytes32 symbol) external view returns (uint256) {
        return oraclesBySymbol[symbol].length;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
