
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract PriceOracleDataContract is Ownable, ReentrancyGuard, Pausable {


    uint256 public constant MAX_PRICE_DEVIATION = 500;
    uint256 public constant MIN_UPDATE_INTERVAL = 300;
    uint256 public constant MAX_DATA_STALENESS = 3600;
    uint256 public constant BASIS_POINTS = 10000;


    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint256 confidence;
        bool isActive;
    }

    struct DataSource {
        address sourceAddress;
        uint256 weight;
        bool isAuthorized;
        uint256 lastUpdateTime;
    }


    mapping(string => PriceData) private _priceFeeds;
    mapping(address => DataSource) private _dataSources;
    mapping(string => address[]) private _feedSources;

    address[] private _authorizedSources;
    string[] private _supportedAssets;

    uint256 private _totalWeight;
    uint256 private _minConfidenceLevel;


    event PriceUpdated(string indexed asset, uint256 price, uint256 timestamp, address indexed source);
    event DataSourceAdded(address indexed source, uint256 weight);
    event DataSourceRemoved(address indexed source);
    event DataSourceWeightUpdated(address indexed source, uint256 oldWeight, uint256 newWeight);
    event AssetAdded(string indexed asset);
    event AssetRemoved(string indexed asset);
    event ConfidenceLevelUpdated(uint256 oldLevel, uint256 newLevel);


    modifier onlyAuthorizedSource() {
        require(_dataSources[msg.sender].isAuthorized, "Unauthorized data source");
        _;
    }

    modifier validAsset(string memory asset) {
        require(_isAssetSupported(asset), "Asset not supported");
        _;
    }

    modifier validPrice(uint256 price) {
        require(price > 0, "Price must be greater than zero");
        _;
    }

    modifier validConfidence(uint256 confidence) {
        require(confidence <= BASIS_POINTS, "Invalid confidence level");
        _;
    }

    modifier notStale(string memory asset) {
        require(
            block.timestamp - _priceFeeds[asset].timestamp <= MAX_DATA_STALENESS,
            "Data is stale"
        );
        _;
    }

    constructor(uint256 minConfidenceLevel) {
        require(minConfidenceLevel <= BASIS_POINTS, "Invalid confidence level");
        _minConfidenceLevel = minConfidenceLevel;
    }


    function addDataSource(
        address sourceAddress,
        uint256 weight
    ) external onlyOwner {
        require(sourceAddress != address(0), "Invalid source address");
        require(weight > 0, "Weight must be greater than zero");
        require(!_dataSources[sourceAddress].isAuthorized, "Source already exists");

        _dataSources[sourceAddress] = DataSource({
            sourceAddress: sourceAddress,
            weight: weight,
            isAuthorized: true,
            lastUpdateTime: 0
        });

        _authorizedSources.push(sourceAddress);
        _totalWeight += weight;

        emit DataSourceAdded(sourceAddress, weight);
    }


    function removeDataSource(address sourceAddress) external onlyOwner {
        require(_dataSources[sourceAddress].isAuthorized, "Source not found");

        uint256 weight = _dataSources[sourceAddress].weight;
        _dataSources[sourceAddress].isAuthorized = false;
        _totalWeight -= weight;

        _removeFromAuthorizedSources(sourceAddress);

        emit DataSourceRemoved(sourceAddress);
    }


    function updateSourceWeight(
        address sourceAddress,
        uint256 newWeight
    ) external onlyOwner {
        require(_dataSources[sourceAddress].isAuthorized, "Source not found");
        require(newWeight > 0, "Weight must be greater than zero");

        uint256 oldWeight = _dataSources[sourceAddress].weight;
        _dataSources[sourceAddress].weight = newWeight;
        _totalWeight = _totalWeight - oldWeight + newWeight;

        emit DataSourceWeightUpdated(sourceAddress, oldWeight, newWeight);
    }


    function addSupportedAsset(string memory asset) external onlyOwner {
        require(bytes(asset).length > 0, "Invalid asset name");
        require(!_isAssetSupported(asset), "Asset already supported");

        _supportedAssets.push(asset);
        emit AssetAdded(asset);
    }


    function removeSupportedAsset(string memory asset) external onlyOwner validAsset(asset) {
        _removeFromSupportedAssets(asset);
        delete _priceFeeds[asset];
        emit AssetRemoved(asset);
    }


    function updatePrice(
        string memory asset,
        uint256 price,
        uint256 confidence
    ) external
        whenNotPaused
        onlyAuthorizedSource
        validAsset(asset)
        validPrice(price)
        validConfidence(confidence)
        nonReentrant
    {
        require(
            block.timestamp - _dataSources[msg.sender].lastUpdateTime >= MIN_UPDATE_INTERVAL,
            "Update too frequent"
        );


        if (_priceFeeds[asset].timestamp > 0) {
            _validatePriceDeviation(asset, price);
        }

        _priceFeeds[asset] = PriceData({
            price: price,
            timestamp: block.timestamp,
            confidence: confidence,
            isActive: true
        });

        _dataSources[msg.sender].lastUpdateTime = block.timestamp;

        emit PriceUpdated(asset, price, block.timestamp, msg.sender);
    }


    function getPrice(string memory asset)
        external
        view
        validAsset(asset)
        notStale(asset)
        returns (uint256 price, uint256 timestamp, uint256 confidence)
    {
        PriceData memory data = _priceFeeds[asset];
        require(data.isActive, "Price feed inactive");
        require(data.confidence >= _minConfidenceLevel, "Confidence too low");

        return (data.price, data.timestamp, data.confidence);
    }


    function getAggregatedPrice(string memory asset)
        external
        view
        validAsset(asset)
        returns (uint256 aggregatedPrice, uint256 totalConfidence)
    {
        address[] memory sources = _feedSources[asset];
        require(sources.length > 0, "No sources for asset");

        uint256 weightedSum = 0;
        uint256 totalValidWeight = 0;
        uint256 confidenceSum = 0;

        for (uint256 i = 0; i < sources.length; i++) {
            address source = sources[i];
            if (_dataSources[source].isAuthorized) {
                PriceData memory data = _priceFeeds[asset];
                if (data.isActive &&
                    block.timestamp - data.timestamp <= MAX_DATA_STALENESS &&
                    data.confidence >= _minConfidenceLevel) {

                    uint256 weight = _dataSources[source].weight;
                    weightedSum += data.price * weight;
                    totalValidWeight += weight;
                    confidenceSum += data.confidence * weight;
                }
            }
        }

        require(totalValidWeight > 0, "No valid price data");

        aggregatedPrice = weightedSum / totalValidWeight;
        totalConfidence = confidenceSum / totalValidWeight;
    }


    function isPriceValid(string memory asset)
        external
        view
        validAsset(asset)
        returns (bool)
    {
        PriceData memory data = _priceFeeds[asset];
        return data.isActive &&
               block.timestamp - data.timestamp <= MAX_DATA_STALENESS &&
               data.confidence >= _minConfidenceLevel;
    }


    function setMinConfidenceLevel(uint256 newLevel) external onlyOwner validConfidence(newLevel) {
        uint256 oldLevel = _minConfidenceLevel;
        _minConfidenceLevel = newLevel;
        emit ConfidenceLevelUpdated(oldLevel, newLevel);
    }


    function pause() external onlyOwner {
        _pause();
    }


    function unpause() external onlyOwner {
        _unpause();
    }


    function getDataSource(address sourceAddress)
        external
        view
        returns (uint256 weight, bool isAuthorized, uint256 lastUpdateTime)
    {
        DataSource memory source = _dataSources[sourceAddress];
        return (source.weight, source.isAuthorized, source.lastUpdateTime);
    }

    function getSupportedAssets() external view returns (string[] memory) {
        return _supportedAssets;
    }

    function getAuthorizedSources() external view returns (address[] memory) {
        return _authorizedSources;
    }

    function getTotalWeight() external view returns (uint256) {
        return _totalWeight;
    }

    function getMinConfidenceLevel() external view returns (uint256) {
        return _minConfidenceLevel;
    }


    function _isAssetSupported(string memory asset) internal view returns (bool) {
        for (uint256 i = 0; i < _supportedAssets.length; i++) {
            if (keccak256(bytes(_supportedAssets[i])) == keccak256(bytes(asset))) {
                return true;
            }
        }
        return false;
    }

    function _removeFromAuthorizedSources(address sourceAddress) internal {
        for (uint256 i = 0; i < _authorizedSources.length; i++) {
            if (_authorizedSources[i] == sourceAddress) {
                _authorizedSources[i] = _authorizedSources[_authorizedSources.length - 1];
                _authorizedSources.pop();
                break;
            }
        }
    }

    function _removeFromSupportedAssets(string memory asset) internal {
        for (uint256 i = 0; i < _supportedAssets.length; i++) {
            if (keccak256(bytes(_supportedAssets[i])) == keccak256(bytes(asset))) {
                _supportedAssets[i] = _supportedAssets[_supportedAssets.length - 1];
                _supportedAssets.pop();
                break;
            }
        }
    }

    function _validatePriceDeviation(string memory asset, uint256 newPrice) internal view {
        uint256 currentPrice = _priceFeeds[asset].price;
        uint256 deviation;

        if (newPrice > currentPrice) {
            deviation = ((newPrice - currentPrice) * BASIS_POINTS) / currentPrice;
        } else {
            deviation = ((currentPrice - newPrice) * BASIS_POINTS) / currentPrice;
        }

        require(deviation <= MAX_PRICE_DEVIATION, "Price deviation too large");
    }
}
