
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract PriceOracleDataContract is Ownable, ReentrancyGuard, Pausable {


    uint256 public constant MAX_DEVIATION = 1000;
    uint256 public constant MIN_UPDATE_INTERVAL = 60;
    uint256 public constant MAX_STALENESS = 3600;
    uint256 public constant BASIS_POINTS = 10000;


    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint256 roundId;
        bool isValid;
    }

    struct DataSource {
        address oracle;
        uint256 weight;
        bool isActive;
        uint256 lastUpdateTime;
    }


    mapping(string => PriceData) private _priceFeeds;
    mapping(string => DataSource[]) private _dataSources;
    mapping(address => bool) private _authorizedUpdaters;
    mapping(string => uint256) private _lastUpdateTimes;

    string[] private _supportedAssets;
    uint256 private _roundId;


    event PriceUpdated(
        string indexed asset,
        uint256 indexed price,
        uint256 indexed roundId,
        uint256 timestamp
    );

    event DataSourceAdded(
        string indexed asset,
        address indexed oracle,
        uint256 weight
    );

    event DataSourceRemoved(
        string indexed asset,
        address indexed oracle
    );

    event UpdaterAuthorized(address indexed updater);
    event UpdaterRevoked(address indexed updater);


    modifier onlyAuthorized() {
        require(_authorizedUpdaters[msg.sender] || msg.sender == owner(), "Unauthorized");
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

    modifier notStale(string memory asset) {
        require(
            block.timestamp - _priceFeeds[asset].timestamp <= MAX_STALENESS,
            "Price data is stale"
        );
        _;
    }

    constructor() {
        _authorizedUpdaters[msg.sender] = true;
        _roundId = 1;
    }


    function updatePrice(
        string memory asset,
        uint256 price
    ) external onlyAuthorized validAsset(asset) validPrice(price) whenNotPaused {
        require(
            block.timestamp >= _lastUpdateTimes[asset] + MIN_UPDATE_INTERVAL,
            "Update too frequent"
        );

        _validatePriceDeviation(asset, price);
        _updatePriceData(asset, price);
    }

    function batchUpdatePrices(
        string[] memory assets,
        uint256[] memory prices
    ) external onlyAuthorized whenNotPaused {
        require(assets.length == prices.length, "Array length mismatch");

        for (uint256 i = 0; i < assets.length; i++) {
            if (_isAssetSupported(assets[i]) && prices[i] > 0) {
                if (block.timestamp >= _lastUpdateTimes[assets[i]] + MIN_UPDATE_INTERVAL) {
                    _updatePriceData(assets[i], prices[i]);
                }
            }
        }
    }

    function getLatestPrice(
        string memory asset
    ) external view validAsset(asset) notStale(asset) returns (uint256, uint256) {
        PriceData memory data = _priceFeeds[asset];
        return (data.price, data.timestamp);
    }

    function getPriceData(
        string memory asset
    ) external view validAsset(asset) returns (PriceData memory) {
        return _priceFeeds[asset];
    }

    function addDataSource(
        string memory asset,
        address oracle,
        uint256 weight
    ) external onlyOwner {
        require(oracle != address(0), "Invalid oracle address");
        require(weight > 0 && weight <= BASIS_POINTS, "Invalid weight");

        if (!_isAssetSupported(asset)) {
            _supportedAssets.push(asset);
        }

        _dataSources[asset].push(DataSource({
            oracle: oracle,
            weight: weight,
            isActive: true,
            lastUpdateTime: 0
        }));

        emit DataSourceAdded(asset, oracle, weight);
    }

    function removeDataSource(
        string memory asset,
        address oracle
    ) external onlyOwner validAsset(asset) {
        DataSource[] storage sources = _dataSources[asset];

        for (uint256 i = 0; i < sources.length; i++) {
            if (sources[i].oracle == oracle) {
                sources[i] = sources[sources.length - 1];
                sources.pop();
                emit DataSourceRemoved(asset, oracle);
                break;
            }
        }
    }

    function authorizeUpdater(address updater) external onlyOwner {
        require(updater != address(0), "Invalid address");
        _authorizedUpdaters[updater] = true;
        emit UpdaterAuthorized(updater);
    }

    function revokeUpdater(address updater) external onlyOwner {
        _authorizedUpdaters[updater] = false;
        emit UpdaterRevoked(updater);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }


    function isAuthorizedUpdater(address updater) public view returns (bool) {
        return _authorizedUpdaters[updater];
    }

    function getSupportedAssets() public view returns (string[] memory) {
        return _supportedAssets;
    }

    function getDataSources(string memory asset) public view returns (DataSource[] memory) {
        return _dataSources[asset];
    }

    function getCurrentRoundId() public view returns (uint256) {
        return _roundId;
    }


    function _updatePriceData(string memory asset, uint256 price) internal {
        _priceFeeds[asset] = PriceData({
            price: price,
            timestamp: block.timestamp,
            roundId: _roundId,
            isValid: true
        });

        _lastUpdateTimes[asset] = block.timestamp;
        _roundId++;

        emit PriceUpdated(asset, price, _roundId - 1, block.timestamp);
    }

    function _validatePriceDeviation(string memory asset, uint256 newPrice) internal view {
        PriceData memory currentData = _priceFeeds[asset];

        if (currentData.isValid && currentData.price > 0) {
            uint256 deviation = _calculateDeviation(currentData.price, newPrice);
            require(deviation <= MAX_DEVIATION, "Price deviation too high");
        }
    }

    function _calculateDeviation(uint256 oldPrice, uint256 newPrice) internal pure returns (uint256) {
        if (oldPrice == 0) return 0;

        uint256 diff = oldPrice > newPrice ? oldPrice - newPrice : newPrice - oldPrice;
        return (diff * BASIS_POINTS) / oldPrice;
    }

    function _isAssetSupported(string memory asset) internal view returns (bool) {
        for (uint256 i = 0; i < _supportedAssets.length; i++) {
            if (keccak256(bytes(_supportedAssets[i])) == keccak256(bytes(asset))) {
                return true;
            }
        }
        return false;
    }
}
