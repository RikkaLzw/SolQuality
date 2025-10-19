
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract PriceOracleDataContract is Ownable, ReentrancyGuard, Pausable {


    uint256 public constant MAX_PRICE_DEVIATION = 10;
    uint256 public constant MIN_UPDATE_INTERVAL = 300;
    uint256 public constant MAX_DATA_AGE = 3600;
    uint256 public constant PRECISION = 1e8;


    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint256 confidence;
        bool isValid;
    }

    struct DataSource {
        address sourceAddress;
        uint256 weight;
        bool isActive;
        uint256 lastUpdate;
        string name;
    }


    mapping(string => PriceData) private _priceFeeds;
    mapping(address => DataSource) private _dataSources;
    mapping(string => address[]) private _feedSources;

    address[] private _activeSourcesList;
    string[] private _supportedAssets;

    uint256 private _totalWeight;
    uint256 private _minConfidenceThreshold;


    event PriceUpdated(
        string indexed asset,
        uint256 price,
        uint256 confidence,
        address indexed source,
        uint256 timestamp
    );

    event DataSourceAdded(
        address indexed source,
        string name,
        uint256 weight
    );

    event DataSourceRemoved(address indexed source);

    event DataSourceStatusChanged(
        address indexed source,
        bool isActive
    );

    event AssetAdded(string indexed asset);
    event AssetRemoved(string indexed asset);


    modifier onlyAuthorizedSource() {
        require(_dataSources[msg.sender].isActive, "Unauthorized data source");
        _;
    }

    modifier validAsset(string memory asset) {
        require(_isAssetSupported(asset), "Asset not supported");
        _;
    }

    modifier validPrice(uint256 price) {
        require(price > 0, "Invalid price");
        _;
    }

    modifier validConfidence(uint256 confidence) {
        require(confidence <= 100, "Invalid confidence level");
        _;
    }

    modifier notExpired(uint256 timestamp) {
        require(
            block.timestamp - timestamp <= MAX_DATA_AGE,
            "Data too old"
        );
        _;
    }

    constructor(uint256 minConfidenceThreshold) {
        require(minConfidenceThreshold <= 100, "Invalid confidence threshold");
        _minConfidenceThreshold = minConfidenceThreshold;
    }


    function addDataSource(
        address source,
        string memory name,
        uint256 weight
    ) external onlyOwner {
        require(source != address(0), "Invalid source address");
        require(weight > 0, "Weight must be positive");
        require(!_dataSources[source].isActive, "Source already exists");

        _dataSources[source] = DataSource({
            sourceAddress: source,
            weight: weight,
            isActive: true,
            lastUpdate: 0,
            name: name
        });

        _activeSourcesList.push(source);
        _totalWeight += weight;

        emit DataSourceAdded(source, name, weight);
    }


    function removeDataSource(address source) external onlyOwner {
        require(_dataSources[source].isActive, "Source not found");

        _dataSources[source].isActive = false;
        _totalWeight -= _dataSources[source].weight;

        _removeFromActiveList(source);

        emit DataSourceRemoved(source);
    }


    function addAsset(string memory asset) external onlyOwner {
        require(!_isAssetSupported(asset), "Asset already supported");

        _supportedAssets.push(asset);
        emit AssetAdded(asset);
    }


    function updatePrice(
        string memory asset,
        uint256 price,
        uint256 confidence
    )
        external
        onlyAuthorizedSource
        whenNotPaused
        nonReentrant
        validAsset(asset)
        validPrice(price)
        validConfidence(confidence)
    {
        require(
            block.timestamp - _dataSources[msg.sender].lastUpdate >= MIN_UPDATE_INTERVAL,
            "Update too frequent"
        );

        _validatePriceDeviation(asset, price);

        PriceData storage currentData = _priceFeeds[asset];


        currentData.price = price;
        currentData.timestamp = block.timestamp;
        currentData.confidence = confidence;
        currentData.isValid = confidence >= _minConfidenceThreshold;

        _dataSources[msg.sender].lastUpdate = block.timestamp;

        emit PriceUpdated(asset, price, confidence, msg.sender, block.timestamp);
    }


    function getPrice(string memory asset)
        external
        view
        validAsset(asset)
        returns (uint256 price, uint256 timestamp, uint256 confidence, bool isValid)
    {
        PriceData memory data = _priceFeeds[asset];
        require(data.timestamp > 0, "No price data available");

        return (data.price, data.timestamp, data.confidence, data.isValid);
    }


    function getAggregatedPrice(string memory asset)
        external
        view
        validAsset(asset)
        returns (uint256 weightedPrice, uint256 totalConfidence)
    {
        address[] memory sources = _feedSources[asset];
        require(sources.length > 0, "No sources for asset");

        uint256 totalWeightedPrice = 0;
        uint256 totalActiveWeight = 0;
        uint256 confidenceSum = 0;
        uint256 activeSourceCount = 0;

        for (uint256 i = 0; i < sources.length; i++) {
            address source = sources[i];
            DataSource memory sourceData = _dataSources[source];

            if (sourceData.isActive &&
                block.timestamp - sourceData.lastUpdate <= MAX_DATA_AGE) {

                PriceData memory priceData = _priceFeeds[asset];
                if (priceData.isValid) {
                    totalWeightedPrice += priceData.price * sourceData.weight;
                    totalActiveWeight += sourceData.weight;
                    confidenceSum += priceData.confidence;
                    activeSourceCount++;
                }
            }
        }

        require(totalActiveWeight > 0, "No active sources");

        weightedPrice = totalWeightedPrice / totalActiveWeight;
        totalConfidence = confidenceSum / activeSourceCount;
    }


    function isPriceDataFresh(string memory asset)
        external
        view
        validAsset(asset)
        returns (bool)
    {
        PriceData memory data = _priceFeeds[asset];
        return data.timestamp > 0 &&
               block.timestamp - data.timestamp <= MAX_DATA_AGE &&
               data.isValid;
    }


    function getDataSource(address source)
        external
        view
        returns (
            string memory name,
            uint256 weight,
            bool isActive,
            uint256 lastUpdate
        )
    {
        DataSource memory sourceData = _dataSources[source];
        return (sourceData.name, sourceData.weight, sourceData.isActive, sourceData.lastUpdate);
    }


    function getSupportedAssets() external view returns (string[] memory) {
        return _supportedAssets;
    }


    function setMinConfidenceThreshold(uint256 threshold) external onlyOwner {
        require(threshold <= 100, "Invalid threshold");
        _minConfidenceThreshold = threshold;
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
    }


    function _isAssetSupported(string memory asset) internal view returns (bool) {
        for (uint256 i = 0; i < _supportedAssets.length; i++) {
            if (keccak256(bytes(_supportedAssets[i])) == keccak256(bytes(asset))) {
                return true;
            }
        }
        return false;
    }

    function _validatePriceDeviation(string memory asset, uint256 newPrice) internal view {
        PriceData memory currentData = _priceFeeds[asset];

        if (currentData.timestamp > 0 && currentData.isValid) {
            uint256 deviation = _calculateDeviation(currentData.price, newPrice);
            require(deviation <= MAX_PRICE_DEVIATION, "Price deviation too high");
        }
    }

    function _calculateDeviation(uint256 oldPrice, uint256 newPrice) internal pure returns (uint256) {
        if (oldPrice == 0) return 0;

        uint256 diff = oldPrice > newPrice ? oldPrice - newPrice : newPrice - oldPrice;
        return (diff * 100) / oldPrice;
    }

    function _removeFromActiveList(address source) internal {
        for (uint256 i = 0; i < _activeSourcesList.length; i++) {
            if (_activeSourcesList[i] == source) {
                _activeSourcesList[i] = _activeSourcesList[_activeSourcesList.length - 1];
                _activeSourcesList.pop();
                break;
            }
        }
    }
}
